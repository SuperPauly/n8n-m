# n8n Development Environment Setup Guide

This guide provides instructions for setting up, building, testing, and running the n8n workflow automation platform in the Jules development environment.

## Prerequisites

The following tools are pre-installed in the Jules environment:
- Node.js v22.16.0
- pnpm v10.12.1
- Docker v28.2.2
- Git v2.49.0
- TypeScript
- Various testing tools (Jest, Cypress)

## Initial Setup

### 1. Install Dependencies
```bash
# Install all dependencies using pnpm
pnpm install

# Verify installation
node -v  # Should output v22.16.0
pnpm -v  # Should output 10.12.1
```

### 2. Prepare Environment
```bash
# Run preparation script
pnpm prepare
```

## Development Commands

### Starting Development Server

#### Full Development Environment
```bash
# Start all services in development mode
pnpm dev
```

#### Backend Only
```bash
# Start backend services only (excluding frontend)
pnpm dev:be
```

#### Frontend Only
```bash
# Start frontend development server
pnpm dev:fe
```

#### Frontend Editor Only
```bash
# Start just the editor UI
pnpm dev:fe:editor
```

#### AI Development
```bash
# Start development for AI/LangChain features
pnpm dev:ai
```

### Starting Production Server

#### Standard Start
```bash
# Start n8n in production mode
pnpm start
```

#### With Tunnel (Development Only)
```bash
# Start with tunnel for webhook testing
pnpm start:tunnel
```

#### Specific Services
```bash
# Start webhook service
pnpm webhook

# Start worker service
pnpm worker
```

## Building

### Full Build
```bash
# Build entire project
pnpm build
```

### Build n8n Application
```bash
# Build n8n specifically
pnpm build:n8n
```

### Build for Deployment
```bash
# Build for production deployment
pnpm build:deploy
```

### Docker Builds
```bash
# Build Docker image
pnpm build:docker

# Build and scan Docker image
pnpm build:docker:scan

# Build Docker image and run tests
pnpm build:docker:test
```

## Testing

### Unit Tests
```bash
# Run all tests
pnpm test

# Run tests with CI configuration
pnpm test:ci

# Run only affected tests
pnpm test:affected
```

### End-to-End Tests
```bash
# Start E2E development environment
pnpm dev:e2e

# Run E2E tests in development mode
cd cypress && pnpm run test:e2e:dev

# Run all E2E tests
cd cypress && pnpm run test:e2e:all

# Debug flaky E2E tests
pnpm debug:flaky:e2e
```

### Container Tests
```bash
# Run tests with Docker containers
pnpm test:with:docker

# Show test reports
pnpm test:show:report
```

## Code Quality

### Linting
```bash
# Run linter
pnpm lint

# Fix linting issues
pnpm lint:fix

# Lint only affected files
pnpm lint:affected

# Lint styles
pnpm lint:styles

# Fix style issues
pnpm lint:styles:fix
```

### Formatting
```bash
# Format code
pnpm format

# Check formatting
pnpm format:check
```

### Type Checking
```bash
# Run TypeScript type checking
pnpm typecheck
```

## Maintenance Commands

### Cleaning
```bash
# Clean build artifacts
pnpm clean

# Reset entire environment
pnpm reset
```

### Watching for Changes
```bash
# Watch for file changes and rebuild
pnpm watch
```

### Optimization
```bash
# Optimize SVG files
pnpm optimize-svg

# Generate third-party licenses
pnpm generate:third-party-licenses
```

## Docker Development

### Quick Start with Docker
```bash
# Create volume for persistent data
docker volume create n8n_data

# Run n8n in Docker
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n
```

### Access the Application
- **Local Development**: http://localhost:5678
- **With Tunnel**: URL will be provided in console output

## Environment Variables

### Common Configuration
```bash
# Set timezone
export GENERIC_TIMEZONE="UTC"
export TZ="UTC"

# Database configuration (if using PostgreSQL)
export DB_TYPE=postgresdb
export DB_POSTGRESDB_HOST=localhost
export DB_POSTGRESDB_PORT=5432
export DB_POSTGRESDB_DATABASE=n8n
export DB_POSTGRESDB_USER=n8n
export DB_POSTGRESDB_PASSWORD=n8n
```

## Troubleshooting

### Common Issues

1. **Node Version Mismatch**
   ```bash
   # Verify Node.js version
   node -v  # Should be v22.16.0 or higher
   ```

2. **Package Manager Issues**
   ```bash
   # Clear pnpm cache
   pnpm store prune
   
   # Reinstall dependencies
   rm -rf node_modules
   pnpm install
   ```

3. **Build Failures**
   ```bash
   # Clean and rebuild
   pnpm clean
   pnpm build
   ```

4. **Port Conflicts**
   ```bash
   # Check if port 5678 is in use
   lsof -i :5678
   
   # Kill process using the port
   kill -9 <PID>
   ```

### Database Setup
```bash
# For PostgreSQL development
docker run --name n8n-postgres \
  -e POSTGRES_DB=n8n \
  -e POSTGRES_USER=n8n \
  -e POSTGRES_PASSWORD=n8n \
  -p 5432:5432 \
  -d postgres:13
```

## Development Workflow

1. **Start Development**
   ```bash
   pnpm install
   pnpm dev
   ```

2. **Make Changes**
   - Edit code files
   - Hot reload will update the application

3. **Test Changes**
   ```bash
   pnpm lint
   pnpm test
   pnpm test:e2e:dev
   ```

4. **Build for Production**
   ```bash
   pnpm build:deploy
   ```

## Performance Monitoring

### Bundle Analysis
```bash
# Analyze bundle size
pnpm bundlemon
```

### Development Monitoring
```bash
# Monitor file changes
pnpm watch
```

## Additional Resources

- **Documentation**: https://docs.n8n.io
- **Community Forum**: https://community.n8n.io
- **Integrations**: https://n8n.io/integrations
- **Example Workflows**: https://n8n.io/workflows

## Module Development

### Backend Module Setup
```bash
# Setup new backend module
pnpm setup-backend-module
```

### Testing Specific Components
```bash
# Test specific package
pnpm --filter=<package-name> test

# Example: Test CLI package
pnpm --filter=cli test
```
