#!/bin/bash

# WLNX Cloud Deployment Script
# Automatic deployment to DigitalOcean App Platform

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
    
    if ! command -v doctl &> /dev/null; then
        error "doctl is not installed. Install it: https://docs.digitalocean.com/reference/doctl/how-to/install/"
        exit 1
    fi
    
    # Check authorization
    if ! doctl auth list &> /dev/null; then
        error "doctl is not authorized. Run: doctl auth init"
        exit 1
    fi
    
    success "All dependencies checked"
}

# Validate configuration
validate_config() {
    log "Validating configuration..."
    
    if [[ ! -f "do-app.yaml" ]]; then
        error "do-app.yaml file not found"
        exit 1
    fi
    
    # Validate specification
    if doctl apps spec validate --spec do-app.yaml; then
        success "Configuration is valid"
    else
        error "Error in do-app.yaml configuration"
        exit 1
    fi
}

# Create database (optional)
create_database() {
    log "Creating database..."
    
    DB_NAME="wlnx-pg"
    
    # Check if DB already exists
    if doctl databases list | grep -q "$DB_NAME"; then
        warning "Database $DB_NAME already exists"
        return 0
    fi
    
    log "Creating new PostgreSQL database..."
    doctl databases create "$DB_NAME" \
        --engine pg \
        --region fra \
        --size db-s-1vcpu-1gb \
        --num-nodes 1
    
    success "Database created"
}

# Deploy application
deploy_app() {
    log "Deploying application..."
    
    # Create or update application
    if [[ -f ".app-id" ]]; then
        APP_ID=$(cat .app-id)
        log "Updating existing application (ID: $APP_ID)..."
        doctl apps update "$APP_ID" --spec do-app.yaml
    else
        log "Creating new application..."
        APP_ID=$(doctl apps create --spec do-app.yaml --format ID --no-header)
        echo "$APP_ID" > .app-id
        success "Application created with ID: $APP_ID"
    fi
    
    # Wait for deployment completion
    log "Waiting for deployment completion..."
    while true; do
        DEPLOYMENT_STATUS=$(doctl apps list-deployments "$APP_ID" --format Phase --no-header | head -n1)
        case "$DEPLOYMENT_STATUS" in
            "ACTIVE")
                success "Deployment completed successfully!"
                break
                ;;
            "ERROR"|"CANCELED")
                error "Deployment failed"
                doctl apps logs "$APP_ID" api-server --type build
                exit 1
                ;;
            *)
                log "Deployment status: $DEPLOYMENT_STATUS"
                sleep 30
                ;;
        esac
    done
}

# Get application info
get_app_info() {
    if [[ ! -f ".app-id" ]]; then
        warning "Application ID not found"
        return
    fi
    
    APP_ID=$(cat .app-id)
    log "Getting application info..."
    
    echo ""
    echo "🚀 Deployment info:"
    doctl apps get "$APP_ID" --format Name,DefaultIngress,LiveURL
    echo ""
    
    # Get application URL
    APP_URL=$(doctl apps get "$APP_ID" --format LiveURL --no-header)
    if [[ -n "$APP_URL" ]]; then
        success "Application available at: $APP_URL"
        echo "📱 Control Panel: $APP_URL"
        echo "🔧 API: $APP_URL/api"
    fi
}

# Main function
main() {
    log "🚀 Starting WLNX deployment to DigitalOcean App Platform"
    
    # Check we're in the right directory
    if [[ ! -f "do-app.yaml" ]]; then
        error "Run script from project root directory"
        exit 1
    fi
    
    check_dependencies
    validate_config
    
    # Optionally create DB (uncomment if needed)
    # create_database
    
    deploy_app
    get_app_info
    
    success "🎉 Deployment completed successfully!"
}

# Run
main "$@"
