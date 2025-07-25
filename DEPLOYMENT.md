# Zero2Prod 容器化部署指南

## 概述

本项目已经优化为完全容器化的部署方案，特别适合国内开发环境。通过将数据库迁移集成到 Docker 容器中，避免了在服务器上安装 Rust 工具链的复杂性。

## 部署架构

```
Windows 本地开发 → Docker 镜像构建 → 镜像仓库 → 服务器拉取部署
```

## 主要改进

### 1. 自动化数据库迁移
- 容器启动时自动执行数据库迁移
- 无需在服务器上安装 `sqlx-cli`
- 包含数据库连接检查和重试机制

### 2. 容器化配置
- 迁移文件打包到镜像中
- 启动脚本处理数据库初始化
- 环境变量配置数据库连接

## 本地开发

### 启动开发环境
```bash
# 构建并启动所有服务
docker-compose up --build

# 后台运行
docker-compose up -d --build
```

### 查看日志
```bash
# 查看应用日志
docker-compose logs app

# 查看数据库日志
docker-compose logs postgres

# 实时跟踪日志
docker-compose logs -f app
```

### 停止服务
```bash
docker-compose down

# 同时删除数据卷
docker-compose down -v
```

## 生产部署

### 1. 构建生产镜像
```bash
# 构建镜像
docker build -t zero2prod:latest .

# 标记为阿里云镜像
docker tag zero2prod:latest registry.cn-hangzhou.aliyuncs.com/your-namespace/zero2prod:latest

# 推送到阿里云容器镜像服务
docker push registry.cn-hangzhou.aliyuncs.com/your-namespace/zero2prod:latest
```

### 2. 服务器部署
```bash
# 拉取镜像
docker pull registry.cn-hangzhou.aliyuncs.com/your-namespace/zero2prod:latest
docker pull postgres:15

# 使用 docker-compose 部署
docker-compose -f docker-compose.prod.yml up -d
```

### 3. 生产环境 docker-compose.yml 示例
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: your_secure_password
      POSTGRES_DB: newsletter
    volumes:
      - pgdata:/var/lib/postgresql/data
    restart: unless-stopped
    
  app:
    image: registry.cn-hangzhou.aliyuncs.com/your-namespace/zero2prod:latest
    depends_on:
      - postgres
    environment:
      DATABASE_URL: postgres://postgres:your_secure_password@postgres/newsletter
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: your_secure_password
      DB_NAME: newsletter
    ports:
      - "8000:8000"
    restart: unless-stopped

volumes:
  pgdata:
```

## 数据库迁移说明

### 自动迁移流程
1. 容器启动时等待数据库就绪
2. 检查并创建目标数据库
3. 执行 `migrations/` 目录下的所有 SQL 文件
4. 启动应用程序

### 手动迁移（如需要）
```bash
# 进入应用容器
docker exec -it <container_name> bash

# 手动执行迁移
psql $DATABASE_URL -f /app/migrations/20250616095146_create_subscriptions_table.sql
```

## 测试接口

### 健康检查
```bash
curl http://localhost:8000/health_check
```

### 订阅接口
```bash
curl -X POST http://localhost:8000/subscriptions \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "name=John Doe&email=john@example.com"
```

## 故障排除

### 查看容器状态
```bash
docker ps
docker-compose ps
```

### 检查数据库连接
```bash
# 连接到数据库容器
docker exec -it <postgres_container> psql -U postgres -d newsletter

# 检查表是否存在
\dt

# 查看订阅数据
SELECT * FROM subscriptions;
```

### 重新构建和部署
```bash
# 停止所有服务
docker-compose down

# 重新构建镜像
docker-compose build --no-cache

# 启动服务
docker-compose up -d
```

## 优势总结

✅ **避免网络问题**：无需在服务器上下载 Rust 工具链  
✅ **自动化部署**：数据库迁移自动执行  
✅ **环境一致性**：开发和生产环境完全一致  
✅ **易于维护**：容器化管理，便于版本控制和回滚  
✅ **适合国内**：避免了 crates.io 访问问题