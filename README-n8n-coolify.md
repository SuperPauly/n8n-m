# n8n Coolify Deployment Guide

This guide provides instructions for building and deploying n8n to your Coolify infrastructure at `nn.crusader.work` with automatic SSL certificates and Traefik integration.

## 🚀 Quick Start

```bash
# Make the script executable
chmod +x scripts/coolify-build-n8n.sh

# Run the build script
./scripts/coolify-build-n8n.sh
```

## 📋 Prerequisites

- **Docker**: Installed and running
- **pnpm**: Required for building n8n from source
- **Coolify**: Running with Traefik proxy
- **Domain**: `nn.crusader.work` pointing to your server
- **SSL**: Let's Encrypt configured in Traefik

## 🏗️ What the Script Does

1. **Validates Environment**: Checks for Docker, pnpm, and required files
2. **Stops Existing Containers**: Safely stops any running n8n containers
3. **Builds from Source**: Compiles n8n using pnpm
4. **Creates Docker Image**: Builds custom n8n Docker image
5. **Generates Configuration**: Creates Coolify-compatible docker-compose.yml
6. **Sets Up Environment**: Creates .env.n8n with secure defaults
7. **Generates Security Keys**: Creates encryption key for n8n
8. **Prepares Deployment**: Creates deployment script for Coolify

## 📁 Generated Files

After running the script, you'll have:

```
├── docker-compose.coolify.yml  # Coolify deployment configuration
├── .env.n8n                   # Environment variables
├── deploy-coolify.sh          # Deployment script
└── build.log                  # Build output log
```

## ⚙️ Configuration

### Environment Variables (.env.n8n)

```bash
# Domain Configuration
N8N_HOST=nn.crusader.work
N8N_PROTOCOL=https
WEBHOOK_URL=https://nn.crusader.work/

# Security (CHANGE THIS!)
N8N_ENCRYPTION_KEY=your-generated-key-here

# Database
DB_TYPE=sqlite
DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite

# Timezone
GENERIC_TIMEZONE=Europe/London
```

### Traefik Labels

The docker-compose.yml includes these Traefik labels:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.n8n.rule=Host(`nn.crusader.work`)
  - traefik.http.routers.n8n.entrypoints=https
  - traefik.http.routers.n8n.tls.certresolver=letsencrypt
  - traefik.http.services.n8n.loadbalancer.server.port=5678
```

## 🚀 Deployment Steps

### 1. Build Locally

```bash
# Run the build script
./scripts/coolify-build-n8n.sh
```

### 2. Transfer to Coolify Server

```bash
# Copy files to your Coolify server
scp docker-compose.coolify.yml user@your-server:/path/to/n8n/
scp .env.n8n user@your-server:/path/to/n8n/
scp deploy-coolify.sh user@your-server:/path/to/n8n/
```

### 3. Deploy on Coolify Server

```bash
# SSH to your Coolify server
ssh user@your-server

# Navigate to n8n directory
cd /path/to/n8n/

# Run deployment
./deploy-coolify.sh
```

### 4. Access n8n

Visit: https://nn.crusader.work

## 🔧 Advanced Configuration

### Using PostgreSQL Database

Edit `.env.n8n`:

```bash
# Database Configuration
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=postgres
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=your-secure-password
```

Add PostgreSQL service to `docker-compose.coolify.yml`:

```yaml
services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    networks:
      - coolify
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: your-secure-password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
    driver: local
```

### Email Configuration

Add to `.env.n8n`:

```bash
# Email Configuration
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=your-email@gmail.com
N8N_SMTP_PASS=your-app-password
N8N_SMTP_SENDER=your-email@gmail.com
```

## 🔍 Troubleshooting

### Build Issues

```bash
# Check build log
tail -n 50 build.log

# Clean and rebuild
rm -rf node_modules compiled
pnpm install
pnpm build
```

**Memory Issues:**
The script automatically handles JavaScript heap out of memory errors by:
1. **Proactive Memory Check**: Detects available system memory before building
2. **Smart Package Exclusion**: Automatically excludes `@n8n/chat` if < 6GB available
3. **Progressive Memory Scaling**: Increases Node.js heap size to 8GB, then 12GB
4. **Core Package Fallback**: Builds only essential packages individually as last resort

**Memory Optimization Features:**
- ✅ **6GB Threshold**: Automatically uses conservative build if less than 6GB available
- ✅ **Chat Package Exclusion**: Skips memory-intensive `@n8n/chat` (not essential for core functionality)
- ✅ **Progressive Scaling**: 8GB → 12GB → Individual package builds
- ✅ **System Diagnostics**: Reports total and available memory before building

If you encounter persistent memory issues:
```bash
# Build without chat package manually
pnpm build --filter='!@n8n/chat'

# Or build with more memory
NODE_OPTIONS="--max-old-space-size=16384" pnpm build

# Check available memory
free -h
```

### Container Issues

```bash
# Check container status
docker ps -a | grep n8n

# View container logs
docker logs n8n-coolify

# Restart container
docker restart n8n-coolify
```

### SSL Certificate Issues

```bash
# Check Traefik logs
docker logs coolify-proxy

# Verify domain resolution
nslookup nn.crusader.work

# Test HTTP access
curl -I http://nn.crusader.work
```

### Health Check Issues

```bash
# Test n8n health endpoint
curl http://localhost:5678/healthz

# Check if n8n is responding
docker exec n8n-coolify wget -qO- http://localhost:5678/healthz
```

## 🔒 Security Considerations

1. **Encryption Key**: Always use a secure, unique encryption key
2. **Database**: Use PostgreSQL for production deployments
3. **Backups**: Regularly backup your n8n data volume
4. **Updates**: Keep n8n and dependencies updated
5. **Access Control**: Configure user management and authentication

## 📊 Monitoring

### Health Checks

The deployment includes health checks:

```yaml
healthcheck:
  test: ['CMD-SHELL', 'wget --spider -q http://localhost:5678/healthz || exit 1']
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### Logs

```bash
# View n8n logs
docker logs -f n8n-coolify

# View Traefik logs
docker logs -f coolify-proxy
```

## 🔄 Updates

To update n8n:

1. Pull latest changes from the repository
2. Run the build script again
3. Deploy the updated image

```bash
# Update and rebuild
git pull origin master
./scripts/coolify-build-n8n.sh

# Redeploy
./deploy-coolify.sh
```

## 🆘 Support

### Common Issues

1. **Port 5678 already in use**: Stop existing n8n containers
2. **SSL certificate not working**: Check domain DNS and Traefik configuration
3. **Build failures**: Ensure pnpm and Node.js versions are compatible
4. **Database connection issues**: Verify database configuration and connectivity

### Useful Commands

```bash
# Check n8n version
docker exec n8n-coolify n8n --version

# Access n8n CLI
docker exec -it n8n-coolify n8n

# Backup n8n data
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n-backup.tar.gz /data

# Restore n8n data
docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar xzf /backup/n8n-backup.tar.gz -C /
```

## 📚 Additional Resources

- [n8n Documentation](https://docs.n8n.io)
- [Coolify Documentation](https://coolify.io/docs)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

---

**Note**: This deployment is configured for `nn.crusader.work`. Update the domain in all configuration files if using a different domain.
