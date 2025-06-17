#!/bin/bash
# Validate deployment - comprehensive testing

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Get service URLs based on environment
if [ "$1" == "--k8s" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    BASE_URL="http://${NODE_IP}"
    USER_PORT="30081"
    PRODUCT_PORT="30082"
    ORDER_PORT="30083"
    PROMETHEUS_PORT="30090"
    GRAFANA_PORT="30030"
    ENV="Kubernetes"
else
    BASE_URL="http://localhost"
    USER_PORT="8081"
    PRODUCT_PORT="8082"
    ORDER_PORT="8083"
    ENV="Docker Compose"
fi

echo "==================================="
echo "Deployment Validation"
echo "Environment: $ENV"
echo "==================================="
echo ""

# 1. Check Kubernetes resources (if in K8s mode)
if [ "$1" == "--k8s" ]; then
    print_header "Kubernetes Resources"
    
    # Check nodes
    echo "Nodes:"
    kubectl get nodes
    echo ""
    
    # Check pods
    echo "Pods in cloud-shop namespace:"
    kubectl get pods -n cloud-shop
    PODS_READY=$(kubectl get pods -n cloud-shop -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
    PODS_TOTAL=$(kubectl get pods -n cloud-shop --no-headers | wc -l)
    
    if [ "$PODS_READY" -eq "$PODS_TOTAL" ]; then
        print_success "All pods are ready ($PODS_READY/$PODS_TOTAL)"
    else
        print_error "Some pods are not ready ($PODS_READY/$PODS_TOTAL)"
    fi
    echo ""
fi

# 2. Check service health
print_header "Service Health Checks"

services=("user:$USER_PORT" "product:$PRODUCT_PORT" "order:$ORDER_PORT")
for service_info in "${services[@]}"; do
    IFS=':' read -r service port <<< "$service_info"
    if curl -s -f "${BASE_URL}:${port}/health" > /dev/null; then
        print_success "${service}-service is healthy"
    else
        print_error "${service}-service health check failed"
    fi
done
echo ""

# 3. Test user registration and login
print_header "User Service Testing"

TEST_USER="validator_$(date +%s)"
TEST_EMAIL="validator_$(date +%s)@test.com"

# Register
print_info "Testing user registration..."
REGISTER_RESPONSE=$(curl -s -X POST "${BASE_URL}:${USER_PORT}/api/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${TEST_USER}\",\"password\":\"test123\",\"email\":\"${TEST_EMAIL}\"}")

if echo "$REGISTER_RESPONSE" | grep -q "User created successfully"; then
    print_success "User registration works"
else
    print_error "User registration failed: $REGISTER_RESPONSE"
fi

# Login
print_info "Testing user login..."
LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}:${USER_PORT}/api/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${TEST_USER}\",\"password\":\"test123\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
if [ -n "$TOKEN" ]; then
    print_success "User login works, JWT token received"
else
    print_error "User login failed"
fi
echo ""

# 4. Test product operations
print_header "Product Service Testing"

# Create product
print_info "Testing product creation..."
PRODUCT_RESPONSE=$(curl -s -X POST "${BASE_URL}:${PRODUCT_PORT}/api/products" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d '{"name":"Validation Test Product","price":99.99,"stock":10}')

PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
if [ -n "$PRODUCT_ID" ]; then
    print_success "Product creation works"
else
    print_error "Product creation failed"
fi

# List products
print_info "Testing product listing..."
if curl -s "${BASE_URL}:${PRODUCT_PORT}/api/products" | grep -q "Validation Test Product"; then
    print_success "Product listing works"
else
    print_error "Product listing failed"
fi
echo ""

# 5. Test order operations
print_header "Order Service Testing"

# Create order
print_info "Testing order creation..."
ORDER_RESPONSE=$(curl -s -X POST "${BASE_URL}:${ORDER_PORT}/api/orders" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -d "{\"items\":[{\"productId\":\"${PRODUCT_ID}\",\"quantity\":1}]}")

ORDER_ID=$(echo "$ORDER_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
if [ -n "$ORDER_ID" ]; then
    print_success "Order creation works"
else
    print_error "Order creation failed: $ORDER_RESPONSE"
fi

# List orders
print_info "Testing order listing..."
if curl -s -H "Authorization: Bearer ${TOKEN}" "${BASE_URL}:${ORDER_PORT}/api/orders" | grep -q "$ORDER_ID"; then
    print_success "Order listing works"
else
    print_error "Order listing failed"
fi
echo ""

# 6. Check monitoring (if in K8s mode)
if [ "$1" == "--k8s" ]; then
    print_header "Monitoring Stack"
    
    # Check Prometheus
    if curl -s -f "${BASE_URL}:${PROMETHEUS_PORT}/api/v1/targets" > /dev/null; then
        print_success "Prometheus is accessible at ${BASE_URL}:${PROMETHEUS_PORT}"
    else
        print_error "Prometheus is not accessible"
    fi
    
    # Check Grafana
    if curl -s -f "${BASE_URL}:${GRAFANA_PORT}/api/health" > /dev/null; then
        print_success "Grafana is accessible at ${BASE_URL}:${GRAFANA_PORT}"
    else
        print_error "Grafana is not accessible"
    fi
    echo ""
fi

# 7. Performance check
print_header "Basic Performance Test"

print_info "Running quick load test..."
START_TIME=$(date +%s)
SUCCESS_COUNT=0
TOTAL_REQUESTS=50

for i in $(seq 1 $TOTAL_REQUESTS); do
    if curl -s -f "${BASE_URL}:${PRODUCT_PORT}/api/products" > /dev/null; then
        ((SUCCESS_COUNT++))
    fi
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
RATE=$((TOTAL_REQUESTS / DURATION))

print_success "Completed $TOTAL_REQUESTS requests in ${DURATION}s (~${RATE} req/s)"
print_success "Success rate: $((SUCCESS_COUNT * 100 / TOTAL_REQUESTS))%"
echo ""

# Summary
print_header "Validation Summary"

echo "Service URLs:"
echo "- User Service: ${BASE_URL}:${USER_PORT}"
echo "- Product Service: ${BASE_URL}:${PRODUCT_PORT}"
echo "- Order Service: ${BASE_URL}:${ORDER_PORT}"
if [ "$1" == "--k8s" ]; then
    echo "- Prometheus: ${BASE_URL}:${PROMETHEUS_PORT}"
    echo "- Grafana: ${BASE_URL}:${GRAFANA_PORT} (admin/admin)"
fi
echo ""

print_success "Deployment validation completed!"