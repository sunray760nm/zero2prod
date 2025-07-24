# 数据库初始化脚本

本目录包含用于初始化PostgreSQL数据库的脚本，支持在Windows和Linux/Ubuntu环境中使用。

## 脚本说明

- `init_db.sh`: Bash脚本，适用于Linux/Ubuntu和macOS环境，也可在Windows的Git Bash、WSL或其他Bash环境中使用
- `init_db.ps1`: PowerShell脚本，为Windows PowerShell和Windows Terminal环境提供更好的支持

## 前置条件

无论使用哪个脚本，都需要满足以下条件：

1. 安装Docker并确保Docker服务正在运行
   - Windows: 安装并启动Docker Desktop
   - Ubuntu: 安装Docker并启动服务 (`sudo systemctl start docker`)

2. 安装PostgreSQL客户端工具
   - Windows: 安装PostgreSQL，确保`psql`命令可用
   - Ubuntu: `sudo apt-get install postgresql-client`

3. 安装SQLx CLI工具
   - 所有平台: `cargo install sqlx-cli --no-default-features --features postgres`

## 使用方法

### 在Windows中使用

1. 打开PowerShell或Windows Terminal
2. 导航到项目根目录
3. 执行PowerShell脚本：
   ```powershell
   .\scripts\init_db.ps1
   ```

### 在Linux/Ubuntu中使用

1. 打开终端
2. 导航到项目根目录
3. 执行Bash脚本：
   ```
   ./scripts/init_db.sh
   ```

### 环境变量

这些脚本支持以下环境变量来自定义数据库连接：

- `POSTGRES_USER`: 数据库用户名（默认：postgres）
- `POSTGRES_PASSWORD`: 数据库密码（默认：password）
- `POSTGRES_DB`: 数据库名称（默认：newsletter）
- `POSTGRES_PORT`: 数据库端口（默认：5432）
- `POSTGRES_HOST`: 数据库主机（默认：localhost）
- `SKIP_DOCKER`: 如果设置，则跳过Docker容器启动步骤

## 故障排除

### Windows环境

- 确保Docker Desktop已启动并正在运行
- 如果遇到权限问题，尝试以管理员身份运行PowerShell或命令提示符
- 确保`psql`和`sqlx`命令在PATH中可用

### Linux/Ubuntu环境

- 确保Docker服务正在运行：`sudo systemctl status docker`
- 如果遇到权限问题：`sudo chmod +x ./scripts/init_db.sh`
- 如果Docker需要sudo权限：将`docker`命令前加上`sudo`或将用户添加到docker组