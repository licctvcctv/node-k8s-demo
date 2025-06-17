#!/bin/bash
# Pre-deployment checklist script

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Check functions
check_file() {
    if [ -f "$1" ]; then
        print_success "Found: $1"
        return 0
    else
        print_error "Missing: $1"
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        print_success "Found directory: $1"
        return 0
    else
        print_error "Missing directory: $1"
        return 1
    fi
}

check_command() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_error "$1 is not installed"
        return 1
    fi
}

# Main checks
echo "==================================="
echo "Pre-deployment Checklist"
echo "==================================="
echo ""

ERRORS=0

echo "Checking project structure..."
# Check directories
for dir in services k8s scripts jenkins tests; do
    check_dir "$dir" || ((ERRORS++))
done

echo ""
echo "Checking service files..."
# Check each service
for service in user-service product-service order-service; do
    echo "Checking $service..."
    check_file "services/$service/index.js" || ((ERRORS++))
    check_file "services/$service/package.json" || ((ERRORS++))
    check_file "services/$service/Dockerfile" || ((ERRORS++))
    check_file "services/$service/tests/*.test.js" 2>/dev/null || print_warning "No tests found for $service"
done

echo ""
echo "Checking deployment files..."
# Check K8s files
check_file "k8s/namespace.yaml" || ((ERRORS++))
check_file "k8s/redis/redis-deployment.yaml" || ((ERRORS++))
for service in user-service product-service order-service; do
    check_file "k8s/$service/deployment.yaml" || ((ERRORS++))
done

echo ""
echo "Checking scripts..."
# Check scripts
for script in install-k3s.sh install-tools.sh deploy-all.sh test-apis.sh; do
    check_file "scripts/$script" || ((ERRORS++))
    if [ -f "scripts/$script" ]; then
        if [ ! -x "scripts/$script" ]; then
            print_warning "$script is not executable, fixing..."
            chmod +x "scripts/$script"
        fi
    fi
done

echo ""
echo "Checking documentation..."
# Check documentation
for doc in README.md QUICK_START.md ARCHITECTURE.md VM_DEPLOYMENT_GUIDE.md; do
    check_file "$doc" || ((ERRORS++))
done

echo ""
echo "Checking CI/CD files..."
check_file "docker-compose.yml" || ((ERRORS++))
check_file "jenkins/Jenkinsfile" || ((ERRORS++))
check_file "Makefile" || ((ERRORS++))

echo ""
echo "Checking system requirements..."
# Check commands
for cmd in docker git make; do
    check_command "$cmd" || print_warning "$cmd needs to be installed"
done

echo ""
echo "Checking configuration templates..."
check_file "config/deployment.env.example" || print_warning "Deployment config template missing"

# Check for sensitive files
echo ""
echo "Checking for sensitive files that should not be committed..."
if [ -f ".env" ]; then
    print_warning ".env file found - make sure it's in .gitignore"
fi
if [ -f "config/deployment.env" ]; then
    print_warning "deployment.env found - make sure it's in .gitignore"
fi

# Summary
echo ""
echo "==================================="
if [ $ERRORS -eq 0 ]; then
    print_success "All checks passed! Ready for deployment."
    echo ""
    echo "Next steps:"
    echo "1. Push to Git repository"
    echo "2. Clone on Master VM"
    echo "3. Follow VM_DEPLOYMENT_GUIDE.md"
else
    print_error "Found $ERRORS errors. Please fix them before deployment."
    exit 1
fi