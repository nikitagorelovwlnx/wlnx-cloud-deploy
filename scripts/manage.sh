#!/bin/bash

# WLNX Management Script
# Application management on Google Cloud Run

set -e

# Configuration
REGION="europe-west1"
SERVICES=("wlnx-api-server" "wlnx-control-panel" "wlnx-telegram-bot")

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

# Check if gcloud is configured
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI is not installed"
        exit 1
    fi
    
    if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" | head -n1 &> /dev/null; then
        error "gcloud is not authenticated. Run: gcloud auth login"
        exit 1
    fi
    
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [[ -z "$PROJECT_ID" ]]; then
        error "No project set. Run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
}

# Show services status
show_status() {
    log "Getting services status..."
    check_gcloud
    
    echo ""
    echo "🚀 Services Status:"
    for service in "${SERVICES[@]}"; do
        echo -n "  $service: "
        status=$(gcloud run services describe "$service" --region="$REGION" --format="value(status.conditions[0].type)" 2>/dev/null || echo "Not Found")
        if [[ "$status" == "Ready" ]]; then
            echo -e "${GREEN}Running${NC}"
        else
            echo -e "${RED}$status${NC}"
        fi
    done
    
    echo ""
    echo "🌐 Service URLs:"
    for service in "${SERVICES[@]}"; do
        url=$(gcloud run services describe "$service" --region="$REGION" --format="value(status.url)" 2>/dev/null || echo "Not deployed")
        echo "  $service: $url"
    done
    
    echo ""
    echo "💾 Cloud SQL Status:"
    gcloud sql instances list --format="table(name,databaseVersion,state,ipAddresses[0].ipAddress)" 2>/dev/null || echo "No databases found"
}

# Show logs
show_logs() {
    local service="$1"
    local lines="${2:-50}"
    
    if [[ -z "$service" ]]; then
        echo "Available services:"
        echo "  wlnx-api-server      API server"
        echo "  wlnx-control-panel   Control panel"
        echo "  wlnx-telegram-bot    Telegram bot"
        echo ""
        echo -n "Select service: "
        read -r service
    fi
    
    if [[ -z "$lines" ]]; then
        echo -n "Number of lines (default 50): "
        read -r lines
        lines=${lines:-50}
    fi
    
    check_gcloud
    
    log "Showing logs for $service (last $lines lines)..."
    gcloud run services logs read "$service" --region="$REGION" --limit="$lines"
}

# Scale services
scale_service() {
    local service="$1"
    local min_instances="$2"
    local max_instances="${3:-$2}"
    
    if [[ -z "$service" ]]; then
        echo "Available services:"
        echo "  wlnx-api-server      API server"
        echo "  wlnx-control-panel   Control panel"
        echo "  wlnx-telegram-bot    Telegram bot"
        echo ""
        echo -n "Select service: "
        read -r service
    fi
    
    if [[ -z "$min_instances" ]]; then
        echo -n "Enter minimum instances: "
        read -r min_instances
    fi
    
    if [[ -z "$max_instances" ]] || [[ "$max_instances" == "$min_instances" ]]; then
        echo -n "Enter maximum instances (default: $min_instances): "
        read -r max_instances
        max_instances=${max_instances:-$min_instances}
    fi
    
    if ! [[ "$min_instances" =~ ^[0-9]+$ ]] || [[ "$min_instances" -lt 0 ]] || [[ "$min_instances" -gt 100 ]]; then
        error "Minimum instance count must be between 0 and 100"
        exit 1
    fi
    
    check_gcloud
    
    log "Scaling $service to min: $min_instances, max: $max_instances instances..."
    
    gcloud run services update "$service" \
        --region="$REGION" \
        --min-instances="$min_instances" \
        --max-instances="$max_instances"
    
    success "Service $service scaled successfully"
}

# Environment variables management
manage_env() {
    local action="$1"
    local service="$2"
    local key="$3"
    local value="$4"
    
    check_gcloud
    
    case "$action" in
        "list")
            log "Environment variables for service $service:"
            gcloud run services describe "$service" --region="$REGION" --format="value(spec.template.spec.containers[0].env[].name,spec.template.spec.containers[0].env[].value)"
            ;;
        "set")
            if [[ -z "$key" ]] || [[ -z "$value" ]]; then
                error "Usage: manage_env set SERVICE KEY VALUE"
                exit 1
            fi
            log "Setting $key for service $service..."
            gcloud run services update "$service" --region="$REGION" --set-env-vars="$key=$value"
            success "Environment variable $key updated"
            ;;
        *)
            echo "Environment variable actions:"
            echo "  list SERVICE           Show variables"
            echo "  set SERVICE KEY VALUE  Set variable"
            ;;
    esac
}

# Resource monitoring
show_metrics() {
    check_gcloud
    
    log "📈 Service metrics"
    
    PROJECT_ID=$(gcloud config get-value project)
    
    echo ""
    echo "📊 Performance Metrics:"
    for service in "${SERVICES[@]}"; do
        echo "  $service:"
        echo "    Metrics: https://console.cloud.google.com/run/detail/$REGION/$service/metrics?project=$PROJECT_ID"
        echo "    Logs: https://console.cloud.google.com/run/detail/$REGION/$service/logs?project=$PROJECT_ID"
    done
    
    echo ""
    echo "💰 Billing Information:"
    echo "Visit: https://console.cloud.google.com/billing?project=$PROJECT_ID"
}

# Database backup
backup_database() {
    check_gcloud
    
    log "💾 Creating Cloud SQL backup..."
    
    # Get instances list
    instances=$(gcloud sql instances list --format="value(name)" 2>/dev/null)
    
    if [[ -z "$instances" ]]; then
        warning "No Cloud SQL instances found"
        return
    fi
    
    echo "Available instances:"
    echo "$instances"
    echo ""
    echo -n "Enter instance name (or press Enter for all): "
    read -r instance_name
    
    if [[ -z "$instance_name" ]]; then
        # Backup all instances
        for instance in $instances; do
            log "Creating backup for instance: $instance"
            backup_id="wlnx-backup-$(date +%Y%m%d-%H%M%S)"
            gcloud sql backups create --instance="$instance" --description="Manual backup $backup_id"
            success "Backup created for instance: $instance"
        done
    else
        # Backup specific instance
        log "Creating backup for instance: $instance_name"
        backup_id="wlnx-backup-$(date +%Y%m%d-%H%M%S)"
        gcloud sql backups create --instance="$instance_name" --description="Manual backup $backup_id"
        success "Backup created for instance: $instance_name"
    fi
}

# Restart service
restart_service() {
    local service="$1"
    
    if [[ -z "$service" ]]; then
        echo "Available services:"
        echo "  wlnx-api-server      API server"
        echo "  wlnx-control-panel   Control panel"
        echo "  wlnx-telegram-bot    Telegram bot"
        echo ""
        echo -n "Select service: "
        read -r service
    fi
    
    check_gcloud
    
    log "Restarting $service..."
    
    # Force a new revision by updating with current time annotation
    gcloud run services update "$service" \
        --region="$REGION" \
        --update-annotations="restart.time=$(date +%s)"
    
    success "Service $service restarted"
}

# Show help
show_help() {
    echo "🚀 WLNX Management Tool for Google Cloud Run"
    echo ""
    echo "Usage: $0 COMMAND [OPTIONS]"
    echo ""
    echo "Management commands:"
    echo "  status                           Show services status"
    echo "  logs [SERVICE] [LINES]          Show service logs (default: 50 lines)"
    echo "  scale SERVICE MIN [MAX]         Scale service instances"
    echo "  env ACTION [ARGS]               Manage environment variables"
    echo "  metrics                         Show performance metrics URLs"
    echo "  backup                          Create Cloud SQL backup"
    echo "  restart [SERVICE]               Restart a service"
    echo "  help                            Show this help"
    echo ""
    echo "Services:"
    echo "  wlnx-api-server                 API Server service"
    echo "  wlnx-control-panel              Control Panel service"
    echo "  wlnx-telegram-bot               Telegram Bot service"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 logs wlnx-api-server 100"
    echo "  $0 scale wlnx-api-server 2 5"
    echo "  $0 env list wlnx-api-server"
    echo "  $0 restart wlnx-telegram-bot"
    echo "  $0 backup"
}

# Delete services
delete_services() {
    check_gcloud
    
    warning "⚠️  WARNING: This action will delete all WLNX services!"
    echo "Will be deleted:"
    echo "  - All Cloud Run services"
    echo "  - All service revisions and history"
    echo ""
    echo "Cloud SQL databases will remain and need to be deleted separately."
    echo ""
    echo -n "Are you sure? Type 'DELETE' to confirm: "
    read -r confirmation
    
    if [[ "$confirmation" == "DELETE" ]]; then
        log "Deleting services..."
        for service in "${SERVICES[@]}"; do
            if gcloud run services describe "$service" --region="$REGION" >/dev/null 2>&1; then
                log "Deleting service: $service"
                gcloud run services delete "$service" --region="$REGION" --quiet
            else
                warning "Service $service not found, skipping"
            fi
        done
        
        success "All services deleted"
    else
        log "Deletion cancelled"
    fi
}

# Main function
main() {
    command="$1"
    
    if [[ -z "$command" ]]; then
        show_help
        exit 1
    fi
    
    case "$command" in
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2" "$3"
            ;;
        "scale")
            scale_service "$2" "$3" "$4"
            ;;
        "env")
            manage_env "$2" "$3" "$4" "$5"
            ;;
        "metrics")
            show_metrics
            ;;
        "backup")
            backup_database
            ;;
        "restart")
            restart_service "$2"
            ;;
        "delete")
            delete_services
            ;;
        *)
            error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run
main "$@"
