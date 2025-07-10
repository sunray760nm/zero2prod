# 构建阶段
FROM rust:latest AS builder

WORKDIR /app
RUN apt update && apt install lld clang -y
COPY . .
ENV SQLX_OFFLINE=true
RUN cargo build --release

# 运行时阶段
FROM ubuntu:22.04 AS runtime
WORKDIR /app
# 安装 OpenSSL——通过一些依赖的动态库
# 安装 ca-certificates——在建立HTTPS连接时，需要验证TLS证书
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    # 清理
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
# 从构建环境中复制已编译的二进制文件到运行时环境中
COPY --from=builder /app/target/release/zero2prod zero2prod
# 在运行时需要配置文件
COPY configuration configuration
ENV APP_ENVIRONMENT=production
ENTRYPOINT [ "./zero2prod" ]
