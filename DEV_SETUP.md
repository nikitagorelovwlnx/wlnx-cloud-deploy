# 🛠️ Development Setup - WLNX

## 🤖 Telegram Bot Dev/Prod Separation

### **Production Bot (Cloud):**
- **Bot**: @wlnx_prod_bot
- **Token**: `8333194739:AAGNb5E4NwwmdP7rhYQlvR6jrTBsS87H9W8`
- **Environment**: Google Cloud Run
- **Mode**: Production mode
- **URL**: Connected to cloud API

### **Development Bot Setup:**

#### 1. Create Development Bot
1. Go to [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Choose name: `WLNX Dev Bot` (or similar)
4. Choose username: `wlnx_dev_bot` (or similar)
5. Copy the dev token

#### 2. Configure Local Development
Create `.env` file in your local `wlnx-telegram-bot` directory:

```bash
cd /path/to/your/wlnx-telegram-bot
cp .env.example .env
```

Edit `.env` file:
```env
# Development Environment
NODE_ENV=development
TELEGRAM_BOT_TOKEN=YOUR_DEV_BOT_TOKEN_HERE
API_BASE_URL=http://localhost:3000/api
DATABASE_URL=postgresql://localhost:5432/wlnx_dev
```

#### 3. Local Development Workflow

**Start local services:**
```bash
# Terminal 1: Start API Server
cd wlnx-api-server
npm run dev

# Terminal 2: Start Telegram Bot  
cd wlnx-telegram-bot
npm run dev

# Terminal 3: Start Control Panel (optional)
cd wlnx-control-panel  
npm run dev
```

#### 4. Testing Strategy

**Development Bot (Local):**
- Use for testing new features
- Connects to local API (localhost:3000)
- Uses local database
- Fast iteration

**Production Bot (Cloud):**
- Real users only
- Connects to Google Cloud Run API
- Uses Google Cloud SQL database
- Stable version

#### 5. Deployment Process

1. **Develop locally** with dev bot
2. **Test thoroughly** 
3. **Push to GitHub** when ready
4. **Deploy to Google Cloud Run** using deployment script
5. **Production bot** serves real users

### **Benefits:**
✅ No conflicts between dev/prod  
✅ Safe testing environment  
✅ Isolated databases  
✅ Different API endpoints  
✅ Independent deployment  

### **Commands:**

```bash
# Check production services status
gcloud run services list --region=europe-west1

# View production logs
# API Server logs
gcloud run services logs read wlnx-api-server --region=europe-west1

# Telegram Bot logs  
gcloud run services logs read wlnx-telegram-bot --region=europe-west1

# Control Panel logs
gcloud run services logs read wlnx-control-panel --region=europe-west1

# Local development
npm run dev  # Uses dev token from .env
```
