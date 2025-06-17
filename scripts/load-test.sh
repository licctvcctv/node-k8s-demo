#!/bin/bash
# Simple load testing script using curl

set -e

# Configuration
BASE_URL=${BASE_URL:-"http://localhost"}
USER_PORT=${USER_PORT:-"8081"}
PRODUCT_PORT=${PRODUCT_PORT:-"8082"}
ORDER_PORT=${ORDER_PORT:-"8083"}
CONCURRENT=${CONCURRENT:-10}
REQUESTS=${REQUESTS:-100}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_result() {
    echo -e "${GREEN}[RESULT]${NC} $1"
}

# Create test user and get token
setup_test_user() {
    print_info "Setting up test user..."
    
    # Register user
    curl -s -X POST "${BASE_URL}:${USER_PORT}/api/register" \
        -H "Content-Type: application/json" \
        -d '{"username":"loadtest","password":"loadtest123","email":"load@test.com"}' > /dev/null || true
    
    # Login and get token
    RESPONSE=$(curl -s -X POST "${BASE_URL}:${USER_PORT}/api/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"loadtest","password":"loadtest123"}')
    
    TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    
    if [ -n "$TOKEN" ]; then
        export JWT_TOKEN="$TOKEN"
        print_info "Test user ready"
    else
        echo "Failed to get token"
        exit 1
    fi
}

# Load test function
run_load_test() {
    local endpoint=$1
    local method=$2
    local data=$3
    local auth=$4
    
    print_info "Testing $endpoint with $CONCURRENT concurrent requests..."
    
    # Create temporary script for parallel execution
    cat > /tmp/load_test_worker.sh << EOF
#!/bin/bash
for i in \$(seq 1 $((REQUESTS/CONCURRENT))); do
    if [ "$auth" = "true" ]; then
        curl -s -X $method "$endpoint" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $JWT_TOKEN" \
            ${data:+-d "$data"} \
            -w "%{http_code} %{time_total}\n" \
            -o /dev/null
    else
        curl -s -X $method "$endpoint" \
            -H "Content-Type: application/json" \
            ${data:+-d "$data"} \
            -w "%{http_code} %{time_total}\n" \
            -o /dev/null
    fi
done
EOF
    chmod +x /tmp/load_test_worker.sh
    
    # Run parallel requests and collect results
    START_TIME=$(date +%s)
    
    for i in $(seq 1 $CONCURRENT); do
        /tmp/load_test_worker.sh >> /tmp/load_test_results_$$.txt &
    done
    
    # Wait for all background jobs
    wait
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    # Analyze results
    TOTAL_REQUESTS=$(wc -l < /tmp/load_test_results_$$.txt)
    SUCCESS_COUNT=$(grep "^200" /tmp/load_test_results_$$.txt | wc -l)
    AVG_TIME=$(awk '{sum+=$2; count++} END {print sum/count}' /tmp/load_test_results_$$.txt)
    
    print_result "Endpoint: $endpoint"
    print_result "Total requests: $TOTAL_REQUESTS"
    print_result "Successful: $SUCCESS_COUNT"
    print_result "Duration: ${DURATION}s"
    print_result "Requests/sec: $((TOTAL_REQUESTS/DURATION))"
    print_result "Avg response time: ${AVG_TIME}s"
    echo ""
    
    # Cleanup
    rm -f /tmp/load_test_results_$$.txt
}

# Main
main() {
    echo "==================================="
    echo "Cloud Native Shop Load Testing"
    echo "==================================="
    echo ""
    echo "Configuration:"
    echo "- Base URL: ${BASE_URL}"
    echo "- Concurrent requests: ${CONCURRENT}"
    echo "- Total requests per endpoint: ${REQUESTS}"
    echo ""
    
    # Setup
    setup_test_user
    
    # Test health endpoints (no auth)
    print_info "Testing health endpoints..."
    run_load_test "${BASE_URL}:${USER_PORT}/health" "GET" "" "false"
    
    # Test product listing (no auth)
    print_info "Testing product listing..."
    run_load_test "${BASE_URL}:${PRODUCT_PORT}/api/products" "GET" "" "false"
    
    # Test user profile (with auth)
    print_info "Testing authenticated endpoints..."
    run_load_test "${BASE_URL}:${USER_PORT}/api/profile" "GET" "" "true"
    
    # Test product creation (with auth)
    print_info "Testing product creation..."
    PRODUCT_DATA='{"name":"Load Test Product","price":99.99,"stock":100}'
    run_load_test "${BASE_URL}:${PRODUCT_PORT}/api/products" "POST" "$PRODUCT_DATA" "true"
    
    print_info "Load testing completed!"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --k8s)
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
            BASE_URL="http://${NODE_IP}"
            USER_PORT="30081"
            PRODUCT_PORT="30082"
            ORDER_PORT="30083"
            shift
            ;;
        --concurrent)
            CONCURRENT=$2
            shift 2
            ;;
        --requests)
            REQUESTS=$2
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--k8s] [--concurrent N] [--requests N]"
            exit 1
            ;;
    esac
done

# Check dependencies
if ! command -v curl &> /dev/null; then
    echo "curl is required but not installed"
    exit 1
fi

# Run main
main