//! src/configuration.rs
use std::fmt::format;

use secrecy::Secret;
use secrecy::ExposeSecret;

#[derive(serde::Deserialize)]
pub struct Settings {
    pub database: DatabaseSettings,
    pub application: ApplicationSettings,
}

#[derive(serde::Deserialize)]
pub struct ApplicationSettings {
    pub port: u16,
    pub host: String,
}

#[derive(serde::Deserialize)]
pub struct DatabaseSettings {
    pub username: String,
    pub password: Secret<String>,
    pub port: u16,
    pub host: String,
    pub database_name: String,
}

pub fn get_configuration() -> Result<Settings, config::ConfigError> {
    let base_path = std::env::current_dir().expect(
        "Failed to determine the current directory");
    let configuration_directory = base_path.join("configuration");

    // 检查运行环境
    // 如果没有指定则默认是“local”
    let environment: Environment = std::env::var("APP_ENVIRONMENT")
        .unwrap_or_else(|_| "local".into())
        .try_into()
        .expect("Failed to parse APP_ENVIRONMENT");

    let environment_filename = format!("{}.yaml", environment.as_str()); 

    // 初始化配置读取器
    let settings = config::Config::builder()
        .add_source(config::File::from(configuration_directory.join("base.yaml")))
        .add_source(config::File::from(configuration_directory.join(&environment_filename)))
        .build()?;

    // 尝试将其读取到的配置值转换为Settings类型
    settings.try_deserialize::<Settings>()
}

/// 应用程序可能的运行时环境
pub enum Environment {
    Local,
    Production,
}

impl Environment {
    pub fn as_str(&self) -> &'static str {
        match self {
            Environment::Local => "local",
            Environment::Production => "production",
        }
    }
}

impl TryFrom<String> for Environment {
    type Error = String;
    fn try_from(s: String) -> Result<Self, Self::Error> {
        match s.to_lowercase().as_str() {
            "local" => Ok(Self::Local),
            "production" => Ok(Self::Production),
            other => Err(format!(
                "'{}' is not a supported environment. Use either 'local' or 'production'.",
                other
            )),
        }
    }
}

impl DatabaseSettings {
    pub fn connection_string(&self) ->Secret<String> {
        Secret::new(
            format!(
                "postgres://{}:{}@{}:{}/{}",
                self.username,
                self.password.expose_secret()   ,
                self.host,
                self.port,
                self.database_name,
            )
        )
    }

    pub fn connection_string_without_db(&self) -> Secret<String> {
        Secret::new(
            format!(
                "postgres://{}:{}@{}:{}",
                self.username,
                self.password.expose_secret(),
                self.host,
                self.port
            )
        )
    }
}
