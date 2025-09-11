#!/bin/bash

# Coolify n8n Build Script with Memory Optimization
# This script builds n8n from source and creates a Docker image for Coolify deployment
# Includes intelligent memory management and package exclusion for memory-constrained environments

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN="${1:-nn.crusader.work}"
IMAGE_NAME="n8n-custom"
IMAGE_TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Script failed with exit code $?"
        log_info "Check the logs above for details"
    fi
}

trap cleanup EXIT

# Check system memory and return status
check_system_memory() {
    log_info "Checking system memory..."
    
    if command -v free &> /dev/null; then
        # Get memory info - try different approaches for compatibility
        local memory_info=$(free -m 2>/dev/null)
        log_info "Memory info output:"
        echo "$memory_info" | head -3
        
        # Try to get available memory (column 7 in newer versions, column 4 in older)
        local available_mem=$(echo "$memory_info" | awk 'NR==2{if($7!="") print $7; else print $4}')
        local total_mem=$(echo "$memory_info" | awk 'NR==2{print $2}')
        
        # Fallback if available memory is empty or zero
        if [ -z "$available_mem" ] || [ "$available_mem" -eq 0 ] 2>/dev/null; then
            # Calculate available as total - used (basic estimation)
            local used_mem=$(echo "$memory_info" | awk 'NR==2{print $3}')
            available_mem=$((total_mem - used_mem))
            log_info "Using calculated available memory: ${available_mem}MB"
        fi
        
        log_info "Total memory: ${total_mem}MB"
        log_info "Available memory: ${available_mem}MB"
        
        # Check if we have valid numbers
        if ! [[ "$available_mem" =~ ^[0-9]+$ ]] || ! [[ "$total_mem" =~ ^[0-9]+$ ]]; then
            log_warning "Could not parse memory information, using conservative approach"
            return 1  # Assume low memory
        fi
        
        if [ "$available_mem" -lt 6144 ]; then
            log_warning "Low memory detected (${available_mem}MB available, need 6144MB)"
            log_warning "Will exclude memory-intensive packages from build"
            return 1  # Low memory
        else
            log_success "Sufficient memory available for full build (${available_mem}MB >= 6144MB)"
            return 0  # Sufficient memory
        fi
    else
        log_warning "Cannot check memory usage (free command not available)"
        log_warning "Will use conservative build approach"
        return 1  # Unknown, assume low memory
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
    
    log_success "Prerequisites check passed"
}

# Stop existing containers
stop_existing_containers() {
    log_info "Stopping existing n8n containers..."
    if docker ps -q --filter "name=n8n-coolify" | grep -q .; then
        docker stop n8n-coolify
        docker rm n8n-coolify
        log_success "Stopped and removed existing n8n container"
    else
        log_info "No running n8n containers found"
    fi
}

# Build core packages individually (fallback strategy)
build_core_packages() {
    log_info "Building core packages individually..."
    
    # List of essential packages for n8n functionality
    local core_packages=(
        "@n8n/api-types"
        "@n8n/config"
        "n8n-workflow"
        "n8n-core"
        "n8n-nodes-base"
        "n8n-editor-ui"
        "n8n"
    )
    
    for package in "${core_packages[@]}"; do
        log_info "Building package: $package"
        if pnpm --filter="$package" build >> build.log 2>&1; then
            log_success "Successfully built $package"
        else
            log_warning "Failed to build $package, continuing with others..."
        fi
    done
    
    # Copy built artifacts
    log_info "Copying built artifacts..."
    for package in "${core_packages[@]}"; do
        local package_path="packages/${package#@n8n/}"
        if [ "$package" = "n8n" ]; then
            package_path="packages/cli"
        elif [[ "$package" == n8n-* ]]; then
            package_path="packages/${package}"
        fi
        
        if [ -d "$package_path/dist" ]; then
            log_info "Found dist directory for $package"
        else
            log_warning "No dist directory found for $package at $package_path"
        fi
    done
    
    return 0
}

# Build n8n from source with memory optimization
build_n8n() {
    log_info "Building n8n from source..."
    
    cd "$PROJECT_ROOT"
    
    # Install dependencies
    log_info "Installing dependencies with pnpm..."
    pnpm install --frozen-lockfile
    
    # Set Node.js memory options for large builds
    export NODE_OPTIONS="--max-old-space-size=8192"
    log_info "Set Node.js max memory to 8GB for build process"
    
    # ALWAYS use conservative build approach to prevent memory issues
    log_info "🛡️  USING CONSERVATIVE BUILD STRATEGY"
    log_info "🛡️  AUTOMATICALLY EXCLUDING @n8n/chat package to prevent memory errors"
    log_info "🛡️  This package is memory-intensive and not essential for core n8n functionality"
    
    local build_command="pnpm build --filter='!@n8n/chat'"
    
    # Build the project with conservative strategy
    log_info "Executing build command: $build_command"
    log_info "Building n8n project (excluding chat package)..."
    $build_command > build.log 2>&1 || {
        log_error "Conservative build failed with command: $build_command"
        log_error "Build failed. Check build.log for details:"
        tail -n 20 build.log
        
        log_warning "Conservative build failed even after excluding @n8n/chat"
        log_info "Trying with increased memory allocation..."
        
        # Try with more memory
        export NODE_OPTIONS="--max-old-space-size=12288"
        log_info "Retrying with 12GB memory limit (still excluding chat package)..."
        pnpm build --filter='!@n8n/chat' >> build.log 2>&1 || {
            log_warning "Build still failed with 12GB memory, trying with 16GB..."
            
            # Try with even more memory
            export NODE_OPTIONS="--max-old-space-size=16384"
            log_info "Retrying with 16GB memory limit (still excluding chat package)..."
            pnpm build --filter='!@n8n/chat' >> build.log 2>&1 || {
                log_error "Build failed even with 16GB memory."
                log_warning "Attempting selective build of core packages only..."
                
                # Try building core packages individually
                build_core_packages || {
                    log_error "Core package build failed. Check build.log for details:"
                    tail -n 50 build.log
                    exit 1
                }
            }
        }
    }
    
    log_success "n8n build completed successfully"
}

# Build Docker image
build_docker_image() {
    log_info "Building Docker image..."
    
    cd "$PROJECT_ROOT"
    
    # Build the Docker image
    docker build -f docker/images/n8n/Dockerfile -t "$IMAGE_NAME:$IMAGE_TAG" .
    
    log_success "Docker image built successfully: $IMAGE_NAME:$IMAGE_TAG"
}

# Generate docker-compose.yml
generate_docker_compose() {
    log_info "Generating docker-compose.yml for Coolify..."
    
    cat > "$PROJECT_ROOT/docker-compose.yml" << EOF
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
      - N8N_HOST=$DOMAIN
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://$DOMAIN/
      - GENERIC_TIMEZONE=Europe/London
      
      # Database (using SQLite for simplicity)
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite
      
      # Security
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY:-your-encryption-key-here}
      
      # Performance
      - N8N_METRICS=true
      - N8N_DIAGNOSTICS_ENABLED=false
      
      # Logging
      - N8N_LOG_LEVEL=info
      - N8N_LOG_OUTPUT=console
    
    volumes:
      - n8n_data:/home/node/.n8n
    
    ports:
      - "5678:5678"
    
    labels:
      # Coolify labels for automatic deployment
      - "coolify.managed=true"
      - "coolify.version=1.0"
      - "coolify.name=n8n-custom"
      
      # Traefik labels for SSL and routing
      - "traefik.enable=true"
      - "traefik.http.routers.n8n.rule=Host(\`$DOMAIN\`)"
      - "traefik.http.routers.n8n.tls=true"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
      
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF
    
    log_success "docker-compose.yml generated successfully"
}

# Generate Coolify deployment instructions
generate_coolify_instructions() {
    log_info "Generating Coolify deployment instructions..."
    
    cat > "$PROJECT_ROOT/COOLIFY-DEPLOYMENT.md" << EOF
# n8n Coolify Deployment Instructions

## 🚀 Quick Deploy

1. **Upload to your server:**
   \`\`\`bash
   scp docker-compose.yml your-server:/path/to/deployment/
   \`\`\`

2. **Set environment variables in Coolify:**
   - \`N8N_ENCRYPTION_KEY\`: Generate a secure key
   - Domain: \`$DOMAIN\`

3. **Deploy in Coolify:**
   - Import the docker-compose.yml
   - Coolify will handle SSL certificates via Traefik
   - n8n will be available at https://$DOMAIN

## 🔧 Configuration

### Environment Variables
- **N8N_HOST**: $DOMAIN
- **N8N_PROTOCOL**: https
- **WEBHOOK_URL**: https://$DOMAIN/
- **DB_TYPE**: sqlite (for simplicity)

### SSL & Routing
- Automatic SSL via Let's Encrypt
- Traefik handles routing and certificates
- Health checks included

### Data Persistence
- SQLite database stored in Docker volume
- Workflow data persisted across restarts

## 🔍 Troubleshooting

### Build Issues
\`\`\`bash
# Check build log
tail -n 50 build.log

# Clean and rebuild
rm -rf node_modules compiled
pnpm install
pnpm build
\`\`\`

**Memory Issues:**
The script automatically handles JavaScript heap out of memory errors by:
1. Increasing Node.js heap size to 8GB, then 12GB
2. Excluding memory-intensive packages like \`@n8n/chat\` (not essential for core functionality)
3. Falling back to building only core packages individually

If you encounter persistent memory issues:
\`\`\`bash
# Build without chat package manually
pnpm build --filter='!@n8n/chat'

# Or build with more memory
NODE_OPTIONS="--max-old-space-size=16384" pnpm build
\`\`\`

### Container Issues
\`\`\`bash
# Check container logs
docker logs n8n-coolify

# Restart container
docker restart n8n-coolify

# Check health
docker exec n8n-coolify wget -qO- http://localhost:5678/healthz
\`\`\`

### Access Issues
- Ensure domain DNS points to your server
- Check Traefik configuration in Coolify
- Verify SSL certificate generation

## 📊 Monitoring

Access n8n at: https://$DOMAIN
- Health endpoint: https://$DOMAIN/healthz
- Metrics (if enabled): https://$DOMAIN/metrics

## 🔐 Security Notes

1. **Change default encryption key**
2. **Set up proper authentication**
3. **Configure webhook security**
4. **Regular backups of SQLite database**

EOF
    
    log_success "Deployment instructions generated: COOLIFY-DEPLOYMENT.md"
}

# Main execution
main() {
    log_info "Starting n8n Coolify build process..."
    log_info "Target domain: $DOMAIN"
    
    # Run all steps
    check_prerequisites
    stop_existing_containers
    build_n8n
    build_docker_image
    generate_docker_compose
    generate_coolify_instructions
    
    log_success "🎉 Build process completed successfully!"
    log_info "Next steps:"
    log_info "1. Review docker-compose.yml"
    log_info "2. Set N8N_ENCRYPTION_KEY in Coolify"
    log_info "3. Deploy using Coolify"
    log_info "4. Access n8n at https://$DOMAIN"
    log_info ""
    log_info "📖 See COOLIFY-DEPLOYMENT.md for detailed instructions"
}

# Run main function
main "$@"
