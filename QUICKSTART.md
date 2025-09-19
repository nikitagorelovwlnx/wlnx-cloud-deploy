# ⚡ Quick Start Guide - WLNX Cloud Deploy

Deploy WLNX applications to DigitalOcean in 5 minutes.

## 🚀 1-Minute Setup

```bash
# 1. Clone the repository
git clone https://github.com/nikitagorelovwlnx/wlnx-cloud-deploy.git
cd wlnx-cloud-deploy

# 2. Install doctl (if not installed)
brew install doctl  # macOS
# or
curl -sL https://github.com/digitalocean/doctl/releases/download/v1.100.0/doctl-1.100.0-linux-amd64.tar.gz | tar -xzv && sudo mv doctl /usr/local/bin  # Linux

# 3. Authorize with DigitalOcean
doctl auth init  # Insert your token

# 4. Configure environment variables
make setup
# Edit .env file with your tokens

# 5. Deploy!
make deploy
```

## 📋 Pre-deployment Checklist

### ✅ Required Steps:

1. **Get DigitalOcean Token**
   - Go to: https://cloud.digitalocean.com/account/api/tokens
   - Create new token with Read+Write permissions
   - Save the token (shown only once!)

2. **Create Telegram Bot**
   - Open @BotFather in Telegram
   - Run command `/newbot`
   - Save the received token

3. **Connect GitHub to DigitalOcean**
   - Open: https://cloud.digitalocean.com/apps
   - Click "Create App" → "GitHub" → "Install and Authorize"
   - Grant access to `wlnx-*` repositories

### 🔧 Variable Configuration:

```bash
# Copy template
cp .env.template .env

# Fill required variables:
TELEGRAM_BOT_TOKEN=your_token_from_botfather
JWT_SECRET=$(openssl rand -base64 32)
API_SECRET_KEY=$(openssl rand -base64 32)
TELEGRAM_WEBHOOK_SECRET=$(openssl rand -base64 32)
```

## 🎯 Quick Start Commands

```bash
# Check deployment readiness
make check

# Deploy to production
make deploy

# Setup Telegram webhook
make webhook

# Check application health
make health

# View status
make status

# View logs
make logs
```

## 🌍 Environment Selection

### Development (cheaper, for testing):
```bash
make deploy-dev
```
**Cost**: ~$20/month
- 1 instance per service
- 512MB RAM
- Dev database

### Production (high availability):
```bash
make deploy-prod
```
**Cost**: ~$40/month  
- 2-3 instances for fault tolerance
- 2GB RAM
- Production database
- Auto-scaling

## 🔍 Post-Deployment

### 1. Get Application URL:
```bash
make status
# Copy URL from output
```

### 2. Setup Telegram Webhook:
```bash
make webhook
# Automatically configures webhook for bot
```

### 3. Test Functionality:
```bash
# Check core components
make health

# Open management panel
open https://your-domain.ondigitalocean.app

# Test API
curl https://your-domain.ondigitalocean.app/api/health

# Message bot in Telegram
# Find your bot and send /start
```

## 🚨 Troubleshooting

### Issue: "GitHub repository not found"
```bash
# Make sure repositories are public
# Or granted DigitalOcean access to private repos
```

### Issue: "Build failed"
```bash
# Check build logs
make logs-api

# Verify package.json has "start" script
```

### Issue: "Telegram bot not responding"
```bash
# Check bot token
make webhook-info

# Reconfigure webhook
make webhook
```

### Issue: "Database connection failed"
```bash
# Check DB status
doctl databases list

# View application logs
make logs
```

## 📊 Monitoring

### Continuous Monitoring:
```bash
# Start monitoring (stop: Ctrl+C)
./scripts/monitor.sh

# Single check
./scripts/monitor.sh check

# Monitoring statistics
./scripts/monitor.sh stats
```

### DigitalOcean Web Interface:
- Open https://cloud.digitalocean.com/apps
- Find your application
- Use tabs: Overview, Deployments, Runtime Logs, Insights

## 🔄 Updates

### Automatic:
- Push to `main` branches → automatic deployment
- GitHub Actions configured out of the box

### Manual:
```bash
# Update configuration
make deploy

# Rollback on issues
make rollback

# Rollback to last successful version
make rollback-last
```

## 💰 Cost

| Environment | Cost/month | Description |
|-------------|------------|-------------|
| Development | ~$20 | For testing and development |
| Production | ~$40 | High availability, auto-scaling |

**Cost Components:**
- API Server: $6-12/month
- Control Panel: $6-12/month  
- Telegram Bot: $6/month
- PostgreSQL: $15/month

## 📞 Support

### Quick Links:
- 📖 [Full Documentation](README-EN.md)
- 🔧 [Step-by-step Guide](docs/DEPLOYMENT_GUIDE.md)
- 🌐 [DigitalOcean Docs](https://docs.digitalocean.com/products/app-platform/)

### For Issues:
1. Check logs: `make logs`
2. Check status: `make status`
3. Check health: `make health`
4. Create issue in repository

---

## 🎉 Done!

After successful deployment you'll have:
- ✅ Working API server
- ✅ Web management panel  
- ✅ Telegram bot
- ✅ PostgreSQL database
- ✅ Automatic deployments
- ✅ Monitoring and alerts
- ✅ HTTPS and custom domain

**Total deployment time**: 5-10 minutes
**Time to first bot response**: 1-2 minutes after webhook setup
