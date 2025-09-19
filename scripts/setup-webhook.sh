#!/bin/bash

# Script for setting up Telegram webhook
# Automatically configures webhook after deployment

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

# Check .env file
check_env() {
    if [[ ! -f ".env" ]]; then
        error ".env file not found. Create it from .env.template"
        exit 1
    fi
    
    # Load variables from .env
    source .env
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        error "TELEGRAM_BOT_TOKEN not set in .env"
        exit 1
    fi
    
    if [[ -z "$TELEGRAM_WEBHOOK_SECRET" ]]; then
        error "TELEGRAM_WEBHOOK_SECRET not set in .env"
        exit 1
    fi
}

# Get application URL
get_app_url() {
    if [[ ! -f ".app-id" ]]; then
        error "Application ID not found. Deploy first."
        exit 1
    fi
    
    APP_ID=$(cat .app-id)
    APP_URL=$(doctl apps get "$APP_ID" --format LiveURL --no-header)
    
    if [[ -z "$APP_URL" ]]; then
        error "Unable to get application URL"
        exit 1
    fi
    
    log "Application URL: $APP_URL"
}

# Setup webhook
setup_webhook() {
    local webhook_url="$APP_URL/api/webhook/telegram"
    
    log "Setting up webhook: $webhook_url"
    
    # Send request to Telegram API
    response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook" \
        -H "Content-Type: application/json" \
        -d "{
            \"url\":\"$webhook_url\",
            \"secret_token\":\"$TELEGRAM_WEBHOOK_SECRET\",
            \"max_connections\":100,
            \"allowed_updates\":[\"message\",\"callback_query\",\"inline_query\"]
        }")
    
    # Parse response
    if echo "$response" | grep -q '"ok":true'; then
        success "Webhook configured successfully!"
        
        # Show webhook information
        log "Getting webhook information..."
        curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo" | \
            jq -r '.result | "URL: \(.url)\nLast error: \(.last_error_message // "None")\nCertificate: \(.has_custom_certificate)\nMax connections: \(.max_connections)"'
        
    else
        error "Error setting up webhook:"
        echo "$response" | jq -r '.description // .error_code'
        exit 1
    fi
}

# Check webhook
test_webhook() {
    log "Testing webhook..."
    
    # Get bot information
    bot_info=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe")
    
    if echo "$bot_info" | grep -q '"ok":true'; then
        bot_username=$(echo "$bot_info" | jq -r '.result.username')
        success "Bot is active: @$bot_username"
        
        echo ""
        echo "🤖 To test functionality:"
        echo "1. Open Telegram"
        echo "2. Find bot @$bot_username"
        echo "3. Send /start command"
        echo "4. Bot should respond"
        
    else
        warning "Unable to get bot information"
        echo "$bot_info" | jq -r '.description // .error_code'
    fi
}

# Remove webhook (for testing)
remove_webhook() {
    log "Removing webhook..."
    
    response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/deleteWebhook")
    
    if echo "$response" | grep -q '"ok":true'; then
        success "Webhook removed"
    else
        error "Error removing webhook:"
        echo "$response" | jq -r '.description'
    fi
}

# Show help
show_help() {
    echo "🔧 Telegram webhook setup script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup     Setup webhook (default)"
    echo "  test      Test bot functionality"
    echo "  remove    Remove webhook"
    echo "  info      Show webhook information"
    echo ""
    echo "Examples:"
    echo "  $0              # Setup webhook"
    echo "  $0 setup        # Setup webhook"
    echo "  $0 test         # Test bot"
    echo "  $0 remove       # Remove webhook"
}

# Show webhook information
show_info() {
    log "Getting webhook information..."
    
    response=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo")
    
    if echo "$response" | grep -q '"ok":true'; then
        echo "$response" | jq -r '
            .result | 
            "📍 URL: \(.url // "Not set")
📊 Pending updates: \(.pending_update_count)
🔗 Max connections: \(.max_connections)
📝 Allowed updates: \(.allowed_updates | join(", "))
❌ Last error: \(.last_error_message // "None")
📅 Last error date: \(.last_error_date // "None" | if . == "None" then . else (. | strftime("%Y-%m-%d %H:%M:%S")) end)
🎯 IP address: \(.ip_address // "Unknown")"
        '
    else
        error "Error getting information:"
        echo "$response" | jq -r '.description'
    fi
}

# Main function
main() {
    command="${1:-setup}"
    
    case "$command" in
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        "setup")
            log "🔧 Setting up Telegram webhook for WLNX"
            check_env
            get_app_url
            setup_webhook
            test_webhook
            ;;
        "test")
            check_env
            test_webhook
            ;;
        "remove")
            check_env
            remove_webhook
            ;;
        "info")
            check_env
            show_info
            ;;
        *)
            error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Check dependencies
if ! command -v jq &> /dev/null; then
    warning "jq is not installed. Some functions may not work correctly."
    warning "Install jq: brew install jq (macOS) or apt install jq (Ubuntu)"
fi

if ! command -v curl &> /dev/null; then
    error "curl is not installed"
    exit 1
fi

# Run
main "$@"
