#!/bin/bash
# Synology NAS 部署腳本
#
# 使用方式:
#   chmod +x setup.sh
#   ./setup.sh
#
set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 預設路徑
DEFAULT_APP_DIR="/volume1/docker/shioaji-trading"

echo -e "${BLUE}"
echo "============================================================"
echo "   Shioaji Trading Backend - Synology NAS 部署"
echo "============================================================"
echo -e "${NC}"

# 檢查是否在 Synology 上執行
if [ ! -d "/volume1" ]; then
    echo -e "${YELLOW}警告: 找不到 /volume1，可能不是 Synology NAS${NC}"
    read -p "繼續安裝? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 檢查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}錯誤: Docker 未安裝${NC}"
    echo "請先從 Synology 套件中心安裝 Container Manager"
    exit 1
fi

echo -e "${GREEN}✓ Docker 已安裝${NC}"

# 設定安裝路徑
read -p "安裝路徑 [$DEFAULT_APP_DIR]: " APP_DIR
APP_DIR=${APP_DIR:-$DEFAULT_APP_DIR}

echo -e "\n${BLUE}建立目錄結構...${NC}"
mkdir -p "$APP_DIR"/{app,data/postgres,data/redis,secrets,logs,migrations}
echo -e "${GREEN}✓ 目錄已建立${NC}"

# 複製檔案
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "\n${BLUE}複製設定檔...${NC}"
cp "$SCRIPT_DIR/docker-compose.yml" "$APP_DIR/"
cp "$SCRIPT_DIR/.env.example" "$APP_DIR/.env"
echo -e "${GREEN}✓ 設定檔已複製${NC}"

# 產生安全金鑰
echo -e "\n${BLUE}產生安全金鑰...${NC}"

POSTGRES_PASSWORD=$(openssl rand -hex 16)
ADMIN_API_TOKEN=$(openssl rand -hex 24)
CREDENTIAL_MASTER_KEY=$(openssl rand -hex 32)

# 更新 .env 檔案
sed -i "s|APP_DIR=.*|APP_DIR=$APP_DIR|g" "$APP_DIR/.env"
sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$POSTGRES_PASSWORD|g" "$APP_DIR/.env"
sed -i "s|ADMIN_API_TOKEN=.*|ADMIN_API_TOKEN=$ADMIN_API_TOKEN|g" "$APP_DIR/.env"
sed -i "s|CREDENTIAL_MASTER_KEY=.*|CREDENTIAL_MASTER_KEY=$CREDENTIAL_MASTER_KEY|g" "$APP_DIR/.env"

echo -e "${GREEN}✓ 安全金鑰已產生${NC}"

# Cloudflare Tunnel Token
echo -e "\n${YELLOW}============================================================${NC}"
echo -e "${YELLOW}Cloudflare Tunnel 設定${NC}"
echo -e "${YELLOW}============================================================${NC}"
echo ""
echo "1. 登入 https://one.dash.cloudflare.com/"
echo "2. 選擇 Networks → Tunnels"
echo "3. 建立新 Tunnel，命名為 'shioaji-trading'"
echo "4. 複製 Tunnel Token"
echo ""
read -p "貼上 Tunnel Token (或按 Enter 稍後設定): " TUNNEL_TOKEN

if [ -n "$TUNNEL_TOKEN" ]; then
    sed -i "s|CLOUDFLARE_TUNNEL_TOKEN=.*|CLOUDFLARE_TUNNEL_TOKEN=$TUNNEL_TOKEN|g" "$APP_DIR/.env"
    echo -e "${GREEN}✓ Tunnel Token 已設定${NC}"
else
    echo -e "${YELLOW}⚠ 稍後請編輯 $APP_DIR/.env 設定 CLOUDFLARE_TUNNEL_TOKEN${NC}"
fi

# 前端網域
echo ""
read -p "前端網域 (例: https://trading.yourdomain.com): " FRONTEND_DOMAIN
if [ -n "$FRONTEND_DOMAIN" ]; then
    sed -i "s|ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=$FRONTEND_DOMAIN|g" "$APP_DIR/.env"
fi

# 顯示摘要
echo -e "\n${BLUE}============================================================${NC}"
echo -e "${BLUE}   部署摘要${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo -e "安裝路徑:     ${GREEN}$APP_DIR${NC}"
echo -e "Gateway Port: ${GREEN}9879${NC}"
echo -e "Admin Port:   ${GREEN}9880${NC}"
echo ""
echo -e "${YELLOW}重要! 請記錄以下資訊:${NC}"
echo -e "Admin API Token: ${GREEN}$ADMIN_API_TOKEN${NC}"
echo ""

# 儲存憑證到檔案
cat > "$APP_DIR/CREDENTIALS.txt" << EOF
============================================================
Shioaji Trading Backend 憑證
產生時間: $(date)
============================================================

PostgreSQL 密碼: $POSTGRES_PASSWORD
Admin API Token: $ADMIN_API_TOKEN
Credential Master Key: $CREDENTIAL_MASTER_KEY

請妥善保管此檔案！
============================================================
EOF
chmod 600 "$APP_DIR/CREDENTIALS.txt"
echo -e "${GREEN}✓ 憑證已儲存到 $APP_DIR/CREDENTIALS.txt${NC}"

# 下載應用程式碼
echo -e "\n${BLUE}下載應用程式...${NC}"
if command -v git &> /dev/null; then
    git clone --depth 1 https://github.com/gn00295120/vibe-shioaji-api-dashboard.git "$APP_DIR/app" 2>/dev/null || {
        echo -e "${YELLOW}Git clone 失敗，嘗試使用現有程式碼...${NC}"
    }
else
    echo -e "${YELLOW}Git 未安裝，請手動複製程式碼到 $APP_DIR/app${NC}"
fi

# 複製 migrations
if [ -d "$APP_DIR/app/db/migrations" ]; then
    cp "$APP_DIR/app/db/migrations"/*.sql "$APP_DIR/migrations/" 2>/dev/null || true
    echo -e "${GREEN}✓ Migration 檔案已複製${NC}"
fi

# 啟動服務
echo -e "\n${BLUE}============================================================${NC}"
echo -e "${BLUE}   準備完成！${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "執行以下指令啟動服務:"
echo ""
echo -e "  ${GREEN}cd $APP_DIR${NC}"
echo -e "  ${GREEN}docker-compose up -d${NC}"
echo ""
echo "啟用自動更新 (選用):"
echo -e "  ${GREEN}docker-compose --profile auto-update up -d${NC}"
echo ""
echo "查看日誌:"
echo -e "  ${GREEN}docker-compose logs -f${NC}"
echo ""

# 詢問是否立即啟動
read -p "現在啟動服務? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$APP_DIR"

    # 先建立 worker image
    echo -e "\n${BLUE}建立 Worker Image...${NC}"
    docker-compose --profile build-only build worker-base

    # 啟動服務
    echo -e "\n${BLUE}啟動服務...${NC}"
    docker-compose up -d

    echo -e "\n${GREEN}✓ 服務已啟動！${NC}"
    echo ""
    docker-compose ps
fi

echo -e "\n${BLUE}============================================================${NC}"
echo -e "${BLUE}   Cloudflare Tunnel 設定 (重要!)${NC}"
echo -e "${BLUE}============================================================${NC}"
echo ""
echo "在 Cloudflare Dashboard 設定 Public Hostname:"
echo ""
echo "  1. api.yourdomain.com → http://gateway:8000"
echo "  2. admin.yourdomain.com → http://admin-api:8000"
echo ""
echo -e "${GREEN}部署完成！${NC}"
