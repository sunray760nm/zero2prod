//! src/main.rs
use zero2prod::configuration::get_configuration;
use zero2prod::startup::run;
use sqlx::PgPool;
use sqlx::postgres::PgPoolOptions;
use zero2prod::telemetry::{get_subscriber, init_subscriber};
use std::net::TcpListener;
use secrecy::ExposeSecret;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let subscriber = 
        get_subscriber("zero2prod".into(), "info".into(), std::io::stdout);
    init_subscriber(subscriber);

    let configuration = get_configuration().expect("Failed to read configurations");
    let connection_pool = PgPoolOptions::new()
        .acquire_timeout(std::time::Duration::from_secs(2))
        .connect_lazy(
            &configuration.database.connection_string().expose_secret()
        )
        .expect("Failed to connect Postpres.");
    let address = format!("{}:{}",  
        configuration.application.host, 
        configuration.application.port);
    let listener = TcpListener::bind(address)?;
    // 如果绑定地址失败，则会发生io：：Error
    // 否则，在服务器上调用await
    run(listener, connection_pool)?.await?;
    Ok(())
}
