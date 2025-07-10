# 我们使用最新的rust稳定版作为基础镜像
FROM rust:latest
# 把工作目录切换到‘app'，相当于’cd app‘
# ’app'文件夹将由Docker为我们创建，防止它不存在
WORKDIR /app
# 为链接配置安装所需的系统依赖
RUN apt update && apt install lld clang -y
# 将工作中的所有文件复制到Docker镜像中
COPY . .
ENV SQLX_OFFLINE=true
# 开始构建二进制文件
# 使用release参数优化以提高速度
RUN cargo build --release
# 当执行‘docker run’时启动二进制文件
ENTRYPOINT ["./target/release/zero2prod"]

