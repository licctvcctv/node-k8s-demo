#!/bin/bash
# Jenkins setup script for CI/CD

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Jenkins home directory
JENKINS_HOME="/opt/jenkins"

# Start Jenkins
start_jenkins() {
    print_info "Starting Jenkins..."
    
    cd ${JENKINS_HOME}
    docker-compose up -d
    
    print_info "Waiting for Jenkins to start (this may take a few minutes)..."
    sleep 60
    
    # Get initial admin password
    if [ -f "${JENKINS_HOME}/jenkins_home/secrets/initialAdminPassword" ]; then
        print_info "Jenkins initial admin password:"
        cat ${JENKINS_HOME}/jenkins_home/secrets/initialAdminPassword
        echo ""
    else
        print_warning "Initial admin password file not found yet. Jenkins may still be starting."
        print_info "You can get it later with: cat ${JENKINS_HOME}/jenkins_home/secrets/initialAdminPassword"
    fi
    
    print_info "Jenkins is available at: http://localhost:8080"
}

# Create Jenkins pipeline job configuration
create_pipeline_config() {
    print_info "Creating Jenkins pipeline configuration..."
    
    mkdir -p ${JENKINS_HOME}/pipeline
    
    # Create a sample pipeline configuration
    cat > ${JENKINS_HOME}/pipeline/cloud-shop-pipeline.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.40">
  <description>Cloud Native Shop CI/CD Pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps@2.90">
    <script>
pipeline {
    agent any
    
    environment {
        REGISTRY = 'cloud-shop'
        NAMESPACE = 'cloud-shop'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Test') {
            parallel {
                stage('Test User Service') {
                    steps {
                        dir('services/user-service') {
                            sh 'npm install'
                            sh 'npm test'
                        }
                    }
                }
                stage('Test Product Service') {
                    steps {
                        dir('services/product-service') {
                            sh 'npm install'
                            sh 'npm test'
                        }
                    }
                }
                stage('Test Order Service') {
                    steps {
                        dir('services/order-service') {
                            sh 'npm install'
                            sh 'npm test'
                        }
                    }
                }
            }
        }
        
        stage('Build') {
            parallel {
                stage('Build User Service') {
                    steps {
                        script {
                            docker.build("${REGISTRY}/user-service:${BUILD_NUMBER}", "./services/user-service")
                        }
                    }
                }
                stage('Build Product Service') {
                    steps {
                        script {
                            docker.build("${REGISTRY}/product-service:${BUILD_NUMBER}", "./services/product-service")
                        }
                    }
                }
                stage('Build Order Service') {
                    steps {
                        script {
                            docker.build("${REGISTRY}/order-service:${BUILD_NUMBER}", "./services/order-service")
                        }
                    }
                }
            }
        }
        
        stage('Deploy to K8s') {
            steps {
                script {
                    // Update image tags
                    sh """
                        sed -i 's|image: ${REGISTRY}/user-service:.*|image: ${REGISTRY}/user-service:${BUILD_NUMBER}|' k8s/user-service/deployment.yaml
                        sed -i 's|image: ${REGISTRY}/product-service:.*|image: ${REGISTRY}/product-service:${BUILD_NUMBER}|' k8s/product-service/deployment.yaml
                        sed -i 's|image: ${REGISTRY}/order-service:.*|image: ${REGISTRY}/order-service:${BUILD_NUMBER}|' k8s/order-service/deployment.yaml
                    """
                    
                    // Apply to Kubernetes
                    sh "kubectl apply -f k8s/"
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
    </script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

    print_info "Pipeline configuration created at: ${JENKINS_HOME}/pipeline/cloud-shop-pipeline.xml"
}

# Install Jenkins plugins
install_plugins() {
    print_info "Preparing plugin installation script..."
    
    cat > ${JENKINS_HOME}/install-plugins.sh << 'EOF'
#!/bin/bash
# Run this inside Jenkins Script Console or after Jenkins is fully started

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_TOKEN="<your-token>"

# Required plugins
PLUGINS=(
    "git"
    "workflow-aggregator"
    "docker-workflow"
    "kubernetes"
    "kubernetes-cd"
    "blueocean"
    "nodejs"
)

echo "Installing Jenkins plugins..."
for plugin in "${PLUGINS[@]}"; do
    echo "Installing $plugin..."
    curl -X POST \
        -u ${JENKINS_USER}:${JENKINS_TOKEN} \
        ${JENKINS_URL}/pluginManager/installNecessaryPlugins \
        -d "<install plugin='${plugin}@latest' />"
done
EOF

    chmod +x ${JENKINS_HOME}/install-plugins.sh
    print_info "Plugin installation script created at: ${JENKINS_HOME}/install-plugins.sh"
}

# Main function
main() {
    print_info "Setting up Jenkins for Cloud Native Shop CI/CD..."
    
    # Check if Jenkins directory exists
    if [ ! -d "${JENKINS_HOME}" ]; then
        print_warning "Jenkins directory not found. Creating..."
        mkdir -p ${JENKINS_HOME}
    fi
    
    # Create docker-compose if not exists
    if [ ! -f "${JENKINS_HOME}/docker-compose.yml" ]; then
        cat > ${JENKINS_HOME}/docker-compose.yml << 'EOF'
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
      - /usr/bin/kubectl:/usr/bin/kubectl
      - ~/.kube:/root/.kube
    restart: unless-stopped
    environment:
      - JENKINS_OPTS=--prefix=/jenkins
EOF
    fi
    
    # Start Jenkins
    start_jenkins
    
    # Create pipeline configuration
    create_pipeline_config
    
    # Create plugin installation script
    install_plugins
    
    print_info "Jenkins setup completed!"
    print_info ""
    print_info "Next steps:"
    print_info "1. Access Jenkins at http://localhost:8080"
    print_info "2. Complete initial setup with the admin password shown above"
    print_info "3. Install suggested plugins"
    print_info "4. Create a new Pipeline job using the configuration in ${JENKINS_HOME}/pipeline/"
    print_info "5. Configure your Git repository in the job"
}

# Run main
main