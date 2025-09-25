# 🚀 WLNX Cloud Deploy

Infrastructure project for automatic deployment of WLNX applications on **Google Cloud Run**.

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
            │  Google Cloud   │    │   Cloud SQL     │
            │     Run         │    │   PostgreSQL    │
            │                 │    │                 │
            │ Auto HTTPS      │    │  Managed DB     │
            │ Load Balancer   │    │  Backups        │
            │ Auto Scaling    │    │  Monitoring     │
            └─────────────────┘    └─────────────────┘
```

## 🛠️ Prerequisites

### 1. Install Google Cloud SDK

```bash
# macOS
brew install google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Windows
# Download and install from: https://cloud.google.com/sdk/docs/install
```

### 2. Install Docker

```bash
# macOS
brew install docker

# Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install docker.io

# Windows
# Download Docker Desktop from: https://www.docker.com/products/docker-desktop
```

### 3. Setup Authentication

1. Log in to Google Cloud:

```bash
gcloud auth login
```

2. Set your project:

```bash
gcloud config set project YOUR_PROJECT_ID
```

3. Enable required APIs:

```bash
gcloud services enable run.googleapis.com cloudbuild.googleapis.com containerregistry.googleapis.com
```

### 4. Setup Container Registry

```bash
# Configure Docker to use gcloud as credential helper
gcloud auth configure-docker
```

## 🚀 Quick Start

### Step 1: Clone and Setup

```bash
# Clone this repository
git clone <your-infrastructure-repo>
cd wlnx-cloud-deploy

# Update secrets in gcp-config/secrets.yaml with your actual values
nano gcp-config/secrets.yaml
```

### Step 2: Configure Secrets

Update the secrets in `gcp-config/secrets.yaml`:

```yaml
# Generate secrets
echo "JWT_SECRET=$(openssl rand -base64 32)"
echo "API_SECRET_KEY=$(openssl rand -base64 32)"
echo "TELEGRAM_WEBHOOK_SECRET=$(openssl rand -base64 32)"

# Then edit gcp-config/secrets.yaml with these values
# Also add your TELEGRAM_BOT_TOKEN and DATABASE_URL
```

### Step 3: Validate Configuration

```bash
# Check that all required files exist
ls gcp-config/
ls docker/

# Validate YAML syntax
for file in gcp-config/*.yaml; do echo "Checking $file"; cat "$file" | python -c "import yaml,sys; yaml.safe_load(sys.stdin)"; done
```

### Step 4: Deploy

```bash
# Run automatic deployment
./scripts/deploy.sh
```

The script will automatically:
- ✅ Check dependencies and configuration
- ✅ Enable required Google Cloud services
- ✅ Build and push Docker images
- ✅ Deploy all three services to Cloud Run
- ✅ Configure auto-scaling and HTTPS
- ✅ Show URLs to access the services

## 📂 Project Structure

```
wlnx-cloud-deploy/
├── README.md                        # Project documentation
├── DEV_SETUP.md                    # Development setup guide
├── .gitignore                      # Git ignore rules
├── docker/                         # Docker configurations
│   ├── api-server.Dockerfile      # API Server Docker image
│   ├── control-panel.Dockerfile   # Control Panel Docker image
│   └── telegram-bot.Dockerfile    # Telegram Bot Docker image
├── gcp-config/                     # Google Cloud Run configurations
│   ├── api-server-service.yaml    # API Server service definition
│   ├── control-panel-service.yaml # Control Panel service definition
│   ├── telegram-bot-service.yaml  # Telegram Bot service definition
│   └── secrets.yaml               # Secrets configuration
└── scripts/                        # Automation scripts
    ├── deploy.sh                   # Deploy script
    ├── rollback.sh                 # Rollback script
    └── manage.sh                   # Management script
```

## 🔧 Application Management

### Monitor Status

```bash
# Check services status
./scripts/manage.sh status

# View API server logs
./scripts/manage.sh logs wlnx-api-server 100

# View control panel logs
./scripts/manage.sh logs wlnx-control-panel 50

# View Telegram bot logs
./scripts/manage.sh logs wlnx-telegram-bot 100
```

### Scaling

```bash
# Scale API server (min 2, max 5 instances)
./scripts/manage.sh scale wlnx-api-server 2 5

# Show performance metrics URLs
./scripts/manage.sh metrics
```

### Version Rollback

```bash
# Restart a service (creates new revision)
./scripts/manage.sh restart wlnx-api-server

# Restart all services
for service in wlnx-api-server wlnx-control-panel wlnx-telegram-bot; do
  ./scripts/manage.sh restart $service
done
```

### Backup

```bash
# Create Cloud SQL backup
./scripts/manage.sh backup
```

### Environment Variables Management

To change environment variables:

1. Edit `gcp-config/secrets.yaml` for secret values
2. Use management script: `./scripts/manage.sh env set wlnx-api-server KEY VALUE`
3. Or update service directly: `gcloud run services update SERVICE --set-env-vars="KEY=VALUE"`

## 🔐 Security

### Environment Variables

| Variable | Description | Used by |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | wlnx-telegram-bot |
| `JWT_SECRET` | Secret for JWT tokens | wlnx-api-server |
| `API_SECRET_KEY` | API authentication key | wlnx-api-server |
| `TELEGRAM_WEBHOOK_SECRET` | Webhook secret | wlnx-api-server, wlnx-telegram-bot |
| `DATABASE_URL` | Cloud SQL connection string | wlnx-api-server, wlnx-telegram-bot |

### 🛠️ Dev/Prod Separation

**Production Bot (Cloud):** @wlnx_prod_bot (`8333194739:AAGNb5E4NwwmdP7rhYQlvR6jrTBsS87H9W8`)  
**Development Setup:** See [DEV_SETUP.md](DEV_SETUP.md) for local development configuration

### Security Recommendations

1. **Never commit secrets to git**
2. **Use long random strings for secrets**
3. **Regularly rotate API keys**
4. **Enable 2FA for Google Cloud account**
5. **Use separate tokens for different environments**
6. **Store secrets in Google Secret Manager for production**

## 🔄 CI/CD and Auto-deploy

The project is configured for automatic deployment when changes are made to `main` branches:

- ✅ Push to `main` → Automatic deployment
- ✅ Zero-downtime deployments
- ✅ Automatic rollback on errors
- ✅ Health checks for all services
- ✅ Automatic scaling

## 📊 Monitoring and Logs

### Built-in Google Cloud Monitoring

- **Performance metrics**: CPU, memory, network, requests
- **Real-time logs**: Cloud Logging integration
- **Alerts**: Cloud Monitoring alerts
- **Health checks**: automatic service monitoring
- **Error reporting**: automatic error detection

### Access Metrics

```bash
# Via CLI
./scripts/manage.sh metrics

# Direct gcloud commands
gcloud run services describe wlnx-api-server --region=europe-west1
gcloud logging read "resource.type=cloud_run_revision" --limit=50
```

## 🌐 Domains and HTTPS

### Automatic Domains

After deployment, each service automatically gets:
- `https://wlnx-api-server-{project-id}.a.run.app` - API Server
- `https://wlnx-control-panel-{project-id}.a.run.app` - Control Panel
- `https://wlnx-telegram-bot-{project-id}.a.run.app` - Telegram Bot
- Automatic SSL certificates
- HTTP/2 support

### Connect Custom Domain

```bash
# Map custom domain to a service
gcloud run domain-mappings create --service wlnx-control-panel --domain your-domain.com --region europe-west1

# Update DNS records as shown in the output
```

## 💰 Cost

### Estimated Monthly Cost (Cheapest Configuration)

| Component | Type | Cost (estimate) |
|-----------|------|----------------|
| API Server (Cloud Run) | 0.5 CPU, 256Mi RAM | $2-5/month* |
| Control Panel (Cloud Run) | 0.2 CPU, 128Mi RAM | $1-3/month* |
| Telegram Bot (Cloud Run) | 0.2 CPU, 128Mi RAM | $1-2/month* |
| Cloud SQL (db-f1-micro, HDD) | Database | $4/month |
| Container Registry | Storage | $1-2/month |
| **Total** | | **~$9-17/month** |

*Based on usage (CPU time, requests, memory)
*Scale to zero when not in use

### Cost Optimization

- Use `--min-instances=0` for development (scale to zero)
- Use `db-f1-micro` tier for light workloads
- Enable Cloud Run always-allocated CPU only for high-traffic services
- Use `--concurrency=1000` to maximize instance utilization

## 🚨 Troubleshooting

### Common Issues

#### 1. Docker build errors

```bash
# Check Docker is running
docker info

# Verify Dockerfile syntax
docker build -f docker/api-server.Dockerfile ../wlnx-api-server --no-cache
```

#### 2. Service deployment failures

```bash
# Check service logs
./scripts/manage.sh logs wlnx-api-server 100

# Verify service configuration
gcloud run services describe wlnx-api-server --region=europe-west1
```

#### 3. Database connection errors

```bash
# Check Cloud SQL instance status
gcloud sql instances list

# Verify DATABASE_URL in secrets
kubectl get secret wlnx-secrets -o yaml

# Check service logs
./scripts/manage.sh logs wlnx-api-server 50
```

#### 4. Telegram bot not responding

```bash
# Check bot service logs
./scripts/manage.sh logs wlnx-telegram-bot 100

# Verify webhook configuration
curl -X POST "https://api.telegram.org/bot${TOKEN}/getWebhookInfo"
```

### Getting Support

1. Check logs: `./scripts/manage.sh logs <service> <lines>`
2. Check status: `./scripts/manage.sh status`
3. Check [Google Cloud Run documentation](https://cloud.google.com/run/docs)
4. Use [Cloud Console](https://console.cloud.google.com) for detailed debugging
5. Create an issue in this repository

## 📚 Additional Resources

- [Google Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud Run Service YAML Reference](https://cloud.google.com/run/docs/reference/yaml/v1)
- [gcloud CLI Reference](https://cloud.google.com/sdk/gcloud/reference/run)
- [Container Runtime Best Practices](https://cloud.google.com/run/docs/tips/general)
- [Cloud SQL for PostgreSQL](https://cloud.google.com/sql/docs/postgres)

## 🤝 Contributing

1. Fork this repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Create Pull Request

## 📝 License

This project is distributed under the MIT License. See `LICENSE` file for details.

---

## 🚀 Quick Deploy Command

```bash
# Set your Google Cloud project
gcloud config set project YOUR_PROJECT_ID

# Update secrets
nano gcp-config/secrets.yaml

# Deploy everything
./scripts/deploy.sh
```

**🎉 Ready to Deploy!** Your WLNX application will be running on Google Cloud Run with automatic scaling and HTTPS!
