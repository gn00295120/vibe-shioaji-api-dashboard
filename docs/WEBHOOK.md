# TradingView Webhook 設定教學

本指南說明如何設定 TradingView 警報，透過 Webhook 自動執行交易。

## 目錄

- [運作原理](#運作原理)
- [前置需求](#前置需求)
- [步驟一：取得 Webhook URL](#步驟一取得-webhook-url)
- [步驟二：設定 TradingView 警報](#步驟二設定-tradingview-警報)
- [步驟三：設定警報訊息格式](#步驟三設定警報訊息格式)
- [訊息格式說明](#訊息格式說明)
- [進階用法](#進階用法)
- [測試與除錯](#測試與除錯)
- [常見問題](#常見問題)

---

## 運作原理

```
┌─────────────┐      Webhook       ┌─────────────┐      Queue       ┌─────────────┐
│ TradingView │  ──────────────▶  │   Gateway   │  ────────────▶  │   Worker    │
│   警報觸發   │   POST JSON       │  /webhook   │    Redis        │  執行交易    │
└─────────────┘                    └─────────────┘                  └─────────────┘
                                                                           │
                                                                           ▼
                                                                    ┌─────────────┐
                                                                    │ Shioaji API │
                                                                    │   下單執行   │
                                                                    └─────────────┘
```

**流程說明**：
1. TradingView 策略觸發警報
2. 警報透過 Webhook 發送 JSON 到 Gateway
3. Gateway 驗證後放入 Redis Queue
4. Worker 取出訊息並執行交易
5. 交易結果記錄到資料庫

---

## 前置需求

- ✅ TradingView Pro 以上方案（免費版不支援 Webhook）
- ✅ 後端已部署並可從外網存取（HTTPS）
- ✅ 已建立租戶並上傳 Shioaji 憑證
- ✅ Worker 已啟動或設定為自動啟動

---

## 步驟一：取得 Webhook URL

### 1.1 從 Dashboard 取得

登入 Dashboard → 後端管理 → 選擇你的後端 → Webhook 設定

```
Webhook URL: https://api.yourdomain.com/webhook/{your-tenant-slug}
```

### 1.2 從 API 取得

```bash
# 查詢租戶資訊
curl https://admin.yourdomain.com/tenants/{tenant_id} \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"

# 回應包含 webhook_url
{
  "id": "tenant-uuid",
  "slug": "abc123-my-account",
  "webhook_url": "https://api.yourdomain.com/webhook/abc123-my-account",
  "webhook_secret": "whsec_xxxxxx"
}
```

### 1.3 Webhook URL 格式

```
https://api.yourdomain.com/webhook/{tenant_slug}
```

| 部分 | 說明 |
|------|------|
| `api.yourdomain.com` | 你的 Gateway 網域 |
| `/webhook/` | Webhook 端點路徑 |
| `{tenant_slug}` | 租戶識別碼（如 `abc123-my-account`） |

---

## 步驟二：設定 TradingView 警報

### 2.1 開啟圖表並新增警報

1. 開啟 TradingView 圖表
2. 點擊右側 **警報** 圖示（鈴鐺）
3. 點擊 **建立警報**

### 2.2 設定警報條件

根據你的策略設定觸發條件，例如：

| 設定項目 | 範例值 |
|----------|--------|
| 條件 | 策略指標 / 交叉 / 價格 |
| 觸發頻率 | 每次條件符合時（建議） |

### 2.3 設定 Webhook

1. 展開 **通知** 區塊
2. 勾選 **Webhook URL**
3. 貼上你的 Webhook URL：

```
https://api.yourdomain.com/webhook/abc123-my-account
```

---

## 步驟三：設定警報訊息格式

在 **訊息** 欄位填入 JSON 格式：

### 基本格式（買入）

```json
{
  "action": "buy",
  "symbol": "TXFR1",
  "quantity": 1
}
```

### 基本格式（賣出）

```json
{
  "action": "sell",
  "symbol": "TXFR1",
  "quantity": 1
}
```

### 使用 TradingView 變數

```json
{
  "action": "{{strategy.order.action}}",
  "symbol": "TXFR1",
  "quantity": {{strategy.order.contracts}},
  "price": {{close}},
  "time": "{{time}}"
}
```

---

## 訊息格式說明

### 必填欄位

| 欄位 | 類型 | 說明 | 範例 |
|------|------|------|------|
| `action` | string | 交易方向 | `buy`, `sell` |
| `symbol` | string | 商品代碼 | `TXFR1`, `MXFR1` |
| `quantity` | number | 數量 | `1`, `2` |

### 選填欄位

| 欄位 | 類型 | 說明 | 範例 |
|------|------|------|------|
| `price` | number | 參考價格（記錄用） | `21500.00` |
| `order_type` | string | 委託類型 | `market`, `limit` |
| `time` | string | 觸發時間 | `2024-01-15T09:30:00` |
| `strategy` | string | 策略名稱 | `MA_Cross` |
| `comment` | string | 備註 | `趨勢突破` |

### 完整範例

```json
{
  "action": "buy",
  "symbol": "TXFR1",
  "quantity": 1,
  "order_type": "market",
  "price": 21500,
  "strategy": "均線交叉",
  "comment": "5MA 上穿 20MA"
}
```

### Action 對應表

| TradingView | Webhook Action | Shioaji |
|-------------|----------------|---------|
| `buy` | `buy` | 買進（多單） |
| `sell` | `sell` | 賣出（平多/空單） |
| `long` | `buy` | 買進 |
| `short` | `sell` | 賣出 |
| `close` | 根據持倉 | 平倉 |

---

## 進階用法

### 使用策略變數

TradingView Pine Script 策略可使用內建變數：

```json
{
  "action": "{{strategy.order.action}}",
  "symbol": "TXFR1",
  "quantity": {{strategy.order.contracts}},
  "price": {{strategy.order.price}},
  "position_size": {{strategy.position_size}},
  "time": "{{timenow}}"
}
```

| 變數 | 說明 |
|------|------|
| `{{strategy.order.action}}` | `buy` 或 `sell` |
| `{{strategy.order.contracts}}` | 委託數量 |
| `{{strategy.order.price}}` | 委託價格 |
| `{{strategy.position_size}}` | 當前持倉 |
| `{{close}}` | 當前收盤價 |
| `{{timenow}}` | 當前時間 |

### 多商品支援

```json
{
  "action": "{{strategy.order.action}}",
  "symbol": "{{ticker}}",
  "quantity": {{strategy.order.contracts}}
}
```

### 帶認證的 Webhook

如果啟用了 Webhook Secret 驗證：

```json
{
  "action": "buy",
  "symbol": "TXFR1",
  "quantity": 1,
  "secret": "whsec_your_webhook_secret"
}
```

---

## 測試與除錯

### 手動測試 Webhook

使用 curl 模擬 TradingView 發送：

```bash
curl -X POST https://api.yourdomain.com/webhook/abc123-my-account \
  -H "Content-Type: application/json" \
  -d '{
    "action": "buy",
    "symbol": "TXFR1",
    "quantity": 1
  }'
```

**成功回應**：

```json
{
  "status": "queued",
  "order_id": "ord_xxxxxxxx",
  "message": "Order queued for processing"
}
```

### 查看 Webhook 記錄

```bash
# 透過 Admin API 查詢
curl https://admin.yourdomain.com/tenants/{tenant_id}/webhooks \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

### 查看 Worker 日誌

```bash
# Docker 日誌
docker logs -f worker-{tenant_slug}

# 或透過 Docker Compose
docker compose -f docker-compose.multitenant.yaml logs -f
```

### 常見錯誤

| 錯誤 | 原因 | 解法 |
|------|------|------|
| `401 Unauthorized` | Webhook Secret 錯誤 | 檢查 secret 欄位 |
| `404 Not Found` | Tenant slug 不存在 | 確認 URL 正確 |
| `400 Bad Request` | JSON 格式錯誤 | 檢查訊息格式 |
| `503 Service Unavailable` | Worker 未啟動 | 啟動 Worker 或啟用自動啟動 |

---

## 常見問題

### Q: 免費版 TradingView 可以用嗎？

不行，Webhook 功能需要 TradingView Pro 以上方案。

### Q: 警報多久觸發一次？

取決於你的警報設定：
- **每次條件符合時**：每次觸發都發送
- **一次**：只發送一次
- **每分鐘一次**：限制觸發頻率

建議使用「每次條件符合時」以確保不漏單。

### Q: 可以同時交易多個商品嗎？

可以，為每個商品設定獨立警報，使用 `{{ticker}}` 變數動態帶入商品代碼。

### Q: Worker 沒有在運行怎麼辦？

兩種解法：

1. **手動啟動**：透過 Dashboard 或 API 啟動 Worker
2. **自動啟動**：Webhook 收到訊號時會自動啟動 Worker（需已上傳憑證）

### Q: 如何確認 Webhook 有收到？

1. 檢查 Gateway 日誌
2. 透過 Admin API 查詢 Webhook 記錄
3. Dashboard 的 Webhook 歷史頁面

### Q: 盤中 vs 盤後的差異？

- **盤中**：直接執行交易
- **盤後**：訂單會排隊，待開盤後執行（需策略支援）

### Q: 支援哪些商品？

| 商品代碼 | 說明 |
|----------|------|
| `TXFR1` | 台指期近月 |
| `MXFR1` | 小台期近月 |
| `EXF` | 電子期 |
| `FXF` | 金融期 |

完整商品清單請參考 [Shioaji 文件](https://sinotrade.github.io/zh/tutor/contract/)。

---

## Pine Script 範例

### 簡單均線交叉策略

```pine
//@version=5
strategy("MA Cross Webhook", overlay=true)

fast = ta.sma(close, 5)
slow = ta.sma(close, 20)

if ta.crossover(fast, slow)
    strategy.entry("Long", strategy.long)

if ta.crossunder(fast, slow)
    strategy.close("Long")

plot(fast, color=color.blue)
plot(slow, color=color.red)
```

**對應 Webhook 訊息**：

```json
{
  "action": "{{strategy.order.action}}",
  "symbol": "TXFR1",
  "quantity": 1,
  "strategy": "MA Cross",
  "price": {{close}}
}
```

### RSI 超買超賣策略

```pine
//@version=5
strategy("RSI Strategy", overlay=false)

rsi = ta.rsi(close, 14)

if rsi < 30
    strategy.entry("Long", strategy.long)

if rsi > 70
    strategy.close("Long")

plot(rsi)
hline(30)
hline(70)
```

---

## 下一步

- [API 文件](./API.md) - 完整 API 說明
- [部署教學](./DEPLOYMENT.md) - 後端部署指南
- [前端部署](./FRONTEND.md) - Dashboard 部署指南
