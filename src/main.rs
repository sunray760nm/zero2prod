//! main.rs

use zero2prod::run;
use std::net::TcpListener;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let listener = TcpListener::bind("127.0.0.1:0")
        .expect("Failed to bind random port");

    // 如果绑定地址失败，则会发生io：：Error
    // 否则，在服务器上调用await
    run(listener)?.await
}
