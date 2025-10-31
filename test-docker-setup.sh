#!/bin/bash
# Comprehensive test script for Docker setup validation

set -e

echo "=================================================="
echo "Docker Setup Test Script"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((TESTS_FAILED++))
    fi
}

# Test 1: Verify docker-compose.yml exists
echo "Test 1: Checking docker-compose.yml..."
if [ -f "docker-compose.yml" ]; then
    print_result 0 "docker-compose.yml exists"
else
    print_result 1 "docker-compose.yml not found"
    exit 1
fi

# Test 2: Validate docker-compose configuration
echo ""
echo "Test 2: Validating docker-compose configuration..."
if docker compose config > /dev/null 2>&1; then
    print_result 0 "docker-compose configuration is valid"
else
    print_result 1 "docker-compose configuration has errors"
    docker compose config
    exit 1
fi

# Test 3: Check healthcheck configuration
echo ""
echo "Test 3: Checking healthcheck configuration..."
if docker compose config 2>/dev/null | grep -q "test:"; then
    print_result 0 "Healthcheck is configured"
    echo "  Healthcheck command:"
    docker compose config 2>/dev/null | grep -A 1 "test:" | head -2 | sed 's/^/    /'
else
    print_result 1 "Healthcheck not configured"
fi

# Test 4: Check service dependencies
echo ""
echo "Test 4: Checking service dependencies..."
if docker compose config 2>/dev/null | grep -A 2 "depends_on:" | grep -q "service_healthy"; then
    print_result 0 "Service dependencies configured correctly (service_healthy)"
else
    print_result 1 "Service dependencies not configured correctly"
fi

# Test 5: Clean up existing containers
echo ""
echo "Test 5: Cleaning up existing containers..."
docker compose down -v > /dev/null 2>&1 || true
print_result 0 "Cleaned up existing containers"

# Test 6: Build containers
echo ""
echo "Test 6: Building Docker containers..."
if timeout 600 docker compose build --no-cache > /tmp/build.log 2>&1; then
    print_result 0 "Containers built successfully"
else
    print_result 1 "Container build failed"
    echo "  Build log (last 20 lines):"
    tail -20 /tmp/build.log | sed 's/^/    /'
    exit 1
fi

# Test 7: Start containers
echo ""
echo "Test 7: Starting containers in background..."
docker compose up -d > /tmp/startup.log 2>&1 &
COMPOSE_PID=$!

# Wait for containers to start
echo "  Waiting for containers to start..."
sleep 5

# Test 8: Check if ysweet container is running
echo ""
echo "Test 8: Checking if ysweet container is running..."
if docker ps | grep -q "ysweet"; then
    print_result 0 "ysweet container is running"
else
    print_result 1 "ysweet container is not running"
    docker compose logs ysweet | tail -20 | sed 's/^/    /'
fi

# Test 9: Wait for ysweet healthcheck
echo ""
echo "Test 9: Waiting for ysweet healthcheck to pass (max 60s)..."
HEALTHCHECK_PASSED=0
for i in {1..12}; do
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' ysweet 2>/dev/null || echo "none")
    echo "  Attempt $i/12: Health status = $HEALTH_STATUS"
    
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        HEALTHCHECK_PASSED=1
        break
    fi
    
    if [ "$HEALTH_STATUS" = "unhealthy" ]; then
        echo "  Container became unhealthy. Checking logs..."
        docker inspect --format='{{range .State.Health.Log}}{{.Output}}{{end}}' ysweet 2>/dev/null | sed 's/^/    /'
        break
    fi
    
    sleep 5
done

if [ $HEALTHCHECK_PASSED -eq 1 ]; then
    print_result 0 "ysweet healthcheck passed"
else
    print_result 1 "ysweet healthcheck failed"
    echo "  ysweet logs:"
    docker compose logs ysweet | tail -30 | sed 's/^/    /'
    echo "  Health check logs:"
    docker inspect --format='{{json .State.Health}}' ysweet 2>/dev/null | sed 's/^/    /'
fi

# Test 10: Check if auth container started
echo ""
echo "Test 10: Checking if auth container is running..."
sleep 5  # Give auth time to start after ysweet becomes healthy
if docker ps | grep -q "ysweet-auth"; then
    print_result 0 "auth container is running"
else
    print_result 1 "auth container is not running"
    echo "  auth logs:"
    docker compose logs auth 2>/dev/null | tail -20 | sed 's/^/    /'
fi

# Test 11: Test ysweet port accessibility
echo ""
echo "Test 11: Testing ysweet port accessibility..."
if timeout 5 bash -c "echo > /dev/tcp/localhost/8080" 2>/dev/null; then
    print_result 0 "ysweet port 8080 is accessible"
else
    print_result 1 "ysweet port 8080 is not accessible"
fi

# Test 12: Test auth port accessibility
echo ""
echo "Test 12: Testing auth port accessibility..."
if timeout 5 bash -c "echo > /dev/tcp/localhost/3001" 2>/dev/null; then
    print_result 0 "auth port 3001 is accessible"
else
    print_result 1 "auth port 3001 is not accessible"
fi

# Test 13: Test auth API endpoint
echo ""
echo "Test 13: Testing auth API endpoint..."
sleep 2  # Give auth service time to fully start
AUTH_RESPONSE=$(curl -s -X POST http://localhost:3001/api/auth \
    -H "Content-Type: application/json" \
    -d '{"docId":"test-doc"}' \
    -w "\n%{http_code}" 2>/dev/null || echo "curl_failed\n000")

HTTP_CODE=$(echo "$AUTH_RESPONSE" | tail -1)
RESPONSE_BODY=$(echo "$AUTH_RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "200" ] && echo "$RESPONSE_BODY" | grep -q "token"; then
    print_result 0 "auth API returns valid token"
    echo "  Response: $(echo $RESPONSE_BODY | head -c 80)..."
else
    print_result 1 "auth API failed or returned invalid response"
    echo "  HTTP Code: $HTTP_CODE"
    echo "  Response: $RESPONSE_BODY"
fi

# Test 14: Check for errors in logs
echo ""
echo "Test 14: Checking for errors in container logs..."
ERROR_COUNT=$(docker compose logs 2>&1 | grep -i "error\|failed\|refused" | grep -v "healthcheck" | wc -l)
if [ $ERROR_COUNT -eq 0 ]; then
    print_result 0 "No errors found in container logs"
else
    print_result 1 "Found $ERROR_COUNT error(s) in container logs"
    echo "  Recent errors:"
    docker compose logs 2>&1 | grep -i "error\|failed\|refused" | grep -v "healthcheck" | tail -10 | sed 's/^/    /'
fi

# Print final results
echo ""
echo "=================================================="
echo "Test Results Summary"
echo "=================================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

# Show container status
echo "Current container status:"
docker compose ps
echo ""

# Show recent logs
echo "Recent logs from containers:"
echo "--- ysweet logs (last 10 lines) ---"
docker compose logs ysweet | tail -10
echo ""
echo "--- auth logs (last 10 lines) ---"
docker compose logs auth | tail -10
echo ""

# Cleanup instructions
echo "=================================================="
echo "To stop containers: docker compose down"
echo "To view logs: docker compose logs -f"
echo "To restart: docker compose restart"
echo "=================================================="

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
