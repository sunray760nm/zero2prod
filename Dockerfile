# Dockerfile

# 构建阶段
# 使用 cargo-chef 来缓存依赖项，加快后续构建速度
FROM lukemathwalker/cargo-chef:latest-rust-1.88-trixie AS chef
WORKDIR /app
# 安装构建所需的系统依赖
RUN apt update && apt install lld clang -y

# 计划阶段
# 仅复制必要的文件来计算依赖关系
FROM chef AS planner
COPY . .
# 计算项目的依赖蓝图
RUN cargo chef prepare --recipe-path recipe.json

# 构建器阶段
FROM chef AS builder
# 复制依赖蓝图
COPY --from=planner /app/recipe.json recipe.json
# 只编译依赖项，这一层可以被高度缓存
RUN cargo chef cook --release --recipe-path recipe.json

# 【新增】安装 sqlx-cli 工具
# 这个工具将在入口脚本中用来运行数据库迁移
RUN cargo install sqlx-cli --version="~0.7" --no-default-features --features rustls,postgres

# 复制整个项目的源代码
COPY . .
# 设置环境变量，告诉 sqlx 在构建时不要尝试连接数据库
ENV SQLX_OFFLINE=true
# 构建我们的应用程序二进制文件
RUN cargo build --release --bin zero2prod

# 运行时阶段
# 使用一个轻量的 Ubuntu 基础镜像作为最终运行环境
FROM ubuntu:24.04 AS runtime
WORKDIR /app
# 安装运行时所需的最小依赖：OpenSSL 和 PostgreSQL 客户端 (用于 pg_isready)
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl ca-certificates postgresql-client \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# 从构建器阶段复制编译好的应用程序
COPY --from=builder /app/target/release/zero2prod zero2prod

# 【新增】从构建器阶段复制安装好的 sqlx-cli 工具
COPY --from=builder /usr/local/cargo/bin/sqlx /usr/local/bin/sqlx

# 复制应用程序所需的其他文件
COPY configuration configuration
COPY migrations ./migrations
COPY scripts/docker-entrypoint.sh ./docker-entrypoint.sh

# 赋予入口脚本执行权限
RUN chmod +x ./docker-entrypoint.sh

# 设置环境变量，告诉应用程序在生产模式下运行
ENV APP_ENVIRONMENT=production

# 将入口脚本设置为容器的启动命令
ENTRYPOINT ["./docker-entrypoint.sh"]
