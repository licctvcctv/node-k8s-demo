#!/bin/bash
# API testing script for Cloud Native Shop

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
BASE_URL=${BASE_URL:-"http://localhost"}
USER_PORT=${USER_PORT:-"8081"}
PRODUCT_PORT=${PRODUCT_PORT:-"8082"}
ORDER_PORT=${ORDER_PORT:-"8083"}

# Test data
TEST_USER="testuser_$(date +%s)"
TEST_PASSWORD="password123"
TEST_EMAIL="test_$(date +%s)@example.com"

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Test health endpoints
test_health() {
    print_info "Testing health endpoints..."
    
    # User service health
    if curl -s -f "${BASE_URL}:${USER_PORT}/health" > /dev/null; then
        print_success "User service is healthy"
    else
        print_error "User service health check failed"
        exit 1
    fi
    
    # Product service health
    if curl -s -f "${BASE_URL}:${PRODUCT_PORT}/health" > /dev/null; then
        print_success "Product service is healthy"
    else
        print_error "Product service health check failed"
        exit 1
    fi
    
    # Order service health
    if curl -s -f "${BASE_URL}:${ORDER_PORT}/health" > /dev/null; then
        print_success "Order service is healthy"
    else
        print_error "Order service health check failed"
        exit 1
    fi
}

# Test user registration
test_user_registration() {
    print_info "Testing user registration..."
    
    RESPONSE=$(curl -s -X POST "${BASE_URL}:${USER_PORT}/api/register" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${TEST_USER}\",\"password\":\"${TEST_PASSWORD}\",\"email\":\"${TEST_EMAIL}\"}")
    
    if echo "$RESPONSE" | grep -q "User created successfully"; then
        print_success "User registration successful"
    else
        print_error "User registration failed: $RESPONSE"
        exit 1
    fi
}

# Test user login
test_user_login() {
    print_info "Testing user login..."
    
    RESPONSE=$(curl -s -X POST "${BASE_URL}:${USER_PORT}/api/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${TEST_USER}\",\"password\":\"${TEST_PASSWORD}\"}")
    
    TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    if [ -n "$TOKEN" ]; then
        print_success "User login successful"
        export JWT_TOKEN="$TOKEN"
    else
        print_error "User login failed: $RESPONSE"
        exit 1
    fi
}

# Test token verification
test_token_verification() {
    print_info "Testing token verification..."
    
    RESPONSE=$(curl -s -X GET "${BASE_URL}:${USER_PORT}/api/verify" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    if echo "$RESPONSE" | grep -q "valid.*true"; then
        print_success "Token verification successful"
    else
        print_error "Token verification failed: $RESPONSE"
        exit 1
    fi
}

# Test product creation
test_product_creation() {
    print_info "Testing product creation..."
    
    RESPONSE=$(curl -s -X POST "${BASE_URL}:${PRODUCT_PORT}/api/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -d '{"name":"Test Product","description":"Test Description","price":99.99,"stock":10}')
    
    PRODUCT_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    
    if [ -n "$PRODUCT_ID" ]; then
        print_success "Product creation successful"
        export TEST_PRODUCT_ID="$PRODUCT_ID"
    else
        print_error "Product creation failed: $RESPONSE"
        exit 1
    fi
}

# Test product listing
test_product_listing() {
    print_info "Testing product listing..."
    
    RESPONSE=$(curl -s -X GET "${BASE_URL}:${PRODUCT_PORT}/api/products")
    
    if echo "$RESPONSE" | grep -q "Test Product"; then
        print_success "Product listing successful"
    else
        print_error "Product listing failed: $RESPONSE"
        exit 1
    fi
}

# Test order creation
test_order_creation() {
    print_info "Testing order creation..."
    
    RESPONSE=$(curl -s -X POST "${BASE_URL}:${ORDER_PORT}/api/orders" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${JWT_TOKEN}" \
        -d "{\"items\":[{\"productId\":\"${TEST_PRODUCT_ID}\",\"quantity\":2}]}")
    
    ORDER_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)
    
    if [ -n "$ORDER_ID" ]; then
        print_success "Order creation successful"
        export TEST_ORDER_ID="$ORDER_ID"
    else
        print_error "Order creation failed: $RESPONSE"
        exit 1
    fi
}

# Test order listing
test_order_listing() {
    print_info "Testing order listing..."
    
    RESPONSE=$(curl -s -X GET "${BASE_URL}:${ORDER_PORT}/api/orders" \
        -H "Authorization: Bearer ${JWT_TOKEN}")
    
    if echo "$RESPONSE" | grep -q "$TEST_ORDER_ID"; then
        print_success "Order listing successful"
    else
        print_error "Order listing failed: $RESPONSE"
        exit 1
    fi
}

# Main test flow
main() {
    echo "==================================="
    echo "Cloud Native Shop API Testing"
    echo "==================================="
    echo ""
    echo "Testing against:"
    echo "- User Service: ${BASE_URL}:${USER_PORT}"
    echo "- Product Service: ${BASE_URL}:${PRODUCT_PORT}"
    echo "- Order Service: ${BASE_URL}:${ORDER_PORT}"
    echo ""
    
    # Run tests
    test_health
    test_user_registration
    test_user_login
    test_token_verification
    test_product_creation
    test_product_listing
    test_order_creation
    test_order_listing
    
    echo ""
    print_success "All tests passed successfully!"
    echo ""
    echo "Test data created:"
    echo "- Username: ${TEST_USER}"
    echo "- Product ID: ${TEST_PRODUCT_ID}"
    echo "- Order ID: ${TEST_ORDER_ID}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --k8s)
            # For K8s deployment, use NodePort
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
            BASE_URL="http://${NODE_IP}"
            USER_PORT="30081"
            PRODUCT_PORT="30082"
            ORDER_PORT="30083"
            shift
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--k8s] [--base-url URL]"
            exit 1
            ;;
    esac
done

# Run main
main