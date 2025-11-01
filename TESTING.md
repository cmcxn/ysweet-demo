# 测试指南

## 问题描述

原始错误信息：
```
dependency failed to start: container ysweet is unhealthy
```

**根本原因**：ysweet 服务的健康检查配置不正确。原配置使用 `wget --spider http://localhost:8080/` 检查 HTTP 端点，但 y-sweet 主要是一个 WebSocket 服务器，可能不会在根路径 `/` 响应 HTTP 请求，导致健康检查失败。

## 解决方案

### 1. 健康检查配置优化
在 `docker-compose.yml` 中更新 ysweet 服务的健康检查，使用 TCP 连接检查：

```yaml
healthcheck:
  test: ["CMD", "sh", "-c", "nc -z localhost 8080 || exit 1"]
  interval: 5s
  timeout: 3s
  retries: 10
  start_period: 15s
```

**优势**：
- 使用 `nc -z` (netcat) 进行 TCP 端口检查，更适合 WebSocket 服务器
- `nc` 在 `node:20-alpine` 镜像中默认可用，无需额外安装
- TCP 检查比 HTTP 检查更可靠，因为只需要确认端口监听即可
- 每 5 秒检查一次，给予 15 秒的启动时间（start_period）
- 最多重试 10 次才标记为不健康

### 2. 服务依赖配置
保持 auth 服务的 `depends_on` 配置：

```yaml
depends_on:
  ysweet:
    condition: service_healthy
```

这确保了：
- auth 服务只在 ysweet 服务健康检查通过后才启动
- 避免了过早连接导致的 "ServerRefused" 错误

### 3. Dockerfile 优化
移除了中国镜像源配置，使用标准 npm registry，提高兼容性：

**Dockerfile**:
```dockerfile
FROM node:20-alpine
RUN npm install -g y-sweet
WORKDIR /app/data
EXPOSE 8080
CMD ["y-sweet", "serve", "/app/data"]
```

**backend/Dockerfile.auth**:
```dockerfile
FROM node:20-alpine
WORKDIR /app/backend
COPY package.json package-lock.json* ./
RUN npm install --production
COPY . .
EXPOSE 3001
CMD ["node", "server.js"]
```

## 如何测试

### 快速验证（推荐）

使用提供的验证脚本快速检查配置：

```bash
./validate-docker-config.sh
```

这个脚本会验证：
- ✅ docker-compose.yml 配置语法
- ✅ 健康检查使用 nc (netcat) 进行 TCP 检查
- ✅ 服务依赖配置正确
- ✅ 端口映射配置
- ✅ 环境变量配置
- ✅ Dockerfile 文件存在性
- ✅ 必要的依赖项

### 完整测试流程

### 步骤 1: 验证配置
```bash
./validate-docker-config.sh
```

### 步骤 2: 清理旧容器
```bash
docker compose down -v
```

### 步骤 3: 构建并启动服务
```bash
docker compose up --build
```

### 步骤 4: 观察启动顺序
正确的启动顺序应该是：
1. ysweet 容器开始构建和启动
2. ysweet 健康检查开始运行（使用 `nc -z localhost 8080`）
3. 健康检查通过后，auth 服务才开始启动
4. 两个服务都成功运行，没有连接错误

### 步骤 5: 检查服务状态
```bash
docker compose ps
```

应该看到：
- ysweet 服务处于 `running (healthy)` 状态
- auth 服务处于 `running` 状态

### 步骤 6: 查看日志
```bash
docker compose logs -f
```

应该看到：
- ysweet 服务成功启动的日志：`Listening on ws://127.0.0.1:8080`
- auth 服务成功启动的日志：`Auth 服务器已启动，监听端口 3001`
- **不应该** 看到任何 "ServerRefused" 或 "unhealthy" 错误

### 步骤 7: 测试功能
1. 打开浏览器访问 `client/index.html`
2. 在输入框中输入文本
3. 在另一个浏览器窗口打开相同的页面
4. 验证文本同步是否正常工作


## 预期结果

✅ **成功的标志**：
- 配置验证脚本所有测试通过
- 所有服务启动无错误
- ysweet 服务显示为 `healthy` 状态
- auth 服务成功获取客户端 token
- 客户端可以正常连接和同步数据
- 日志中没有 "ServerRefused" 或 "unhealthy" 错误

❌ **如果仍然失败**：
1. 运行 `./validate-docker-config.sh` 检查配置
2. 检查 ysweet 服务日志：`docker compose logs ysweet`
3. 检查健康检查日志：`docker inspect --format='{{json .State.Health}}' ysweet`
4. 确认 nc (netcat) 可用：`docker run --rm node:20-alpine which nc`
5. 增加 `start_period` 时间，如果服务启动较慢
6. 检查 Docker 网络配置是否正确

## 技术细节

### 为什么使用 nc (netcat)？
- **TCP 端口检查**：`nc -z localhost 8080` 只检查端口是否监听，不需要 HTTP 协议
- **适合 WebSocket**：y-sweet 是 WebSocket 服务器，TCP 检查比 HTTP 检查更可靠
- **默认可用**：`nc` 在 `node:20-alpine` 基础镜像中默认可用（BusyBox 版本）
- **轻量高效**：不下载任何内容，只检查连接性
- **无需额外包**：不需要安装 curl 或 wget

### 为什么不使用 wget？
- y-sweet 主要提供 WebSocket 服务，HTTP 端点可能有限
- 根路径 `/` 可能不返回 200 状态码
- 需要正确的 HTTP 响应，而 TCP 检查只需要端口监听

### 健康检查参数说明
- `test`: 执行的健康检查命令
- `interval`: 健康检查的间隔时间（5秒）
- `timeout`: 单次检查的超时时间（3秒）
- `retries`: 标记为不健康前的重试次数（10次）
- `start_period`: 容器启动后等待多久才开始健康检查（15秒，给服务初始化时间）

### Docker Compose 依赖条件
- `service_started`: 仅等待容器启动（默认，不够可靠）
- `service_healthy`: 等待健康检查通过（推荐，已采用）
- `service_completed_successfully`: 等待服务完成（用于一次性任务）

## 自动化测试

项目提供了两个测试脚本：

### 1. validate-docker-config.sh
快速验证配置文件，不需要构建镜像：
```bash
./validate-docker-config.sh
```

### 2. test-docker-setup.sh
完整的端到端测试，包括构建、启动和功能测试：
```bash
./test-docker-setup.sh
```

这个脚本会：
- 验证配置文件
- 构建 Docker 镜像
- 启动服务
- 等待健康检查
- 测试 API 端点
- 检查日志中的错误
- 提供详细的测试报告
