//! tests/health_check.rs
use std::net::TcpListener;
use reqwest;
use sqlx::{PgConnection, Connection};
use zero2prod::configuration::{get_configuration};

#[tokio::test]
async fn subscribe_return_a_200_for_valid_form_data() {
    // 准备
    let app_address = spawn_app();
    let configration = get_configuration()
        .expect("Failed to read configration");
    let connection_string = configration.database.connection_string();
    // 为了调用 ‘PgConnection::connect’, 'Connection'特质必须位于作用于内
    // 它不该结构体的内在方法
    let mut connection = PgConnection::connect(&connection_string)
    .await
    .expect("Failed to connect to Postgres.");
    let client = reqwest::Client::new();

    // 执行
    let body = "name=le%20guin&email=ursula_le_guin%40gmail.com";
    let response = client
        .post(&format!("{}/subscriptions", &app_address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    // 断言
    assert_eq!(200, response.status().as_u16());

    let saved = sqlx::query!("SELECT email, name FROM subscriptions")
        .fetch_one(&mut connection)
        .await
        .expect("Failed to fetch saved subscriptions");

    assert_eq!(saved.email, "ursula_le_guin@gmail.com");
    assert_eq!(saved.name, "le guin");
}

#[tokio::test]
async fn health_check_works() {
    let address = spawn_app();
    let client = reqwest::Client::new();
    let response = client
        .get(&format!("{}/health_check", &address))
        .send()
        .await
        .expect("Failed to execute request");
    
    assert!(response.status().is_success());
    assert_eq!(
        response.text().await.expect("Failed to read response body"),
        "Health check passed!"
    );
}

#[tokio::test]
async fn subscribe_return_a_400_when_data_is_missing() {
    let app_address = spawn_app();
    let client = reqwest::Client::new();
    let test_cases = vec![
        ("name=le%20guin", "missing the email"),
        ("email=ursula_le_guin%40gmail.com", "missing the name"),
        ("", "missing both name and email"),
    ];

    for (invalid_body, error_message) in test_cases {
        let response = client
            .post(&format!("{}/subscriptions", &app_address))
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body(invalid_body)
            .send()
            .await
            .expect("Failed to execute request");

        assert_eq!(
            400,
            response.status().as_u16(),
            "The API did not fail with 400 Bad Request when the payload was {}",
            error_message
        )
    }
}

fn spawn_app() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind random port");
    let port = listener.local_addr().unwrap().port();
    println!("---- port :{}", port);
    
    let server = zero2prod::startup::run(listener).expect("Failed to bind address");
    tokio::spawn(server); // ✅ 正确启动服务器
    
    format!("http://127.0.0.1:{}", port)
}
