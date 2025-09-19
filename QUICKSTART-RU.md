# ⚡ Quick Start Guide - WLNX Cloud Deploy

Быстрое развёртывание WLNX приложений в DigitalOcean за 5 минут.

## 🚀 1-минутная настройка

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/nikitagorelovwlnx/wlnx-cloud-deploy.git
cd wlnx-cloud-deploy

# 2. Установите doctl (если не установлен)
brew install doctl  # macOS
# или
curl -sL https://github.com/digitalocean/doctl/releases/download/v1.100.0/doctl-1.100.0-linux-amd64.tar.gz | tar -xzv && sudo mv doctl /usr/local/bin  # Linux

# 3. Авторизуйтесь в DigitalOcean
doctl auth init  # Вставьте ваш токен

# 4. Настройте переменные окружения
make setup
# Отредактируйте .env файл с вашими токенами

# 5. Деплой!
make deploy
```

## 📋 Чеклист перед деплоем

### ✅ Обязательные шаги:

1. **Получите токен DigitalOcean**
   - Перейдите: https://cloud.digitalocean.com/account/api/tokens
   - Создайте новый токен с правами Read+Write
   - Сохраните токен (показывается только один раз!)

2. **Создайте Telegram бота**
   - Откройте @BotFather в Telegram
   - Выполните команду `/newbot`
   - Сохраните полученный токен

3. **Подключите GitHub к DigitalOcean**
   - Откройте: https://cloud.digitalocean.com/apps
   - Нажмите "Create App" → "GitHub" → "Install and Authorize"
   - Предоставьте доступ к репозиториям `wlnx-*`

### 🔧 Настройка переменных:

```bash
# Скопируйте шаблон
cp .env.template .env

# Заполните обязательные переменные:
TELEGRAM_BOT_TOKEN=ваш_токен_от_botfather
JWT_SECRET=$(openssl rand -base64 32)
API_SECRET_KEY=$(openssl rand -base64 32)
TELEGRAM_WEBHOOK_SECRET=$(openssl rand -base64 32)
```

## 🎯 Команды для быстрого старта

```bash
# Проверить готовность к деплою
make check

# Развернуть в production
make deploy

# Настроить Telegram webhook
make webhook

# Проверить здоровье приложения
make health

# Посмотреть статус
make status

# Посмотреть логи
make logs
```

## 🌍 Выбор окружения

### Development (дешевле, для тестирования):
```bash
make deploy-dev
```
**Стоимость**: ~$20/месяц
- 1 инстанс каждого сервиса
- 512MB RAM
- Dev база данных

### Production (высокая доступность):
```bash
make deploy-prod
```
**Стоимость**: ~$40/месяц  
- 2-3 инстанса для отказоустойчивости
- 2GB RAM
- Производственная база данных
- Автомасштабирование

## 🔍 После деплоя

### 1. Получить URL приложения:
```bash
make status
# Скопируйте URL из вывода
```

### 2. Настроить Telegram webhook:
```bash
make webhook
# Автоматически настроит webhook для бота
```

### 3. Протестировать работу:
```bash
# Проверить основные компоненты
make health

# Открыть панель управления
open https://ваш-домен.ondigitalocean.app

# Протестировать API
curl https://ваш-домен.ondigitalocean.app/api/health

# Написать боту в Telegram
# Найдите вашего бота и отправьте /start
```

## 🚨 Решение проблем

### Проблема: "GitHub repository not found"
```bash
# Убедитесь, что репозитории публичные
# Или предоставили доступ DigitalOcean к приватным репо
```

### Проблема: "Build failed"
```bash
# Посмотрите логи сборки
make logs-api

# Проверьте, что в package.json есть "start" script
```

### Проблема: "Telegram bot not responding"
```bash
# Проверьте токен бота
make webhook-info

# Перенастройте webhook
make webhook
```

### Проблема: "Database connection failed"
```bash
# Проверьте статус БД
doctl databases list

# Посмотрите логи приложения
make logs
```

## 📊 Мониторинг

### Непрерывный мониторинг:
```bash
# Запустить мониторинг (остановка: Ctrl+C)
./scripts/monitor.sh

# Разовая проверка
./scripts/monitor.sh check

# Статистика мониторинга
./scripts/monitor.sh stats
```

### Веб-интерфейс DigitalOcean:
- Откройте https://cloud.digitalocean.com/apps
- Найдите ваше приложение
- Используйте вкладки: Overview, Deployments, Runtime Logs, Insights

## 🔄 Обновления

### Автоматические:
- При пуше в `main` ветки → автоматический деплой
- GitHub Actions настроены из коробки

### Ручные:
```bash
# Обновить конфигурацию
make deploy

# Откатиться при проблемах
make rollback

# Откатиться к последней успешной версии
make rollback-last
```

## 💰 Стоимость

| Окружение | Стоимость/месяц | Описание |
|-----------|-----------------|----------|
| Development | ~$20 | Для тестирования и разработки |
| Production | ~$40 | Высокая доступность, автомасштабирование |

**Компоненты стоимости:**
- API Server: $6-12/месяц
- Control Panel: $6-12/месяц  
- Telegram Bot: $6/месяц
- PostgreSQL: $15/месяц

## 📞 Поддержка

### Быстрые ссылки:
- 📖 [Полная документация](README.md)
- 🔧 [Пошаговое руководство](docs/DEPLOYMENT_GUIDE.md)
- 🌐 [DigitalOcean Docs](https://docs.digitalocean.com/products/app-platform/)

### При проблемах:
1. Проверьте логи: `make logs`
2. Проверьте статус: `make status`
3. Проверьте здоровье: `make health`
4. Создайте issue в репозитории

---

## 🎉 Готово!

После успешного деплоя у вас будет:
- ✅ Работающий API сервер
- ✅ Веб-панель управления  
- ✅ Telegram бот
- ✅ PostgreSQL база данных
- ✅ Автоматические деплои
- ✅ Мониторинг и алерты
- ✅ HTTPS и собственный домен

**Время полного деплоя**: 5-10 минут
**Время до первого ответа бота**: 1-2 минуты после настройки webhook
