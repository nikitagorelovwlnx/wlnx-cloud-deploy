#!/bin/bash

# Script for checking WLNX application health
# Checks all components and their operability

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
    echo -e "${RED}[✗]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Global variables
ISSUES=0
APP_URL=""
TELEGRAM_BOT_TOKEN=""

# Check App ID
check_app_id() {
    if [[ ! -f ".app-id" ]]; then
        error "Application ID not found"
        ((ISSUES++))
        return 1
    fi
    
    APP_ID=$(cat .app-id)
    success "App ID found: $APP_ID"
    return 0
}

# Get application URL
get_app_url() {
    if ! check_app_id; then
        return 1
    fi
    
    APP_ID=$(cat .app-id)
    APP_URL=$(doctl apps get "$APP_ID" --format LiveURL --no-header 2>/dev/null)
    
    if [[ -z "$APP_URL" ]]; then
        error "Unable to get application URL"
        ((ISSUES++))
        return 1
    fi
    
    success "Application URL: $APP_URL"
    return 0
}

# Check application status in DO
check_app_status() {
    log "Checking application status in DigitalOcean..."
    
    if ! check_app_id; then
        return 1
    fi
    
    APP_ID=$(cat .app-id)
    
    # Get general status
    app_status=$(doctl apps get "$APP_ID" --format Phase --no-header 2>/dev/null)
    
    case "$app_status" in
        "ACTIVE")
            success "Application is active"
            ;;
        "DEPLOYING")
            warning "Application is deploying"
            ;;
        "ERROR")
            error "Application is in error state"
            ((ISSUES++))
            ;;
        *)
            warning "Unknown application status: $app_status"
            ((ISSUES++))
            ;;
    esac
    
    # Check last deployment
    last_deployment=$(doctl apps list-deployments "$APP_ID" --format Phase,CreatedAt --no-header | head -1)
    log "Last deployment: $last_deployment"
}

# Check API server
check_api_server() {
    log "Checking API server..."
    
    if [[ -z "$APP_URL" ]]; then
        error "Application URL unavailable"
        ((ISSUES++))
        return 1
    fi
    
    # Check health endpoint
    health_url="$APP_URL/api/health"
    
    if response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 "$health_url"); then
        if [[ "$response" == "200" ]]; then
            success "API server responds (HTTP $response)"
        else
            warning "API server responds with HTTP $response"
            ((ISSUES++))
        fi
    else
        error "API server unavailable"
        ((ISSUES++))
    fi
    
    # Check basic API endpoint
    api_url="$APP_URL/api"
    if response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 "$api_url"); then
        if [[ "$response" == "200" || "$response" == "404" ]]; then
            success "API endpoint accessible (HTTP $response)"
        else
            warning "API endpoint returned HTTP $response"
        fi
    else
        error "API endpoint unavailable"
        ((ISSUES++))
    fi
}

# Check control panel
check_control_panel() {
    log "Checking control panel..."
    
    if [[ -z "$APP_URL" ]]; then
        error "Application URL unavailable"
        ((ISSUES++))
        return 1
    fi
    
    if response=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 "$APP_URL"); then
        if [[ "$response" == "200" ]]; then
            success "Control panel accessible (HTTP $response)"
        else
            warning "Control panel returned HTTP $response"
            ((ISSUES++))
        fi
    else
        error "Control panel unavailable"
        ((ISSUES++))
    fi
}

# Check Telegram bot
check_telegram_bot() {
    log "Checking Telegram bot..."
    
    # Load token from .env if exists
    if [[ -f ".env" ]]; then
        source .env
        TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
    fi
    
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]]; then
        warning "TELEGRAM_BOT_TOKEN not found in .env"
        ((ISSUES++))
        return 1
    fi
    
    # Check bot status via API
    bot_response=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getMe")
    
    if echo "$bot_response" | grep -q '"ok":true'; then
        bot_username=$(echo "$bot_response" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        success "Telegram bot active: @$bot_username"
    else
        error "Telegram bot unavailable or token invalid"
        ((ISSUES++))
        return 1
    fi
    
    # Check webhook
    webhook_response=$(curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getWebhookInfo")
    
    if echo "$webhook_response" | grep -q '"ok":true'; then
        webhook_url=$(echo "$webhook_response" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        
        if [[ -n "$webhook_url" ]]; then
            success "Webhook configured: $webhook_url"
        else
            warning "Webhook not configured"
            ((ISSUES++))
        fi
    else
        error "Unable to get webhook information"
        ((ISSUES++))
    fi
}

# Check database
check_database() {
    log "Checking database..."
    
    # Get database list
    db_list=$(doctl databases list --format Name,Status,Engine --no-header 2>/dev/null | grep wlnx || true)
    
    if [[ -n "$db_list" ]]; then
        success "Found databases:"
        echo "$db_list" | while read -r line; do
            echo "  $line"
        done
        
        # Check status of each DB
        echo "$db_list" | while IFS=$'\t' read -r name status engine; do
            if [[ "$status" == "online" ]]; then
                success "DB $name ($engine) online"
            else
                warning "DB $name ($engine) status: $status"
                ((ISSUES++))
            fi
        done
    else
        warning "WLNX databases not found or unavailable"
        ((ISSUES++))
    fi
}

# Check SSL certificates
check_ssl() {
    log "Checking SSL certificate..."
    
    if [[ -z "$APP_URL" ]]; then
        return 1
    fi
    
    # Extract domain from URL
    domain=$(echo "$APP_URL" | sed 's|https\?://||' | sed 's|/.*||')
    
    # Check certificate
    if cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null); then
        expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
        success "SSL certificate valid until: $expiry_date"
        
        # Check if certificate expires in next 30 days
        if command -v gdate &> /dev/null; then
            # macOS with GNU date
            expiry_timestamp=$(gdate -d "$expiry_date" +%s)
            current_timestamp=$(gdate +%s)
        else
            # Linux date
            expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
            current_timestamp=$(date +%s)
        fi
        
        if [[ "$expiry_timestamp" -gt "$current_timestamp" ]]; then
            days_left=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            if [[ "$days_left" -lt 30 ]]; then
                warning "SSL certificate expires in $days_left days"
            fi
        fi
    else
        error "Unable to check SSL certificate"
        ((ISSUES++))
    fi
}

# Check performance
check_performance() {
    log "Checking performance..."
    
    if [[ -z "$APP_URL" ]]; then
        return 1
    fi
    
    # Measure response time
    start_time=$(date +%s.%N)
    
    if curl -s -o /dev/null --connect-timeout 10 --max-time 30 "$APP_URL/api/health" &>/dev/null; then
        end_time=$(date +%s.%N)
        response_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
        
        if command -v bc &> /dev/null && [[ "$response_time" != "N/A" ]]; then
            response_ms=$(echo "$response_time * 1000" | bc | cut -d. -f1)
            
            if [[ "$response_ms" -lt 1000 ]]; then
                success "API response time: ${response_ms}ms"
            elif [[ "$response_ms" -lt 5000 ]]; then
                warning "API response time: ${response_ms}ms (slow)"
            else
                error "API response time: ${response_ms}ms (very slow)"
                ((ISSUES++))
            fi
        else
            success "API responds (response time not measured)"
        fi
    else
        error "API doesn't respond within 30 seconds"
        ((ISSUES++))
    fi
}

# Generate report
generate_report() {
    echo ""
    echo "=================================================="
    echo "📋 WLNX HEALTH REPORT"
    echo "=================================================="
    echo "🕐 Check time: $(date)"
    
    if [[ "$ISSUES" -eq 0 ]]; then
        echo -e "🎉 ${GREEN}Status: ALL OK${NC}"
        echo "✅ All components working normally"
    elif [[ "$ISSUES" -le 3 ]]; then
        echo -e "⚠️  ${YELLOW}Status: WARNINGS PRESENT${NC}"
        echo "🔧 Issues found: $ISSUES"
        echo "💡 Recommend checking logs: ./scripts/manage.sh logs"
    else
        echo -e "❌ ${RED}Status: CRITICAL ISSUES${NC}"
        echo "🚨 Serious issues found: $ISSUES"
        echo "🔥 Immediate attention required!"
        echo ""
        echo "Recommended actions:"
        echo "1. Check logs: ./scripts/manage.sh logs"
        echo "2. Check status: ./scripts/manage.sh status"
        echo "3. If necessary rollback: ./scripts/rollback.sh"
    fi
    
    echo ""
    echo "🌐 Application URL: ${APP_URL:-"Unavailable"}"
    echo "📊 For detailed monitoring: ./scripts/manage.sh metrics"
    echo "=================================================="
}

# Main function
main() {
    echo "🩺 WLNX Application Health Check"
    echo ""
    
    # Perform all checks
    get_app_url
    check_app_status
    check_api_server
    check_control_panel
    check_telegram_bot
    check_database
    check_ssl
    check_performance
    
    # Generate report
    generate_report
    
    # Return exit code based on issue count
    if [[ "$ISSUES" -eq 0 ]]; then
        exit 0
    elif [[ "$ISSUES" -le 3 ]]; then
        exit 1
    else
        exit 2
    fi
}

# Show help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "🩺 WLNX Health Check Script"
    echo ""
    echo "Usage: $0"
    echo ""
    echo "Checks:"
    echo "  ✓ Application status in DigitalOcean"
    echo "  ✓ API server availability"
    echo "  ✓ Control panel availability"
    echo "  ✓ Telegram bot functionality"
    echo "  ✓ Database status"
    echo "  ✓ SSL certificates"
    echo "  ✓ Performance"
    echo ""
    echo "Exit codes:"
    echo "  0 - All OK"
    echo "  1 - Warnings present (1-3 issues)"
    echo "  2 - Critical issues (>3 issues)"
    exit 0
fi

# Run
main "$@"
