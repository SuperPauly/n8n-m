#!/bin/bash

# =============================================================================
# n8n Coolify Build & Deploy Script
# =============================================================================
# This script builds n8n from source and prepares it for Coolify deployment
# at nn.crusader.work with Traefik SSL integration
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_TAG="n8n-custom:latest"
COOLIFY_DOMAIN="nn.crusader.work"
CONTAINER_NAME="n8n-coolify"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Error handling
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script failed with exit code $exit_code"
        log_info "Check the logs above for details"
    fi
    exit $exit_code
}

trap cleanup EXIT

# Check system memory
check_system_memory() {
    log_info "Checking system memory..."
    
    if command -v free &> /dev/null; then
        local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
        local available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        
        log_info "Total memory: ${total_mem}MB"
        log_info "Available memory: ${available_mem}MB"
        
        if [ "$available_mem" -lt 4096 ]; then
            log_warning "Low memory detected (${available_mem}MB available)"
            log_warning "n8n build requires at least 4GB of available memory"
            log_warning "Consider closing other applications or using a machine with more RAM"
        else
            log_success "Sufficient memory available for build"
        fi
    else
        log_warning "Cannot check memory usage (free command not available)"
    fi
}

# Validation functions
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -f "$PROJECT_ROOT/docker/images/n8n/Dockerfile" ]; then
        log_error "n8n Dockerfile not found at $PROJECT_ROOT/docker/images/n8n/Dockerfile"
        log_error "Please run this script from the n8n repository root"
        exit 1
    fi
    
    # Check if pnpm is available for building
    if ! command -v pnpm &> /dev/null; then
        log_error "pnpm is not installed or not in PATH"
        log_error "pnpm is required to build n8n from source"
        exit 1
    fi
    
    # Check system memory
    check_system_memory
    
    log_success "Prerequisites check passed"
}

# Stop existing containers
stop_existing_containers() {
    log_info "Stopping existing n8n containers..."
    
    # Stop containers by name pattern
    local containers=$(docker ps -q --filter "name=n8n" --filter "name=coolify" | head -10)
    if [ -n "$containers" ]; then
        log_info "Found running containers, stopping them..."
        echo "$containers" | xargs -r docker stop
        log_success "Stopped existing containers"
    else
        log_info "No running n8n containers found"
    fi
    
    # Clean up any stopped containers
    local stopped_containers=$(docker ps -aq --filter "name=n8n-coolify" | head -5)
    if [ -n "$stopped_containers" ]; then
        log_info "Removing stopped containers..."
        echo "$stopped_containers" | xargs -r docker rm
    fi
}

# Build core packages individually (fallback method)
build_core_packages() {
    log_info "Building core packages individually..."
    
    # Essential packages for n8n core functionality
    local core_packages=(
        "@n8n/api-types"
        "@n8n/config"
        "@n8n/constants"
        "@n8n/errors"
        "@n8n/utils"
        "n8n-workflow"
        "n8n-core"
        "@n8n/backend-common"
        "n8n-nodes-base"
        "n8n-editor-ui"
        "n8n"
    )
    
    for package in "${core_packages[@]}"; do
        log_info "Building package: $package"
        if pnpm --filter="$package" build >> build.log 2>&1; then
            log_success "Built $package successfully"
        else
            log_warning "Failed to build $package, continuing..."
        fi
    done
    
    log_success "Core packages build completed"
    return 0
}

# Build n8n from source
build_n8n_source() {
    log_info "Building n8n from source..."
    
    cd "$PROJECT_ROOT"
    
    # Install dependencies
    log_info "Installing dependencies with pnpm..."
    pnpm install --frozen-lockfile
    
    # Set Node.js memory options for large builds
    export NODE_OPTIONS="--max-old-space-size=8192"
    log_info "Set Node.js max memory to 8GB for build process"
    
    # Build the project with increased memory
    log_info "Building n8n project..."
    pnpm build > build.log 2>&1 || {
        log_error "Build failed. Check build.log for details:"
        tail -n 20 build.log
        log_info "Trying build with even more memory..."
        
        # Try with more memory if first attempt fails
        export NODE_OPTIONS="--max-old-space-size=12288"
        log_info "Retrying with 12GB memory limit..."
        pnpm build >> build.log 2>&1 || {
            log_error "Build failed even with increased memory."
            log_warning "Attempting selective build without problematic packages..."
            
            # Try building core packages individually
            build_core_packages || {
                log_error "Core package build failed. Check build.log for details:"
                tail -n 50 build.log
                exit 1
            }
        }
    }
    
    # Create compiled directory for Docker build
    log_info "Preparing compiled artifacts..."
    rm -rf compiled
    mkdir -p compiled
    
    # Copy built artifacts (with error handling for missing directories)
    copy_if_exists() {
        local src="$1"
        local dest="$2"
        if [ -d "$src" ]; then
            cp -r "$src" "$dest"
            log_success "Copied $src to $dest"
        else
            log_warning "Directory $src not found, skipping..."
        fi
    }
    
    copy_if_exists "packages/cli/dist" "compiled/cli"
    copy_if_exists "packages/core/dist" "compiled/core"
    copy_if_exists "packages/workflow/dist" "compiled/workflow"
    copy_if_exists "packages/nodes-base/dist" "compiled/nodes-base"
    copy_if_exists "packages/frontend/editor-ui/dist" "compiled/editor-ui"
    
    # Copy package.json files
    find packages -name "package.json" -exec cp --parents {} compiled/ \;
    
    # Copy root package.json
    cp package.json compiled/
    cp pnpm-lock.yaml compiled/
    
    log_success "Source build completed"
}

# Build Docker image
build_docker_image() {
    log_info "Building Docker image: $BUILD_TAG"
    
    cd "$PROJECT_ROOT"
    
    # Build the Docker image
    docker build \
        -f docker/images/n8n/Dockerfile \
        -t "$BUILD_TAG" \
        --build-arg N8N_VERSION=custom \
        --build-arg N8N_RELEASE_TYPE=dev \
        . || {
        log_error "Docker build failed"
        exit 1
    }
    
    log_success "Docker image built successfully: $BUILD_TAG"
}

# Create Coolify-compatible docker-compose.yml
create_coolify_compose() {
    log_info "Creating Coolify-compatible docker-compose.yml..."
    
    cat > "$PROJECT_ROOT/docker-compose.coolify.yml" << 'EOF'
version: '3.8'

networks:
  coolify:
    external: true

volumes:
  n8n_data:
    driver: local

services:
  n8n:
    image: n8n-custom:latest
    container_name: n8n-coolify
    restart: unless-stopped
    networks:
      - coolify
    environment:
      # Basic n8n configuration
      - N8N_HOST=nn.crusader.work
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://nn.crusader.work/
      - GENERIC_TIMEZONE=Europe/London
      
      # Database (using SQLite for simplicity)
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
      
      # Security
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY:-your-encryption-key-here}
      
      # Disable telemetry for self-hosted
      - N8N_DIAGNOSTICS_ENABLED=false
      - N8N_VERSION_NOTIFICATIONS_ENABLED=false
      - N8N_TEMPLATES_ENABLED=true
      - N8N_ONBOARDING_FLOW_DISABLED=false
      
      # Task runners
      - N8N_RUNNERS_ENABLED=true
      - N8N_RUNNERS_MODE=internal
      
      # User management
      - N8N_USER_MANAGEMENT_DISABLED=false
      - N8N_PUBLIC_API_DISABLED=false
      
    volumes:
      - n8n_data:/home/node/.n8n
    
    # Health check
    healthcheck:
      test: ['CMD-SHELL', 'wget --spider -q http://localhost:5678/healthz || exit 1']
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    
    # Traefik labels for Coolify integration
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(`nn.crusader.work`)
      - traefik.http.routers.n8n.entrypoints=https
      - traefik.http.routers.n8n.tls.certresolver=letsencrypt
      - traefik.http.services.n8n.loadbalancer.server.port=5678
      
      # Optional: HTTP to HTTPS redirect
      - traefik.http.routers.n8n-http.rule=Host(`nn.crusader.work`)
      - traefik.http.routers.n8n-http.entrypoints=http
      - traefik.http.routers.n8n-http.middlewares=n8n-https-redirect
      - traefik.http.middlewares.n8n-https-redirect.redirectscheme.scheme=https
      - traefik.http.middlewares.n8n-https-redirect.redirectscheme.permanent=true
      
      # Coolify labels
      - coolify.managed=true
      - coolify.name=n8n
      - coolify.service=n8n
EOF

    log_success "Created docker-compose.coolify.yml"
}

# Create environment template
create_env_template() {
    log_info "Creating environment template..."
    
    cat > "$PROJECT_ROOT/.env.n8n" << 'EOF'
# =============================================================================
# n8n Environment Configuration for Coolify
# =============================================================================

# Domain Configuration
N8N_HOST=nn.crusader.work
N8N_PROTOCOL=https
WEBHOOK_URL=https://nn.crusader.work/

# Security - CHANGE THIS!
N8N_ENCRYPTION_KEY=your-very-secure-encryption-key-change-this-immediately

# Database Configuration
DB_TYPE=sqlite
DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite

# Optional: PostgreSQL configuration (uncomment to use)
# DB_TYPE=postgresdb
# DB_POSTGRESDB_HOST=postgres
# DB_POSTGRESDB_PORT=5432
# DB_POSTGRESDB_DATABASE=n8n
# DB_POSTGRESDB_USER=n8n
# DB_POSTGRESDB_PASSWORD=your-postgres-password

# Timezone
GENERIC_TIMEZONE=Europe/London

# Features
N8N_DIAGNOSTICS_ENABLED=false
N8N_VERSION_NOTIFICATIONS_ENABLED=false
N8N_TEMPLATES_ENABLED=true
N8N_ONBOARDING_FLOW_DISABLED=false
N8N_USER_MANAGEMENT_DISABLED=false
N8N_PUBLIC_API_DISABLED=false

# Task Runners
N8N_RUNNERS_ENABLED=true
N8N_RUNNERS_MODE=internal

# Email Configuration (optional)
# N8N_EMAIL_MODE=smtp
# N8N_SMTP_HOST=smtp.gmail.com
# N8N_SMTP_PORT=587
# N8N_SMTP_USER=your-email@gmail.com
# N8N_SMTP_PASS=your-app-password
# N8N_SMTP_SENDER=your-email@gmail.com
EOF

    log_success "Created .env.n8n template"
}

# Deploy with Coolify
deploy_to_coolify() {
    log_info "Preparing for Coolify deployment..."
    
    # Create a deployment script for Coolify
    cat > "$PROJECT_ROOT/deploy-coolify.sh" << 'EOF'
#!/bin/bash
# Coolify deployment script
# Run this script in your Coolify environment

set -e

echo "Deploying n8n to Coolify..."

# Load environment variables
if [ -f .env.n8n ]; then
    source .env.n8n
fi

# Deploy with docker-compose
docker-compose -f docker-compose.coolify.yml up -d

echo "n8n deployed successfully!"
echo "Access your n8n instance at: https://nn.crusader.work"
EOF

    chmod +x "$PROJECT_ROOT/deploy-coolify.sh"
    
    log_success "Created Coolify deployment script"
}

# Generate encryption key
generate_encryption_key() {
    log_info "Generating secure encryption key..."
    
    local key=$(openssl rand -hex 32)
    log_success "Generated encryption key: $key"
    log_warning "IMPORTANT: Save this encryption key securely!"
    log_warning "Add this to your .env.n8n file: N8N_ENCRYPTION_KEY=$key"
    
    # Update the env file if it exists
    if [ -f "$PROJECT_ROOT/.env.n8n" ]; then
        sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$key/" "$PROJECT_ROOT/.env.n8n"
        log_info "Updated .env.n8n with new encryption key"
    fi
}

# Main execution
main() {
    log_info "Starting n8n Coolify build process..."
    log_info "Target domain: $COOLIFY_DOMAIN"
    
    check_prerequisites
    stop_existing_containers
    build_n8n_source
    build_docker_image
    create_coolify_compose
    create_env_template
    generate_encryption_key
    deploy_to_coolify
    
    log_success "Build process completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Review and update .env.n8n with your configuration"
    echo "2. Copy the files to your Coolify server:"
    echo "   - docker-compose.coolify.yml"
    echo "   - .env.n8n"
    echo "   - deploy-coolify.sh"
    echo "3. Run ./deploy-coolify.sh on your Coolify server"
    echo "4. Access n8n at: https://nn.crusader.work"
    echo
    log_warning "Don't forget to update the N8N_ENCRYPTION_KEY in .env.n8n!"
}

# Run main function
main "$@"
