# WLNX Cloud Deploy Makefile
# Convenient commands for deployment management

.PHONY: help setup deploy rollback status logs validate clean install

# Colors for output
BLUE=\033[0;34m
GREEN=\033[0;32m
YELLOW=\033[1;33m
NC=\033[0m

help: ## Show this help
	@echo "$(BLUE)WLNX Cloud Deploy Commands:$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Usage examples:$(NC)"
	@echo "  make setup     # Initial setup"
	@echo "  make deploy    # Deploy application"
	@echo "  make status    # Check status"
	@echo "  make logs      # View logs"

setup: ## Setup environment (copy .env.template)
	@echo "$(BLUE)Setting up environment...$(NC)"
	@if [ ! -f .env ]; then \
		cp .env.template .env; \
		echo "$(GREEN).env file created from template$(NC)"; \
		echo "$(YELLOW)Edit .env file before deployment$(NC)"; \
	else \
		echo "$(YELLOW).env file already exists$(NC)"; \
	fi

validate: ## Validate App Platform configuration
	@echo "$(BLUE)Checking configuration...$(NC)"
	@doctl apps spec validate --spec do-app.yaml

install: ## Install dependencies
	@echo "$(BLUE)Checking dependencies...$(NC)"
	@command -v doctl >/dev/null 2>&1 || { echo "$(YELLOW)doctl not found. Install: https://docs.digitalocean.com/reference/doctl/how-to/install/$(NC)"; exit 1; }
	@doctl auth list >/dev/null 2>&1 || { echo "$(YELLOW)doctl not authorized. Run: doctl auth init$(NC)"; exit 1; }
	@echo "$(GREEN)All dependencies are OK$(NC)"

deploy: install validate ## Deploy application
	@echo "$(BLUE)Starting deployment...$(NC)"
	@./scripts/deploy.sh

rollback: ## Rollback to previous version
	@echo "$(BLUE)Starting rollback...$(NC)"
	@./scripts/rollback.sh

rollback-last: ## Rollback to last successful version
	@echo "$(BLUE)Rolling back to last successful version...$(NC)"
	@./scripts/rollback.sh last

status: ## Show application status
	@./scripts/manage.sh status

logs: ## Show logs (interactive selection)
	@./scripts/manage.sh logs

logs-api: ## Show API server logs
	@./scripts/manage.sh logs api-server run

logs-bot: ## Show Telegram bot logs
	@./scripts/manage.sh logs telegram-bot run

logs-panel: ## Show control panel logs
	@./scripts/manage.sh logs control-panel run

scale: ## Scale components (interactive)
	@./scripts/manage.sh scale

scale-api: ## Scale API server to 2 instances
	@echo "$(BLUE)Scaling API server...$(NC)"
	@echo "$(YELLOW)Edit do-app.yaml and run make deploy$(NC)"

backup: ## Create database backup
	@./scripts/manage.sh backup

metrics: ## Show performance metrics
	@./scripts/manage.sh metrics

webhook: ## Setup Telegram webhook
	@./scripts/setup-webhook.sh

webhook-info: ## Show webhook information
	@./scripts/setup-webhook.sh info

health: ## Check application health
	@./scripts/health-check.sh

deploy-dev: ## Deploy to development environment
	@echo "$(BLUE)Deploying to development environment...$(NC)"
	@doctl apps create --spec environments/development.yaml --format ID --no-header > .app-id-dev || \
		(APP_ID=$$(cat .app-id-dev 2>/dev/null) && doctl apps update $$APP_ID --spec environments/development.yaml)

deploy-prod: ## Deploy to production environment  
	@echo "$(BLUE)Deploying to production environment...$(NC)"
	@doctl apps create --spec environments/production.yaml --format ID --no-header > .app-id-prod || \
		(APP_ID=$$(cat .app-id-prod 2>/dev/null) && doctl apps update $$APP_ID --spec environments/production.yaml)

monitor: ## Start continuous monitoring
	@./scripts/monitor.sh

monitor-check: ## Perform single monitoring check
	@./scripts/monitor.sh check

monitor-stats: ## Show monitoring statistics
	@./scripts/monitor.sh stats

monitor-logs: ## Show monitoring logs
	@./scripts/monitor.sh logs

restart: ## Restart application
	@./scripts/manage.sh restart

delete: ## Delete application (WARNING!)
	@echo "$(YELLOW)WARNING: This will delete the entire application!$(NC)"
	@./scripts/manage.sh delete

clean: ## Clean temporary files
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	@rm -f .app-id
	@rm -f .app-id-dev .app-id-prod
	@rm -rf deployment-logs/
	@rm -f .env
	@echo "$(GREEN)Cleanup completed$(NC)"

check: validate ## Check deployment readiness
	@echo "$(BLUE)Checking deployment readiness...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(YELLOW).env file not found. Run: make setup$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Ready to deploy!$(NC)"

quick-deploy: check deploy ## Quick deploy (check + deploy)

dev-setup: setup ## Setup for development
	@echo "$(BLUE)Setting up for development...$(NC)"
	@echo "Edit do-app.yaml:"
	@echo "  - Change production: true to production: false for DB"
	@echo "  - Reduce instance_count to 1 for cost savings"
	@echo "$(YELLOW)After changes run: make deploy$(NC)"

prod-check: ## Check production settings
	@echo "$(BLUE)Checking production settings...$(NC)"
	@grep -q "production: true" do-app.yaml && echo "$(GREEN)✓ DB configured for production$(NC)" || echo "$(YELLOW)⚠ DB configured for development$(NC)"
	@grep -q "instance_count: 2" do-app.yaml && echo "$(GREEN)✓ API scaled$(NC)" || echo "$(YELLOW)⚠ API not scaled$(NC)"

# Show help by default
.DEFAULT_GOAL := help
