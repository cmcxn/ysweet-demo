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
