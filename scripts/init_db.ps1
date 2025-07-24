# PowerShell脚本用于初始化PostgreSQL数据库

# 设置默认的数据库连接参数
$DB_USER = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "postgres" }
$DB_PASSWORD = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { "password" }
$DB_NAME = if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { "newsletter" }
$DB_PORT = if ($env:POSTGRES_PORT) { $env:POSTGRES_PORT } else { "5432" }
$DB_HOST = if ($env:POSTGRES_HOST) { $env:POSTGRES_HOST } else { "localhost" }

# 检查psql是否安装
$psqlInstalled = $false
try {
    $null = Get-Command psql -ErrorAction Stop
    $psqlInstalled = $true
    Write-Host "psql is installed locally."
}
catch {
    Write-Warning "Warning: psql is not installed locally."
    Write-Warning "We will try to use Docker for database operations instead."
}

# 检查sqlx是否安装
$sqlxInstalled = $false
try {
    $null = Get-Command sqlx -ErrorAction Stop
    $sqlxInstalled = $true
    Write-Host "sqlx is installed locally."
}
catch {
    Write-Warning "Warning: sqlx is not installed."
    Write-Warning "We will try to continue without it, but you may need to install it later using:"
    Write-Warning "cargo install sqlx-cli --no-default-features --features postgres"
}

# 检查Docker是否安装
try {
    $null = Get-Command docker -ErrorAction Stop
    Write-Host "Docker is installed."
}
catch {
    Write-Error "Error: Docker is not installed or not in PATH."
    exit 1
}

# 检查Docker是否正在运行
try {
    $null = docker info
    Write-Host "Docker is running."
}
catch {
    Write-Error "Error: Docker is not running. Please start Docker Desktop and try again."
    exit 1
}

# 检查是否跳过Docker步骤
if (-not $env:SKIP_DOCKER) {
    # 检查是否已有PostgreSQL容器在运行
    $runningPostgres = docker ps --filter "name=postgres" --format "{{.Names}}" 2>$null
    
    if ($runningPostgres) {
        Write-Host "Notice: PostgreSQL container is already running: $runningPostgres"
    }
    else {
        Write-Host "Starting PostgreSQL container..."
        $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
        docker run `
        -e POSTGRES_USER=$DB_USER `
        -e POSTGRES_PASSWORD=$DB_PASSWORD `
        -e POSTGRES_DB=$DB_NAME `
        -p "${DB_PORT}:5432" `
        -d --name "postgres_$timestamp" `
        postgres `
        postgres -N 1000
    }
}

# 设置数据库连接环境变量
$env:PGPASSWORD = $DB_PASSWORD

# 等待PostgreSQL准备就绪
Write-Host "Waiting for PostgreSQL to be ready..."
$maxAttempts = 30
$attempt = 1

# 循环直到连接成功或达到最大尝试次数
do {
    $connectionSuccessful = $false
    
    if ($psqlInstalled) {
        # 使用本地psql命令
        try {
            $null = psql -h $DB_HOST -U $DB_USER -p $DB_PORT -d "postgres" -c "\q" 2>$null
            $connectionSuccessful = $true
        }
        catch {
            # 本地psql连接失败，继续尝试
        }
    }
    else {
        # 使用Docker中的psql命令
        try {
            $null = docker exec $(docker ps -q -f "name=postgres") psql -U $DB_USER -d "postgres" -c "\q" 2>$null
            $connectionSuccessful = $true
        }
        catch {
            # Docker中psql连接失败，继续尝试
        }
    }
    
    if ($connectionSuccessful) {
        Write-Host "PostgreSQL is up and running on port $DB_PORT!"
    }
    else {
        Write-Host "Attempt ${attempt} of ${maxAttempts}: PostgreSQL is still unavailable - sleeping"
        Start-Sleep -Seconds 1
        $attempt = $attempt + 1
        
        if ($attempt -gt $maxAttempts) {
            Write-Error "Error: Failed to connect to PostgreSQL after ${maxAttempts} attempts."
            exit 1
        }
    }
} while (-not $connectionSuccessful)

# 设置DATABASE_URL环境变量
$env:DATABASE_URL = "postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# 创建数据库和运行迁移
Write-Host "Creating database and running migrations..."

if ($sqlxInstalled) {
    # 使用sqlx命令创建数据库和运行迁移
    sqlx database create
    sqlx migrate run
    Write-Host "PostgreSQL has been migrated using sqlx, ready to go!"
}
else {
    # 使用psql命令创建数据库
    Write-Host "Attempting to create database and run migrations without sqlx..."
    
    # 检查migrations目录是否存在
    if (Test-Path "./migrations") {
        # 获取所有迁移文件并按名称排序
        $migrationFiles = Get-ChildItem "./migrations" -Filter "*.sql" | Sort-Object Name
        
        if ($migrationFiles.Count -gt 0) {
            if ($psqlInstalled) {
                # 使用本地psql创建数据库（如果不存在）
                try {
                    $null = psql -h $DB_HOST -U $DB_USER -p $DB_PORT -d "postgres" -c "CREATE DATABASE $DB_NAME;" 2>$null
                    Write-Host "Database created successfully."
                }
                catch {
                    Write-Host "Database may already exist, continuing..."
                }
                
                # 运行迁移文件
                foreach ($file in $migrationFiles) {
                    Write-Host "Applying migration: $($file.Name)"
                    psql -h $DB_HOST -U $DB_USER -p $DB_PORT -d $DB_NAME -f $file.FullName
                }
            }
            else {
                # 使用Docker中的psql创建数据库和运行迁移
                $postgresContainer = docker ps -q -f "name=postgres"
                
                if ($postgresContainer) {
                    # 创建数据库（如果不存在）
                    docker exec $postgresContainer psql -U $DB_USER -d "postgres" -c "CREATE DATABASE $DB_NAME;" 2>$null
                    
                    # 将迁移文件复制到容器并运行
                    foreach ($file in $migrationFiles) {
                        Write-Host "Applying migration: $($file.Name)"
                        Get-Content $file.FullName | docker exec -i $postgresContainer psql -U $DB_USER -d $DB_NAME
                    }
                }
                else {
                    Write-Error "No PostgreSQL container found. Cannot run migrations."
                    exit 1
                }
            }
            
            Write-Host "PostgreSQL has been migrated manually, ready to go!"
        }
        else {
            Write-Warning "No migration files found in ./migrations directory."
        }
    }
    else {
        Write-Warning "Migrations directory not found. Database setup may be incomplete."
    }
}

Write-Host "Database initialization completed successfully!"
