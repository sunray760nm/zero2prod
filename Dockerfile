# 构建阶段
FROM rust:latest AS builder

WORKDIR /app
RUN apt update && apt install lld clang -y
COPY . .
ENV SQLX_OFFLINE=true
RUN cargo build --release

# 运行阶段
FROM rust:latest AS runtime

WORKDIR /app

# 从构建环境中复制已编译的二进制文件到运行时环境中
COPY --from=builder /app/target/release/zero2prod zero2prod
# 在运行时需要配置文件
COPY configuration configuration
ENV APP_ENVIRONMENT=production
ENTRYPOINT [ "./zero2prod" ]
