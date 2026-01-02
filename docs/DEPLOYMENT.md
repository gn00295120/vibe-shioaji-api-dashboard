# 部署教學

本指南說明如何部署 Shioaji Trading Backend 的 Multi-tenant SaaS 架構。

## 目錄

- [架構總覽](#架構總覽)
- [部署選項](#部署選項)
- [方案一：Synology NAS 部署](#方案一synology-nas-部署)
- [方案二：VPS/雲端部署](#方案二vps雲端部署)
- [方案三：本地開發](#方案三本地開發)
- [環境變數說明](#環境變數說明)
- [驗證部署](#驗證部署)
- [常見問題](#常見問題)

---

## 架構總覽

```
                     Internet
                        │
                        ▼
              ┌─────────────────┐
              │ Cloudflare      │  (選用，提供 HTTPS + 免開 Port)
              │ Tunnel          │
              └────────┬────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ┌─────────┐   ┌──────────┐   ┌─────────┐
   │ Gateway │   │ Admin API│   │ Workers │
   │  :9879  │   │  :9880   │   │ (動態)  │
   └────┬────┘   └────┬─────┘   └────┬────┘
        │             │              │
        └──────┬──────┴──────────────┘
               ▼
        ┌─────────────┐
        │   Redis     │  (訊息佇列)
        │   :6379     │
        └──────┬──────┘
               │
        ┌──────┴──────┐
        │ PostgreSQL  │  (資料儲存)
        │   :5432     │
        └─────────────┘
```

**服務說明**：

| 服務 | Port | 功能 |
|------|------|------|
| Gateway | 9879 | API 閘道，處理交易請求和 Webhook |
| Admin API | 9880 | 管理租戶、憑證、Worker 生命週期 |
| Workers | 動態 | 每個租戶獨立容器，執行實際交易 |
| Redis | 6379 | 訊息佇列，Gateway 與 Worker 通訊 |
| PostgreSQL | 5432 | 儲存租戶資料、交易紀錄 |

---

## 部署選項

| 方案 | 適用場景 | 難度 | 成本 |
|------|----------|------|------|
| Synology NAS | 家用/小型團隊 | ⭐⭐ | 低（一次性硬體） |
| VPS/雲端 | 正式環境 | ⭐⭐⭐ | 中（月費） |
| 本地開發 | 開發測試 | ⭐ | 無 |

---

## 方案一：Synology NAS 部署

### 系統需求

- Synology NAS（支援 Docker 的機型，如 DS220+、DS920+ 等）
- Container Manager（從套件中心安裝）
- 至少 2GB RAM
- Cloudflare 帳號（免費版即可）

### 步驟 1：SSH 登入 NAS

```bash
ssh admin@your-nas-ip
```

### 步驟 2：執行自動安裝腳本

```bash
# 下載並執行安裝腳本
curl -sSL https://raw.githubusercontent.com/gn00295120/vibe-shioaji-api-dashboard/main/deploy/synology/setup.sh -o setup.sh
chmod +x setup.sh
./setup.sh
```

腳本會自動：
- 建立目錄結構
- 產生安全金鑰（PostgreSQL 密碼、Admin Token、Master Key）
- 下載 Docker Compose 設定
- 提示設定 Cloudflare Tunnel Token

### 步驟 3：設定 Cloudflare Tunnel

1. 登入 [Cloudflare Zero Trust](https://one.dash.cloudflare.com/)
2. 選擇 **Networks** → **Tunnels**
3. 點擊 **Create a tunnel**
4. 選擇 **Cloudflared** connector
5. 命名為 `shioaji-trading`
6. 複製 **Tunnel Token**

```bash
# 編輯 .env 填入 Token
vi /volume1/docker/shioaji-trading/.env

# 填入
CLOUDFLARE_TUNNEL_TOKEN=your-token-here
```

### 步驟 4：設定 Public Hostname

在 Cloudflare Dashboard 設定路由：

| Subdomain | Service |
|-----------|---------|
| `api.yourdomain.com` | `http://gateway:8000` |
| `admin.yourdomain.com` | `http://admin-api:8000` |

### 步驟 5：啟動服務

```bash
cd /volume1/docker/shioaji-trading

# 建立 Worker Image
docker-compose --profile build-only build worker-base

# 啟動所有服務
docker-compose up -d

# 查看狀態
docker-compose ps
```

### 驗證

```bash
# 測試 Gateway
curl https://api.yourdomain.com/health

# 測試 Admin API
curl https://admin.yourdomain.com/health
```

---

## 方案二：VPS/雲端部署

適用於 AWS EC2、GCP、DigitalOcean、Linode 等。

### 系統需求

- Ubuntu 22.04 LTS（建議）
- 2 vCPU / 4GB RAM（最低）
- Docker + Docker Compose

### 步驟 1：安裝 Docker

```bash
# 安裝 Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# 安裝 Docker Compose
sudo apt install docker-compose-plugin
```

### 步驟 2：下載專案

```bash
git clone https://github.com/gn00295120/vibe-shioaji-api-dashboard.git
cd vibe-shioaji-api-dashboard
```

### 步驟 3：設定環境變數

```bash
# 複製範本
cp example.env .env

# 編輯設定
vi .env
```

**必填項目**：

```bash
# 產生安全金鑰
POSTGRES_PASSWORD=$(openssl rand -hex 16)
ADMIN_API_TOKEN=$(openssl rand -hex 24)
CREDENTIAL_MASTER_KEY=$(openssl rand -hex 32)

echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
echo "ADMIN_API_TOKEN=$ADMIN_API_TOKEN"
echo "CREDENTIAL_MASTER_KEY=$CREDENTIAL_MASTER_KEY"
```

將產生的金鑰填入 `.env`。

### 步驟 4：啟動服務

```bash
# 建立 Worker Image
docker compose --profile build-only build worker-base

# 啟動 Multi-tenant 模式
docker compose -f docker-compose.multitenant.yaml up -d

# 查看日誌
docker compose -f docker-compose.multitenant.yaml logs -f
```

### 步驟 5：設定反向代理（Nginx）

```nginx
# /etc/nginx/sites-available/shioaji
server {
    listen 80;
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:9879;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    listen 80;
    server_name admin.yourdomain.com;

    location / {
        proxy_pass http://localhost:9880;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/shioaji /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 設定 HTTPS（使用 Certbot）
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d api.yourdomain.com -d admin.yourdomain.com
```

---

## 方案三：本地開發

### 步驟 1：啟動基礎服務

```bash
# 單租戶模式（開發用）
docker compose up -d

# 或 Multi-tenant 模式
docker compose -f docker-compose.multitenant.yaml up -d
```

### 步驟 2：存取服務

- Gateway: http://localhost:9879
- Admin API: http://localhost:9880
- API 文件: http://localhost:9879/docs

---

## 環境變數說明

### 必填

| 變數 | 說明 | 範例 |
|------|------|------|
| `POSTGRES_PASSWORD` | PostgreSQL 密碼 | `your_secure_password` |
| `CREDENTIAL_MASTER_KEY` | 憑證加密主金鑰 | `openssl rand -hex 32` |
| `ADMIN_API_TOKEN` | Admin API 認證 Token | `openssl rand -hex 24` |

### 選填

| 變數 | 說明 | 預設值 |
|------|------|--------|
| `ALLOWED_ORIGINS` | CORS 允許來源 | `*` |
| `REDIS_HOST` | Redis 主機 | `redis` |
| `REDIS_PORT` | Redis Port | `6379` |
| `WORKER_IMAGE` | Worker 映像名稱 | `shioaji-worker:latest` |

### Cloudflare Tunnel（Synology 專用）

| 變數 | 說明 |
|------|------|
| `CLOUDFLARE_TUNNEL_TOKEN` | Tunnel Token（從 Dashboard 取得） |

---

## 驗證部署

### 1. 健康檢查

```bash
# Gateway
curl http://localhost:9879/health
# 預期: {"status": "healthy"}

# Admin API
curl http://localhost:9880/health
# 預期: {"status": "healthy"}
```

### 2. 建立租戶

```bash
curl -X POST http://localhost:9880/tenants \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-User-ID: user-001" \
  -d '{"name": "我的交易帳戶"}'
```

### 3. 上傳憑證

```bash
curl -X POST http://localhost:9880/tenants/{tenant_id}/credentials \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "YOUR_SHIOAJI_API_KEY",
    "secret_key": "YOUR_SHIOAJI_SECRET_KEY"
  }'
```

### 4. 啟動 Worker

```bash
curl -X POST http://localhost:9880/tenants/{tenant_id}/start \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

### 5. 測試交易 API

```bash
curl http://localhost:9879/api/v1/{tenant_slug}/status \
  -H "Authorization: Bearer YOUR_TENANT_TOKEN"
```

---

## 常見問題

### Q: Worker 無法啟動？

```bash
# 檢查 Docker socket 權限
ls -la /var/run/docker.sock

# 確認 Worker Image 已建立
docker images | grep shioaji-worker
```

### Q: 資料庫連線失敗？

```bash
# 檢查 PostgreSQL 狀態
docker compose logs db

# 測試連線
docker exec -it shioaji-db psql -U postgres -d shioaji -c "SELECT 1"
```

### Q: Cloudflare Tunnel 連不上？

```bash
# 檢查 Tunnel 狀態
docker compose logs cloudflared

# 確認 Token 正確
echo $CLOUDFLARE_TUNNEL_TOKEN
```

### Q: 如何備份資料？

```bash
# 備份資料庫
docker exec shioaji-db pg_dump -U postgres shioaji > backup.sql

# 備份憑證（加密檔案）
tar -czf secrets-backup.tar.gz secrets/
```

### Q: 如何更新版本？

```bash
cd /path/to/shioaji-trading

# 拉取最新程式碼
git pull

# 重建 Image
docker compose build

# 重啟服務
docker compose up -d
```

---

## 下一步

- [API 文件](./API.md) - 完整 API 說明
- [Webhook 整合](./WEBHOOK.md) - TradingView 設定教學
- [前端部署](./FRONTEND.md) - Dashboard 部署指南
