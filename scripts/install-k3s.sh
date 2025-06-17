#!/bin/bash
# K3s cluster installation script

set -e

echo "=== K3s Cluster Installation Script ==="
echo "This script will install K3s on 3 CentOS 7 VMs"
echo ""

# Configuration
MASTER_IP=${1:-"192.168.1.10"}
WORKER1_IP=${2:-"192.168.1.11"}
WORKER2_IP=${3:-"192.168.1.12"}
K3S_TOKEN="my-k3s-token-changeme"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Function to install K3s master
install_master() {
    print_info "Installing K3s master on current node..."
    
    # Disable firewall (for demo purposes)
    systemctl stop firewalld || true
    systemctl disable firewalld || true
    
    # Set SELinux to permissive
    setenforce 0 || true
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config || true
    
    # Install K3s master
    curl -sfL https://get.k3s.io | K3S_TOKEN=${K3S_TOKEN} sh -s - server \
        --write-kubeconfig-mode 644 \
        --disable traefik \
        --node-name master
    
    # Wait for K3s to be ready
    print_info "Waiting for K3s to be ready..."
    sleep 30
    
    # Check if K3s is running
    if systemctl is-active --quiet k3s; then
        print_info "K3s master installed successfully!"
    else
        print_error "K3s master installation failed!"
        exit 1
    fi
    
    # Save kubeconfig
    mkdir -p ~/.kube
    cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    chmod 600 ~/.kube/config
    
    # Display join command
    print_info "Master node token: ${K3S_TOKEN}"
    print_info "Master node URL: https://${MASTER_IP}:6443"
}

# Function to install K3s worker
install_worker() {
    local worker_name=$1
    print_info "Installing K3s worker ${worker_name}..."
    
    # Create worker installation script
    cat > /tmp/install-worker.sh << EOF
#!/bin/bash
# Disable firewall
systemctl stop firewalld || true
systemctl disable firewalld || true

# Set SELinux to permissive
setenforce 0 || true
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config || true

# Install K3s agent
curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN=${K3S_TOKEN} sh -s - agent --node-name ${worker_name}
EOF
    
    chmod +x /tmp/install-worker.sh
}

# Main installation process
main() {
    print_info "Starting K3s cluster installation..."
    print_info "Master IP: ${MASTER_IP}"
    print_info "Worker1 IP: ${WORKER1_IP}"
    print_info "Worker2 IP: ${WORKER2_IP}"
    echo ""
    
    # Install on master (current node)
    install_master
    
    # Generate worker installation scripts
    print_info "Generating worker installation scripts..."
    install_worker "worker1"
    mv /tmp/install-worker.sh /tmp/install-worker1.sh
    
    install_worker "worker2"
    mv /tmp/install-worker.sh /tmp/install-worker2.sh
    
    print_info "Installation scripts generated!"
    echo ""
    print_info "Next steps:"
    print_info "1. Copy /tmp/install-worker1.sh to ${WORKER1_IP} and run it as root"
    print_info "2. Copy /tmp/install-worker2.sh to ${WORKER2_IP} and run it as root"
    echo ""
    print_info "Example:"
    print_info "  scp /tmp/install-worker1.sh root@${WORKER1_IP}:/tmp/"
    print_info "  ssh root@${WORKER1_IP} 'bash /tmp/install-worker1.sh'"
    echo ""
    
    # Test cluster
    print_info "Testing cluster access..."
    kubectl get nodes || print_warning "kubectl not found, please wait for installation to complete"
    
    print_info "K3s master installation completed!"
}

# Run main function
main

# Create helper script for checking cluster status
cat > check-cluster.sh << 'EOF'
#!/bin/bash
echo "=== K3s Cluster Status ==="
kubectl get nodes
echo ""
echo "=== Pods in all namespaces ==="
kubectl get pods --all-namespaces
EOF
chmod +x check-cluster.sh

print_info "Use ./check-cluster.sh to check cluster status"