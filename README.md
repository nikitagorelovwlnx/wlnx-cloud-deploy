# 🚀 WLNX Cloud Deploy

Infrastructure project for automatic deployment of WLNX applications on **DigitalOcean App Platform**.

## 📋 Overview

This project contains all necessary configurations and scripts for deploying three WLNX components:

- **API Server** (`wlnx-api-server`) - Backend API
- **Control Panel** (`wlnx-control-panel`) - Web management panel
- **Telegram Bot** (`wlnx-telegram-bot`) - Telegram bot

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Control Panel │    │   API Server    │    │  Telegram Bot   │
│   (Frontend)    │    │   (Backend)     │    │   (Worker)      │
│                 │    │                 │    │                 │
│ TypeScript      │    │ TypeScript      │    │ TypeScript      │
│ React/Next.js   │    │ Node.js/Express │    │ Node.js         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────┬───────────┴───────────┬───────────┘
                     │                       │
            ┌─────────────────┐    ┌─────────────────┐
            │  DigitalOcean   │    │   PostgreSQL    │
            │  App Platform   │    │    Database     │
            │                 │    │                 │
            │ Auto HTTPS      │    │  Managed DB     │
            │ Load Balancer   │    │  Backups        │
            │ Auto Scaling    │    │  Monitoring     │
            └─────────────────┘    └─────────────────┘
```

## 🛠️ Prerequisites

### 1. Install DigitalOcean CLI

```bash
# macOS
brew install doctl

# Linux
curl -sL https://github.com/digitalocean/doctl/releases/download/v1.100.0/doctl-1.100.0-linux-amd64.tar.gz | tar -xzv
sudo mv doctl /usr/local/bin

# Windows
scoop install doctl
```

### 2. Setup Authentication

1. Create a personal access token at [DigitalOcean](https://cloud.digitalocean.com/account/api/tokens)
2. Run authentication:

```bash
doctl auth init
# Insert your token
```

### 3. Connect GitHub

Connect your GitHub account to DigitalOcean App Platform:
1. Open [Apps in DigitalOcean](https://cloud.digitalocean.com/apps)
2. Click "Create App" → "GitHub" → "Install and Authorize"
3. Grant access to `wlnx-*` repositories

## 🚀 Quick Start

### Step 1: Clone and Setup

```bash
# Clone this repository
git clone <your-infrastructure-repo>
cd wlnx-cloud-deploy

# Copy environment variables template
cp .env.template .env

# Edit .env file
nano .env
```

### Step 2: Configure Environment Variables

Fill in the `.env` file:

```bash
# Required variables
TELEGRAM_BOT_TOKEN=your_bot_token_from_botfather
JWT_SECRET=$(openssl rand -base64 32)
API_SECRET_KEY=$(openssl rand -base64 32)
TELEGRAM_WEBHOOK_SECRET=$(openssl rand -base64 32)
```

### Step 3: Validate Configuration

```bash
# Check configuration correctness
doctl apps spec validate --spec do-app.yaml
```

### Step 4: Deploy

```bash
# Run automatic deployment
./scripts/deploy.sh
```

The script will automatically:
- ✅ Check dependencies and configuration
- ✅ Create application in DigitalOcean
- ✅ Setup PostgreSQL database
- ✅ Deploy all three components
- ✅ Configure domain and HTTPS
- ✅ Show URL to access the application

## 📂 Project Structure

```
wlnx-cloud-deploy/
├── README.md                 # Project documentation
├── do-app.yaml              # DigitalOcean App Platform specification
├── .env.template            # Environment variables template
├── .env                     # Environment variables (created locally)
├── .app-id                  # Application ID (created after deploy)
├── .gitignore              # Git ignore rules
└── scripts/                # Automation scripts
    ├── deploy.sh           # Deploy script
    ├── rollback.sh         # Rollback script
    └── manage.sh           # Management script
```

## 🔧 Application Management

### Monitor Status

```bash
# Check application status
./scripts/manage.sh status

# View API server logs
./scripts/manage.sh logs api-server run

# View build logs
./scripts/manage.sh logs control-panel build

# View Telegram bot logs
./scripts/manage.sh logs telegram-bot run
```

### Scaling

```bash
# Increase API server instances
./scripts/manage.sh scale api-server 3

# Show performance metrics
./scripts/manage.sh metrics
```

### Version Rollback

```bash
# Interactive version selection for rollback
./scripts/rollback.sh

# Rollback to last successful version
./scripts/rollback.sh last

# Show available versions
./scripts/rollback.sh list

# Rollback to specific version
./scripts/rollback.sh deployment_id_here
```

### Backup

```bash
# Create database backup
./scripts/manage.sh backup
```

### Environment Variables Management

To change environment variables:

1. Edit `do-app.yaml`
2. Update secrets in DigitalOcean web interface
3. Run re-deploy: `./scripts/deploy.sh`

## 🔐 Security

### Environment Variables

| Variable | Description | Used by |
|----------|-------------|---------|
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | telegram-bot |
| `JWT_SECRET` | Secret for JWT tokens | api-server |
| `API_SECRET_KEY` | API authentication key | api-server |
| `TELEGRAM_WEBHOOK_SECRET` | Webhook secret | api-server, telegram-bot |
| `DATABASE_URL` | Database connection | api-server, telegram-bot |

### Security Recommendations

1. **Never commit `.env` files**
2. **Use long random strings for secrets**
3. **Regularly rotate API keys**
4. **Enable 2FA for DigitalOcean account**
5. **Use separate tokens for different environments**

## 🔄 CI/CD and Auto-deploy

The project is configured for automatic deployment when changes are made to `main` branches:

- ✅ Push to `main` → Automatic deployment
- ✅ Zero-downtime deployments
- ✅ Automatic rollback on errors
- ✅ Health checks for all services
- ✅ Automatic scaling

## 📊 Monitoring and Logs

### Built-in DigitalOcean Monitoring

- **Performance metrics**: CPU, memory, network
- **Real-time logs**: build, deploy, runtime
- **Alerts**: deployment failure notifications
- **Health checks**: automatic service monitoring

### Access Metrics

```bash
# Via CLI
./scripts/manage.sh metrics

# Via web interface
# https://cloud.digitalocean.com/apps/{app-id}/overview
```

## 🌐 Domains and HTTPS

### Automatic Domains

After deployment, the application automatically gets:
- `https://wlnx-{random}.ondigitalocean.app` - main domain
- Automatic SSL certificate
- HTTP → HTTPS redirect

### Connect Custom Domain

1. Open [application settings](https://cloud.digitalocean.com/apps)
2. Go to "Settings" → "Domains"
3. Add your domain
4. Configure DNS records according to instructions

## 💰 Cost

### Estimated Monthly Cost

| Component | Type | Cost |
|-----------|------|------|
| API Server (2x apps-s-1vcpu-1gb) | Service | $12/month |
| Control Panel (1x apps-s-1vcpu-1gb) | Service | $6/month |
| Telegram Bot (1x apps-s-1vcpu-1gb) | Worker | $6/month |
| PostgreSQL (db-s-1vcpu-1gb) | Database | $15/month |
| **Total** | | **~$39/month** |

### Cost Optimization

- Use `production: false` for dev database
- Reduce `instance_count` to 1 for development
- Consider using `apps-s-1vcpu-512mb` for smaller workloads

## 🚨 Troubleshooting

### Common Issues

#### 1. "GitHub repository not found" error

```bash
# Make sure repositories are public or access is granted
# Check repository names in do-app.yaml are correct
```

#### 2. Node.js build error

```bash
# Check build logs
./scripts/manage.sh logs api-server build

# Make sure package.json contains scripts: start
```

#### 3. Database connection errors

```bash
# Check DATABASE_URL variable is configured correctly
# Make sure DB is created and accessible
./scripts/manage.sh logs api-server run
```

#### 4. Telegram bot not responding

```bash
# Check bot logs
./scripts/manage.sh logs telegram-bot run

# Make sure TELEGRAM_BOT_TOKEN is correct
# Check webhook configuration
```

### Getting Support

1. Check logs: `./scripts/manage.sh logs <component> <type>`
2. Check status: `./scripts/manage.sh status`
3. Check [DigitalOcean documentation](https://docs.digitalocean.com/products/app-platform/)
4. Create an issue in this repository

## 📚 Additional Resources

- [DigitalOcean App Platform Docs](https://docs.digitalocean.com/products/app-platform/)
- [App Spec Reference](https://docs.digitalocean.com/products/app-platform/reference/app-spec/)
- [doctl CLI Reference](https://docs.digitalocean.com/reference/doctl/)
- [Node.js Best Practices for App Platform](https://docs.digitalocean.com/products/app-platform/languages-frameworks/nodejs/)

## 🤝 Contributing

1. Fork this repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Create Pull Request

## 📝 License

This project is distributed under the MIT License. See `LICENSE` file for details.

---

**🎉 Ready to Deploy!** Run `./scripts/deploy.sh` to start deployment.
