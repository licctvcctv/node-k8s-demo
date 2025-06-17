#!/bin/bash
# Script to upload project to GitHub repository

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# GitHub repository URL
REPO_URL="https://github.com/licctvcctv/node-k8s-demo.git"

print_info "Preparing to upload Cloud Native Shop to GitHub..."

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ] || [ ! -d "services" ]; then
    print_warning "Please run this script from the cloud-native-shop directory"
    exit 1
fi

# Initialize git if not already initialized
if [ ! -d ".git" ]; then
    print_info "Initializing Git repository..."
    git init
    print_success "Git repository initialized"
else
    print_info "Git repository already initialized"
fi

# Add all files
print_info "Adding all files to Git..."
git add .
print_success "Files added"

# Create initial commit
print_info "Creating initial commit..."
git commit -m "Initial commit: Cloud Native Shop - 云原生电商微服务系统

Features:
- User Service with JWT authentication
- Product Service with CRUD operations  
- Order Service with order management
- Docker containerization
- Kubernetes (K3s) deployment
- Jenkins CI/CD pipeline
- Prometheus + Grafana monitoring
- Comprehensive test suites
- One-click deployment scripts

Tech Stack:
- Node.js + Express
- Redis
- Docker + K8s
- Jenkins
- Prometheus + Grafana" || print_warning "Already committed"

# Add remote origin
print_info "Adding GitHub remote..."
git remote add origin ${REPO_URL} 2>/dev/null || print_warning "Remote already exists"

# Set main branch
print_info "Setting main branch..."
git branch -M main

# Push to GitHub
print_info "Pushing to GitHub (you may need to enter your credentials)..."
print_warning "If using HTTPS, you might need a Personal Access Token instead of password"
print_warning "Create one at: https://github.com/settings/tokens"

git push -u origin main --force

print_success "Project successfully uploaded to GitHub!"
print_info "Repository URL: https://github.com/licctvcctv/node-k8s-demo"
print_info ""
print_info "Next steps:"
print_info "1. Visit your repository: https://github.com/licctvcctv/node-k8s-demo"
print_info "2. Check that all files are uploaded correctly"
print_info "3. Update repository description and topics"
print_info "4. Add a license if needed"