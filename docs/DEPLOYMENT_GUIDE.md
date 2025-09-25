# 🚀 WLNX Deployment Guide

Comprehensive guide for deploying WLNX applications on Google Cloud Run.

## 📋 Prerequisites

### 1. Google Cloud Account Setup

1. **Account Creation and Verification**
   - Sign up at [Google Cloud Console](https://console.cloud.google.com)
   - Verify your email address
   - Add billing information
   - Create a new project or select existing one

2. **Enable Required APIs**
   - Go to [APIs & Services](https://console.cloud.google.com/apis/dashboard)
   - Enable the following APIs:
     - Cloud Run API
     - Cloud Build API
     - Container Registry API
     - Cloud SQL Admin API (if using Cloud SQL)

### 2. Local Development Setup

1. **Install Google Cloud SDK**
   ```bash
   # macOS
   brew install google-cloud-sdk
   
   # Linux
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   
   # Windows
   # Download installer from: https://cloud.google.com/sdk/docs/install
   ```

2. **Install Docker**
   ```bash
   # macOS
   brew install docker
   
   # Linux (Ubuntu/Debian)
   sudo apt-get update
   sudo apt-get install docker.io
   
   # Windows
   # Download Docker Desktop from: https://www.docker.com/products/docker-desktop
   ```

3. **Authenticate with Google Cloud**
   ```bash
   # Login to Google Cloud
   gcloud auth login
   
   # Set your project
   gcloud config set project YOUR_PROJECT_ID
   
   # Configure Docker for GCR
   gcloud auth configure-docker
   ```

### 3. Telegram Bot Setup

1. Open Telegram and find [@BotFather](https://t.me/botfather)
2. Send `/newbot` command
3. Follow the instructions to create your bot:
   - Bot name: `WLNX Bot` (or your choice)
   - Username: `your_wlnx_bot` (must end with `bot`)
4. Save the **bot token** you receive
5. Configure bot settings:
   ```
   /setdescription
   Your personal WLNX assistant
   
   /setabouttext
   Bot for WLNX system management
   
   /setcommands
   start - Start working with the bot
   help - Get help information
   status - System status
   ```

## 🛠️ Installation and Setup

### 1. Clone the Project

```bash
git clone https://github.com/nikitagorelovwlnx/wlnx-cloud-deploy.git
cd wlnx-cloud-deploy
```

### 2. Configure Secrets

Edit the secrets configuration file:

```bash
# Edit the secrets file
nano gcp-config/secrets.yaml
```

**Required variables:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: wlnx-secrets
type: Opaque
stringData:
  # Telegram Bot Token (from @BotFather)
  telegram-bot-token: "1234567890:ABCDEFghijklmnopqrstuvwxyz1234567890"
  
  # JWT Secret (generate random string)
  jwt-secret: "YOUR_JWT_SECRET_HERE"
  
  # API Secret Key (generate random string)
  api-secret-key: "YOUR_API_SECRET_HERE"
  
  # Telegram Webhook Secret (generate random string)
  telegram-webhook-secret: "YOUR_WEBHOOK_SECRET_HERE"
  
  # Database connection string
  database-url: "postgresql://username:password@/database?host=/cloudsql/PROJECT_ID:REGION:INSTANCE_NAME"
```

**Generate secrets:**
```bash
# Auto-generate all secrets
echo "JWT_SECRET=$(openssl rand -base64 32)"
echo "API_SECRET_KEY=$(openssl rand -base64 32)"
echo "TELEGRAM_WEBHOOK_SECRET=$(openssl rand -base64 32)"
```

### 3. Validate Configuration

```bash
# Check required files exist
ls docker/
ls gcp-config/

# Validate YAML syntax
for file in gcp-config/*.yaml; do 
  echo "Checking $file"
  python3 -c "import yaml,sys; yaml.safe_load(open('$file'))"
done
```

## 🚀 Deployment Process

### Step 1: Enable Google Cloud Services

```bash
# Enable required APIs
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  containerregistry.googleapis.com \
  sql-component.googleapis.com
```

### Step 2: Create Cloud SQL Database (Optional)

If you need a managed database:

```bash
# Create PostgreSQL instance
gcloud sql instances create wlnx-postgres \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=europe-west1 \
  --storage-type=SSD \
  --storage-size=10GB

# Create database
gcloud sql databases create wlnx --instance=wlnx-postgres
```

### Step 3: Deploy Application

```bash
# Automated deployment
./scripts/deploy.sh
```

**What happens:**
1. ✅ Check dependencies and configuration
2. ✅ Enable required Google Cloud services  
3. ✅ Build and push Docker images to GCR
4. ✅ Deploy services to Cloud Run
5. ✅ Configure auto-scaling
6. ✅ Setup HTTPS and routing
7. ✅ Display service URLs

### Step 4: Apply Secrets Configuration

```bash
# Apply secrets to the cluster
kubectl apply -f gcp-config/secrets.yaml

# Verify secrets were created
kubectl get secrets
```

### Step 5: Verify Deployment

```bash
# Check services status
./scripts/manage.sh status

# View service logs
./scripts/manage.sh logs wlnx-api-server 50
./scripts/manage.sh logs wlnx-telegram-bot 50
./scripts/manage.sh logs wlnx-control-panel 50

# Get service URLs
gcloud run services list --region=europe-west1
```

## 🔧 Настройка после развёртывания

### 1. Настройка webhook для Telegram бота

После успешного деплоя нужно настроить webhook:

```bash
# Получить URL приложения
APP_URL=$(doctl apps get $(cat .app-id) --format LiveURL --no-header)

# Установить webhook для бота
curl -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setWebhook" \
     -H "Content-Type: application/json" \
     -d "{\"url\":\"${APP_URL}/api/webhook/telegram\",\"secret_token\":\"${TELEGRAM_WEBHOOK_SECRET}\"}"
```

### 2. Проверка работы компонентов

```bash
# Проверить API
curl https://your-app-url.ondigitalocean.app/api/health

# Проверить панель управления
curl https://your-app-url.ondigitalocean.app/

# Проверить Telegram бота
# Отправьте /start в Telegram
```

### 3. Настройка мониторинга

1. Откройте приложение в DigitalOcean
2. Перейдите в "Insights" → "Alerts"
3. Настройте алерты:
   - CPU Usage > 80%
   - Memory Usage > 80%
   - Deployment Failed
   - Response Time > 5s

## 📊 Мониторинг и обслуживание

### Ежедневные проверки

```bash
# Статус всех компонентов
make status

# Проверка логов на ошибки
make logs-api | grep -i error
make logs-bot | grep -i error
```

### Еженедельные задачи

```bash
# Резервное копирование БД
make backup

# Проверка метрик производительности
make metrics
```

### Ежемесячные задачи

1. **Обновление зависимостей** в репозиториях
2. **Ротация секретов** (JWT, API ключи)
3. **Анализ использования ресурсов** и оптимизация
4. **Проверка логов безопасности**

## 🚨 Устранение проблем

### Проблема: Ошибка сборки Node.js

**Симптомы:**
```
Build failed: npm ERR! missing script: start
```

**Решение:**
1. Проверьте `package.json` в каждом репозитории
2. Убедитесь, что есть script `"start"`
3. Проверьте зависимости в `package.json`

### Проблема: База данных недоступна

**Симптомы:**
```
Error: connect ECONNREFUSED
```

**Решение:**
1. Проверьте статус БД: `doctl databases list`
2. Убедитесь, что `DATABASE_URL` правильно настроена
3. Проверьте firewall правила для БД

### Проблема: Telegram бот не отвечает

**Симптомы:**
- Бот не реагирует на команды
- Webhook ошибки в логах

**Решение:**
1. Проверьте токен бота
2. Убедитесь, что webhook настроен правильно
3. Проверьте логи бота: `make logs-bot`

## 📈 Оптимизация производительности

### 1. Масштабирование API сервера

Если нагрузка высокая:

```yaml
# В do-app.yaml увеличить instance_count
services:
  - name: api-server
    instance_count: 3  # было 2
    instance_size_slug: apps-s-2vcpu-2gb  # больше ресурсов
```

### 2. Оптимизация базы данных

```bash
# Увеличить размер БД
doctl databases resize wlnx-pg --size db-s-2vcpu-2gb --num-nodes 1
```

### 3. Включение автомасштабирования

```yaml
# В do-app.yaml добавить autoscaling
services:
  - name: api-server
    autoscaling:
      min_instance_count: 2
      max_instance_count: 5
      metrics:
        cpu:
          percent: 70
```

## 💰 Управление затратами

### Мониторинг расходов

1. Откройте [Billing](https://cloud.digitalocean.com/account/billing)
2. Настройте лимиты расходов
3. Включите email уведомления

### Оптимизация для разработки

```yaml
# В do-app.yaml для dev окружения
databases:
  - production: false  # dev БД дешевле

services:
  - instance_count: 1  # меньше инстансов
  - instance_size_slug: apps-s-1vcpu-512mb  # меньше ресурсов
```

## 🔄 Обновления и поддержка

### Автоматические обновления

При изменениях в `main` ветках репозиториев:
- ✅ Автоматическая сборка
- ✅ Автоматический деплой
- ✅ Zero-downtime deployment
- ✅ Автоматический откат при ошибках

### Ручные обновления

```bash
# Обновить конфигурацию
./scripts/deploy.sh

# Откат при проблемах
./scripts/rollback.sh last
```

---

## 📞 Поддержка

Если возникли проблемы:

1. **Проверьте логи:** `make logs`
2. **Проверьте статус:** `make status`  
3. **Изучите документацию:** [DigitalOcean Docs](https://docs.digitalocean.com/products/app-platform/)
4. **Создайте issue** в репозитории проекта

**🎉 Готово!** Ваше WLNX приложение развёрнуто и готово к использованию!
