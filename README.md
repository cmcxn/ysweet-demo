# Y-Sweet 快速启动示例

## 运行步骤
1. 启动服务：`docker-compose up --build`
2. 打开 `client/index.html`，在两个浏览器窗口中测试共享同步。

## 架构说明
- **ysweet 服务**：在端口 8080 上提供 Y-Sweet 服务器
- **auth 服务**：在端口 3001 上提供认证 API (`/api/auth`)
- **client**：浏览器端应用，连接到 ysweet 和 auth 服务

## 注意事项
- auth 服务使用 Docker 服务名 `ysweet:8080` 进行容器间通信
- 客户端使用 `localhost:8080` 从浏览器连接到 ysweet 服务（通过端口映射）

## Docker 网络配置
为了确保 auth 服务能够正确连接到 ysweet 服务，已配置以下机制：
- **健康检查**：ysweet 服务配置了健康检查，确保服务完全启动后才接受连接
- **服务依赖**：auth 服务配置为等待 ysweet 服务健康后才启动（`depends_on.condition: service_healthy`）
- 这样可以避免 "ServerRefused" 连接错误，因为 auth 服务只会在 ysweet 服务准备好后才尝试连接
