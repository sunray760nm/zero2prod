#!/bin/bash
# scripts/docker-entrypoint.sh
set -e

# 使用与 Rust 应用一致的环境变量
# APP_DATABASE__HOST 将由 docker-compose.yml 注入
# 其他变量从 .env 文件注入

# 等待数据库准备就绪
echo "Waiting for database to be ready..."
until pg_isready -h "${APP_DATABASE__HOST}" -p "${APP_DATABASE__PORT}" -U "${APP_DATABASE__USERNAME}"; do
  echo "Database is unavailable - sleeping"
  sleep 1
done

echo "Database is ready!"

# 执行数据库迁移
echo "Running database migrations..."
export DATABASE_URL="postgres://${APP_DATABASE__USERNAME}:${APP_DATABASE__PASSWORD}@${APP_DATABASE__HOST}:${APP_DATABASE__PORT}/${APP_DATABASE__DATABASE_NAME}"
sqlx database create # 使用 sqlx-cli，更加健壮
sqlx migrate run

echo "Database setup completed!"

# 启动应用程序
echo "Starting application..."
exec ./zero2prod