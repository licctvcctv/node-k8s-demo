.PHONY: help build up down logs test clean install-deps build-images push-images deploy

# Default target
help:
	@echo "Available commands:"
	@echo "  make install-deps   - Install dependencies for all services"
	@echo "  make build         - Build Docker images"
	@echo "  make up            - Start all services with Docker Compose"
	@echo "  make down          - Stop all services"
	@echo "  make logs          - View logs from all services"
	@echo "  make test          - Run tests for all services"
	@echo "  make clean         - Clean up containers and volumes"
	@echo "  make deploy        - Deploy to Kubernetes"

# Install dependencies for all services
install-deps:
	@echo "Installing dependencies for all services..."
	cd services/user-service && npm install
	cd services/product-service && npm install
	cd services/order-service && npm install

# Build Docker images
build:
	@echo "Building Docker images..."
	docker-compose build

# Start all services
up:
	@echo "Starting all services..."
	docker-compose up -d
	@echo "Services are starting. Check status with 'make logs'"

# Stop all services
down:
	@echo "Stopping all services..."
	docker-compose down

# View logs
logs:
	docker-compose logs -f

# Run tests
test:
	@echo "Running tests for user-service..."
	cd services/user-service && npm test
	@echo "\nRunning tests for product-service..."
	cd services/product-service && npm test
	@echo "\nRunning tests for order-service..."
	cd services/order-service && npm test

# Clean up
clean:
	@echo "Cleaning up..."
	docker-compose down -v
	docker system prune -f

# Build images for production
build-images:
	@echo "Building production images..."
	docker build -t cloud-shop/user-service:latest ./services/user-service
	docker build -t cloud-shop/product-service:latest ./services/product-service
	docker build -t cloud-shop/order-service:latest ./services/order-service

# Push images to registry (configure registry first)
push-images:
	@echo "Pushing images to registry..."
	docker push cloud-shop/user-service:latest
	docker push cloud-shop/product-service:latest
	docker push cloud-shop/order-service:latest

# Deploy to Kubernetes
deploy:
	@echo "Deploying to Kubernetes..."
	kubectl apply -f k8s/

# Quick development cycle
dev: down build up logs