//! lib.rs

use actix_web::{web, App, HttpRequest, HttpResponse, HttpServer, Responder};
use actix_web::dev::Server;
use std::net::TcpListener;


async fn health_check(_req: HttpRequest) -> HttpResponse {
    HttpResponse::Ok().finish()
}

// 我们以一种简单的方式开始，总是返回200 OK
async fn subscribe() -> HttpResponse {
    HttpResponse::Ok().finish()
}

// 注意不同的函数起那命
// 在正常情况下返回“Server”，并删除了‘async’关键字
// 没有进行.await调用，所以不再需要它了
pub fn run(listener: TcpListener) -> Result<Server, std::io::Error> {
    let server = HttpServer::new(||{
        App::new()
            .route("/health_check", web::get().to(health_check))
            // 为POST /subscription 在请求路由表中添加一个新条目
            .route("/subscription", web::post().to(subscribe))
    })
        .listen(listener)?
        .run();
    // 此处没有await
    Ok(server)
}
