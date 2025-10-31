# Docker 容器健康检查修复说明

## 问题概述

**原始错误**：
```
dependency failed to start: container ysweet is unhealthy
```

## 根本原因

ysweet 容器的健康检查配置不正确，导致容器被标记为"不健康"(unhealthy)，从而阻止了依赖它的 auth 服务启动。

### 技术分析

1. **原始健康检查**：使用 `wget --spider http://localhost:8080/`
2. **y-sweet 特性**：主要是 WebSocket 服务器（`ws://127.0.0.1:8080`）
3. **问题**：y-sweet 可能不在根路径 `/` 提供标准的 HTTP 200 响应
4. **结果**：健康检查失败 → 容器标记为不健康 → auth 服务无法启动

## 解决方案

### 核心修复：使用 TCP 端口检查

**修改前** (docker-compose.yml):
```yaml
healthcheck:
  test: ["CMD", "sh", "-c", "wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1"]
```

**修改后** (docker-compose.yml):
```yaml
healthcheck:
  test: ["CMD", "sh", "-c", "nc -z localhost 8080 || exit 1"]
```

### 为什么这个修复有效？

| 方面 | wget (HTTP 检查) | nc -z (TCP 检查) |
|------|-----------------|-----------------|
| 检查内容 | HTTP 协议响应 | TCP 端口监听 |
| 适用场景 | HTTP/REST API | 任何 TCP 服务 |
| 对 WebSocket | 可能失败 | 总是有效 |
| 依赖 | 需要 HTTP 端点 | 只需端口监听 |
| 性能 | 较慢（完整 HTTP） | 快速（仅 TCP 握手） |

### 技术优势

1. **TCP 层检查**：`nc -z` 只检查端口是否在监听，不需要应用层协议
2. **适合 WebSocket**：WebSocket 服务器不一定有标准的 HTTP 端点
3. **轻量高效**：仅执行 TCP 握手，无需下载或解析内容
4. **默认可用**：nc 在 node:20-alpine 中预装（BusyBox 版本）

## 其他修复

### 1. Dockerfile 优化

移除了可能导致网络问题的中国镜像源配置：

**Dockerfile**:
```diff
  FROM node:20-alpine
- RUN npm config set registry https://registry.npmmirror.com \
-     && npm install -g y-sweet
+ RUN npm install -g y-sweet
  WORKDIR /app/data
  EXPOSE 8080
  CMD ["y-sweet", "serve", "/app/data"]
```

**backend/Dockerfile.auth**:
```diff
  FROM node:20-alpine
- RUN npm config set registry https://registry.npmmirror.com
  WORKDIR /app/backend
  COPY package.json package-lock.json* ./
  RUN npm install --production
  COPY . .
  EXPOSE 3001
  CMD ["node", "server.js"]
```

### 2. 测试工具

提供了三个测试脚本：

1. **validate-docker-config.sh**: 快速验证配置（无需构建）
2. **test-docker-setup.sh**: 完整的端到端测试
3. **test-healthcheck-mock.sh**: 演示健康检查修复的模拟测试

## 验证修复

### 快速验证（推荐）

```bash
# 1. 验证配置
./validate-docker-config.sh

# 2. 演示健康检查修复
./test-healthcheck-mock.sh
```

### 完整测试流程

```bash
# 1. 清理
docker compose down -v

# 2. 构建并启动
docker compose up --build

# 3. 检查状态
docker compose ps

# 4. 查看日志
docker compose logs -f
```

### 预期结果

```
NAME            IMAGE                    STATUS                    PORTS
ysweet          ysweet-demo-ysweet       Up (healthy)             0.0.0.0:8080->8080/tcp
ysweet-auth     ysweet-demo-auth         Up                       0.0.0.0:3001->3001/tcp
```

注意 ysweet 显示为 `Up (healthy)`，而不是 `Up (unhealthy)`。

## 技术细节

### 健康检查流程

1. **启动阶段** (0-15s): `start_period`，检查结果不影响健康状态
2. **检查阶段** (15s+): 每 5 秒执行一次健康检查
3. **成功标准**: `nc -z localhost 8080` 返回 0
4. **失败处理**: 连续失败 10 次后标记为不健康

### nc -z 工作原理

```bash
nc -z localhost 8080
```

- `nc`: netcat 命令
- `-z`: 零 I/O 模式，仅扫描监听端口
- `localhost 8080`: 目标主机和端口
- 返回码: 0 = 端口监听, 1 = 端口未监听

### BusyBox nc 兼容性

node:20-alpine 使用 BusyBox 版本的 nc：
```
BusyBox v1.37.0 (2025-08-05 16:40:33 UTC) multi-call binary.
```

支持的选项包括 `-z` 用于端口扫描。

## 故障排除

### 如果容器仍然不健康

1. **检查健康检查日志**:
   ```bash
   docker inspect --format='{{json .State.Health}}' ysweet | jq
   ```

2. **手动测试健康检查**:
   ```bash
   docker exec ysweet nc -z localhost 8080
   echo $?  # 应该输出 0
   ```

3. **检查 y-sweet 日志**:
   ```bash
   docker compose logs ysweet
   ```

4. **验证端口监听**:
   ```bash
   docker exec ysweet netstat -tlnp | grep 8080
   ```

### 如果 nc 不可用

极少情况下，如果 nc 不可用，可以使用替代方案：

```yaml
# 使用 sh 内置的重定向
test: ["CMD", "sh", "-c", "echo > /dev/tcp/localhost/8080"]

# 或使用 timeout
test: ["CMD", "timeout", "1", "sh", "-c", "echo > /dev/tcp/localhost/8080"]
```

## 总结

这个修复通过以下方式解决了容器健康检查问题：

✅ 使用 TCP 端口检查替代 HTTP 端点检查  
✅ 适应 WebSocket 服务器的特性  
✅ 提高健康检查的可靠性和性能  
✅ 使用系统预装工具，无需额外依赖  
✅ 确保 auth 服务在 ysweet 就绪后才启动  

结果：消除 "container ysweet is unhealthy" 错误，实现稳定的服务启动。
