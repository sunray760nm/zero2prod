#!/usr/bin/env bash
set -x
set -eo pipefail

# 检测操作系统类型
OS_TYPE="unknown"
case "$(uname -s)" in
    Linux*)     OS_TYPE="linux";;
    Darwin*)    OS_TYPE="mac";;
    CYGWIN*)    OS_TYPE="windows";;
    MINGW*)     OS_TYPE="windows";;
    MSYS*)      OS_TYPE="windows";;
    *)          OS_TYPE="unknown";;
esac

# 检查psql是否安装
check_psql() {
    if command -v psql >/dev/null 2>&1; then
        return 0
    else
        echo >&2 "Error: psql is not installed."
        if [ "$OS_TYPE" = "windows" ]; then
            echo >&2 "Please install PostgreSQL client tools for Windows."
        else
            echo >&2 "On Ubuntu/Debian: sudo apt-get install postgresql-client"
            echo >&2 "On RHEL/CentOS: sudo yum install postgresql"
        fi
        return 1
    fi
}

# 检查sqlx是否安装
check_sqlx() {
    if command -v sqlx >/dev/null 2>&1; then
        return 0
    else
        echo >&2 "Error: sqlx is not installed."
        echo >&2 "Use:"
        echo >&2 "cargo install sqlx-cli --no-default-features --features postgres"
        echo >&2 "to install it."
        return 1
    fi
}

# 在Windows上，我们可能需要使用cargo命令的完整路径
if [ "$OS_TYPE" = "windows" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# 检查必要的命令
check_psql || exit 1
check_sqlx || exit 1

# Check if a custom user has been set, otherwise default to 'postgres'
DB_USER="${POSTGRES_USER:=postgres}"
# Check if a custom password has been set, otherwise default to 'password'
DB_PASSWORD="${POSTGRES_PASSWORD:=password}"
# Check if a custom database name has been set, otherwise default to 'newsletter'
DB_NAME="${POSTGRES_DB:=newsletter}"
# Check if a custom port has been set, otherwise default to '5432'
DB_PORT="${POSTGRES_PORT:=5432}"
# Check if a custom host has been set, otherwise default to 'localhost'
DB_HOST="${POSTGRES_HOST:=localhost}"

# 检查Docker是否安装和运行
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo >&2 "Error: Docker is not installed or not in PATH."
        return 1
    fi
    
    # 检查Docker是否正在运行
    if ! docker info >/dev/null 2>&1; then
        echo >&2 "Error: Docker is not running. Please start Docker and try again."
        if [ "$OS_TYPE" = "windows" ]; then
            echo >&2 "Make sure Docker Desktop is running on Windows."
        else
            echo >&2 "Start Docker service with: sudo systemctl start docker"
        fi
        return 1
    fi
    
    return 0
}

# 检查是否已有PostgreSQL容器在运行
check_existing_postgres() {
    local running_postgres=$(docker ps --filter "name=postgres" --format "{{.Names}}" 2>/dev/null)
    if [ -n "$running_postgres" ]; then
        echo >&2 "Notice: PostgreSQL container is already running: $running_postgres"
        return 0
    fi
    return 1
}

# Launch postgres using Docker
# 如果已经运行了Docker中的Postgres数据库，则允许跳过Docker步骤
if [[ -z "${SKIP_DOCKER}" ]]; then
    # 检查Docker状态
    check_docker || exit 1
    
    # 如果没有运行中的PostgreSQL容器，则启动一个新的
    if ! check_existing_postgres; then
        echo >&2 "Starting PostgreSQL container..."
        docker run \
        -e POSTGRES_USER=${DB_USER} \
        -e POSTGRES_PASSWORD=${DB_PASSWORD} \
        -e POSTGRES_DB=${DB_NAME} \
        -p "${DB_PORT}":5432 \
        -d --name "postgres_$(date +%s)" \
        postgres \
        postgres -N 1000
    fi
fi

# 设置数据库连接环境变量
export PGPASSWORD="${DB_PASSWORD}"

# 定义一个函数来检查数据库连接
check_db_connection() {
    local max_attempts=30
    local attempt=1
    
    echo >&2 "Waiting for PostgreSQL to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if psql -h "${DB_HOST}" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q' >/dev/null 2>&1; then
            echo >&2 "PostgreSQL is up and running on port ${DB_PORT}!"
            return 0
        fi
        
        >&2 echo "Attempt $attempt/$max_attempts: PostgreSQL is still unavailable - sleeping"
        sleep 1
        attempt=$((attempt + 1))
    done
    
    echo >&2 "Error: Failed to connect to PostgreSQL after $max_attempts attempts."
    return 1
}

# 检查数据库连接
check_db_connection || exit 1

# 设置DATABASE_URL环境变量
export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}

# 创建数据库和运行迁移
echo >&2 "Creating database and running migrations..."
sqlx database create
sqlx migrate run

>&2 echo "PostgreSQL has been migrated, ready to go!"
