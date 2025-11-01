# Y-Sweet 快速启动示例

## 运行步骤
1. 验证配置：`./validate-docker-config.sh`
2. 启动服务：`docker compose up --build`
3. 打开 `client/index.html`，在两个浏览器窗口中测试共享同步。

## 架构说明
- **ysweet 服务**：在端口 8080 上提供 Y-Sweet WebSocket 服务器，并显式监听 `0.0.0.0` 以供其他容器访问，数据持久化到 MinIO 的 S3 兼容存储
- **auth 服务**：在端口 3001 上提供认证 API (`/api/auth`)
- **minio 服务**：在端口 9000（API）和 9001（控制台）提供 S3 兼容对象存储
- **minio-create-bucket**：一次性初始化容器，用于创建 `ysweet-data` bucket
- **client**：浏览器端应用，连接到 ysweet 和 auth 服务

## 注意事项
- MinIO 管理地址：http://localhost:9001，默认账号密码：`ysweetadmin` / `ysweetsecret`
- MinIO S3 端点：http://localhost:9000，Y-Sweet 使用 bucket `ysweet-data`
- auth 服务使用 Docker 服务名 `ysweet:8080` 进行容器间通信
- 客户端使用 `localhost:8080` 从浏览器连接到 ysweet 服务（通过端口映射）
- 可以通过设置 `PUBLIC_YSWEET_URL`（默认为 `ws://localhost:8080`）来控制发给浏览器的 WebSocket 访问地址，
  确保在 Docker 外部访问时不会收到 `ws://ysweet:8080` 这样的内部主机名

## Docker 网络配置
为了确保 auth 服务能够正确连接到 ysweet 服务，已配置以下机制：
- **健康检查**：ysweet 服务配置了基于 TCP 的健康检查（`nc -z localhost 8080`），确保服务完全启动后才接受连接
- **服务依赖**：auth 服务配置为等待 ysweet 服务健康后才启动（`depends_on.condition: service_healthy`）
- 这样可以避免 "dependency failed to start: container ysweet is unhealthy" 错误

## 测试
详细的测试步骤和故障排除指南，请参考 [TESTING.md](TESTING.md)。

快速验证配置：
```bash
./validate-docker-config.sh
```

完整端到端测试：
```bash
./test-docker-setup.sh
```
