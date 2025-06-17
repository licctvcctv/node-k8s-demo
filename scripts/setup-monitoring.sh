#!/bin/bash
# Setup Prometheus and Grafana monitoring

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

NAMESPACE="cloud-shop"

# Create monitoring namespace
create_monitoring_namespace() {
    print_info "Creating monitoring namespace..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
}

# Deploy Prometheus
deploy_prometheus() {
    print_info "Deploying Prometheus..."
    
    # Create Prometheus configuration
    cat > /tmp/prometheus-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    scrape_configs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
          namespaces:
            names:
            - ${NAMESPACE}
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: \$1:\$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus/'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config-volume
          mountPath: /etc/prometheus/
        - name: prometheus-storage-volume
          mountPath: /prometheus/
      volumes:
      - name: prometheus-config-volume
        configMap:
          name: prometheus-config
      - name: prometheus-storage-volume
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  selector:
    app: prometheus
  type: NodePort
  ports:
    - port: 9090
      targetPort: 9090
      nodePort: 30090
EOF

    kubectl apply -f /tmp/prometheus-config.yaml
}

# Deploy Grafana
deploy_grafana() {
    print_info "Deploying Grafana..."
    
    cat > /tmp/grafana-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "admin"
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  selector:
    app: grafana
  type: NodePort
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 30030
EOF

    kubectl apply -f /tmp/grafana-deployment.yaml
}

# Update services to expose metrics
update_services_metrics() {
    print_info "Creating monitoring configuration for services..."
    
    # Create ServiceMonitor-like configuration
    cat > /tmp/services-monitoring.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: monitoring-config
  namespace: ${NAMESPACE}
data:
  enable-metrics: "true"
---
# Add annotations to services for Prometheus scraping
apiVersion: v1
kind: Service
metadata:
  name: user-service-metrics
  namespace: ${NAMESPACE}
  labels:
    app: user-service
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8081"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: user-service
  ports:
    - name: metrics
      port: 8081
      targetPort: 8081
---
apiVersion: v1
kind: Service
metadata:
  name: product-service-metrics
  namespace: ${NAMESPACE}
  labels:
    app: product-service
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8082"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: product-service
  ports:
    - name: metrics
      port: 8082
      targetPort: 8082
---
apiVersion: v1
kind: Service
metadata:
  name: order-service-metrics
  namespace: ${NAMESPACE}
  labels:
    app: order-service
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8083"
    prometheus.io/path: "/metrics"
spec:
  selector:
    app: order-service
  ports:
    - name: metrics
      port: 8083
      targetPort: 8083
EOF

    kubectl apply -f /tmp/services-monitoring.yaml || print_warning "Services might need to be updated to expose metrics"
}

# Create Grafana dashboards
create_dashboards() {
    print_info "Creating Grafana dashboard configuration..."
    
    cat > /tmp/grafana-dashboard.json << 'EOF'
{
  "dashboard": {
    "title": "Cloud Shop Microservices",
    "panels": [
      {
        "title": "Service Health",
        "targets": [
          {
            "expr": "up{namespace=\"cloud-shop\"}"
          }
        ],
        "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8}
      },
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{namespace=\"cloud-shop\"}[5m])"
          }
        ],
        "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8}
      },
      {
        "title": "Response Time",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{namespace=\"cloud-shop\"}[5m]))"
          }
        ],
        "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8}
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{namespace=\"cloud-shop\",status=~\"5..\"}[5m])"
          }
        ],
        "gridPos": {"x": 12, "y": 8, "w": 12, "h": 8}
      }
    ]
  }
}
EOF

    print_info "Dashboard configuration saved to /tmp/grafana-dashboard.json"
}

# Show access information
show_access_info() {
    print_info "Getting access information..."
    
    # Get node IP
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    echo ""
    print_info "Monitoring Stack Access:"
    echo "Prometheus: http://${NODE_IP}:30090"
    echo "Grafana: http://${NODE_IP}:30030"
    echo "  Username: admin"
    echo "  Password: admin"
    echo ""
    print_info "To configure Grafana:"
    echo "1. Login to Grafana"
    echo "2. Add Prometheus data source: http://prometheus.monitoring.svc.cluster.local:9090"
    echo "3. Import the dashboard from /tmp/grafana-dashboard.json"
}

# Main function
main() {
    print_info "Setting up monitoring stack..."
    
    create_monitoring_namespace
    deploy_prometheus
    deploy_grafana
    update_services_metrics
    create_dashboards
    
    print_info "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring || print_warning "Prometheus timeout"
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring || print_warning "Grafana timeout"
    
    show_access_info
    
    print_info "Monitoring setup completed!"
    print_info "Note: Services need to be updated to expose metrics endpoints"
}

# Run main
main