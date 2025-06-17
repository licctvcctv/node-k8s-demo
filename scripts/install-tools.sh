#!/bin/bash
# Install necessary tools for cloud-native development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

print_info "Installing necessary tools..."

# Update system
print_info "Updating system packages..."
yum update -y

# Install basic tools
print_info "Installing basic tools..."
yum install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    telnet \
    unzip \
    jq \
    yum-utils

# Install Docker
print_info "Installing Docker..."
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io
systemctl start docker
systemctl enable docker

# Add current user to docker group
usermod -aG docker ${SUDO_USER:-$USER} || true

# Install kubectl
print_info "Installing kubectl..."
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yum install -y kubectl

# Install Helm
print_info "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Node.js (for local development)
print_info "Installing Node.js..."
curl -sL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install Jenkins (Docker version will be used)
print_info "Setting up Jenkins directory..."
mkdir -p /opt/jenkins
chmod 777 /opt/jenkins

# Create docker-compose for Jenkins
cat > /opt/jenkins/docker-compose.yml << 'EOF'
version: '3'
services:
  jenkins:
    image: jenkins/jenkins:lts
    privileged: true
    user: root
    ports:
      - 8080:8080
      - 50000:50000
    container_name: jenkins
    volumes:
      - ./jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
EOF

# Install docker-compose
print_info "Installing docker-compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create helpful aliases
print_info "Setting up aliases..."
cat >> /etc/profile.d/k8s-aliases.sh << 'EOF'
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'
alias klog='kubectl logs'
alias kexec='kubectl exec -it'
EOF

# Verify installations
print_info "Verifying installations..."
echo "Docker version:"
docker --version || print_error "Docker installation failed"

echo "kubectl version:"
kubectl version --client || print_error "kubectl installation failed"

echo "Helm version:"
helm version || print_error "Helm installation failed"

echo "Node.js version:"
node --version || print_error "Node.js installation failed"

echo "docker-compose version:"
docker-compose --version || print_error "docker-compose installation failed"

print_info "All tools installed successfully!"
print_info "Note: You may need to log out and back in for Docker group changes to take effect"
print_info "Jenkins can be started with: cd /opt/jenkins && docker-compose up -d"