#!/usr/bin/env bash
set -x
set -eo pipefail

if ! [ -x "$(command -v psql)" ]; then
    echo >&2 "Error: psql is not installed".
    exit 1
fi

if ! [ -x "$(command -v sqlx)" ]; then
    echo >&2 "Error: sqlx is not installed".
    echo >&2 "Use:"
    echo >&2 "Cargo install --version=0.6.0 sqlx-cli --no-default-features --features postgres"
    echo >&2 "to install it."
    exit 1
fi

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

# Launch postgres using Docker
# 如果已经运行了Docker中的Postgres数据库，则允许跳过Docker步骤
if [[ -z "${SKIP_DOCKER}" ]]
then
    docker run \
    -e POSTGRES_USER=${DB_USER} \
    -e POSTGRES_PASSWORD=${DB_PASSWORD} \
    -e POSTGRES_DB=${DB_NAME} \
    -p "${DB_PORT}":5432 \
    -d postgres \
    postgres -N 1000
fi

#保持对 Postgres 的轮询，直到它准备好接受命令
export PGPASSWORD="${DB_PASSWORD}"
until psql -h "localhost" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q'; do
    >&2 echo "Postgres is still unvalidable - sleeping"
    sleep 1
done

>&2 echo "Postgress is up and running on port ${DB_PORT}!"

export DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@localhost:${DB_PORT}/${DB_NAME} 
sqlx database create
sqlx migrate run

>&2 echo "Postgres has been migrated, ready to go"
