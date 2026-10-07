# Makefile for Minor Kime AgriFund — Soroban Smart Contracts

.PHONY: help build build-docker test test-docker clean check-wasm deploy-local soroban-shell

# Default target
help:
	@echo "Minor Kime AgriFund — Soroban Smart Contract Commands"
	@echo ""
	@echo "Building:"
	@echo "  make build                    - Build all contracts locally (requires Rust)"
	@echo "  make build-docker             - Build contracts in Docker container"
	@echo "  make build-escrow             - Build only escrow contract"
	@echo "  make build-revenue-distributor - Build only revenue_distributor contract"
	@echo "  make check-wasm               - Verify WASM binaries were created"
	@echo "  make sizes                    - Show compiled contract sizes"
	@echo ""
	@echo "Testing:"
	@echo "  make test                     - Run all tests locally (requires Rust)"
	@echo "  make test-docker              - Run all tests in Docker container"
	@echo "  make test-escrow              - Test only escrow contract"
	@echo "  make test-verbose             - Run tests with stdout output"
	@echo ""
	@echo "Linting & Formatting:"
	@echo "  make fmt                      - Format all Rust code"
	@echo "  make lint                     - Lint with Clippy (wasm32 target)"
	@echo "  make check                    - Cargo check without building"
	@echo ""
	@echo "Environment:"
	@echo "  make soroban-up               - Start Soroban services (Docker Compose)"
	@echo "  make soroban-down             - Stop Soroban services"
	@echo "  make soroban-shell            - Enter Soroban CLI container"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-local             - Deploy contracts to local network"
	@echo ""
	@echo "Documentation:"
	@echo "  make docs                     - Generate Rust docs"
	@echo ""

# ===== Building =====

build:
	@echo "Building all Soroban contracts locally..."
	cargo build --release --target wasm32-unknown-unknown
	@echo "✓ Build complete. WASM files in: target/wasm32-unknown-unknown/release/"

build-docker:
	@echo "Building contracts in Docker..."
	docker-compose exec soroban cargo build --release --target wasm32-unknown-unknown
	@echo "✓ Docker build complete."

build-escrow:
	@echo "Building escrow contract..."
	cargo build -p escrow --release --target wasm32-unknown-unknown
	@echo "✓ Escrow build complete."

build-farm-campaign:
	@echo "Building farm_campaign contract..."
	cargo build -p farm_campaign --release --target wasm32-unknown-unknown
	@echo "✓ FarmCampaign build complete."

build-revenue-distributor:
	@echo "Building revenue_distributor contract..."
	cargo build -p revenue_distributor --release --target wasm32-unknown-unknown
	@echo "✓ RevenueDistributor build complete."

check-wasm:
	@echo "Checking WASM binaries..."
	@ls -lh target/wasm32-unknown-unknown/release/*.wasm 2>/dev/null || echo "No WASM files found. Run 'make build' first."

sizes:
	@echo "Contract WASM sizes:"
	@du -h target/wasm32-unknown-unknown/release/*.wasm 2>/dev/null | sort -h || \
	  echo "No WASM files. Run 'make build' first."

# ===== Testing =====

test:
	@echo "Running all tests..."
	cargo test --verbose
	@echo "✓ Tests complete."

test-docker:
	@echo "Running tests in Docker..."
	docker-compose exec soroban cargo test --verbose
	@echo "✓ Docker tests complete."

test-escrow:
	@echo "Testing escrow contract..."
	cargo test -p escrow --verbose
	@echo "✓ Escrow tests complete."

test-farm-campaign:
	@echo "Testing farm_campaign contract..."
	cargo test -p farm_campaign --verbose
	@echo "✓ FarmCampaign tests complete."

test-revenue-distributor:
	@echo "Testing revenue_distributor contract..."
	cargo test -p revenue_distributor --verbose
	@echo "✓ RevenueDistributor tests complete."

test-verbose:
	@echo "Running tests with output..."
	cargo test -- --nocapture --test-threads=1

# ===== Linting & Formatting =====

fmt:
	@echo "Formatting Rust code..."
	cargo fmt
	@echo "✓ Code formatted."

lint:
	@echo "Linting Rust code..."
	cargo clippy --target wasm32-unknown-unknown -- -D warnings
	@echo "✓ Linting complete."

check:
	@echo "Checking Rust code..."
	cargo check --target wasm32-unknown-unknown
	@echo "✓ Code check complete."

# ===== Environment Management =====

soroban-up:
	@echo "Starting Soroban development environment..."
	docker-compose up -d soroban soroban-rpc
	@echo "✓ Soroban RPC available at: http://localhost:8000"
	@echo "✓ Use 'make soroban-shell' to enter the Soroban container"

soroban-down:
	@echo "Stopping Soroban services..."
	docker-compose down soroban soroban-rpc
	@echo "✓ Services stopped."

soroban-shell:
	@echo "Entering Soroban CLI container..."
	docker-compose exec soroban bash

soroban-version:
	@docker-compose exec soroban stellar --version

# ===== Cleanup =====

clean:
	@echo "Cleaning build artifacts..."
	cargo clean
	@echo "✓ Cleaned."

clean-docker:
	@echo "Cleaning Docker resources..."
	docker-compose down -v soroban soroban-rpc
	docker image rm stellar/soroban-preview:latest 2>/dev/null || true
	@echo "✓ Docker resources cleaned."

clean-all: clean clean-docker
	@echo "✓ Full cleanup complete."

# ===== Deployment =====

deploy-local:
	@echo "Deploying contracts to local Soroban network..."
	@if [ ! -f target/wasm32-unknown-unknown/release/escrow.wasm ]; then \
		echo "WASM file not found. Building first..."; \
		$(MAKE) build; \
	fi
	docker-compose exec soroban stellar contract deploy \
		--wasm ./target/wasm32-unknown-unknown/release/escrow.wasm \
		--network standalone
	@echo "✓ Contract deployed."

# ===== Documentation =====

docs:
	@echo "Generating documentation..."
	cargo doc --target wasm32-unknown-unknown --no-deps --open
	@echo "✓ Documentation generated."

# ===== CI =====

ci-build:
	@echo "CI Build..."
	cargo build --release --target wasm32-unknown-unknown --verbose

ci-test:
	@echo "CI Tests..."
	cargo test --verbose --all

ci: ci-build ci-test lint check
	@echo "✓ CI validation complete."

# ===== Shortcuts =====

build-test: build test
	@echo "✓ Build and test complete."

all: check build test
	@echo "✓ All checks complete."

.PHONY: help build build-docker build-escrow build-farm-campaign build-revenue-distributor \
	check-wasm sizes test test-docker test-escrow test-farm-campaign test-revenue-distributor \
	test-verbose fmt lint check soroban-up soroban-down soroban-shell soroban-version \
	clean clean-docker clean-all deploy-local docs ci-build ci-test ci build-test all
