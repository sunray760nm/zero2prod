#!/bin/bash
set -e

# 等待数据库准备就绪
echo "Waiting for database to be ready..."
until pg_isready -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}"; do
  echo "Database is unavailable - sleeping"
  sleep 2
done

echo "Database is ready!"

# 执行数据库迁移
echo "Running database migrations..."

# 构建数据库连接字符串
DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-5432}
DB_USER=${DB_USER:-postgres}
DB_PASSWORD=${DB_PASSWORD:-password}
DB_NAME=${DB_NAME:-newsletter}

DATABASE_URL="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

# 创建数据库（如果不存在）
echo "Creating database if not exists..."
psql "postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/postgres" -c "CREATE DATABASE ${DB_NAME};" 2>/dev/null || echo "Database ${DB_NAME} already exists or creation failed, continuing..."

# 执行迁移脚本
echo "Executing migration scripts..."
for migration_file in /app/migrations/*.sql; do
    if [ -f "$migration_file" ]; then
        echo "Executing migration: $(basename "$migration_file")"
        psql "$DATABASE_URL" -f "$migration_file" || {
            echo "Migration failed: $(basename "$migration_file")"
            echo "This might be normal if the migration was already applied."
        }
    fi
done

echo "Database setup completed!"

# 启动应用程序
echo "Starting application..."
exec "./zero2prod"