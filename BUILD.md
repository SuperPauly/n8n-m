# 🚀 n8n Easy Build Guide

Build n8n with **just one command**! This guide shows you the simplest way to build n8n from source to Docker image.

## ⚡ Quick Start

```bash
# Build everything (recommended)
./scripts/build-everything.sh

# Or with clean build (removes node_modules first)
./scripts/build-everything.sh --clean
```

That's it! ✨

## 📋 What This Script Does

The `build-everything.sh` script handles the complete build process:

1. **✅ Checks Prerequisites** - Verifies Node.js, pnpm, and Docker are installed
2. **🧹 Cleans Up** - Removes old build artifacts
3. **📦 Installs Dependencies** - Runs `pnpm install --frozen-lockfile`
4. **⚙️ Builds Source** - Compiles n8n (excluding memory-intensive packages)
5. **🐳 Prepares Docker** - Creates build context with compiled artifacts
6. **🏗️ Builds Docker Image** - Creates `n8n-custom:latest` image
7. **📝 Creates docker-compose.yml** - Ready-to-use deployment configuration

## 🎯 After Building

Once the build completes, you'll have:

- **Docker Image**: `n8n-custom:latest`
- **Docker Compose**: `docker-compose.yml` (ready to deploy)
- **Build Artifacts**: `compiled/` directory

### Start n8n

```bash
# Start n8n
docker-compose up -d

# View logs
docker-compose logs -f

# Access n8n
open http://localhost:5678
```

### Stop n8n

```bash
# Stop n8n
docker-compose down

# Restart n8n
docker-compose restart
```

## 🛠️ Prerequisites

Make sure you have these installed:

- **Node.js** (v18 or higher) - [Download](https://nodejs.org/)
- **pnpm** - Install with: `npm install -g pnpm`
- **Docker** - [Download](https://docs.docker.com/get-docker/)

The script will check these for you and show installation links if anything is missing.

## 🔧 Build Options

### Normal Build
```bash
./scripts/build-everything.sh
```
- Uses existing node_modules if available
- Faster subsequent builds

### Clean Build
```bash
./scripts/build-everything.sh --clean
```
- Removes all node_modules first
- Ensures completely fresh build
- Takes longer but more reliable

## 🎨 Build Output

The script provides colorful, easy-to-follow output:

```
🚀 n8n All-in-One Build Script
================================

⚙️ Checking prerequisites...
✅ All prerequisites are installed!

⚙️ Cleaning up previous builds...
✅ Cleanup completed!

⚙️ Installing dependencies...
✅ Dependencies installed successfully!

⚙️ Building n8n source code...
✅ Source build completed successfully!

⚙️ Preparing Docker build context...
✅ Docker context prepared!

⚙️ Building Docker image...
✅ Docker image built successfully!

⚙️ Creating docker-compose.yml for easy deployment...
✅ docker-compose.yml created!

🎉 BUILD COMPLETED SUCCESSFULLY!
```

## 🚨 Troubleshooting

### Build Fails with Memory Error
The script automatically excludes memory-intensive packages, but if you still get memory errors:

1. Close other applications to free up RAM
2. Try the clean build: `./scripts/build-everything.sh --clean`
3. Increase Docker memory limits in Docker Desktop settings

### Docker Build Fails
1. Make sure Docker is running
2. Check you have enough disk space (build needs ~2GB)
3. Try: `docker system prune` to clean up Docker

### Permission Errors
Make sure the script is executable:
```bash
chmod +x scripts/build-everything.sh
```

## 📁 File Structure After Build

```
n8n-m/
├── scripts/
│   └── build-everything.sh     # The magic script ✨
├── compiled/                   # Built artifacts
├── docker-compose.yml          # Ready to deploy
├── build.log                   # Build output log
└── BUILD.md                    # This guide
```

## 🎯 Why This Script?

- **🚀 One Command**: No need to remember multiple build steps
- **🛡️ Memory Safe**: Automatically excludes problematic packages
- **🐳 Docker Ready**: Creates production-ready Docker image
- **📦 Complete**: Handles everything from source to deployment
- **🎨 User Friendly**: Clear progress and helpful error messages
- **⚡ Fast**: Optimized build process with smart caching

## 🤝 Need Help?

If you run into issues:

1. Check the `build.log` file for detailed error messages
2. Make sure all prerequisites are installed and up to date
3. Try a clean build: `./scripts/build-everything.sh --clean`
4. Check Docker has enough memory allocated (4GB+ recommended)

Happy building! 🎉

