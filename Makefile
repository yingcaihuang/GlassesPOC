# Makefile for Smart Glasses Backend

.PHONY: help build test test-unit test-integration test-all docker-build docker-test clean

# 默认目标
help:
	@echo "Available targets:"
	@echo "  build           - Build the application"
	@echo "  test            - Run all tests"
	@echo "  test-unit       - Run unit tests only"
	@echo "  test-integration - Run integration tests only"
	@echo "  test-all        - Run all tests with coverage"
	@echo "  test-system-integration - Run system integration tests"
	@echo "  test-load-stress - Run load and stress tests"
	@echo "  test-complete-integration - Run complete integration test suite"
	@echo "  test-complete-integration-with-load - Run complete integration tests with load testing"
	@echo "  docker-build    - Build Docker images"
	@echo "  docker-test     - Run tests in Docker environment"
	@echo "  docker-test-full - Run complete Docker test suite"
	@echo "  docker-up       - Start development environment"
	@echo "  docker-down     - Stop development environment"
	@echo "  docker-test-up  - Start test environment"
	@echo "  docker-test-down - Stop test environment"
	@echo "  docker-verify   - Verify Docker configuration"
	@echo "  test-network    - Test container network communication"
	@echo "  clean           - Clean build artifacts"

# 构建应用
build:
	go build -o bin/server cmd/server/main.go

# 运行单元测试
test-unit:
	go test -v -race -short ./...

# 运行集成测试
test-integration:
	go test -v -race -tags=integration ./...

# 运行所有测试
test: test-unit test-integration

# 运行所有测试并生成覆盖率报告
test-all:
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# 构建 Docker 镜像
docker-build:
	docker-compose build

# 在 Docker 环境中运行测试
docker-test:
	docker-compose -f docker-compose.test.yml up --build --abort-on-container-exit test-runner

# 启动开发环境
docker-up:
	docker-compose -f docker-compose.dev.yml up -d postgres redis

# 停止开发环境
docker-down:
	docker-compose -f docker-compose.dev.yml down

# 启动测试环境
docker-test-up:
	docker-compose -f docker-compose.test.yml up -d postgres-test redis-test

# 停止测试环境
docker-test-down:
	docker-compose -f docker-compose.test.yml down -v

# 验证 Docker 环境
docker-verify:
	@echo "验证 Docker 环境配置..."
	docker-compose config
	docker-compose -f docker-compose.dev.yml config
	docker-compose -f docker-compose.test.yml config
	@echo "Docker 配置验证完成"

# 测试容器间网络通信
test-network:
	@echo "测试容器间网络通信..."
	docker-compose -f docker-compose.test.yml up -d postgres-test redis-test
	@echo "等待服务启动..."
	sleep 10
	@echo "测试 PostgreSQL 连接..."
	docker-compose -f docker-compose.test.yml exec postgres-test pg_isready -U smartglasses_test
	@echo "测试 Redis 连接..."
	docker-compose -f docker-compose.test.yml exec redis-test redis-cli ping
	@echo "网络通信测试完成"
	docker-compose -f docker-compose.test.yml down

# 清理构建产物
clean:
	rm -f bin/server
	rm -f coverage.out coverage.html
	docker system prune -f
	docker volume prune -f

# 运行 Realtime API 集成测试
test-realtime:
	@echo "运行 Realtime API 集成测试..."
	go test -v -tags=realtime ./internal/service/
	go test -v -tags=realtime ./internal/handler/

# 完整的 Docker 测试流程
docker-test-full:
	@echo "启动完整的 Docker 测试环境..."
	docker-compose -f docker-compose.test.yml down -v || true
	docker-compose -f docker-compose.test.yml build
	docker-compose -f docker-compose.test.yml up --abort-on-container-exit
	docker-compose -f docker-compose.test.yml down -v

# 系统集成测试
test-system-integration:
	@echo "运行系统集成测试..."
	./scripts/test-system-integration.sh

# 负载和压力测试
test-load-stress:
	@echo "运行负载和压力测试..."
	./scripts/test-load-stress.sh

# 完整集成测试 (包含所有测试阶段)
test-complete-integration:
	@echo "运行完整集成测试..."
	./scripts/test-complete-integration.sh

# 完整集成测试 (包含负载测试)
test-complete-integration-with-load:
	@echo "运行完整集成测试 (包含负载测试)..."
	./scripts/test-complete-integration.sh --with-load-tests