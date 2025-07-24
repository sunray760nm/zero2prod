#!/bin/bash
set -e

echo "Building Rust app..."
cargo build

echo "Running tests..."
cargo test

echo "Starting app in background..."
cargo run &
APP_PID=$!

# 等待服务启动（可根据实际情况调整时间）
sleep 3

echo "Testing health_check endpoint..."
curl -v http://127.0.0.1:8000/health_check

echo "Killing app..."
kill $APP_PID