#!/bin/bash
# One-click deployment script for cloud-native shop

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
NAMESPACE="cloud-shop"
REGISTRY_PREFIX=${REGISTRY_PREFIX:-"cloud-shop"}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null; then
        print_error "docker not found. Please install docker first."
        exit 1
    fi
    
    # Check K8s cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_info "All prerequisites met!"
}

# Build Docker images
build_images() {
    print_step "Building Docker images..."
    
    # Build user-service
    print_info "Building user-service..."
    docker build -t ${REGISTRY_PREFIX}/user-service:latest ./services/user-service
    
    # Build product-service
    print_info "Building product-service..."
    docker build -t ${REGISTRY_PREFIX}/product-service:latest ./services/product-service
    
    # Build order-service
    print_info "Building order-service..."
    docker build -t ${REGISTRY_PREFIX}/order-service:latest ./services/order-service
    
    print_info "All images built successfully!"
}

# Deploy to Kubernetes
deploy_k8s() {
    print_step "Deploying to Kubernetes..."
    
    # Create namespace
    print_info "Creating namespace..."
    kubectl apply -f k8s/namespace.yaml || print_warning "Namespace might already exist"
    
    # Deploy Redis
    print_info "Deploying Redis..."
    kubectl apply -f k8s/redis/
    
    # Wait for Redis to be ready
    print_info "Waiting for Redis to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/redis -n ${NAMESPACE} || print_warning "Redis timeout"
    
    # Deploy services
    print_info "Deploying user-service..."
    kubectl apply -f k8s/user-service/
    
    print_info "Deploying product-service..."
    kubectl apply -f k8s/product-service/
    
    print_info "Deploying order-service..."
    kubectl apply -f k8s/order-service/
    
    # Wait for all deployments
    print_info "Waiting for all services to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/user-service -n ${NAMESPACE}
    kubectl wait --for=condition=available --timeout=300s deployment/product-service -n ${NAMESPACE}
    kubectl wait --for=condition=available --timeout=300s deployment/order-service -n ${NAMESPACE}
    
    print_info "All services deployed successfully!"
}

# Deploy monitoring
deploy_monitoring() {
    print_step "Deploying monitoring stack..."
    
    # Check if Prometheus operator exists
    if kubectl get crd prometheuses.monitoring.coreos.com &> /dev/null; then
        print_info "Prometheus operator already installed"
    else
        print_info "Installing Prometheus operator..."
        # Simple Prometheus deployment
        kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml || true
    fi
    
    # Deploy Prometheus configuration
    if [ -d "k8s/monitoring" ]; then
        kubectl apply -f k8s/monitoring/ || print_warning "Monitoring config not found"
    fi
    
    print_info "Monitoring deployment initiated!"
}

# Show deployment status
show_status() {
    print_step "Deployment Status"
    echo ""
    
    print_info "Nodes:"
    kubectl get nodes
    echo ""
    
    print_info "Pods in ${NAMESPACE} namespace:"
    kubectl get pods -n ${NAMESPACE}
    echo ""
    
    print_info "Services in ${NAMESPACE} namespace:"
    kubectl get svc -n ${NAMESPACE}
    echo ""
    
    # Get service URLs
    print_info "Service URLs:"
    
    # Get node IP (assuming single node or first node)
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    # Get NodePort for each service
    USER_PORT=$(kubectl get svc user-service -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
    PRODUCT_PORT=$(kubectl get svc product-service -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
    ORDER_PORT=$(kubectl get svc order-service -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
    
    echo "User Service: http://${NODE_IP}:${USER_PORT}"
    echo "Product Service: http://${NODE_IP}:${PRODUCT_PORT}"
    echo "Order Service: http://${NODE_IP}:${ORDER_PORT}"
    echo ""
    
    print_info "To test the services:"
    echo "curl http://${NODE_IP}:${USER_PORT}/health"
    echo "curl http://${NODE_IP}:${PRODUCT_PORT}/health"
    echo "curl http://${NODE_IP}:${ORDER_PORT}/health"
}

# Clean up deployment
cleanup() {
    print_warning "Cleaning up deployment..."
    kubectl delete namespace ${NAMESPACE} --force --grace-period=0 || true
    print_info "Cleanup completed!"
}

# Main deployment flow
main() {
    echo "==================================="
    echo "Cloud Native Shop Deployment Script"
    echo "==================================="
    echo ""
    
    # Parse arguments
    case "${1}" in
        "cleanup")
            cleanup
            exit 0
            ;;
        "status")
            show_status
            exit 0
            ;;
        "monitoring")
            deploy_monitoring
            exit 0
            ;;
    esac
    
    # Full deployment
    check_prerequisites
    build_images
    deploy_k8s
    deploy_monitoring
    show_status
    
    print_info "Deployment completed successfully!"
    print_info "Use './deploy-all.sh status' to check deployment status"
    print_info "Use './deploy-all.sh cleanup' to remove all resources"
}

# Run main function
main "$@"