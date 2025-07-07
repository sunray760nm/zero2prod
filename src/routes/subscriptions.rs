//! src/routes/subscriptions.rs
use actix_web::{web, HttpResponse};
use sqlx::PgPool;
use chrono::{DateTime, Utc};
use uuid::Uuid;
use tracing::Instrument;

#[derive(serde::Deserialize)]
pub struct FormData {
    pub email: String,
    pub name: String,
}

/// 订阅端点
pub async fn subscribe(
    form: web::Form<FormData>,
    // 从应用程序状态中取出连接
    pool: web::Data<PgPool>
) -> HttpResponse {
    let request_id = Uuid::new_v4();
    // Spans, like logs, have an associated level
    // 'info_span' create a span at info-level
    let request_span = tracing::info_span!(
        "Adding a new subscriber.",
        %request_id,
        subscriber_email = %form.email,
        subscriber_name = %form.name
    );
    // Using 'enter' in an async function is a recipe for disaster!
    // Bear with me for now, but don't do this at home.
    // See the following section on 'Instrumenting Futures'
    let _request_span_guard = request_span.enter();

    // We do not call '.enter' on query_span !
    // '.instrument' take care of it at the right moments
    // in the query futher lifetime  
    let query_span = tracing::info_span!(
        "Saving new subscriber details in the database"
    );

    

    // '_request_span_guard' is dropped at the end of 'subscribe'
    // that when we exit the span
    tracing::info!("request_id {} - Saving new subscriber details in the database", request_id);

    match sqlx::query!(
        r#"
        INSERT INTO subscriptions (id, email, name, subscribed_at)
        VALUES ($1, $2, $3, $4)
        "#,
        Uuid::new_v4(),
        form.email,
        form.name,
        Utc::now() as DateTime<Utc>
    )
    // 使用 get_ref 来获取一个不可变引用
    // 引用到由‘web：：Data’包装的‘PgConnection'
    .execute(pool.get_ref())
    // first we attach the instrumentation, then we '.await' it
    .instrument(query_span)
    .await
    {
        Ok(_) => {
            tracing::info!("request id {} - New subscriber details have been saved", request_id);
            HttpResponse::Ok().finish()
        }
        Err(e) => {
            tracing::error!("request id {} - Failed to execute query: {:?}", request_id, e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

