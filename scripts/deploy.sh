#!/bin/bash

# WLNX Cloud Deployment Script
# Automatic deployment to Google Cloud Run

set -e  # Stop execution on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function for log output
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI is not installed. Install it: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Install it: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check authorization
    if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" | head -n1 &> /dev/null; then
        error "gcloud is not authorized. Run: gcloud auth login"
        exit 1
    fi
    
    # Check project configuration
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$PROJECT_ID" ]]; then
        error "No project set. Run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    success "All dependencies checked. Using project: $PROJECT_ID"
}

# Validate configuration
validate_config() {
    log "Validating configuration..."
    
    if [[ ! -d "gcp-config" ]]; then
        error "gcp-config directory not found"
        exit 1
    fi
    
    if [[ ! -d "docker" ]]; then
        error "docker directory not found"
        exit 1
    fi
    
    # Check required files
    local required_files=(
        "gcp-config/api-server-service.yaml"
        "gcp-config/control-panel-service.yaml"
        "gcp-config/telegram-bot-service.yaml"
        "gcp-config/secrets.yaml"
        "docker/api-server.Dockerfile"
        "docker/control-panel.Dockerfile"
        "docker/telegram-bot.Dockerfile"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Required file not found: $file"
            exit 1
        fi
    done
    
    success "Configuration is valid"
}

# Setup Google Cloud services
setup_gcp_services() {
    log "Setting up Google Cloud services..."
    
    # Enable required APIs
    log "Enabling required APIs..."
    gcloud services enable \
        run.googleapis.com \
        cloudbuild.googleapis.com \
        containerregistry.googleapis.com \
        sql-component.googleapis.com \
        sqladmin.googleapis.com
    
    success "Google Cloud services enabled"
}

# Create Cloud SQL database (optional)
create_database() {
    log "Creating Cloud SQL database..."
    
    DB_INSTANCE="wlnx-postgres"
    DB_NAME="wlnx"
    REGION="europe-west1"
    
    # Check if instance already exists
    if gcloud sql instances list --filter="name:$DB_INSTANCE" --format="value(name)" | grep -q "$DB_INSTANCE"; then
        warning "Database instance $DB_INSTANCE already exists"
        return 0
    fi
    
    log "Creating new PostgreSQL instance..."
    gcloud sql instances create "$DB_INSTANCE" \
        --database-version=POSTGRES_15 \
        --tier=db-f1-micro \
        --region="$REGION" \
        --storage-type=HDD \
        --storage-size=10GB \
        --no-backup \
        --maintenance-window-day=SUN \
        --maintenance-window-hour=02
    
    log "Creating database..."
    gcloud sql databases create "$DB_NAME" --instance="$DB_INSTANCE"
    
    success "Database created"
}

# Build and push Docker images
build_and_push_images() {
    log "Building and pushing Docker images..."
    
    PROJECT_ID=$(gcloud config get-value project)
    
    # Configure Docker to use gcloud as credential helper
    gcloud auth configure-docker --quiet
    
    # Build and push API Server
    log "Building API Server image..."
    cd ../wlnx-api-server || { error "wlnx-api-server directory not found"; exit 1; }
    docker build -f ../wlnx-cloud-deploy/docker/api-server.Dockerfile -t "gcr.io/${PROJECT_ID}/wlnx-api-server:latest" .
    docker push "gcr.io/${PROJECT_ID}/wlnx-api-server:latest"
    
    # Build and push Control Panel
    log "Building Control Panel image..."
    cd ../wlnx-control-panel || { error "wlnx-control-panel directory not found"; exit 1; }
    docker build -f ../wlnx-cloud-deploy/docker/control-panel.Dockerfile -t "gcr.io/${PROJECT_ID}/wlnx-control-panel:latest" .
    docker push "gcr.io/${PROJECT_ID}/wlnx-control-panel:latest"
    
    # Build and push Telegram Bot
    log "Building Telegram Bot image..."
    cd ../wlnx-telegram-bot || { error "wlnx-telegram-bot directory not found"; exit 1; }
    docker build -f ../wlnx-cloud-deploy/docker/telegram-bot.Dockerfile -t "gcr.io/${PROJECT_ID}/wlnx-telegram-bot:latest" .
    docker push "gcr.io/${PROJECT_ID}/wlnx-telegram-bot:latest"
    
    # Return to original directory
    cd ../wlnx-cloud-deploy
    
    success "Docker images built and pushed"
}

# Deploy secrets and services
deploy_services() {
    log "Deploying services..."
    
    PROJECT_ID=$(gcloud config get-value project)
    
    # Replace PROJECT_ID placeholders in config files
    log "Updating configuration files with project ID..."
    sed -i.bak "s/PROJECT_ID/${PROJECT_ID}/g" gcp-config/*.yaml
    
    # Apply secrets first
    log "Creating secrets..."
    kubectl apply -f gcp-config/secrets.yaml
    
    # Deploy API Server
    log "Deploying API Server..."
    gcloud run services replace gcp-config/api-server-service.yaml --region=europe-west1
    
    # Deploy Control Panel
    log "Deploying Control Panel..."
    gcloud run services replace gcp-config/control-panel-service.yaml --region=europe-west1
    
    # Deploy Telegram Bot
    log "Deploying Telegram Bot..."
    gcloud run services replace gcp-config/telegram-bot-service.yaml --region=europe-west1
    
    # Restore original config files
    mv gcp-config/api-server-service.yaml.bak gcp-config/api-server-service.yaml
    mv gcp-config/control-panel-service.yaml.bak gcp-config/control-panel-service.yaml
    mv gcp-config/telegram-bot-service.yaml.bak gcp-config/telegram-bot-service.yaml
    mv gcp-config/secrets.yaml.bak gcp-config/secrets.yaml
    
    success "Services deployed"
}

# Get service URLs
get_service_info() {
    log "Getting service information..."
    
    PROJECT_ID=$(gcloud config get-value project)
    REGION="europe-west1"
    
    echo ""
    echo "🚀 Deployment info:"
    
    # Get API Server URL
    API_URL=$(gcloud run services describe wlnx-api-server --region=$REGION --format="value(status.url)" 2>/dev/null || echo "Not deployed")
    echo "🔧 API Server: $API_URL"
    
    # Get Control Panel URL
    PANEL_URL=$(gcloud run services describe wlnx-control-panel --region=$REGION --format="value(status.url)" 2>/dev/null || echo "Not deployed")
    echo "📱 Control Panel: $PANEL_URL"
    
    # Get Bot URL
    BOT_URL=$(gcloud run services describe wlnx-telegram-bot --region=$REGION --format="value(status.url)" 2>/dev/null || echo "Not deployed")
    echo "🤖 Telegram Bot: $BOT_URL"
    
    echo ""
    if [[ "$API_URL" != "Not deployed" ]]; then
        success "Services deployed successfully!"
    else
        error "Some services failed to deploy"
    fi
}

# Main function
main() {
    log "🚀 Starting WLNX deployment to Google Cloud Run"
    
    # Check we're in the right directory
    if [[ ! -d "gcp-config" ]]; then
        error "Run script from project root directory (gcp-config not found)"
        exit 1
    fi
    
    check_dependencies
    validate_config
    setup_gcp_services
    
    # Optionally create DB (uncomment if needed)
    # create_database
    
    build_and_push_images
    deploy_services
    get_service_info
    
    success "🎉 Deployment completed successfully!"
    
    echo ""
    echo "📋 Next steps:"
    echo "1. Update the secrets in gcp-config/secrets.yaml with your actual values"
    echo "2. Run: kubectl apply -f gcp-config/secrets.yaml"
    echo "3. Configure your Telegram bot webhook to point to the API server URL"
    echo "4. Test your services using the URLs shown above"
}

# Run
main "$@"
