# 前端部署教學

本指南說明如何部署 Trading Dashboard 前端應用程式。

## 目錄

- [架構總覽](#架構總覽)
- [部署選項](#部署選項)
- [方案一：Cloudflare Pages（推薦）](#方案一cloudflare-pages推薦)
- [方案二：Vercel](#方案二vercel)
- [方案三：Netlify](#方案三netlify)
- [方案四：自架 Nginx](#方案四自架-nginx)
- [環境變數設定](#環境變數設定)
- [建置與部署](#建置與部署)
- [常見問題](#常見問題)

---

## 架構總覽

```
┌─────────────────────────────────────────────────────────────┐
│                        用戶瀏覽器                            │
└─────────────────────────┬───────────────────────────────────┘
                          │
          ┌───────────────┴───────────────┐
          ▼                               ▼
┌─────────────────────┐         ┌─────────────────────┐
│   Frontend (SPA)    │         │    Backend API      │
│  Cloudflare Pages   │  ────▶  │  Gateway + Admin    │
│  dashboard.xxx.com  │  HTTPS  │  api.xxx.com        │
└─────────────────────┘         └─────────────────────┘
```

**前端技術棧**：
- Vue 3 + TypeScript
- Vite（建置工具）
- Pinia（狀態管理）
- TailwindCSS（樣式）

---

## 部署選項

| 方案 | 優點 | 缺點 | 成本 |
|------|------|------|------|
| Cloudflare Pages | 全球 CDN、免費額度高 | 需 Cloudflare 帳號 | 免費 |
| Vercel | 零配置、預覽部署 | 商業用途需付費 | 免費/付費 |
| Netlify | 簡單易用 | 流量限制 | 免費/付費 |
| 自架 Nginx | 完全控制 | 需自行維護 | 依主機 |

**推薦**：搭配 Synology 後端使用 **Cloudflare Pages**，統一在 Cloudflare 管理。

---

## 方案一：Cloudflare Pages（推薦）

### 步驟 1：Fork 或 Clone 前端專案

```bash
git clone https://github.com/your-org/trading-dashboard-saas.git
cd trading-dashboard-saas
```

### 步驟 2：連結 Cloudflare Pages

1. 登入 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 選擇 **Workers & Pages** → **Create**
3. 選擇 **Pages** → **Connect to Git**
4. 授權並選擇你的 GitHub/GitLab 儲存庫

### 步驟 3：設定建置配置

| 設定項目 | 值 |
|----------|-----|
| Production branch | `main` |
| Build command | `npm run build` |
| Build output directory | `dist` |
| Root directory | `/` |

### 步驟 4：設定環境變數

在 **Settings** → **Environment variables** 新增：

```
VITE_API_BASE_URL=https://api.yourdomain.com
VITE_ADMIN_API_URL=https://admin.yourdomain.com
VITE_ADMIN_API_TOKEN=your-admin-api-token
```

### 步驟 5：部署

點擊 **Save and Deploy**，等待建置完成。

### 步驟 6：設定自訂網域

1. 進入 **Custom domains**
2. 新增 `dashboard.yourdomain.com`
3. 依指示設定 DNS CNAME 記錄

```
CNAME dashboard your-project.pages.dev
```

### 完成

前端已部署到：`https://dashboard.yourdomain.com`

---

## 方案二：Vercel

### 步驟 1：安裝 Vercel CLI

```bash
npm i -g vercel
```

### 步驟 2：登入並部署

```bash
cd trading-dashboard-saas
vercel login
vercel
```

### 步驟 3：設定環境變數

```bash
vercel env add VITE_API_BASE_URL
# 輸入：https://api.yourdomain.com

vercel env add VITE_ADMIN_API_URL
# 輸入：https://admin.yourdomain.com

vercel env add VITE_ADMIN_API_TOKEN
# 輸入：your-admin-api-token
```

### 步驟 4：正式部署

```bash
vercel --prod
```

### 步驟 5：設定自訂網域

1. 進入 Vercel Dashboard → 專案設定
2. **Domains** → 新增 `dashboard.yourdomain.com`
3. 設定 DNS 記錄

---

## 方案三：Netlify

### 步驟 1：連結儲存庫

1. 登入 [Netlify](https://app.netlify.com/)
2. **Add new site** → **Import an existing project**
3. 選擇 GitHub 並授權
4. 選擇儲存庫

### 步驟 2：設定建置

| 設定項目 | 值 |
|----------|-----|
| Build command | `npm run build` |
| Publish directory | `dist` |

### 步驟 3：設定環境變數

**Site settings** → **Environment variables**：

```
VITE_API_BASE_URL=https://api.yourdomain.com
VITE_ADMIN_API_URL=https://admin.yourdomain.com
VITE_ADMIN_API_TOKEN=your-admin-api-token
```

### 步驟 4：建立 `netlify.toml`

在專案根目錄建立：

```toml
[build]
  command = "npm run build"
  publish = "dist"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

### 步驟 5：部署並設定網域

---

## 方案四：自架 Nginx

### 步驟 1：建置前端

```bash
cd trading-dashboard-saas

# 安裝相依套件
npm install

# 建立 .env.production
cat > .env.production << EOF
VITE_API_BASE_URL=https://api.yourdomain.com
VITE_ADMIN_API_URL=https://admin.yourdomain.com
VITE_ADMIN_API_TOKEN=your-admin-api-token
EOF

# 建置
npm run build
```

### 步驟 2：複製到伺服器

```bash
# 複製 dist 目錄到伺服器
scp -r dist/* user@server:/var/www/dashboard/
```

### 步驟 3：設定 Nginx

```nginx
# /etc/nginx/sites-available/dashboard
server {
    listen 80;
    server_name dashboard.yourdomain.com;
    root /var/www/dashboard;
    index index.html;

    # SPA 路由支援
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 靜態資源快取
    location /assets {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Gzip 壓縮
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}
```

### 步驟 4：啟用網站

```bash
sudo ln -s /etc/nginx/sites-available/dashboard /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 步驟 5：設定 HTTPS

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d dashboard.yourdomain.com
```

---

## 環境變數設定

### 必填變數

| 變數 | 說明 | 範例 |
|------|------|------|
| `VITE_API_BASE_URL` | Gateway API 網址 | `https://api.yourdomain.com` |
| `VITE_ADMIN_API_URL` | Admin API 網址 | `https://admin.yourdomain.com` |
| `VITE_ADMIN_API_TOKEN` | Admin API Token | `your-token-here` |

### 選填變數

| 變數 | 說明 | 預設值 |
|------|------|--------|
| `VITE_APP_TITLE` | 應用程式標題 | `Trading Dashboard` |
| `VITE_ENABLE_MOCK` | 啟用 Mock 資料 | `false` |
| `VITE_SENTRY_DSN` | Sentry 錯誤追蹤 | - |

### 本地開發

建立 `.env.local`：

```bash
VITE_API_BASE_URL=http://localhost:9879
VITE_ADMIN_API_URL=http://localhost:9880
VITE_ADMIN_API_TOKEN=your-local-token
```

---

## 建置與部署

### 本地建置

```bash
# 安裝相依套件
npm install

# 開發模式
npm run dev

# 建置生產版本
npm run build

# 預覽生產版本
npm run preview
```

### 建置輸出

```
dist/
├── index.html
├── assets/
│   ├── index-[hash].js
│   ├── index-[hash].css
│   └── ...
└── favicon.ico
```

### Docker 部署（可選）

建立 `Dockerfile`：

```dockerfile
# 建置階段
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
ARG VITE_API_BASE_URL
ARG VITE_ADMIN_API_URL
ARG VITE_ADMIN_API_TOKEN
RUN npm run build

# 執行階段
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

建立 `nginx.conf`：

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /assets {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

建置並執行：

```bash
docker build \
  --build-arg VITE_API_BASE_URL=https://api.yourdomain.com \
  --build-arg VITE_ADMIN_API_URL=https://admin.yourdomain.com \
  --build-arg VITE_ADMIN_API_TOKEN=your-token \
  -t trading-dashboard .

docker run -p 8080:80 trading-dashboard
```

---

## 常見問題

### Q: 頁面刷新後出現 404？

SPA 需要設定伺服器將所有路由導向 `index.html`。

**Cloudflare Pages**：自動處理

**Nginx**：
```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

**Netlify**：建立 `_redirects` 檔案
```
/*    /index.html   200
```

### Q: API 請求失敗（CORS 錯誤）？

確認後端 `ALLOWED_ORIGINS` 包含前端網域：

```bash
# 後端 .env
ALLOWED_ORIGINS=https://dashboard.yourdomain.com
```

### Q: 環境變數沒有生效？

Vite 只會嵌入以 `VITE_` 開頭的環境變數，且在**建置時**就會被替換。

1. 確認變數名稱以 `VITE_` 開頭
2. 設定後需要**重新建置**
3. 檢查建置日誌確認變數已載入

### Q: 如何更新部署？

**Cloudflare Pages / Vercel / Netlify**：
- Push 到 `main` 分支自動觸發部署

**自架**：
```bash
git pull
npm run build
# 複製 dist 到伺服器
```

### Q: 如何回滾到上一版？

**Cloudflare Pages**：
1. Deployments → 選擇上一版
2. 點擊 **Rollback to this deployment**

**Vercel**：
```bash
vercel rollback
```

### Q: 建置失敗怎麼辦？

常見原因：

1. **Node 版本不符**
   ```bash
   # 指定 Node 版本（建立 .nvmrc）
   echo "20" > .nvmrc
   ```

2. **相依套件問題**
   ```bash
   rm -rf node_modules package-lock.json
   npm install
   ```

3. **TypeScript 錯誤**
   ```bash
   npm run type-check
   ```

---

## 完整部署檢查清單

- [ ] 後端已部署且可存取
- [ ] 環境變數已設定正確
- [ ] 建置成功無錯誤
- [ ] 網站可正常載入
- [ ] API 請求正常（無 CORS 錯誤）
- [ ] 登入功能正常
- [ ] 所有頁面路由正常
- [ ] HTTPS 已啟用
- [ ] 自訂網域已設定

---

## 下一步

- [部署教學](./DEPLOYMENT.md) - 後端部署指南
- [API 文件](./API.md) - 完整 API 參考
- [Webhook 設定](./WEBHOOK.md) - TradingView 整合
