# 🚀 WLNX Cloud Deploy

Infrastructure project for automatic deployment of WLNX applications on **DigitalOcean App Platform**.

## 📋 Обзор

Этот проект содержит все необходимые конфигурации и скрипты для развёртывания трёх компонентов WLNX:

- **API Server** (`wlnx-api-server`) - Backend API
- **Control Panel** (`wlnx-control-panel`) - Веб-панель управления
- **Telegram Bot** (`wlnx-telegram-bot`) - Telegram бот

## 🏗️ Архитектура

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Control Panel │    │   API Server    │    │  Telegram Bot   │
│   (Frontend)    │    │   (Backend)     │    │   (Worker)      │
│                 │    │                 │    │                 │
│ TypeScript      │    │ TypeScript      │    │ TypeScript      │
│ React/Next.js   │    │ Node.js/Express │    │ Node.js         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────┬───────────┴───────────┬───────────┘
                     │                       │
            ┌─────────────────┐    ┌─────────────────┐
            │  DigitalOcean   │    │   PostgreSQL    │
            │  App Platform   │    │    Database     │
            │                 │    │                 │
            │ Auto HTTPS      │    │  Managed DB     │
            │ Load Balancer   │    │  Backups        │
            │ Auto Scaling    │    │  Monitoring     │
            └─────────────────┘    └─────────────────┘
```

## 🛠️ Предварительные требования

### 1. Установка DigitalOcean CLI

```bash
# macOS
brew install doctl

# Linux
curl -sL https://github.com/digitalocean/doctl/releases/download/v1.100.0/doctl-1.100.0-linux-amd64.tar.gz | tar -xzv
sudo mv doctl /usr/local/bin

# Windows
scoop install doctl
```

### 2. Настройка аутентификации

1. Создайте персональный токен в [DigitalOcean](https://cloud.digitalocean.com/account/api/tokens)
2. Выполните аутентификацию:

```bash
doctl auth init
# Вставьте ваш токен
```

### 3. Подключение GitHub

Подключите ваш GitHub аккаунт к DigitalOcean App Platform:
1. Откройте [Apps в DigitalOcean](https://cloud.digitalocean.com/apps)
2. Нажмите "Create App" → "GitHub" → "Install and Authorize"
3. Предоставьте доступ к репозиториям `wlnx-*`

## 🚀 Быстрый старт

### Шаг 1: Клонирование и настройка

```bash
# Клонируйте этот репозиторий
git clone <your-infrastructure-repo>
cd wlnx-cloud-deploy

# Скопируйте шаблон переменных окружения
cp .env.template .env

# Отредактируйте .env файл
nano .env
```

### Шаг 2: Настройка переменных окружения

Заполните `.env` файл:

```bash
# Обязательные переменные
TELEGRAM_BOT_TOKEN=your_bot_token_from_botfather
JWT_SECRET=$(openssl rand -base64 32)
API_SECRET_KEY=$(openssl rand -base64 32)
TELEGRAM_WEBHOOK_SECRET=$(openssl rand -base64 32)
```

### Шаг 3: Валидация конфигурации

```bash
# Проверьте корректность конфигурации
doctl apps spec validate --spec do-app.yaml
```

### Шаг 4: Развёртывание

```bash
# Запустите автоматический деплой
./scripts/deploy.sh
```

Скрипт автоматически:
- ✅ Проверит зависимости и конфигурацию
- ✅ Создаст приложение в DigitalOcean
- ✅ Настроит базу данных PostgreSQL
- ✅ Развернёт все три компонента
- ✅ Настроит домен и HTTPS
- ✅ Покажет URL для доступа к приложению

## 📂 Структура проекта

```
wlnx-cloud-deploy/
├── README.md                 # Документация проекта
├── do-app.yaml              # Спецификация DigitalOcean App Platform
├── .env.template            # Шаблон переменных окружения
├── .env                     # Переменные окружения (создаётся локально)
├── .app-id                  # ID приложения (создаётся после деплоя)
├── .gitignore              # Правила игнорирования Git
└── scripts/                # Скрипты автоматизации
    ├── deploy.sh           # Скрипт деплоя
    ├── rollback.sh         # Скрипт отката
    └── manage.sh           # Скрипт управления
```

## 🔧 Управление приложением

### Мониторинг статуса

```bash
# Проверить статус приложения
./scripts/manage.sh status

# Просмотр логов API сервера
./scripts/manage.sh logs api-server run

# Просмотр логов сборки
./scripts/manage.sh logs control-panel build

# Просмотр логов Telegram бота
./scripts/manage.sh logs telegram-bot run
```

### Масштабирование

```bash
# Увеличить количество инстансов API сервера
./scripts/manage.sh scale api-server 3

# Показать метрики производительности
./scripts/manage.sh metrics
```

### Откат версий

```bash
# Интерактивный выбор версии для отката
./scripts/rollback.sh

# Откат к последней успешной версии
./scripts/rollback.sh last

# Показать доступные версии
./scripts/rollback.sh list

# Откат к конкретной версии
./scripts/rollback.sh deployment_id_here
```

### Резервное копирование

```bash
# Создать резервную копию базы данных
./scripts/manage.sh backup
```

### Управление переменными

Для изменения переменных окружения:

1. Отредактируйте `do-app.yaml`
2. Обновите секреты в веб-интерфейсе DigitalOcean
3. Выполните повторный деплой: `./scripts/deploy.sh`

## 🔐 Безопасность

### Переменные окружения

| Переменная | Описание | Где используется |
|------------|----------|------------------|
| `TELEGRAM_BOT_TOKEN` | Токен Telegram бота | telegram-bot |
| `JWT_SECRET` | Секрет для JWT токенов | api-server |
| `API_SECRET_KEY` | Ключ для API аутентификации | api-server |
| `TELEGRAM_WEBHOOK_SECRET` | Секрет для webhook'а | api-server, telegram-bot |
| `DATABASE_URL` | Подключение к БД | api-server, telegram-bot |

### Рекомендации по безопасности

1. **Никогда не коммитьте `.env` файлы**
2. **Используйте длинные случайные строки для секретов**
3. **Регулярно ротируйте API ключи**
4. **Включите 2FA для DigitalOcean аккаунта**
5. **Используйте отдельные токены для разных окружений**

## 🔄 CI/CD и автодеплой

Проект настроен для автоматического деплоя при изменениях в `main` ветках:

- ✅ Push в `main` → Автоматический деплой
- ✅ Zero-downtime deployments
- ✅ Автоматический откат при ошибках
- ✅ Health checks для всех сервисов
- ✅ Автоматическое масштабирование

## 📊 Мониторинг и логи

### Встроенный мониторинг DigitalOcean

- **Метрики производительности**: CPU, память, сеть
- **Логи в реальном времени**: build, deploy, runtime
- **Алерты**: уведомления о сбоях деплоя
- **Health checks**: автоматическая проверка работоспособности

### Доступ к метрикам

```bash
# Через CLI
./scripts/manage.sh metrics

# Через веб-интерфейс
# https://cloud.digitalocean.com/apps/{app-id}/overview
```

## 🌐 Домены и HTTPS

### Автоматические домены

После деплоя приложение автоматически получает:
- `https://wlnx-{random}.ondigitalocean.app` - основной домен
- Автоматический SSL сертификат
- HTTP → HTTPS редирект

### Подключение собственного домена

1. Откройте [настройки приложения](https://cloud.digitalocean.com/apps)
2. Перейдите в "Settings" → "Domains"
3. Добавьте ваш домен
4. Настройте DNS записи согласно инструкции

## 💰 Стоимость

### Примерная стоимость в месяц

| Компонент | Тип | Стоимость |
|-----------|-----|-----------|
| API Server (2x apps-s-1vcpu-1gb) | Service | $12/месяц |
| Control Panel (1x apps-s-1vcpu-1gb) | Service | $6/месяц |
| Telegram Bot (1x apps-s-1vcpu-1gb) | Worker | $6/месяц |
| PostgreSQL (db-s-1vcpu-1gb) | Database | $15/месяц |
| **Итого** | | **~$39/месяц** |

### Оптимизация затрат

- Используйте `production: false` для dev базы данных
- Уменьшите `instance_count` до 1 для development
- Рассмотрите использование `apps-s-1vcpu-512mb` для меньших нагрузок

## 🚨 Troubleshooting

### Частые проблемы

#### 1. Ошибка "GitHub repository not found"

```bash
# Убедитесь, что репозитории публичные или предоставили доступ
# Проверьте правильность имён репозиториев в do-app.yaml
```

#### 2. Ошибка сборки Node.js

```bash
# Проверьте логи сборки
./scripts/manage.sh logs api-server build

# Убедитесь, что package.json содержит scripts: start
```

#### 3. Ошибки подключения к БД

```bash
# Проверьте, что переменная DATABASE_URL правильно настроена
# Убедитесь, что БД создана и доступна
./scripts/manage.sh logs api-server run
```

#### 4. Telegram бот не отвечает

```bash
# Проверьте логи бота
./scripts/manage.sh logs telegram-bot run

# Убедитесь, что TELEGRAM_BOT_TOKEN корректный
# Проверьте настройку webhook'а
```

### Получение поддержки

1. Проверьте логи: `./scripts/manage.sh logs <component> <type>`
2. Проверьте статус: `./scripts/manage.sh status`
3. Проверьте [документацию DigitalOcean](https://docs.digitalocean.com/products/app-platform/)
4. Создайте issue в этом репозитории

## 📚 Дополнительные ресурсы

- [DigitalOcean App Platform Docs](https://docs.digitalocean.com/products/app-platform/)
- [App Spec Reference](https://docs.digitalocean.com/products/app-platform/reference/app-spec/)
- [doctl CLI Reference](https://docs.digitalocean.com/reference/doctl/)
- [Best Practices для Node.js в App Platform](https://docs.digitalocean.com/products/app-platform/languages-frameworks/nodejs/)

## 🤝 Contributing

1. Fork этот репозиторий
2. Создайте feature branch: `git checkout -b feature/amazing-feature`
3. Commit изменения: `git commit -m 'Add amazing feature'`
4. Push в branch: `git push origin feature/amazing-feature`
5. Создайте Pull Request

## 📝 License

Этот проект распространяется под лицензией MIT. Смотрите файл `LICENSE` для подробностей.

---

**🎉 Готово к деплою!** Выполните `./scripts/deploy.sh` для начала развёртывания.
