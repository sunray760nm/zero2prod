//! src/routes/health_check.rs
use actix_web::{HttpRequest, HttpResponse};

/// 健康检查端点
pub async fn health_check(_req: HttpRequest) -> HttpResponse {
    HttpResponse::Ok().body("Health check passed!")
}
