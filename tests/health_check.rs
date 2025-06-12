//! tests/health_check.rs

use reqwest;
use std::net::TcpListener;
// use zero2prod::run;

// 'tokio::test'是‘tokio::main'的测试等价物
// 他还使你不必指定‘#[test]'属性
//
// 你可以使用一下命令检查生成了哪些代码
// ‘cargo expand --test health_check'（<-测试文件名）

#[tokio::test]
async fn health_check_works() {
    // 准备
    let address = spawn_app();
    // 需要引入‘reqwest’对应用程序执行HTTP请求
    let client = reqwest::Client::new();

    // 执行
    let response = client
        .get(&format!("{}/health_check", &address))
        .send()
        .await
        .expect("Failed to execute request");

    // 断言
    assert!(response.status().is_success());
    assert_eq!(
        response.text().await.expect("Failed to read response body"),
        "Health check passed!"
    );
}

// 此处没有.await调用，因此spawn_app函数不需要是异步的
// 我们也在此测试，所以传播错误是不值得的
// 如果未能执行初始化，则可能会发生panic并让所有的工作崩溃

fn spawn_app() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind random port");
    let port = listener.local_addr().unwrap().port();
    println!("---- port :{}", port);
    let server = zero2prod::run(listener).expect("Failed to bind address");
    // 启动服务器作为后台
    // tokio：：spawn指向一个spawned future的handle
    // 但是这里没有用它，因为这是非绑定的let方法
    let _ = tokio::spawn(server);
    // 将应用程序的地址返回给调用者
    format!("http://127.0.0.1:{}", port)
}

#[tokio::test]
async fn subscribe_return_a_200_for_valid_form_data() {
    // 准备
    let app_address = spawn_app();
    let client = reqwest::Client::new();

    // 执行
    let body = "name=le%20guin&email=ursula_le_guin%40gmail.com";
    let response = client
        .post(&format!("{}/subscription", app_address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    // 断言
    assert_eq!(200, response.status().as_u16());
}

#[tokio::test]
async fn subscribe_return_a_400_when_data_is_missing() {
    // prepare
    let app_address = spawn_app();
    let client = reqwest::Client::new();
    let test_cases = vec![
        ("name=le%20guin", "missing the email"),
        ("email=ursula_le_guin%40gmail.com", "missing the name"),
        ("", "missing both name and email"),
    ];

    for (invalid_bady, error_message) in test_cases {
        // excute
        let response = client
            .post(&format!("{}/subscriptions", &app_address))
            .header("Content-Type", "applicaton/x-www-form-urlencoded")
            .body(invalid_bady)
            .send()
            .await
            .expect("Failed to execute request");

        // assert
        assert_eq!(
            404,
            response.status().as_u16(),
            "The API did not fail with 400 Bad Request when the payload was {}",
            error_message
        )
    }
}
