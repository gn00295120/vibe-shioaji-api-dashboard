# Synology NAS 部署指南

在 Synology NAS 上部署 Shioaji Trading Backend，搭配 Cloudflare Tunnel 對外服務。

## 系統需求

- Synology NAS（支援 Docker 的機型）
- Container Manager（從套件中心安裝）
- 至少 2GB RAM
- Cloudflare 帳號（免費版即可）

## 架構圖

```
Cloudflare Pages (Frontend)
        │
        ▼ HTTPS
Cloudflare Tunnel (免費、免開 Port)
        │
        ▼
┌───────────────────────────────────────┐
│         Synology NAS (Docker)         │
├───────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐            │
│  │ Gateway │  │  Admin  │            │
│  │  :9879  │  │  :9880  │            │
│  └────┬────┘  └────┬────┘            │
│       │            │                  │
│  ┌────┴────────────┴────┐            │
│  │       Workers        │            │
│  │  (per-tenant Docker) │            │
│  └──────────┬───────────┘            │
│             │                         │
│  ┌──────────┴───────────┐            │
│  │  PostgreSQL │ Redis  │            │
│  └──────────────────────┘            │
└───────────────────────────────────────┘
```

## 快速部署

### 方法 1: 自動安裝腳本

```bash
# SSH 登入 NAS
ssh admin@your-nas-ip

# 下載並執行安裝腳本
curl -sSL https://raw.githubusercontent.com/gn00295120/vibe-shioaji-api-dashboard/main/deploy/synology/setup.sh | bash
```

### 方法 2: 手動安裝

#### 1. 建立目錄

```bash
mkdir -p /volume1/docker/shioaji-trading/{app,data/postgres,data/redis,secrets,logs,migrations}
cd /volume1/docker/shioaji-trading
```

#### 2. 下載設定檔

```bash
# 下載 docker-compose.yml
curl -o docker-compose.yml https://raw.githubusercontent.com/gn00295120/vibe-shioaji-api-dashboard/main/deploy/synology/docker-compose.yml

# 下載環境變數範本
curl -o .env https://raw.githubusercontent.com/gn00295120/vibe-shioaji-api-dashboard/main/deploy/synology/.env.example
```

#### 3. 下載應用程式碼

```bash
git clone --depth 1 https://github.com/gn00295120/vibe-shioaji-api-dashboard.git app

# 複製 migrations
cp app/db/migrations/*.sql migrations/
```

#### 4. 設定環境變數

```bash
# 編輯 .env 檔案
vi .env
```

產生安全金鑰：

```bash
# PostgreSQL 密碼
openssl rand -hex 16

# Admin API Token
openssl rand -hex 24

# Credential Master Key
openssl rand -hex 32
```

#### 5. 啟動服務

```bash
# 建立 Worker Image
docker-compose --profile build-only build worker-base

# 啟動所有服務
docker-compose up -d

# 查看狀態
docker-compose ps
```

## Cloudflare Tunnel 設定

### 1. 建立 Tunnel

1. 登入 [Cloudflare Dashboard](https://one.dash.cloudflare.com/)
2. 選擇 **Networks** → **Tunnels**
3. 點擊 **Create a tunnel**
4. 選擇 **Cloudflared** connector
5. 命名為 `shioaji-trading`
6. 複製 **Tunnel Token**

### 2. 設定 Token

```bash
# 編輯 .env
vi /volume1/docker/shioaji-trading/.env

# 填入 Token
CLOUDFLARE_TUNNEL_TOKEN=your-token-here

# 重啟 cloudflared
docker-compose restart cloudflared
```

### 3. 設定 Public Hostname

在 Cloudflare Dashboard 設定路由：

| Subdomain | Service | URL |
|-----------|---------|-----|
| `api` | HTTP | `gateway:8000` |
| `admin` | HTTP | `admin-api:8000` |

例如：
- `api.yourdomain.com` → `http://gateway:8000`
- `admin.yourdomain.com` → `http://admin-api:8000`

## 前端設定

在 Cloudflare Pages 的環境變數中設定：

```
VITE_API_BASE_URL=https://api.yourdomain.com
VITE_ADMIN_API_URL=https://admin.yourdomain.com
VITE_ADMIN_API_TOKEN=your-admin-token
```

## 常用指令

```bash
cd /volume1/docker/shioaji-trading

# 查看所有容器狀態
docker-compose ps

# 查看日誌
docker-compose logs -f

# 查看特定服務日誌
docker-compose logs -f gateway admin-api

# 重啟服務
docker-compose restart

# 停止服務
docker-compose down

# 更新服務
docker-compose pull
docker-compose up -d
```

## 備份與還原

### 備份

```bash
# 備份資料庫
docker exec shioaji-db pg_dump -U postgres shioaji > backup_$(date +%Y%m%d).sql

# 備份整個資料目錄
tar -czf shioaji-backup-$(date +%Y%m%d).tar.gz data/ secrets/
```

### 還原

```bash
# 還原資料庫
cat backup_20260102.sql | docker exec -i shioaji-db psql -U postgres shioaji

# 還原資料目錄
tar -xzf shioaji-backup-20260102.tar.gz
```

## 故障排除

### 容器無法啟動

```bash
# 檢查日誌
docker-compose logs --tail=50 gateway

# 檢查資源使用
docker stats
```

### 資料庫連線失敗

```bash
# 測試資料庫連線
docker exec shioaji-db psql -U postgres -c "SELECT 1"

# 檢查資料庫日誌
docker-compose logs db
```

### Tunnel 連線問題

```bash
# 檢查 Tunnel 狀態
docker-compose logs cloudflared

# 驗證 Token
docker exec shioaji-tunnel cloudflared tunnel info
```

## 安全建議

1. **更改預設密碼**：所有 `.env` 中的密碼都應更改
2. **限制 Docker Socket**：考慮使用 Docker Socket Proxy
3. **定期備份**：設定 Synology 任務排程自動備份
4. **更新容器**：啟用 Watchtower 自動更新

```bash
# 啟用自動更新
docker-compose --profile auto-update up -d
```

## 支援

如有問題，請在 GitHub 開 Issue：
https://github.com/gn00295120/vibe-shioaji-api-dashboard/issues
