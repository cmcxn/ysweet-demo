#!/bin/bash
# Configuration validation test script
# This script validates the Docker Compose configuration without building images

echo "=================================================="
echo "Docker Compose Configuration Validation"
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
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
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

# Test 2: Validate docker-compose configuration syntax
echo ""
echo "Test 2: Validating docker-compose configuration syntax..."
if docker compose config > /dev/null 2>&1; then
    print_result 0 "docker-compose configuration syntax is valid"
else
    print_result 1 "docker-compose configuration has syntax errors"
    docker compose config
    exit 1
fi

# Test 3: Check if healthcheck is configured
echo ""
echo "Test 3: Checking healthcheck configuration for ysweet service..."
HEALTHCHECK_CMD=$(docker compose config 2>/dev/null | grep -A 5 "healthcheck:" | grep "test:" || echo "")
if [ -n "$HEALTHCHECK_CMD" ]; then
    print_result 0 "Healthcheck is configured"
    echo "  Healthcheck test command:"
    echo "$HEALTHCHECK_CMD" | sed 's/^/    /'
else
    print_result 1 "Healthcheck not configured"
fi

# Test 4: Verify healthcheck uses nc (netcat) instead of wget
echo ""
echo "Test 4: Verifying healthcheck uses nc (netcat)..."
if docker compose config 2>/dev/null | grep -A 10 "healthcheck:" | grep -q "nc -z"; then
    print_result 0 "Healthcheck uses nc (netcat) for TCP check"
else
    print_result 1 "Healthcheck does not use nc (netcat)"
fi

# Test 5: Check healthcheck parameters
echo ""
echo "Test 5: Checking healthcheck parameters..."
CONFIG=$(docker compose config 2>/dev/null)

# Check interval
if echo "$CONFIG" | grep -A 10 "healthcheck:" | grep -q "interval:"; then
    INTERVAL=$(echo "$CONFIG" | grep -A 10 "healthcheck:" | grep "interval:" | awk '{print $2}')
    echo "  Interval: $INTERVAL"
    print_result 0 "Healthcheck interval is configured"
else
    print_result 1 "Healthcheck interval not configured"
fi

# Check timeout
if echo "$CONFIG" | grep -A 10 "healthcheck:" | grep -q "timeout:"; then
    TIMEOUT=$(echo "$CONFIG" | grep -A 10 "healthcheck:" | grep "timeout:" | awk '{print $2}')
    echo "  Timeout: $TIMEOUT"
    print_result 0 "Healthcheck timeout is configured"
else
    print_result 1 "Healthcheck timeout not configured"
fi

# Check retries
if echo "$CONFIG" | grep -A 10 "healthcheck:" | grep -q "retries:"; then
    RETRIES=$(echo "$CONFIG" | grep -A 10 "healthcheck:" | grep "retries:" | awk '{print $2}')
    echo "  Retries: $RETRIES"
    print_result 0 "Healthcheck retries is configured"
else
    print_result 1 "Healthcheck retries not configured"
fi

# Check start_period
if echo "$CONFIG" | grep -A 10 "healthcheck:" | grep -q "start_period:"; then
    START_PERIOD=$(echo "$CONFIG" | grep -A 10 "healthcheck:" | grep "start_period:" | awk '{print $2}')
    echo "  Start period: $START_PERIOD"
    print_result 0 "Healthcheck start_period is configured"
else
    print_result 1 "Healthcheck start_period not configured"
fi

# Test 6: Check service dependencies
echo ""
echo "Test 6: Checking auth service depends_on configuration..."
if docker compose config 2>/dev/null | grep -A 3 "depends_on:" | grep -q "service_healthy"; then
    print_result 0 "auth service depends on ysweet with condition: service_healthy"
else
    print_result 1 "auth service dependency configuration is incorrect"
fi

# Test 7: Verify port mappings
echo ""
echo "Test 7: Checking port mappings..."
if docker compose config 2>/dev/null | grep -q "published.*8080"; then
    print_result 0 "ysweet port 8080 is mapped correctly"
else
    print_result 1 "ysweet port mapping is incorrect"
fi

if docker compose config 2>/dev/null | grep -q "published.*3001"; then
    print_result 0 "auth port 3001 is mapped correctly"
else
    print_result 1 "auth port mapping is incorrect"
fi

# Test 8: Check environment variables for auth service
echo ""
echo "Test 8: Checking environment variables for auth service..."
if docker compose config 2>/dev/null | grep -q "CONNECTION_STRING.*ysweet:8080"; then
    print_result 0 "CONNECTION_STRING is configured correctly for container networking"
else
    print_result 1 "CONNECTION_STRING configuration is incorrect"
fi

# Test 9: Verify Dockerfile existence
echo ""
echo "Test 9: Checking Dockerfile files..."
if [ -f "Dockerfile" ]; then
    print_result 0 "Main Dockerfile exists"
else
    print_result 1 "Main Dockerfile not found"
fi

if [ -f "backend/Dockerfile.auth" ]; then
    print_result 0 "Auth Dockerfile exists"
else
    print_result 1 "Auth Dockerfile not found"
fi

# Test 10: Check if Dockerfiles use standard npm registry
echo ""
echo "Test 10: Verifying Dockerfiles use standard npm registry..."
if ! grep -q "registry.npmmirror.com" Dockerfile 2>/dev/null; then
    print_result 0 "Main Dockerfile uses standard npm registry"
else
    print_result 1 "Main Dockerfile uses alternative registry"
fi

if ! grep -q "registry.npmmirror.com" backend/Dockerfile.auth 2>/dev/null; then
    print_result 0 "Auth Dockerfile uses standard npm registry"
else
    print_result 1 "Auth Dockerfile uses alternative registry"
fi

# Test 11: Validate nc availability in Alpine
echo ""
echo "Test 11: Verifying nc (netcat) is available in node:alpine..."
if docker run --rm node:20-alpine sh -c "which nc" > /dev/null 2>&1; then
    print_result 0 "nc (netcat) is available in node:20-alpine"
else
    print_result 1 "nc (netcat) is not available in node:20-alpine"
fi

# Test 12: Check backend package.json
echo ""
echo "Test 12: Checking backend package.json..."
if [ -f "backend/package.json" ]; then
    print_result 0 "backend/package.json exists"
    
    # Check if required dependencies are listed
    if grep -q "@y-sweet/sdk" backend/package.json; then
        print_result 0 "@y-sweet/sdk dependency is listed"
    else
        print_result 1 "@y-sweet/sdk dependency is missing"
    fi
    
    if grep -q "express" backend/package.json; then
        print_result 0 "express dependency is listed"
    else
        print_result 1 "express dependency is missing"
    fi
else
    print_result 1 "backend/package.json not found"
fi

# Test 13: Verify complete docker-compose structure
echo ""
echo "Test 13: Verifying complete docker-compose structure..."
SERVICES_COUNT=$(docker compose config 2>/dev/null | grep -E "^  (ysweet|auth):" | wc -l)
if [ "$SERVICES_COUNT" -eq 2 ]; then
    print_result 0 "docker-compose defines 2 services (ysweet and auth)"
else
    print_result 1 "docker-compose should define 2 services, found $SERVICES_COUNT"
fi

# Print final results
echo ""
echo "=================================================="
echo "Configuration Validation Summary"
echo "=================================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

# Show the parsed configuration
echo "Parsed docker-compose configuration:"
echo "=================================================="
docker compose config 2>/dev/null | head -80
echo "..."
echo ""

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All configuration tests passed!${NC}"
    echo ""
    echo "The configuration is valid. The healthcheck has been updated to:"
    echo "  - Use 'nc -z localhost 8080' for TCP connectivity check"
    echo "  - This is more reliable than HTTP-based checks for WebSocket servers"
    echo ""
    echo "Next steps:"
    echo "  1. Build containers: docker compose build"
    echo "  2. Start services: docker compose up -d"
    echo "  3. Check status: docker compose ps"
    echo "  4. View logs: docker compose logs -f"
    exit 0
else
    echo -e "${RED}✗ Some configuration tests failed.${NC}"
    exit 1
fi
