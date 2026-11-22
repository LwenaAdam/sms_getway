# 🏢 External Management Application Integration Guide
## Complete Technical Blueprint for Admin Dashboard & External Management Systems
### Product: SMS Gateway Pro & Multi-Tenant Infrastructure
**Maintainer**: TechWare Africa | **Domain**: `https://techware.africa` | **Gateway API**: `https://smsgetway.techware.africa/api`

---

## 1. Executive Architecture Summary

SMS Gateway Pro uses a **distributed hybrid architecture** where:
1. **Customer App (Android / Web Client)**: Runs on the end-user or merchant phone/device. It acts as a local hardware bridge to Android SIM cards for zero-cost SMS sending, an offline-first queue consumer, and a merchant interface.
2. **Central Cloud Database (Supabase PostgreSQL)**: Provides multi-tenant data storage under the `sms_gateway` schema, row-level security (RLS), real-time change streams via WebSockets, and edge functions.
3. **API Edge Gateway (Netlify Proxy / Domain)**: Routes traffic from `https://smsgetway.techware.africa/api` cleanly to cloud functions with CORS handling and SSL termination.
4. **External Management App (Admin Web Portal / Dashboard)**: The external web dashboard or central administration platform used by system administrators and platform operators to manage tenants, inspect device queues, provision API keys, dynamically configure SMS & payment providers, collect mobile money, and monitor real-time delivery logs.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                      EXTERNAL MANAGEMENT APPLICATION (Admin Web Portal)                │
│   • Tenant & User Management      • Dynamic Provider Config (SMS & Payments)           │
│   • Queue Monitor & Dispatcher   • Palm Pesa Mobile Money Billing & Monetization Logs │
└───────────────────────┬──────────────────────────────────────────┬─────────────────────┘
                        │                                          │
                        ▼ (Supabase Service Role / REST)           ▼ (Webhook Callbacks)
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                       CENTRAL CLOUD BACKEND (Supabase PostgreSQL)                      │
│                               Schema: `sms_gateway`                                    │
│   Tables:                                                                              │
│   ├── tenants / tenant_users               ├── sms_providers (Dynamic SMS Gateways)   │
│   ├── api_keys (Hashed SHA-256)            ├── payment_providers (Dynamic Gateways)   │
│   ├── sms_requests (Message Queue)         ├── payments (Mobile Money Transactions)    │
│   └── sms_logs (Audit Trails & Delivery)                                               │
└───────────────────────▲──────────────────────────────────────────▲─────────────────────┘
                        │                                          │
        Realtime Sync / │ Pull Pending Queue                       │ Send SMS via Fallback
                        │                                          │
┌───────────────────────┴────────────────────────┐       ┌─────────┴─────────────────────┐
│          CUSTOMER MOBILE APP (Android)         │       │    CLOUD SMS & PAYMENT APIS   │
│   • Native Android SIM Hardware Bridge         │       │   • Swala SMS (Tanzania)      │
│   • Local SQLite / SharedPreferences Cache     │       │   • Palm Pesa Tz Mobile Money │
│   • Background Queue Poller & Auto-Processor   │       │   • QuickSMS, Beem, Selcom    │
│   • Merchant Top-up & USSD Push Initiator      │       └───────────────────────────────┘
└────────────────────────────────────────────────┘
```

---

## 2. Authentication & Roles for Management Systems

When developing an external management portal (e.g. Next.js, React, Django, Laravel), you have two distinct operational authentication modes:

### A. Super Admin (Full Control Plane Access)
- **Credential**: Supabase `service_role` secret key.
- **Access Level**: Bypasses Row Level Security (RLS). Can read/write across **all tenants**, configure global system providers, force queue retries, and manage billing.
- **Header**:
  ```http
  apikey: <SUPABASE_SERVICE_ROLE_KEY>
  Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
  ```

### B. Tenant Admin (Scoped Workspace Access)
- **Credential**: Authenticated User JWT (`auth.users`) assigned `role = 'owner'` or `role = 'admin'` in `sms_gateway.tenant_users`.
- **Access Level**: Constrained by Postgres RLS to only data belonging to that specific `tenant_id`.
- **Header**:
  ```http
  apikey: <SUPABASE_ANON_KEY>
  Authorization: Bearer <USER_ACCESS_TOKEN>
  ```

---

## 3. Database Schema & Management Data Dictionary

All tables are located in the dedicated **`sms_gateway`** PostgreSQL schema.

### 3.1. `sms_gateway.tenants`
Defines isolated workspaces or client organizations.
| Column | Type | Description |
|--------|------|-------------|
| `id` | `UUID` (PK) | Unique tenant identifier |
| `name` | `TEXT` | Tenant or company display name |
| `slug` | `TEXT` | URL-friendly identifier (unique) |
| `created_at` | `TIMESTAMPTZ` | Timestamp created |

### 3.2. `sms_gateway.tenant_users`
Maps users to tenants with role-based access control.
| Column | Type | Description |
|--------|------|-------------|
| `id` | `UUID` (PK) | Record ID |
| `tenant_id` | `UUID` (FK) | Reference to `sms_gateway.tenants(id)` |
| `user_id` | `UUID` (FK) | Reference to `auth.users(id)` |
| `role` | `VARCHAR(20)`| `owner`, `admin`, `member`, `viewer` |

### 3.3. `sms_gateway.sms_requests` (The Active Queue)
The central queue where external systems enqueue messages for devices or cloud gateways to process.
| Column | Type | Description |
|--------|------|-------------|
| `id` | `UUID` (PK) | Unique request ID |
| `tenant_id` | `UUID` (FK) | Target tenant |
| `phone_number` | `VARCHAR(30)`| Recipient phone number (normalized e.g. `255XXXXXXXXX`) |
| `message` | `TEXT` | SMS message text content |
| `status` | `VARCHAR(20)`| `pending` → `processing` → `sent` / `failed` / `cancelled` |
| `priority` | `INT` | Default `0`. Higher numbers processed first |
| `scheduled_at` | `TIMESTAMPTZ`| Optional future send time |
| `processed_at` | `TIMESTAMPTZ`| When device or provider executed the send |
| `error_message`| `TEXT` | Failure reason if transmission failed |
| `external_id` | `TEXT` | External order/message reference ID |
| `metadata` | `JSONB` | Arbitrary JSON payload for business references |

### 3.4. `sms_gateway.sms_logs` (Audit Trail)
Historical log of every sent SMS message.
| Column | Type | Description |
|--------|------|-------------|
| `id` | `UUID` (PK) | Log ID |
| `tenant_id` | `UUID` (FK) | Tenant ID |
| `user_id` | `UUID` (FK) | User/device that triggered send |
| `phone_number` | `VARCHAR(30)`| Recipient phone |
| `message` | `TEXT` | Message text |
| `status` | `VARCHAR(20)`| `sent`, `failed` |
| `sent_at` | `TIMESTAMPTZ`| Transmission timestamp |
| `error_message`| `TEXT` | Error details if failed |

### 3.5. `sms_gateway.sms_providers` (Dynamic SMS Gateways)
Stores runtime configurations for external SMS gateways created by administrators.
| Column | Type | Description |
|--------|------|-------------|
| `id` | `TEXT` (PK) | Provider unique slug/ID (e.g. `swala_sms`, `beem_africa`) |
| `tenant_id` | `UUID` (FK) | `NULL` for global provider, or scoped to specific tenant |
| `name` | `TEXT` | Display name (e.g. `Swala SMS (Tanzania)`) |
| `slug` | `TEXT` | System slug |
| `endpoint_url`| `TEXT` | Target HTTP URL |
| `http_method` | `VARCHAR(10)`| `POST` or `GET` |
| `auth_type` | `VARCHAR(30)`| `bearer`, `header`, `basic`, `none` |
| `auth_header_key` | `VARCHAR(50)` | e.g. `Authorization`, `x-api-key` |
| `api_key` | `TEXT` | Encrypted/stored API key |
| `api_secret` | `TEXT` | Secret for basic auth or HMAC signature |
| `sender_id` | `VARCHAR(50)` | Default Sender ID (e.g. `TECHWARE`) |
| `body_template`| `TEXT` | JSON template with `{{phone}}`, `{{message}}`, `{{sender_id}}` |
| `custom_headers`| `JSONB` | Custom HTTP headers map |
| `is_active` | `BOOLEAN` | Whether enabled |
| `is_default` | `BOOLEAN` | Whether primary default provider |

### 3.6. `sms_gateway.payment_providers` (Dynamic Payment Gateways)
Stores runtime configurations for payment gateways (mobile money, cards, Lipa Namba).
| Column | Type | Description |
|--------|------|-------------|
| `id` | `TEXT` (PK) | Gateway ID (e.g. `palmpesa_default`, `selcom_tz`) |
| `tenant_id` | `UUID` (FK) | `NULL` for global, or scoped to tenant |
| `name` | `TEXT` | e.g. `Palm Pesa Tz` |
| `slug` | `TEXT` | Slug |
| `base_url` | `TEXT` | Gateway base URL (e.g. `https://palmpesa.drmlelwa.co.tz`) |
| `endpoint_url`| `TEXT` | Endpoint path (e.g. `/api/v2/async/payments`) |
| `merchant_id` | `TEXT` | Public User Ref (e.g. `USR-579470B9AB51`) or Till Number |
| `api_token` | `TEXT` | Gateway API token |
| `currency` | `VARCHAR(10)`| Default `TZS` |
| `payment_type`| `VARCHAR(50)`| `mobile_money_ussd`, `checkout_url`, `manual_lipa_namba` |
| `supported_channels` | `JSONB` | `["Vodacom M-Pesa", "Tigo Pesa", "Airtel Money", "HaloPesa"]` |
| `callback_url`| `TEXT` | Webhook callback URL |
| `is_active` | `BOOLEAN` | Enabled status |
| `is_default` | `BOOLEAN` | Default gateway status |

### 3.7. `sms_gateway.payments` (Mobile Money Transactions)
Tracks customer subscriptions, top-ups, and checkout requests.
| Column | Type | Description |
|--------|------|-------------|
| `id` | `UUID` (PK) | Record ID |
| `transaction_id`| `TEXT` (Unique)| Merchant transaction reference (e.g. `SGW_1700000_A1B2C3`) |
| `tenant_id` | `UUID` (FK) | Paying tenant |
| `user_id` | `UUID` (FK) | Paying user |
| `amount` | `NUMERIC(12,2)`| Amount in TZS |
| `currency` | `VARCHAR(10)`| `TZS` |
| `phone_number`| `VARCHAR(30)`| Customer phone number |
| `plan_name` | `VARCHAR(100)`| Plan name (e.g. `Business Pro Plan`, `SMS Credits Top-up`) |
| `status` | `VARCHAR(30)`| `pending`, `completed`, `failed`, `cancelled` |
| `provider` | `VARCHAR(50)`| `palmpesa`, `selcom`, `lipa_namba` |
| `metadata` | `JSONB` | Gateway response and buyer remarks |

---

## 4. Palm Pesa Tz Mobile Money Integration Details

### 4.1. Account Credentials & Merchant Setup
- **Platform**: [Palm Pesa Tz Dashboard](https://palmpesa.drmlelwa.co.tz/dashboard)
- **Base URL**: `https://palmpesa.drmlelwa.co.tz` (or fallback `https://palmpesa.co.tz`)
- **Public User Ref**: `USR-579470B9AB51`
- **Supported Operators**:
  - Vodacom M-Pesa (prefixes: `074`, `075`, `076`)
  - Tigo Pesa / Mixx by Yas (prefixes: `071`, `065`, `067`)
  - Airtel Money (prefixes: `068`, `069`, `078`)
  - HaloPesa (prefixes: `062`)

### 4.2. Initiating a USSD Push Payment (Async Request)
When a customer purchases a plan in the app or the external admin triggers a payment request:

**Request**:
```http
POST https://palmpesa.drmlelwa.co.tz/api/v2/async/payments
Authorization: Bearer <PALMPESA_API_TOKEN>
X-User-Ref: USR-579470B9AB51
Content-Type: application/json
Accept: application/json

{
  "transaction_id": "SGW_1732280000_XYZ890",
  "amount": 50000,
  "currency": "TZS",
  "phone": "255744123456",
  "name": "Acme Supermarket",
  "email": "finance@acme.co.tz",
  "public_user_ref": "USR-579470B9AB51",
  "callback_url": "https://smsgetway.techware.africa/api/payments/palmpesa/callback",
  "buyer_remarks": "Subscription for Business Pro Plan",
  "merchant_remarks": "SMS Gateway Pro Plan"
}
```

**Response (202 Accepted)**:
```json
{
  "status": "pending",
  "message": "Payment initiation accepted. USSD push dispatched to phone.",
  "transaction_id": "SGW_1732280000_XYZ890"
}
```

### 4.3. Handling the Webhook Callback in External Management Backend
Your external management server or Supabase Edge function should receive the webhook callback from Palm Pesa:

**Endpoint**: `POST /api/payments/palmpesa/callback`

**Payload**:
```json
{
  "transaction_id": "SGW_1732280000_XYZ890",
  "reference": "PP_TXN_9988776655",
  "status": "completed",
  "amount": 50000,
  "currency": "TZS",
  "phone": "255744123456",
  "completed_at": "2026-11-22T14:30:00Z"
}
```

**Handler Logic**:
1. Check if `status == 'completed'`.
2. Locate the record in `sms_gateway.payments` by `transaction_id`.
3. Update `status = 'completed'` and record `metadata`.
4. Add the purchased SMS credits or extend the subscription validity for the corresponding `tenant_id`.
5. Return HTTP `200 OK`.

---

## 5. Swala SMS Integration Details (Branded Sender ID)

### 5.1. Configuration
- **Platform**: [Swala SMS](https://swalasms.com/sms/api-keys)
- **Endpoint**: `https://swalasms.com/api/v1/sms/messages`
- **Method**: `POST`
- **Auth**: `Authorization: Bearer <SWALA_API_KEY>`

### 5.2. Transmission Payload
```json
{
  "sender_id": "TECHWARE",
  "recipients": ["255744123456", "255655987654"],
  "message": "Your verification code is 482910. Valid for 10 minutes."
}
```

### 5.3. Number Formatting Rules for Swala SMS
- Strip spaces, hyphens, and leading `+`.
- If starting with `0`, replace with `255` (e.g. `0744123456` → `255744123456`).
- Total length for Tanzanian numbers must be exactly **12 digits**.

---

## 6. How External Management App Controls Customer App Queues

The customer mobile app has an internal daemon (`ApiSmsQueueService`) that automatically checks for messages to send. Here is how your external admin app coordinates with it:

### 6.1. Enqueueing Messages for Device Sending
Your external system inserts into `sms_gateway.sms_requests`:
```sql
INSERT INTO sms_gateway.sms_requests (
  tenant_id,
  phone_number,
  message,
  status,
  priority,
  external_id,
  metadata
) VALUES (
  'e656d0d2-9725-4c07-b2eb-6d47f2be9b16',
  '255744123456',
  'Monthly school fee reminder: TZS 150,000 due on 30th Nov.',
  'pending',
  5,
  'INV-2026-11-001',
  '{"student_id": "ST-99", "grade": "Form 4"}'::jsonb
);
```

### 6.2. Real-Time WebSocket Subscription (Supabase Realtime)
To update your dashboard live without polling:
```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

// Listen for newly completed SMS
supabase
  .channel('sms-queue-updates')
  .on(
    'postgres_changes',
    {
      event: 'UPDATE',
      schema: 'sms_gateway',
      table: 'sms_requests'
    },
    (payload) => {
      console.log('Request updated:', payload.new.id, payload.new.status);
      updateDashboardStats(payload.new);
    }
  )
  .subscribe();
```

---

## 7. Dynamic Provider CRUD API for External Management

External management systems can add, update, and toggle active providers at any time via standard Supabase REST API or SQL.

### 7.1. Adding a New Custom SMS Provider (e.g. Beem Africa or Custom Webhook)
```http
POST https://kzjgdeqfmxkmpmadtbpb.supabase.co/rest/v1/sms_providers
apikey: <SUPABASE_SERVICE_ROLE_KEY>
Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "id": "beem_africa_custom",
  "name": "Beem Africa Gateway",
  "slug": "beem_africa",
  "endpoint_url": "https://apisms.beem.africa/v1/send",
  "http_method": "POST",
  "auth_type": "basic",
  "auth_header_key": "Authorization",
  "api_key": "YOUR_BEEM_API_KEY",
  "api_secret": "YOUR_BEEM_SECRET_KEY",
  "sender_id": "INFO",
  "body_template": "{\"source_addr\":\"{{sender_id}}\",\"message\":\"{{message}}\",\"encoding\":0,\"recipients\":[{\"recipient_id\":1,\"dest_addr\":\"{{phone}}\"}]}",
  "is_active": true,
  "is_default": false
}
```

### 7.2. Adding a New Payment Gateway (e.g. Selcom Pay or Lipa Namba)
```http
POST https://kzjgdeqfmxkmpmadtbpb.supabase.co/rest/v1/payment_providers
apikey: <SUPABASE_SERVICE_ROLE_KEY>
Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "id": "selcom_tanzania",
  "name": "Selcom Pay",
  "slug": "selcom",
  "base_url": "https://api.selcom.net/v1",
  "endpoint_url": "/checkout/create-order",
  "merchant_id": "SELCOM_MERCHANT_CODE",
  "api_token": "SELCOM_API_TOKEN",
  "currency": "TZS",
  "payment_type": "mobile_money_ussd",
  "supported_channels": ["Vodacom M-Pesa", "Tigo Pesa", "Airtel Money", "HaloPesa"],
  "callback_url": "https://smsgetway.techware.africa/api/payments/selcom/callback",
  "is_active": true,
  "is_default": false
}
```

---

## 8. Complete External Management Code Examples

### 8.1. Node.js / TypeScript Admin Client Example
```typescript
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://kzjgdeqfmxkmpmadtbpb.supabase.co';
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY!;

const adminClient = createClient(SUPABASE_URL, SERVICE_KEY, {
  db: { schema: 'sms_gateway' }
});

export class ExternalManagementService {
  /**
   * Get overall system metrics across all customer apps
   */
  async getSystemOverview() {
    const { count: pendingQueue } = await adminClient
      .from('sms_requests')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'pending');

    const { count: sentToday } = await adminClient
      .from('sms_logs')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'sent')
      .gte('sent_at', new Date().toISOString().split('T')[0]);

    const { count: failedToday } = await adminClient
      .from('sms_logs')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'failed')
      .gte('sent_at', new Date().toISOString().split('T')[0]);

    const { data: recentPayments } = await adminClient
      .from('payments')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(10);

    return {
      pendingQueue: pendingQueue || 0,
      sentToday: sentToday || 0,
      failedToday: failedToday || 0,
      recentPayments: recentPayments || []
    };
  }

  /**
   * Provision a new Tenant Workspace with an initial API Key
   */
  async createTenantWithApiKey(tenantName: string, ownerEmail: string) {
    const slug = tenantName.toLowerCase().replace(/[^a-z0-9]/g, '-');
    
    // 1. Create Tenant
    const { data: tenant, error: tenantErr } = await adminClient
      .from('tenants')
      .insert({ name: tenantName, slug })
      .select()
      .single();

    if (tenantErr) throw tenantErr;

    // 2. Generate API Key
    const crypto = await import('crypto');
    const rawKey = `sgw_${crypto.randomUUID().replace(/-/g, '')}`;
    const keyHash = crypto.createHash('sha256').update(rawKey).digest('hex');

    const { data: apiKey, error: keyErr } = await adminClient
      .from('api_keys')
      .insert({
        tenant_id: tenant.id,
        name: 'Default Production Key',
        key_hash: keyHash,
        active: true
      })
      .select()
      .single();

    if (keyErr) throw keyErr;

    return {
      tenant,
      apiKeyObj: apiKey,
      secretRawApiKey: rawKey // Only shown once!
    };
  }
}
```

### 8.2. Python / FastAPI Management API Example
```python
from fastapi import FastAPI, HTTPException, Header, Depends
from pydantic import BaseModel
from supabase import create_client, Client
import os

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://kzjgdeqfmxkmpmadtbpb.supabase.co")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

supabase: Client = create_client(SUPABASE_URL, SERVICE_KEY)

app = FastAPI(title="SMS Gateway Pro External Management API")

class EnqueueSMSRequest(BaseModel):
    tenant_id: str
    phone_number: str
    message: str
    priority: int = 0
    external_id: str | None = None

@app.post("/management/queue/inject")
def inject_sms_into_queue(req: EnqueueSMSRequest):
    """Allows external CRM or ERP systems to enqueue SMS for customer devices"""
    res = supabase.schema("sms_gateway").table("sms_requests").insert({
        "tenant_id": req.tenant_id,
        "phone_number": req.phone_number,
        "message": req.message,
        "status": "pending",
        "priority": req.priority,
        "external_id": req.external_id
    }).execute()
    
    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to enqueue message")
    return {"success": True, "request_id": res.data[0]["id"]}

@app.post("/management/payments/palmpesa/verify")
def verify_palmpesa_payment(transaction_id: str):
    """Manually checks and resolves Palm Pesa transaction status"""
    res = supabase.schema("sms_gateway").table("payments").select("*").eq("transaction_id", transaction_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    payment = res.data[0]
    return {"transaction_id": transaction_id, "status": payment["status"], "amount": payment["amount"]}
```

---

## 9. Failure Modes & Automatic Failover Strategy

When designing external management rules:
1. **Offline Device Failover**:
   - If an SMS request remains `pending` in `sms_gateway.sms_requests` for > 3 minutes (meaning the customer's Android device is offline, has no battery, or SIM credit depleted), the external management system can trigger **Automatic Cloud Failover**.
   - The external app updates the request or dispatches it directly to `https://swalasms.com/api/v1/sms/messages` via Swala SMS or Beem Africa so customer critical alerts (e.g. OTPs) are never lost.
2. **Duplicate Request Prevention**:
   - `sms_requests` status transitions are atomic: `pending` → `processing` → `sent`.
   - Android apps lock rows during fetch:
     `UPDATE sms_requests SET status = 'processing' WHERE id = :id AND status = 'pending'`.
3. **Transaction Idempotency**:
   - `sms_gateway.payments` has a unique constraint on `transaction_id`.
   - Even if Palm Pesa re-sends a webhook multiple times, verify against `status == 'completed'` before adding customer credits.

---

## 10. Summary Checklist for Management App Developers

- [ ] Connect using `SUPABASE_SERVICE_ROLE_KEY` with schema set to `sms_gateway`.
- [ ] Implement listener on `sms_gateway.sms_requests` table to monitor live device activity.
- [ ] Provide admin interface to view and edit `sms_gateway.sms_providers` (SwalaSMS, QuickSMS, Beem).
- [ ] Provide admin interface to view and edit `sms_gateway.payment_providers` (Palm Pesa Tz, Selcom, Lipa Namba).
- [ ] Setup webhook route `POST /api/payments/palmpesa/callback` with Public User Ref `USR-579470B9AB51`.
- [ ] Add phone number validation ensuring `255XXXXXXXXX` formatting for East African carriers.
