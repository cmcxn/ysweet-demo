# 测试指南

## 问题描述

原始错误信息：
```
ysweet-auth  | 生成 client token 出错 _YSweetError: ServerRefused: Server at 172.18.0.2:8080 refused connection. URL: http://ysweet:8080/doc/new?z=69h6p712ft
```

**根本原因**：auth 服务在 ysweet 服务完全启动并准备好接受连接之前就尝试连接，导致连接被拒绝。

## 解决方案

### 1. 健康检查配置
在 `docker-compose.yml` 中为 ysweet 服务添加健康检查：

```yaml
healthcheck:
  test: ["CMD", "sh", "-c", "wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1"]
  interval: 5s
  timeout: 3s
  retries: 10
  start_period: 15s
```

这确保了：
- 每 5 秒检查一次 ysweet 服务是否就绪
- 给予 15 秒的启动时间（start_period）
- 最多重试 10 次才标记为不健康

### 2. 服务依赖配置
更新 auth 服务的 `depends_on` 配置：

```yaml
depends_on:
  ysweet:
    condition: service_healthy
```

这确保了：
- auth 服务只在 ysweet 服务健康检查通过后才启动
- 避免了过早连接导致的 "ServerRefused" 错误

## 如何测试

### 步骤 1: 清理旧容器
```bash
docker compose down -v
```

### 步骤 2: 构建并启动服务
```bash
docker compose up --build
```

### 步骤 3: 观察启动顺序
正确的启动顺序应该是：
1. ysweet 容器开始构建和启动
2. ysweet 健康检查开始运行
3. 健康检查通过后，auth 服务才开始启动
4. 两个服务都成功运行，没有连接错误

### 步骤 4: 检查服务状态
```bash
docker compose ps
```

应该看到两个服务都处于 `running` 状态，并且 ysweet 服务显示为 `healthy`。

### 步骤 5: 查看日志
```bash
docker compose logs -f
```

应该看到：
- ysweet 服务成功启动的日志
- auth 服务成功连接到 ysweet 的日志
- **不应该** 看到任何 "ServerRefused" 或连接错误

### 步骤 6: 测试功能
1. 打开浏览器访问 `client/index.html`
2. 在输入框中输入文本
3. 在另一个浏览器窗口打开相同的页面
4. 验证文本同步是否正常工作

## 预期结果

✅ **成功的标志**：
- 所有服务启动无错误
- auth 服务成功获取客户端 token
- 客户端可以正常连接和同步数据
- 日志中没有 "ServerRefused" 错误

❌ **如果仍然失败**：
1. 检查 ysweet 服务日志，确认服务正常启动
2. 确认健康检查命令能够执行（wget 在 node:alpine 中可用）
3. 增加 `start_period` 时间，如果服务启动较慢
4. 检查 Docker 网络配置是否正确

## 技术细节

### 为什么使用 wget？
- `wget` 在 `node:alpine` 基础镜像中默认可用
- 不需要安装额外的包（如 curl）
- `--spider` 选项只检查服务是否响应，不下载内容
- `--no-verbose` 减少不必要的日志输出

### 健康检查参数说明
- `interval`: 健康检查的间隔时间
- `timeout`: 单次检查的超时时间
- `retries`: 标记为不健康前的重试次数
- `start_period`: 容器启动后等待多久才开始健康检查（给服务初始化时间）

### Docker Compose 依赖条件
- `service_started`: 仅等待容器启动（默认，不够可靠）
- `service_healthy`: 等待健康检查通过（推荐）
- `service_completed_successfully`: 等待服务完成（用于一次性任务）
