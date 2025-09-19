#!/bin/bash

# WLNX Rollback Script
# Rollback to previous successful deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check App ID exists
check_app_id() {
    if [[ ! -f ".app-id" ]]; then
        error "Application ID not found. Deploy first."
        exit 1
    fi
    
    APP_ID=$(cat .app-id)
    log "Using application ID: $APP_ID"
}

# Show available deployments
list_deployments() {
    log "Available deployments:"
    echo ""
    
    doctl apps list-deployments "$APP_ID" --format ID,Phase,CreatedAt,UpdatedAt | head -11
    echo ""
}

# Get last successful deployment
get_last_successful_deployment() {
    LAST_OK=$(doctl apps list-deployments "$APP_ID" --format ID,Phase --no-header | awk '$2=="ACTIVE"{print $1; exit}')
    
    if [[ -z "$LAST_OK" ]]; then
        error "No successful deployment found for rollback"
        exit 1
    fi
    
    log "Found last successful deployment: $LAST_OK"
    echo "$LAST_OK"
}

# Rollback to specified deployment
rollback_to_deployment() {
    local deployment_id="$1"
    
    if [[ -z "$deployment_id" ]]; then
        error "Deployment ID not specified"
        exit 1
    fi
    
    log "Rolling back to deployment: $deployment_id"
    
    # Get token for API
    DIGITALOCEAN_TOKEN=$(doctl auth list | awk 'NR>1 {print $2}' | head -1)
    
    if [[ -z "$DIGITALOCEAN_TOKEN" ]]; then
        error "Unable to get DigitalOcean token"
        exit 1
    fi
    
    # Execute rollback via API
    response=$(curl -s -w "%{http_code}" -X POST \
        "https://api.digitalocean.com/v2/apps/$APP_ID/rollback" \
        -H "Authorization: Bearer $DIGITALOCEAN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"deployment_id\":\"$deployment_id\"}")
    
    http_code="${response: -3}"
    
    if [[ "$http_code" == "200" || "$http_code" == "202" ]]; then
        success "Rollback initiated successfully"
        
        # Wait for rollback completion
        log "Waiting for rollback completion..."
        while true; do
            DEPLOYMENT_STATUS=$(doctl apps list-deployments "$APP_ID" --format Phase --no-header | head -n1)
            case "$DEPLOYMENT_STATUS" in
                "ACTIVE")
                    success "Rollback completed successfully!"
                    break
                    ;;
                "ERROR"|"CANCELED")
                    error "Rollback failed"
                    exit 1
                    ;;
                *)
                    log "Rollback status: $DEPLOYMENT_STATUS"
                    sleep 30
                    ;;
            esac
        done
    else
        error "Rollback execution error. HTTP code: $http_code"
        echo "Response: ${response%???}"
        exit 1
    fi
}

# Interactive rollback selection
interactive_rollback() {
    list_deployments
    
    echo -n "Enter deployment ID to rollback (or press Enter for last successful): "
    read -r deployment_id
    
    if [[ -z "$deployment_id" ]]; then
        deployment_id=$(get_last_successful_deployment)
    fi
    
    echo ""
    warning "You are about to rollback to deployment: $deployment_id"
    echo -n "Continue? (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rollback_to_deployment "$deployment_id"
    else
        log "Rollback cancelled"
        exit 0
    fi
}

# Main function
main() {
    log "🔄 WLNX Rollback Script"
    
    check_app_id
    
    if [[ $# -eq 0 ]]; then
        # Interactive mode
        interactive_rollback
    elif [[ "$1" == "last" ]]; then
        # Rollback to last successful
        deployment_id=$(get_last_successful_deployment)
        rollback_to_deployment "$deployment_id"
    elif [[ "$1" == "list" ]]; then
        # Show deployment list
        list_deployments
    else
        # Rollback to specified deployment
        rollback_to_deployment "$1"
    fi
    
    success "🎉 Rollback completed!"
}

# Show help
show_help() {
    echo "Usage: $0 [COMMAND|DEPLOYMENT_ID]"
    echo ""
    echo "Commands:"
    echo "  last          Rollback to last successful deployment"
    echo "  list          Show available deployments"
    echo "  DEPLOYMENT_ID Rollback to specified deployment"
    echo "  (no args)     Interactive mode"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive selection"
    echo "  $0 last              # Rollback to last successful"
    echo "  $0 abc123def         # Rollback to specific deployment"
    echo "  $0 list              # Show available deployments"
}

# Check arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Run
main "$@"
