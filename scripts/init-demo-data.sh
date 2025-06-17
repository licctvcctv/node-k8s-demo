#!/bin/bash
# Initialize demo data for presentation

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BASE_URL=${BASE_URL:-"http://localhost"}
USER_PORT=${USER_PORT:-"8081"}
PRODUCT_PORT=${PRODUCT_PORT:-"8082"}
ORDER_PORT=${ORDER_PORT:-"8083"}

print_step() {
    echo -e "${BLUE}→${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Create demo users
create_users() {
    print_step "Creating demo users..."
    
    # Admin user
    curl -s -X POST "${BASE_URL}:${USER_PORT}/api/register" \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123","email":"admin@shop.com"}' > /dev/null
    
    # Regular users
    curl -s -X POST "${BASE_URL}:${USER_PORT}/api/register" \
        -H "Content-Type: application/json" \
        -d '{"username":"alice","password":"alice123","email":"alice@example.com"}' > /dev/null
    
    curl -s -X POST "${BASE_URL}:${USER_PORT}/api/register" \
        -H "Content-Type: application/json" \
        -d '{"username":"bob","password":"bob123","email":"bob@example.com"}' > /dev/null
    
    print_success "Created 3 demo users"
}

# Create demo products
create_products() {
    print_step "Creating demo products..."
    
    # Login as admin
    RESPONSE=$(curl -s -X POST "${BASE_URL}:${USER_PORT}/api/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin123"}')
    
    TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    # Electronics
    curl -s -X POST "${BASE_URL}:${PRODUCT_PORT}/api/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -d '{"name":"iPhone 14 Pro","description":"Latest Apple smartphone","price":999.99,"stock":50}' > /dev/null
    
    curl -s -X POST "${BASE_URL}:${PRODUCT_PORT}/api/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -d '{"name":"MacBook Pro M2","description":"Powerful laptop for professionals","price":1999.99,"stock":30}' > /dev/null
    
    curl -s -X POST "${BASE_URL}:${PRODUCT_PORT}/api/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -d '{"name":"AirPods Pro","description":"Wireless earbuds with ANC","price":249.99,"stock":100}' > /dev/null
    
    # Books
    curl -s -X POST "${BASE_URL}:${PRODUCT_PORT}/api/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -d '{"name":"Cloud Native Patterns","description":"Design patterns for cloud applications","price":45.99,"stock":200}' > /dev/null
    
    curl -s -X POST "${BASE_URL}:${PRODUCT_PORT}/api/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -d '{"name":"Kubernetes in Action","description":"Complete guide to Kubernetes","price":59.99,"stock":150}' > /dev/null
    
    # Accessories
    curl -s -X POST "${BASE_URL}:${PRODUCT_PORT}/api/products" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -d '{"name":"USB-C Hub","description":"7-in-1 USB-C adapter","price":39.99,"stock":300}' > /dev/null
    
    print_success "Created 6 demo products"
}

# Create demo orders
create_orders() {
    print_step "Creating demo orders..."
    
    # Get products
    PRODUCTS=$(curl -s "${BASE_URL}:${PRODUCT_PORT}/api/products")
    PRODUCT_ID=$(echo "$PRODUCTS" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
    
    # Login as alice
    RESPONSE=$(curl -s -X POST "${BASE_URL}:${USER_PORT}/api/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"alice","password":"alice123"}')
    
    TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    # Create order
    curl -s -X POST "${BASE_URL}:${ORDER_PORT}/api/orders" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${TOKEN}" \
        -d "{\"items\":[{\"productId\":\"${PRODUCT_ID}\",\"quantity\":1}]}" > /dev/null
    
    print_success "Created demo order"
}

# Display summary
show_summary() {
    echo ""
    echo "==================================="
    echo "Demo Data Initialized Successfully!"
    echo "==================================="
    echo ""
    echo "Demo Users:"
    echo "- admin/admin123"
    echo "- alice/alice123"
    echo "- bob/bob123"
    echo ""
    echo "Products: 6 items in catalog"
    echo "Orders: 1 demo order"
    echo ""
    echo "You can now login and explore the system!"
}

# Main
main() {
    echo "Initializing demo data..."
    echo ""
    
    create_users
    create_products
    create_orders
    show_summary
}

# Parse arguments
if [ "$1" = "--k8s" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    BASE_URL="http://${NODE_IP}"
    USER_PORT="30081"
    PRODUCT_PORT="30082"
    ORDER_PORT="30083"
fi

# Run main
main