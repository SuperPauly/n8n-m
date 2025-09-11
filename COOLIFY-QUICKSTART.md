# 🚀 n8n Coolify Quick Start

Deploy n8n to your Coolify infrastructure at `nn.crusader.work` in 3 simple steps.

## ⚡ Quick Deploy

```bash
# 1. Build n8n
./build-n8n.sh

# 2. Copy files to Coolify server
scp docker-compose.coolify.yml .env.n8n deploy-coolify.sh user@your-server:/path/to/n8n/

# 3. Deploy on server
ssh user@your-server "cd /path/to/n8n && ./deploy-coolify.sh"
```

## 🌐 Access

Visit: **https://nn.crusader.work**

## 📋 What Gets Created

| File | Purpose |
|------|---------|
| `docker-compose.coolify.yml` | Coolify deployment config with Traefik labels |
| `.env.n8n` | Environment variables (domain, SSL, database) |
| `deploy-coolify.sh` | Server deployment script |
| `build.log` | Build output for troubleshooting |

## 🔧 Key Features

- ✅ **Automatic SSL** via Let's Encrypt
- ✅ **Traefik Integration** with your existing proxy
- ✅ **Secure Encryption** with auto-generated keys
- ✅ **Health Checks** for reliability
- ✅ **SQLite Database** (PostgreSQL optional)
- ✅ **Volume Persistence** for data safety

## 🔒 Security

The script automatically generates a secure encryption key. **Save it safely!**

```bash
# Generated in .env.n8n
N8N_ENCRYPTION_KEY=your-auto-generated-secure-key
```

## 🆘 Troubleshooting

```bash
# Check build logs
tail -n 20 build.log

# Check container status
docker ps | grep n8n

# View n8n logs
docker logs n8n-coolify

# Test health endpoint
curl http://localhost:5678/healthz
```

## 📚 Full Documentation

See [README-n8n-coolify.md](README-n8n-coolify.md) for complete setup instructions, advanced configuration, and troubleshooting.

---

**Domain**: `nn.crusader.work` | **Port**: `5678` | **SSL**: Auto-configured
