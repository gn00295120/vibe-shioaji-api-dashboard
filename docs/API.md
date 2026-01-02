# API 文件

完整的 Shioaji Trading Backend API 參考文件。

## 目錄

- [概覽](#概覽)
- [認證](#認證)
- [Gateway API](#gateway-api)
  - [健康檢查](#健康檢查)
  - [交易狀態](#交易狀態)
  - [商品查詢](#商品查詢)
  - [持倉查詢](#持倉查詢)
  - [下單](#下單)
  - [Webhook](#webhook)
- [Admin API](#admin-api)
  - [租戶管理](#租戶管理)
  - [憑證管理](#憑證管理)
  - [Worker 管理](#worker-管理)
  - [Webhook 設定](#webhook-設定)
- [錯誤處理](#錯誤處理)
- [Rate Limiting](#rate-limiting)

---

## 概覽

### 服務端點

| 服務 | 預設 Port | 用途 |
|------|-----------|------|
| Gateway | 9879 | 交易 API、Webhook 接收 |
| Admin API | 9880 | 租戶管理、憑證上傳、Worker 控制 |

### Base URL

```
Gateway:   https://api.yourdomain.com
Admin API: https://admin.yourdomain.com
```

### 請求格式

- Content-Type: `application/json`
- 字元編碼: UTF-8

### 回應格式

所有回應皆為 JSON 格式：

```json
{
  "field": "value"
}
```

錯誤回應：

```json
{
  "detail": "錯誤訊息"
}
```

---

## 認證

### Gateway API

使用 Bearer Token 認證：

```http
Authorization: Bearer {tenant_api_token}
```

### Admin API

使用 Admin Token + User ID：

```http
Authorization: Bearer {admin_api_token}
X-User-ID: {user_id}
```

| Header | 說明 |
|--------|------|
| `Authorization` | Admin API Token（環境變數 `ADMIN_API_TOKEN`） |
| `X-User-ID` | 用戶識別碼（用於多租戶隔離） |

---

## Gateway API

### 健康檢查

#### GET /health

檢查 Gateway 服務狀態。

**回應**

```json
{
  "status": "healthy"
}
```

#### GET /api/v1/ping

簡單的連線測試。

**回應**

```json
{
  "status": "ok",
  "timestamp": "2024-01-15T09:30:00Z"
}
```

---

### 交易狀態

#### GET /api/v1/{tenant_slug}/status

取得租戶的交易狀態。

**路徑參數**

| 參數 | 類型 | 說明 |
|------|------|------|
| `tenant_slug` | string | 租戶識別碼 |

**回應**

```json
{
  "connected": true,
  "logged_in": true,
  "simulation_mode": true,
  "account_info": {
    "account_id": "F12345678",
    "username": "user@example.com"
  },
  "market_status": "open",
  "last_update": "2024-01-15T09:30:00Z"
}
```

---

### 商品查詢

#### GET /api/v1/{tenant_slug}/symbols

取得所有可交易商品。

**回應**

```json
{
  "symbols": [
    {
      "code": "TXFR1",
      "name": "台指期近月",
      "exchange": "TFE",
      "category": "futures"
    }
  ]
}
```

#### GET /api/v1/{tenant_slug}/symbols/{symbol}

取得特定商品詳情。

**路徑參數**

| 參數 | 類型 | 說明 |
|------|------|------|
| `symbol` | string | 商品代碼（如 `TXFR1`） |

**回應**

```json
{
  "code": "TXFR1",
  "name": "台指期近月",
  "exchange": "TFE",
  "category": "futures",
  "tick_size": 1,
  "contract_size": 200,
  "margin": 184000
}
```

#### GET /api/v1/{tenant_slug}/futures

取得期貨商品列表。

**回應**

```json
{
  "futures": [
    {
      "code": "TXF",
      "name": "台指期",
      "contracts": ["TXFR1", "TXFR2"]
    },
    {
      "code": "MXF",
      "name": "小台期",
      "contracts": ["MXFR1", "MXFR2"]
    }
  ]
}
```

#### GET /api/v1/{tenant_slug}/futures/{product}

取得特定期貨商品的合約。

**路徑參數**

| 參數 | 類型 | 說明 |
|------|------|------|
| `product` | string | 商品類別（如 `TXF`, `MXF`） |

**回應**

```json
{
  "product": "TXF",
  "name": "台指期",
  "contracts": [
    {
      "code": "TXFR1",
      "delivery_month": "202401",
      "last_trading_day": "2024-01-17"
    }
  ]
}
```

#### GET /api/v1/{tenant_slug}/contracts

取得所有可交易合約。

**回應**

```json
{
  "contracts": [
    {
      "code": "TXFR1",
      "name": "台指期202401",
      "product": "TXF"
    }
  ]
}
```

---

### 持倉查詢

#### GET /api/v1/{tenant_slug}/positions

取得當前持倉。

**回應**

```json
{
  "positions": [
    {
      "symbol": "TXFR1",
      "direction": "long",
      "quantity": 2,
      "avg_price": 21500,
      "current_price": 21550,
      "pnl": 20000,
      "pnl_percent": 0.93
    }
  ],
  "total_pnl": 20000,
  "margin_used": 368000
}
```

---

### 下單

#### POST /api/v1/{tenant_slug}/order

提交交易委託。

**請求**

```json
{
  "symbol": "TXFR1",
  "action": "buy",
  "quantity": 1,
  "order_type": "market",
  "price": null
}
```

| 欄位 | 類型 | 必填 | 說明 |
|------|------|------|------|
| `symbol` | string | ✅ | 商品代碼 |
| `action` | string | ✅ | `buy` 或 `sell` |
| `quantity` | number | ✅ | 數量 |
| `order_type` | string | ❌ | `market`（預設）或 `limit` |
| `price` | number | ❌ | 限價（`order_type=limit` 時必填） |

**回應**

```json
{
  "order_id": "ord_abc123",
  "status": "queued",
  "symbol": "TXFR1",
  "action": "buy",
  "quantity": 1,
  "created_at": "2024-01-15T09:30:00Z"
}
```

---

### Webhook

#### POST /api/v1/{tenant_slug}/webhook

接收 TradingView 或其他來源的交易信號。

**請求**

```json
{
  "action": "buy",
  "symbol": "TXFR1",
  "quantity": 1,
  "price": 21500,
  "strategy": "MA_Cross"
}
```

| 欄位 | 類型 | 必填 | 說明 |
|------|------|------|------|
| `action` | string | ✅ | `buy` 或 `sell` |
| `symbol` | string | ✅ | 商品代碼 |
| `quantity` | number | ✅ | 數量 |
| `price` | number | ❌ | 參考價格 |
| `strategy` | string | ❌ | 策略名稱 |
| `secret` | string | ❌ | Webhook Secret（若啟用驗證） |

**回應**

```json
{
  "status": "queued",
  "order_id": "ord_abc123",
  "message": "Order queued for processing"
}
```

---

## Admin API

### 租戶管理

#### POST /admin/tenants

建立新租戶。

**Headers**

```http
Authorization: Bearer {admin_token}
X-User-ID: {user_id}
```

**請求**

```json
{
  "name": "我的交易帳戶",
  "email": "user@example.com",
  "slug": "my-account",
  "plan_tier": "free"
}
```

| 欄位 | 類型 | 必填 | 說明 |
|------|------|------|------|
| `name` | string | ✅ | 租戶名稱 |
| `email` | string | ❌ | 聯絡信箱 |
| `slug` | string | ❌ | 自訂識別碼（會加上隨機前綴） |
| `plan_tier` | string | ❌ | 方案：`free`, `pro`, `business` |

**回應**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "我的交易帳戶",
  "slug": "abc123-my-account",
  "status": "pending",
  "plan_tier": "free",
  "owner_id": "user-001",
  "created_at": "2024-01-15T09:30:00Z"
}
```

#### GET /admin/tenants

列出當前用戶的所有租戶。

**Query 參數**

| 參數 | 類型 | 說明 |
|------|------|------|
| `status` | string | 篩選狀態：`pending`, `active`, `suspended` |
| `plan_tier` | string | 篩選方案 |
| `limit` | number | 回傳數量上限（預設 100） |
| `offset` | number | 偏移量 |

**回應**

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "我的交易帳戶",
    "slug": "abc123-my-account",
    "status": "active",
    "plan_tier": "free"
  }
]
```

#### GET /admin/tenants/{tenant_id}

取得租戶詳情。

**回應**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "我的交易帳戶",
  "slug": "abc123-my-account",
  "status": "active",
  "plan_tier": "free",
  "owner_id": "user-001",
  "created_at": "2024-01-15T09:30:00Z",
  "activated_at": "2024-01-15T09:35:00Z",
  "webhook_enabled": true
}
```

#### GET /admin/tenants/by-slug/{slug}

透過 slug 取得租戶。

#### PATCH /admin/tenants/{tenant_id}

更新租戶資訊。

**請求**

```json
{
  "name": "新名稱",
  "plan_tier": "pro"
}
```

#### DELETE /admin/tenants/{tenant_id}

刪除租戶（軟刪除）。

**回應**

```
204 No Content
```

#### POST /admin/tenants/{tenant_id}/activate

啟用待審核的租戶。

#### POST /admin/tenants/{tenant_id}/suspend

暫停租戶。

---

### 憑證管理

#### POST /admin/tenants/{tenant_id}/credentials/shioaji

上傳 Shioaji API 憑證。

**請求**

```json
{
  "api_key": "YOUR_API_KEY",
  "secret_key": "YOUR_SECRET_KEY"
}
```

**回應**

```json
{
  "id": "cred_abc123",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "credential_type": "shioaji",
  "status": "active",
  "created_at": "2024-01-15T09:30:00Z"
}
```

#### POST /admin/tenants/{tenant_id}/credentials/ca

上傳 CA 憑證（真實交易用）。

**請求**

```
Content-Type: multipart/form-data

ca_file: (binary)
ca_password: YOUR_CA_PASSWORD
```

#### GET /admin/tenants/{tenant_id}/credentials

取得憑證狀態。

**回應**

```json
{
  "shioaji": {
    "status": "active",
    "uploaded_at": "2024-01-15T09:30:00Z"
  },
  "ca": {
    "status": "not_uploaded"
  },
  "ready_for_simulation": true,
  "ready_for_trading": false
}
```

#### DELETE /admin/tenants/{tenant_id}/credentials/{type}

撤銷憑證。

**路徑參數**

| 參數 | 類型 | 說明 |
|------|------|------|
| `type` | string | `shioaji` 或 `ca` |

---

### Worker 管理

#### GET /admin/tenants/{tenant_id}/worker

取得 Worker 狀態。

**回應**

```json
{
  "id": "worker_abc123",
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "container_id": "abc123def456",
  "container_name": "worker-abc123-my-account",
  "status": "running",
  "health_status": "healthy",
  "started_at": "2024-01-15T09:30:00Z"
}
```

**Worker 狀態值**

| 狀態 | 說明 |
|------|------|
| `not_created` | 尚未建立 |
| `pending` | 建立中 |
| `running` | 運行中 |
| `stopped` | 已停止 |
| `error` | 錯誤 |
| `hibernating` | 休眠中 |

#### POST /admin/tenants/{tenant_id}/worker/start

啟動 Worker。

**前置條件**

- 租戶狀態為 `active`
- 已上傳 Shioaji 憑證

**回應**

```json
{
  "id": "worker_abc123",
  "status": "running",
  "started_at": "2024-01-15T09:30:00Z"
}
```

#### POST /admin/tenants/{tenant_id}/worker/stop

停止 Worker。

**回應**

```json
{
  "id": "worker_abc123",
  "status": "stopped",
  "stopped_at": "2024-01-15T10:00:00Z"
}
```

#### POST /admin/tenants/{tenant_id}/worker/restart

重啟 Worker。

---

### Webhook 設定

#### GET /admin/tenants/{tenant_id}/webhook

取得 Webhook 設定。

**回應**

```json
{
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "webhook_enabled": true,
  "webhook_secret": "whsec_xxxxxxxxxxxxx",
  "webhook_url": "https://api.yourdomain.com/api/v1/abc123-my-account/webhook"
}
```

#### POST /admin/tenants/{tenant_id}/webhook/enable

啟用 Webhook 並產生 Secret。

**回應**

```json
{
  "tenant_id": "550e8400-e29b-41d4-a716-446655440000",
  "webhook_enabled": true,
  "webhook_secret": "whsec_xxxxxxxxxxxxx",
  "webhook_url": "https://api.yourdomain.com/api/v1/abc123-my-account/webhook"
}
```

#### POST /admin/tenants/{tenant_id}/webhook/disable

停用 Webhook。

#### POST /admin/tenants/{tenant_id}/webhook/regenerate-secret

重新產生 Webhook Secret。

#### GET /admin/tenants/{tenant_id}/webhook/logs

取得 Webhook 呼叫記錄。

**Query 參數**

| 參數 | 類型 | 說明 |
|------|------|------|
| `limit` | number | 回傳數量（預設 50） |
| `offset` | number | 偏移量 |

**回應**

```json
{
  "logs": [
    {
      "id": 1,
      "source_ip": "104.16.0.1",
      "status": "processed",
      "tv_action": "buy",
      "tv_ticker": "TXFR1",
      "tv_quantity": 1,
      "created_at": "2024-01-15T09:30:00Z",
      "processed_at": "2024-01-15T09:30:01Z"
    }
  ],
  "total": 100
}
```

---

## 錯誤處理

### HTTP 狀態碼

| 狀態碼 | 說明 |
|--------|------|
| 200 | 成功 |
| 201 | 建立成功 |
| 204 | 刪除成功（無內容） |
| 400 | 請求錯誤 |
| 401 | 未授權 |
| 403 | 禁止存取 |
| 404 | 資源不存在 |
| 409 | 衝突（如重複建立） |
| 429 | 請求過於頻繁 |
| 500 | 伺服器錯誤 |

### 錯誤回應格式

```json
{
  "detail": "錯誤描述"
}
```

### 常見錯誤

| 錯誤 | 狀態碼 | 說明 |
|------|--------|------|
| `Tenant not found` | 404 | 租戶不存在 |
| `Credentials not found` | 400 | 憑證未上傳 |
| `Worker already running` | 400 | Worker 已在運行 |
| `Not authorized` | 403 | 無權存取此資源 |
| `Rate limit exceeded` | 429 | 超過請求頻率限制 |

---

## Rate Limiting

### 限制規則

| 端點 | 限制 |
|------|------|
| `POST /admin/tenants` | 10/分鐘 |
| `POST /credentials/*` | 5/分鐘 |
| `POST /webhook/enable` | 10/分鐘 |
| 其他 | 100/分鐘 |

### 超限回應

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 60

{
  "detail": "Rate limit exceeded. Try again in 60 seconds."
}
```

---

## 下一步

- [部署教學](./DEPLOYMENT.md) - 後端部署指南
- [Webhook 設定](./WEBHOOK.md) - TradingView 整合
- [前端部署](./FRONTEND.md) - Dashboard 部署指南
