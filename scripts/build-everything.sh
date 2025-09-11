#!/bin/bash

# 🚀 n8n All-in-One Build Script
# This script builds everything you need with just one command!
# Usage: ./scripts/build-everything.sh

set -e  # Exit on any error

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis for fun
ROCKET="🚀"
GEAR="⚙️"
PACKAGE="📦"
DOCKER="🐳"
SUCCESS="✅"
ERROR="❌"
WARNING="⚠️"

# Project configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_IMAGE_NAME="n8n-custom"
DOCKER_TAG="latest"

# Logging functions
log_header() {
    echo -e "\n${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}\n"
}

log_step() {
    echo -e "${BLUE}${GEAR} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${SUCCESS} $1${NC}"
}

log_error() {
    echo -e "${RED}${ERROR} $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command_exists node; then
        missing_tools+=("Node.js")
    fi
    
    if ! command_exists pnpm; then
        missing_tools+=("pnpm")
    fi
    
    if ! command_exists docker; then
        missing_tools+=("Docker")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Please install the missing tools:"
        echo "• Node.js: https://nodejs.org/"
        echo "• pnpm: npm install -g pnpm"
        echo "• Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    log_success "All prerequisites are installed!"
}

# Function to clean up previous builds
cleanup_previous_builds() {
    log_step "Cleaning up previous builds..."
    
    cd "$PROJECT_ROOT"
    
    # Remove build artifacts
    if [ -f "build.log" ]; then
        rm build.log
        log_info "Removed old build.log"
    fi
    
    # Clean node_modules if requested
    if [ "$1" = "--clean" ]; then
        log_info "Deep cleaning node_modules..."
        rm -rf node_modules
        find . -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
    fi
    
    log_success "Cleanup completed!"
}

# Function to install dependencies
install_dependencies() {
    log_step "Installing dependencies..."
    
    cd "$PROJECT_ROOT"
    
    # Install with frozen lockfile for consistency
    pnpm install --frozen-lockfile
    
    log_success "Dependencies installed successfully!"
}

# Function to build n8n source
build_source() {
    log_step "Building n8n source code..."
    
    cd "$PROJECT_ROOT"
    
    # Set memory options for build
    export NODE_OPTIONS="--max-old-space-size=8192"
    log_info "Set Node.js memory limit to 8GB"
    
    # Always use conservative build to prevent memory issues
    log_info "Using conservative build strategy (excluding memory-intensive packages)"
    
    # Build with progress output
    echo "Building... This may take a few minutes ☕"
    pnpm build --filter='!@n8n/chat' 2>&1 | tee build.log
    
    # Check if build was successful
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Source build completed successfully!"
    else
        log_error "Source build failed!"
        echo ""
        echo "Last 20 lines of build log:"
        tail -n 20 build.log
        exit 1
    fi
}

# Function to prepare Docker build context
prepare_docker_context() {
    log_step "Preparing Docker build context..."
    
    cd "$PROJECT_ROOT"
    
    # Create compiled directory for Docker
    if [ ! -d "compiled" ]; then
        mkdir -p compiled
        log_info "Created compiled directory"
    fi
    
    # Copy built packages to compiled directory
    log_info "Copying built packages..."
    
    # Copy main packages
    for package in packages/cli packages/core packages/workflow packages/editor-ui; do
        if [ -d "$package/dist" ]; then
            mkdir -p "compiled/$(basename $package)"
            cp -r "$package/dist"/* "compiled/$(basename $package)/"
            log_info "Copied $package"
        fi
    done
    
    # Copy package.json files
    find packages -name "package.json" -exec cp --parents {} compiled/ \;
    
    # Copy root package.json
    cp package.json compiled/
    
    log_success "Docker context prepared!"
}

# Function to build Docker image
build_docker_image() {
    log_step "Building Docker image..."
    
    cd "$PROJECT_ROOT"
    
    # Build Docker image
    log_info "Building Docker image: $DOCKER_IMAGE_NAME:$DOCKER_TAG"
    
    # Use the existing Dockerfile in docker/images/n8n
    if [ -f "docker/images/n8n/Dockerfile" ]; then
        docker build -f docker/images/n8n/Dockerfile -t "$DOCKER_IMAGE_NAME:$DOCKER_TAG" .
    else
        log_error "Dockerfile not found at docker/images/n8n/Dockerfile"
        exit 1
    fi
    
    log_success "Docker image built successfully!"
    log_info "Image: $DOCKER_IMAGE_NAME:$DOCKER_TAG"
}

# Function to create docker-compose file
create_docker_compose() {
    log_step "Creating docker-compose.yml for easy deployment..."
    
    cd "$PROJECT_ROOT"
    
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  n8n:
    image: $DOCKER_IMAGE_NAME:$DOCKER_TAG
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - NODE_ENV=production
      - WEBHOOK_URL=http://localhost:5678/
    volumes:
      - n8n_data:/home/node/.n8n
    networks:
      - n8n_network

volumes:
  n8n_data:

networks:
  n8n_network:
    driver: bridge
EOF
    
    log_success "docker-compose.yml created!"
}

# Function to show final instructions
show_final_instructions() {
    log_header "🎉 BUILD COMPLETED SUCCESSFULLY!"
    
    echo -e "${GREEN}Your n8n build is ready! Here's what was created:${NC}"
    echo ""
    echo -e "${CYAN}📦 Docker Image:${NC} $DOCKER_IMAGE_NAME:$DOCKER_TAG"
    echo -e "${CYAN}🐳 Docker Compose:${NC} docker-compose.yml"
    echo -e "${CYAN}📁 Build Artifacts:${NC} compiled/"
    echo ""
    echo -e "${YELLOW}🚀 To start n8n:${NC}"
    echo "   docker-compose up -d"
    echo ""
    echo -e "${YELLOW}🌐 Access n8n at:${NC}"
    echo "   http://localhost:5678"
    echo ""
    echo -e "${YELLOW}📋 Useful commands:${NC}"
    echo "   docker-compose logs -f     # View logs"
    echo "   docker-compose down        # Stop n8n"
    echo "   docker-compose restart     # Restart n8n"
    echo ""
    echo -e "${GREEN}Happy automating! 🎯${NC}"
}

# Main execution function
main() {
    log_header "$ROCKET n8n All-in-One Build Script"
    
    echo -e "${CYAN}This script will:${NC}"
    echo "1. Check prerequisites"
    echo "2. Clean up previous builds"
    echo "3. Install dependencies"
    echo "4. Build n8n source code"
    echo "5. Prepare Docker context"
    echo "6. Build Docker image"
    echo "7. Create docker-compose.yml"
    echo ""
    
    # Parse command line arguments
    CLEAN_BUILD=false
    if [ "$1" = "--clean" ]; then
        CLEAN_BUILD=true
        log_info "Clean build requested"
    fi
    
    # Execute build steps
    check_prerequisites
    
    if [ "$CLEAN_BUILD" = true ]; then
        cleanup_previous_builds --clean
    else
        cleanup_previous_builds
    fi
    
    install_dependencies
    build_source
    prepare_docker_context
    build_docker_image
    create_docker_compose
    
    show_final_instructions
}

# Handle script interruption
trap 'log_error "Build interrupted!"; exit 1' INT TERM

# Run main function with all arguments
main "$@"

