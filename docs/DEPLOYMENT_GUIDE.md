# 🚀 Пошаговое руководство по развёртыванию WLNX

Подробная инструкция по развёртыванию WLNX приложений в DigitalOcean App Platform.

## 📋 Предварительные шаги

### 1. Подготовка DigitalOcean аккаунта

1. **Регистрация и верификация**
   - Зарегистрируйтесь на [DigitalOcean](https://cloud.digitalocean.com)
   - Подтвердите email
   - Добавьте платёжный метод

2. **Создание персонального токена**
   - Перейдите в [API & Tokens](https://cloud.digitalocean.com/account/api/tokens)
   - Нажмите "Generate New Token"
   - Имя: `WLNX Deploy Token`
   - Права: Read + Write
   - Скопируйте токен (он показывается только один раз!)

### 2. Подключение GitHub

1. Откройте [Apps в DigitalOcean](https://cloud.digitalocean.com/apps)
2. Нажмите "Create App"
3. Выберите "GitHub"
4. Нажмите "Install and Authorize DigitalOcean"
5. Выберите организацию `nikitagorelovwlnx`
6. Предоставьте доступ к репозиториям:
   - `wlnx-api-server`
   - `wlnx-telegram-bot`
   - `wlnx-control-panel`

### 3. Подготовка Telegram бота

1. Откройте Telegram и найдите [@BotFather](https://t.me/botfather)
2. Отправьте команду `/newbot`
3. Следуйте инструкциям для создания бота:
   - Имя бота: `WLNX Bot` (или своё)
   - Username: `your_wlnx_bot` (должен заканчиваться на `bot`)
4. Сохраните полученный **токен бота**
5. Настройте бота:
   ```
   /setdescription
   Ваш личный помощник WLNX
   
   /setabouttext
   Бот для управления WLNX системой
   
   /setcommands
   start - Начать работу с ботом
   help - Получить справку
   status - Статус системы
   ```

## 🛠️ Установка и настройка

### 1. Установка doctl (DigitalOcean CLI)

**macOS:**
```bash
brew install doctl
```

**Linux (Ubuntu/Debian):**
```bash
cd ~
curl -sL https://github.com/digitalocean/doctl/releases/download/v1.100.0/doctl-1.100.0-linux-amd64.tar.gz | tar -xzv
sudo mv doctl /usr/local/bin
```

**Windows:**
```bash
# Через Chocolatey
choco install doctl

# Через Scoop
scoop install doctl
```

### 2. Аутентификация doctl

```bash
doctl auth init
```

Вставьте ваш персональный токен DigitalOcean.

**Проверка:**
```bash
doctl auth list
doctl account get
```

### 3. Клонирование проекта

```bash
git clone https://github.com/nikitagorelovwlnx/wlnx-cloud-deploy.git
cd wlnx-cloud-deploy
```

### 4. Настройка переменных окружения

```bash
# Создать файл окружения из шаблона
cp .env.template .env

# Отредактировать переменные
nano .env  # или в любом редакторе
```

**Обязательные переменные:**

```bash
# Telegram Bot Token (от @BotFather)
TELEGRAM_BOT_TOKEN=1234567890:ABCDEFghijklmnopqrstuvwxyz1234567890

# JWT Secret (сгенерировать случайную строку)
JWT_SECRET=$(openssl rand -base64 32)

# API Secret Key (сгенерировать случайную строку)
API_SECRET_KEY=$(openssl rand -base64 32)

# Telegram Webhook Secret (сгенерировать случайную строку)
TELEGRAM_WEBHOOK_SECRET=$(openssl rand -base64 32)
```

**Генерация секретов:**
```bash
# Автоматическая генерация всех секретов
echo "JWT_SECRET=$(openssl rand -base64 32)"
echo "API_SECRET_KEY=$(openssl rand -base64 32)"
echo "TELEGRAM_WEBHOOK_SECRET=$(openssl rand -base64 32)"
```

## 🚀 Процесс развёртывания

### Шаг 1: Валидация конфигурации

```bash
# Проверить корректность YAML спецификации
doctl apps spec validate --spec do-app.yaml
```

Если есть ошибки - исправьте их в `do-app.yaml`.

### Шаг 2: Создание базы данных (опционально)

Если нужна отдельная управляемая БД:

```bash
# Создать PostgreSQL кластер
doctl databases create wlnx-pg \
  --engine pg \
  --version 15 \
  --region fra \
  --size db-s-1vcpu-1gb \
  --num-nodes 1
```

### Шаг 3: Развёртывание приложения

```bash
# Автоматический деплой
./scripts/deploy.sh
```

**Что происходит:**
1. ✅ Проверка зависимостей
2. ✅ Валидация конфигурации  
3. ✅ Создание приложения в DO
4. ✅ Настройка компонентов
5. ✅ Сборка и деплой
6. ✅ Настройка маршрутизации
7. ✅ Выдача SSL сертификатов

### Шаг 4: Настройка переменных в веб-интерфейсе

1. Откройте [Apps в DigitalOcean](https://cloud.digitalocean.com/apps)
2. Найдите ваше приложение "wlnx"
3. Перейдите в "Settings" → "App-Level Environment Variables"
4. Установите секретные переменные:

| Переменная | Значение | Тип |
|------------|----------|-----|
| `TELEGRAM_BOT_TOKEN` | Ваш токен от BotFather | Encrypted |
| `JWT_SECRET` | Сгенерированный секрет | Encrypted |
| `API_SECRET_KEY` | Сгенерированный ключ | Encrypted |
| `TELEGRAM_WEBHOOK_SECRET` | Сгенерированный секрет | Encrypted |

5. Сохраните изменения

### Шаг 5: Проверка развёртывания

```bash
# Проверить статус
./scripts/manage.sh status

# Посмотреть логи
./scripts/manage.sh logs api-server run
./scripts/manage.sh logs telegram-bot run
./scripts/manage.sh logs control-panel run
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
