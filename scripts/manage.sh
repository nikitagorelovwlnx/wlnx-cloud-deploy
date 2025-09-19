#!/bin/bash

# WLNX Management Script
# Application management on DigitalOcean App Platform

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

# Check App ID
check_app_id() {
    if [[ ! -f ".app-id" ]]; then
        error "Application ID not found. Deploy first."
        exit 1
    fi
    
    APP_ID=$(cat .app-id)
}

# Show application status
show_status() {
    log "Getting application status..."
    
    echo "📊 General information:"
    doctl apps get "$APP_ID" --format Name,Phase,LiveURL,CreatedAt
    
    echo ""
    echo "🔄 Recent deployments:"
    doctl apps list-deployments "$APP_ID" --format ID,Phase,CreatedAt | head -6
    
    echo ""
    echo "🏗️ Application components:"
    doctl apps get "$APP_ID" --format Services,Workers,StaticSites
}

# Show logs
show_logs() {
    local component="$1"
    local type="$2"
    
    if [[ -z "$component" ]]; then
        echo "Available components:"
        echo "  api-server      API server"
        echo "  control-panel   Control panel"
        echo "  telegram-bot    Telegram bot"
        echo ""
        echo -n "Select component: "
        read -r component
    fi
    
    if [[ -z "$type" ]]; then
        echo "Available log types:"
        echo "  build    Build logs"
        echo "  deploy   Deploy logs"
        echo "  run      Runtime logs"
        echo ""
        echo -n "Select type (default run): "
        read -r type
        type=${type:-run}
    fi
    
    log "Getting $type logs for component $component..."
    doctl apps logs "$APP_ID" "$component" --type "$type" --follow
}

# Scaling
scale_component() {
    local component="$1"
    local instances="$2"
    
    if [[ -z "$component" ]]; then
        echo "Available components for scaling:"
        echo "  api-server      API server"
        echo "  control-panel   Control panel"
        echo ""
        echo -n "Select component: "
        read -r component
    fi
    
    if [[ -z "$instances" ]]; then
        echo -n "Enter number of instances: "
        read -r instances
    fi
    
    if ! [[ "$instances" =~ ^[0-9]+$ ]] || [[ "$instances" -lt 1 ]] || [[ "$instances" -gt 10 ]]; then
        error "Instance count must be between 1 and 10"
        exit 1
    fi
    
    warning "Changing instance count requires updating application specification"
    echo "Edit do-app.yaml and run deployment again"
    
    # TODO: Automatic YAML update and deploy
}

# Environment variables management
manage_env() {
    local action="$1"
    local component="$2"
    local key="$3"
    local value="$4"
    
    case "$action" in
        "list")
            log "Environment variables for component $component:"
            # doctl apps get doesn't show variables directly
            # Show what's in specification
            echo "Check variables in do-app.yaml file"
            ;;
        "set")
            warning "Changing environment variables requires updating specification"
            echo "Edit do-app.yaml and run deployment again"
            ;;
        *)
            echo "Environment variable actions:"
            echo "  list COMPONENT      Show variables"
            echo "  set COMPONENT KEY VALUE  Set variable"
            ;;
    esac
}

# Resource monitoring
show_metrics() {
    log "📈 Application metrics"
    warning "Detailed metrics available in DigitalOcean web interface"
    
    # Show basic information
    doctl apps get "$APP_ID" --format Name,Phase,Region,TierSlug
    
    echo ""
    echo "🌐 For detailed metrics open:"
    echo "https://cloud.digitalocean.com/apps/$APP_ID/overview"
}

# Database backup
backup_database() {
    log "💾 Creating database backup..."
    
    # Get database list
    DB_LIST=$(doctl databases list --format Name,Engine --no-header | grep "wlnx")
    
    if [[ -z "$DB_LIST" ]]; then
        warning "WLNX database not found"
        return
    fi
    
    echo "$DB_LIST"
    echo ""
    echo -n "Enter database name: "
    read -r db_name
    
    # Create backup
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_name="wlnx_backup_$timestamp"
    
    doctl databases backups create "$db_name" --name "$backup_name"
    success "Backup '$backup_name' created"
}

# Show help
show_help() {
    echo "🚀 WLNX Management Tool"
    echo ""
    echo "Usage: $0 COMMAND [OPTIONS]"
    echo ""
    echo "Management commands:"
    echo "  status                 Show application status"
    echo "  logs [COMPONENT] [TYPE] Show component logs"
    echo "  scale COMPONENT COUNT  Scale component"
    echo "  env ACTION [ARGS]      Manage environment variables"
    echo "  metrics               Show metrics"
    echo "  backup                Create database backup"
    echo "  restart               Restart application"
    echo "  delete                Delete application"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 logs api-server run"
    echo "  $0 scale api-server 3"
    echo "  $0 env list api-server"
    echo "  $0 metrics"
    echo "  $0 backup"
}

# Restart application
restart_app() {
    warning "Application restart is performed through re-deployment"
    echo -n "Continue? (y/N): "
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log "Performing re-deployment..."
        ./scripts/deploy.sh
    else
        log "Restart cancelled"
    fi
}

# Delete application
delete_app() {
    warning "⚠️  WARNING: This action will delete the entire application!"
    echo "Will be deleted:"
    echo "  - All services and workers"
    echo "  - All deployments and their history"
    echo "  - All application settings"
    echo ""
    echo "Database will remain, it needs to be deleted separately."
    echo ""
    echo -n "Are you sure? Type 'DELETE' to confirm: "
    read -r confirmation
    
    if [[ "$confirmation" == "DELETE" ]]; then
        log "Deleting application..."
        doctl apps delete "$APP_ID" --force
        
        # Remove local ID file
        rm -f .app-id
        
        success "Application deleted"
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
    
    # Commands that don't require App ID check
    case "$command" in
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
    esac
    
    # For all other commands App ID is required
    check_app_id
    
    case "$command" in
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2" "$3"
            ;;
        "scale")
            scale_component "$2" "$3"
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
            restart_app
            ;;
        "delete")
            delete_app
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
