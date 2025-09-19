#!/bin/bash

# WLNX Monitoring Script
# Continuous application monitoring with alerts

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

# Monitoring configuration
MONITOR_INTERVAL=60  # seconds between checks
ALERT_THRESHOLD=3    # consecutive failures for alert
RESPONSE_TIME_THRESHOLD=5.0  # max response time in seconds

# Files for tracking state
STATUS_FILE="/tmp/wlnx_monitor_status"
ALERT_FILE="/tmp/wlnx_monitor_alerts"
LOG_FILE="/tmp/wlnx_monitor.log"

# Counters
FAILURE_COUNT=0
TOTAL_CHECKS=0
SUCCESS_COUNT=0

# Check App ID
get_app_info() {
    if [[ ! -f ".app-id" ]]; then
        error "Application ID not found. Deploy first."
        exit 1
    fi
    
    APP_ID=$(cat .app-id)
    APP_URL=$(doctl apps get "$APP_ID" --format LiveURL --no-header 2>/dev/null)
    
    if [[ -z "$APP_URL" ]]; then
        error "Unable to get application URL"
        exit 1
    fi
    
    log "Monitoring application: $APP_URL (ID: $APP_ID)"
}

# Check application health
check_health() {
    local check_time=$(date)
    local status="OK"
    local issues=""
    
    ((TOTAL_CHECKS++))
    
    # Check main page availability
    if ! curl -s -f --max-time 10 "$APP_URL" > /dev/null 2>&1; then
        status="FAILED"
        issues="$issues Main_page_unreachable"
    fi
    
    # Check API health endpoint
    if ! curl -s -f --max-time 10 "$APP_URL/api/health" > /dev/null 2>&1; then
        status="FAILED"
        issues="$issues API_health_failed"
    fi
    
    # Check response time
    response_time=$(curl -s -w "%{time_total}" -o /dev/null --max-time 30 "$APP_URL/api/health" 2>/dev/null || echo "999")
    
    if (( $(echo "$response_time > $RESPONSE_TIME_THRESHOLD" | bc -l 2>/dev/null || echo "1") )); then
        if [[ "$status" == "OK" ]]; then
            status="SLOW"
        fi
        issues="$issues Slow_response(${response_time}s)"
    fi
    
    # Check application status in DO
    app_status=$(doctl apps get "$APP_ID" --format Phase --no-header 2>/dev/null || echo "UNKNOWN")
    if [[ "$app_status" != "ACTIVE" ]]; then
        status="FAILED"
        issues="$issues App_status($app_status)"
    fi
    
    # Update statistics
    if [[ "$status" == "OK" ]]; then
        ((SUCCESS_COUNT++))
        FAILURE_COUNT=0
        success "Check #$TOTAL_CHECKS: ALL OK (response time: ${response_time}s)"
    else
        ((FAILURE_COUNT++))
        if [[ "$status" == "SLOW" ]]; then
            warning "Check #$TOTAL_CHECKS: SLOW RESPONSE - $issues"
        else
            error "Check #$TOTAL_CHECKS: ERROR - $issues"
        fi
    fi
    
    # Logging
    echo "$check_time,$status,$response_time,$issues" >> "$LOG_FILE"
    
    # Save current status
    echo "$status|$FAILURE_COUNT|$response_time|$issues" > "$STATUS_FILE"
    
    # Check for alert necessity
    if [[ "$FAILURE_COUNT" -ge "$ALERT_THRESHOLD" ]]; then
        send_alert "$status" "$issues"
    fi
    
    return 0
}

# Send alert
send_alert() {
    local status="$1"
    local issues="$2"
    local alert_time=$(date)
    
    # Check if we already sent alert recently
    if [[ -f "$ALERT_FILE" ]]; then
        last_alert=$(cat "$ALERT_FILE")
        # Send alerts no more than once per 15 minutes
        if [[ $(($(date +%s) - last_alert)) -lt 900 ]]; then
            return 0
        fi
    fi
    
    error "🚨 ALERT: WLNX issue detected!"
    echo "   Status: $status"
    echo "   Issues: $issues"
    echo "   Consecutive failures: $FAILURE_COUNT"
    echo "   Time: $alert_time"
    echo ""
    
    # Save last alert time
    date +%s > "$ALERT_FILE"
    
    # Try to get additional information
    log "Getting additional diagnostic information..."
    
    # Check recent deployments logs
    echo "Recent deployments:"
    doctl apps list-deployments "$APP_ID" --format ID,Phase,CreatedAt | head -5 || true
    
    # Here you can add notification sending:
    # - Telegram bot
    # - Email
    # - Slack
    # - Discord
    # - SMS
    
    echo ""
    warning "Recommended actions:"
    echo "1. Check logs: ./scripts/manage.sh logs"
    echo "2. Check status: ./scripts/manage.sh status"
    echo "3. If necessary rollback: ./scripts/rollback.sh"
    echo "4. Check DB status: doctl databases list"
}

# Show statistics
show_stats() {
    if [[ -f "$STATUS_FILE" ]]; then
        IFS='|' read -r current_status failure_count response_time issues < "$STATUS_FILE"
        
        echo ""
        echo "📊 MONITORING STATISTICS"
        echo "========================"
        echo "🕐 Start time: $(date)"
        echo "📈 Total checks: $TOTAL_CHECKS"
        echo "✅ Successful: $SUCCESS_COUNT"
        echo "❌ Consecutive failures: $failure_count"
        
        if [[ -n "$response_time" ]]; then
            echo "⏱️ Last response time: ${response_time}s"
        fi
        
        echo "📊 Success rate: $(( SUCCESS_COUNT * 100 / TOTAL_CHECKS ))%"
        
        case "$current_status" in
            "OK")
                echo -e "🟢 Current status: ${GREEN}ALL OK${NC}"
                ;;
            "SLOW")
                echo -e "🟡 Current status: ${YELLOW}SLOW RESPONSE${NC}"
                ;;
            "FAILED")
                echo -e "🔴 Current status: ${RED}ERROR${NC}"
                ;;
        esac
        
        if [[ -n "$issues" && "$issues" != " " ]]; then
            echo "⚠️ Current issues: $issues"
        fi
    fi
}

# Interactive mode
interactive_mode() {
    log "🔄 Starting interactive monitoring (Ctrl+C to stop)"
    log "Check interval: $MONITOR_INTERVAL seconds"
    log "Alert threshold: $ALERT_THRESHOLD consecutive failures"
    echo ""
    
    # Signal handler for graceful stop
    trap 'echo ""; log "Monitoring stopped by user"; show_stats; exit 0' INT
    
    while true; do
        check_health
        sleep "$MONITOR_INTERVAL"
    done
}

# Single check mode
single_check() {
    log "🔍 Performing single health check..."
    check_health
    show_stats
}

# View monitoring logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        echo "📋 MONITORING LOGS:"
        echo "===================="
        echo "Format: time,status,response_time,issues"
        echo ""
        tail -20 "$LOG_FILE"
    else
        warning "Monitoring logs not found"
    fi
}

# Clean monitoring files
cleanup() {
    rm -f "$STATUS_FILE" "$ALERT_FILE" "$LOG_FILE"
    success "Monitoring files cleaned"
}

# Show help
show_help() {
    echo "🔍 WLNX Monitoring Tool"
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  monitor     Start continuous monitoring (default)"
    echo "  check       Perform single check"
    echo "  stats       Show statistics"
    echo "  logs        Show monitoring logs"
    echo "  cleanup     Clean monitoring files"
    echo ""
    echo "Options:"
    echo "  -i, --interval SECONDS    Check interval (default: 60)"
    echo "  -t, --threshold COUNT     Alert threshold (default: 3)"
    echo "  -r, --response-time SEC   Max response time (default: 5.0)"
    echo ""
    echo "Examples:"
    echo "  $0                        # Start monitoring"
    echo "  $0 check                  # Single check"
    echo "  $0 monitor -i 30 -t 5     # Monitor every 30 sec, alert after 5 errors"
    echo "  $0 stats                  # Show statistics"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interval)
                MONITOR_INTERVAL="$2"
                shift 2
                ;;
            -t|--threshold)
                ALERT_THRESHOLD="$2"
                shift 2
                ;;
            -r|--response-time)
                RESPONSE_TIME_THRESHOLD="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                COMMAND="$1"
                shift
                ;;
        esac
    done
}

# Main function
main() {
    local command="${COMMAND:-monitor}"
    
    # Check dependencies
    if ! command -v doctl &> /dev/null; then
        error "doctl is not installed"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        error "curl is not installed"
        exit 1
    fi
    
    case "$command" in
        "monitor")
            get_app_info
            interactive_mode
            ;;
        "check")
            get_app_info
            single_check
            ;;
        "stats")
            show_stats
            ;;
        "logs")
            show_logs
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Parse arguments and run
parse_args "$@"
main
