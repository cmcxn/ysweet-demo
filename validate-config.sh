#!/bin/sh
# Docker Compose 配置验证脚本

echo "=== Docker Compose 配置验证 ==="
echo ""

# 检查 docker-compose.yml 是否存在
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ 错误: docker-compose.yml 文件不存在"
    exit 1
fi
echo "✅ docker-compose.yml 文件存在"

# 验证配置语法
echo ""
echo "检查 Docker Compose 配置语法..."
if docker compose config > /dev/null 2>&1; then
    echo "✅ Docker Compose 配置语法正确"
else
    echo "❌ Docker Compose 配置语法错误"
    docker compose config
    exit 1
fi

# 检查健康检查配置
echo ""
echo "检查 ysweet 服务健康检查配置..."
if docker compose config 2>/dev/null | grep -q "healthcheck:"; then
    echo "✅ ysweet 服务已配置健康检查"
    docker compose config 2>/dev/null | grep -A 10 "healthcheck:" | head -11
else
    echo "❌ ysweet 服务未配置健康检查"
    exit 1
fi

# 检查服务依赖配置
echo ""
echo "检查 auth 服务依赖配置..."
if docker compose config 2>/dev/null | grep -A 2 "depends_on:" | grep -q "service_healthy"; then
    echo "✅ auth 服务已配置正确的依赖条件 (service_healthy)"
    docker compose config 2>/dev/null | grep -A 3 "depends_on:"
else
    echo "⚠️  警告: auth 服务依赖配置可能不正确"
fi

# 检查 Dockerfile 是否存在
echo ""
echo "检查 Dockerfile 文件..."
if [ -f "Dockerfile" ] && [ -f "backend/Dockerfile.auth" ]; then
    echo "✅ 所有 Dockerfile 文件都存在"
else
    echo "❌ 错误: 缺少 Dockerfile 文件"
    exit 1
fi

echo ""
echo "=== 配置验证完成 ==="
echo ""
echo "下一步："
echo "1. 运行 'docker compose down -v' 清理旧容器"
echo "2. 运行 'docker compose up --build' 启动服务"
echo "3. 观察启动顺序，确保 auth 服务在 ysweet 健康后才启动"
echo "4. 查看详细测试步骤，请参考 TESTING.md"
