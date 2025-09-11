#!/bin/bash

# =============================================================================
# n8n Build Wrapper Script
# =============================================================================
# Simple wrapper to run the Coolify build script
# =============================================================================

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 n8n Coolify Build & Deploy${NC}"
echo -e "${BLUE}================================${NC}"
echo

# Check if we're in the right directory
if [ ! -f "scripts/coolify-build-n8n.sh" ]; then
    echo "❌ Error: scripts/coolify-build-n8n.sh not found"
    echo "Please run this script from the n8n repository root"
    exit 1
fi

# Run the main build script
echo -e "${GREEN}Starting build process...${NC}"
echo

exec ./scripts/coolify-build-n8n.sh "$@"
