# 🛠️ Development Setup - WLNX

## 🤖 Telegram Bot Dev/Prod Separation

### **Production Bot (Cloud):**
- **Bot**: @wlnx_prod_bot
- **Token**: `8333194739:AAGNb5E4NwwmdP7rhYQlvR6jrTBsS87H9W8`
- **Environment**: DigitalOcean App Platform
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
API_BASE_URL=http://localhost:8080/api
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
- Connects to local API (localhost:8080)
- Uses local database
- Fast iteration

**Production Bot (Cloud):**
- Real users only
- Connects to cloud API
- Uses cloud database
- Stable version

#### 5. Deployment Process

1. **Develop locally** with dev bot
2. **Test thoroughly** 
3. **Push to GitHub** when ready
4. **Cloud auto-deploys** production bot
5. **Production bot** serves real users

### **Benefits:**
✅ No conflicts between dev/prod  
✅ Safe testing environment  
✅ Isolated databases  
✅ Different API endpoints  
✅ Independent deployment  

### **Commands:**

```bash
# Check production bot status
doctl apps get 42f177fc-ad04-4d72-8ddc-d2fd6a4505dc

# View production logs
doctl apps logs 42f177fc-ad04-4d72-8ddc-d2fd6a4505dc

# Local development
npm run dev  # Uses dev token from .env
```
