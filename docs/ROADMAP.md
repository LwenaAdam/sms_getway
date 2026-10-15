# 🚀 SMS Gateway Pro - Product Roadmap

A **distributed, SIM-based messaging platform** that allows organizations to send bulk SMS using their **own mobile devices**, with optional internet-based integrations for automation, logging, and Sender ID support.

---

## 🎯 Core Principles

| Principle | Description |
|-----------|-------------|
| **SIM-First Delivery** | Cost-efficient, legal, decentralized SMS via device SIM |
| **Offline-First** | Manual operations work without internet |
| **Online for Automation** | API features require connectivity |
| **Organization-Owned** | Each org uses their own devices and SIM cards |
| **Unified Logging** | All messages logged regardless of delivery channel |
| **Extensible** | Supports future Sender ID and provider integrations |

---

## 📊 Development Phases

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: Local SMS Gateway                         ✅ COMPLETE         │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 2: Connected & API-Enabled Gateway           🔄 CORE COMPLETE    │
│  ├── 2.1 Organization & Authentication              ✅ COMPLETE         │
│  ├── 2.2 Backend & Sync Layer                       🔄 IN PROGRESS      │
│  ├── 2.3 API-Triggered SMS                          ✅ COMPLETE         │
│  ├── 2.4 API Security & Control                     ✅ COMPLETE         │
│  ├── 2.5 Revenue Enablement (Sender ID)             🔲 PLANNED          │
│  ├── 2.6 Settings Backup & Cross-Device Sync        ✅ COMPLETE         │
│  └── 2.7 Marketing Automation Engine                🔄 IN PROGRESS      │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 3: Scale & Enterprise Features               📋 PLANNED          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## ✅ Phase 1: Local SMS Gateway (COMPLETE)

**Goal:** Enable bulk SMS sending directly from a user's phone, working without internet connectivity.

### Features Delivered

| Feature | Status | Description |
|---------|--------|-------------|
| Native Android SMS | ✅ | Send SMS via device SIM card |
| Bulk SMS Sending | ✅ | Send to multiple contacts/groups |
| Contact Management | ✅ | Add, edit, delete, CSV import |
| Group Management | ✅ | Create groups with members |
| Message Composition | ✅ | User-friendly SMS editor |
| Local Message Logs | ✅ | Track sent/failed messages |
| Offline Functionality | ✅ | Works without internet |
| Multi-Tenant Architecture | ✅ | Workspace isolation |
| Dark Mode | ✅ | Full theme support |
| Row Level Security | ✅ | Database-level isolation |

### Architecture
```
User → App UI → Android SmsManager → Phone SIM → Recipient
                     ↓
              Local SQLite Logs
```

### Limitations
- ⚠️ Android only (iOS cannot send SMS programmatically)
- ⚠️ Requires device with active SIM card
- ⚠️ Carrier rate limits may apply
- ⚠️ Sender appears as phone number (not branded)

📌 **Status:** Completed & stable

---

## ✅ Phase 2: Connected & API-Enabled Gateway (CORE COMPLETE)

**Note:** Core features complete. Offline-first logging active; hardening in progress.

---

### 📊 Data Ownership & Sync Policy

**Source of Truth Rules:**

| Data Type | Source of Truth | Sync Direction | Notes |
|-----------|----------------|----------------|-------|
| **Campaign Definitions** | Supabase | Cloud → Device | Always pull from cloud |
| **API-Triggered SMS** | Supabase | Cloud → Device | Requires internet |
| **Marketing Analytics** | Supabase | Cloud ← Device | Device pushes logs |
| **Offline SMS Sends** | Local SQLite | Device → Cloud | Append-only sync |
| **WorkManager Jobs** | Local SQLite | Device only | Ephemeral state |
| **Daily Counters** | Local SQLite | Device → Cloud | Synced hourly |

**Conflict Resolution:**
```
├── Local logs always sync UP to Supabase (append-only, no conflicts)
├── Campaign state always pulled DOWN from Supabase (cloud is truth)
├── Settings: Last-write-wins (timestamped)
└── Counters: Supabase aggregates from all devices
```

**When Offline:**
```
✅ Can send: Manual SMS, queued campaigns
✅ Can create: Contacts, groups, draft campaigns
❌ Cannot: Activate campaigns, pull new API requests
📤 Auto-syncs when connection restored
```

---

### 🔸 Phase 2.1 – Organization & Authentication ✅ COMPLETE

**Objective:** Introduce organization-level ownership and secure access.

| Feature | Status | Description |
|---------|--------|-------------|
| Organization Registration | ✅ | Complete 8-step registration flow |
| Secure Login | ✅ | Email/password authentication |
| Multi-Tenant Access | ✅ | Users can belong to multiple orgs |
| Workspace Picker | ✅ | Select organization after login |
| Tenant-Scoped Data | ✅ | All data filtered by tenant_id |
| Session Management | ✅ | Secure token handling |
| Role System | ✅ | Owner, Admin, Member, Viewer roles |
| Client-Product Access | ✅ | Product access verification for login |
| RLS Policies | ✅ | Row-level security on all tables |

**Registration Flow (8 Steps):**
```
1. Create auth.users account
2. Create public.clients record (top-level organization)
3. Create sms_gateway.tenants record (product tenant)
4. Create sms_gateway.users record (user profile)
5. Create sms_gateway.tenant_members record (membership)
6. Create sms_gateway.user_settings record (preferences)
7. Create sms_gateway.tenant_settings record (org config)
8. Create public.client_product_access record (login verification)
```

**Login Architecture:**
```
User Login → Auth → Load Tenants (via client_product_access)
                         ↓
              (2+ tenants?) → Workspace Picker → Home
                         ↓ (1 tenant)
                    Auto-select → Home
```

📌 **Status:** Completed December 2024

---

### 🔸 Phase 2.2 – Backend & Sync Layer 🔄 IN PROGRESS

**Objective:** Centralize message logging and enable offline-to-online sync.

| Feature | Status | Description |
|---------|--------|-------------|
| Central Message Storage | ✅ | PostgreSQL via Supabase |
| SMS Logs Table | ✅ | sms_gateway.sms_logs with delivery tracking |
| Contacts Storage | ✅ | Centralized contact management |
| Groups Storage | ✅ | Group and membership tracking |
| Sync Sent/Failed SMS | 🔄 | Push from local to cloud with retry |
| Timestamping | ✅ | Accurate message timing |
| Message Source Tracking | 🔄 | UI tracking implemented (refine) |
| Offline-First Storage | ✅ | Local SQLite with sync layer |

**Current Sync Behavior:**
```
┌─────────────────────────────────────────────────────────────┐
│  ONLINE: SMS sent → Local log + push to Supabase           │
│  OFFLINE: Local log → auto-sync on reconnect               │
└─────────────────────────────────────────────────────────────┘
```

📌 Offline-first logging is active; remaining work is resiliency and edge cases.

---

### 🔸 Phase 2.3 – API-Triggered SMS (Online Only) ✅ COMPLETE

**Objective:** Allow external systems (CRMs, ERPs, school systems) to trigger SMS via the mobile app.

**Flow:**
```
External System → Internet → API → Mobile App → SIM → Recipient
        ↓
   POST /api/sms/send
   {
     "api_key": "sk_xxx",
     "recipients": ["+255..."],
     "message": "Your order is ready"
   }
```

**API Implementation Status:**

| Method | Endpoint | Status | Description |
|--------|----------|--------|-------------|
| `POST` | `/sms-api/send` | ✅ | Queue single SMS via Edge Function |
| `POST` | `/sms-api/bulk` | ✅ | Queue bulk SMS via Edge Function |
| `GET` | `/sms-api/status/:id` | ✅ | Get SMS request status |
| `GET` | `/sms-api/docs` | ✅ | API documentation endpoint |

**Current Implementation:**
- ✅ API SMS Queue Service (ApiSmsQueueService)
- ✅ Database polling every 30 seconds
- ✅ Support for both Native SMS and QuickSMS API
- ✅ Auto-start queue processing setting
- ✅ Manual queue control in Settings UI
- ✅ Edge Functions for API endpoints (sms-api/index.ts)
- ✅ Supabase RPC functions (submit_sms_request, submit_bulk_sms_request)
- ✅ Request status tracking

**Requirements:**
- ✅ Active internet connection
- ✅ Valid API key (x-api-key header)
- ✅ Device online with app running
- ✅ Queue processing enabled in settings

📌 API-triggered SMS **cannot work offline** – SMS delivery still uses phone's SIM.
📌 **Status:** Completed December 28, 2025

---

### 🔸 Phase 2.4 – API Security & Control ✅ COMPLETE

**Objective:** Prevent misuse and unauthorized SMS sending.

| Feature | Status | Description |
|---------|--------|-------------|
| API Key Generation | ✅ | Per-organization keys with UI |
| Key Rotation | ✅ | Activate/deactivate keys |
| Request Authentication | ✅ | x-api-key header validation |
| Rate Limiting | ✅ | 100 requests per minute |
| Device Authorization | ✅ | Tenant-based access control |
| Message Ownership | ✅ | Tenant isolation via RLS |
| Audit Logging | ✅ | Track all SMS requests in queue |
| Edge Functions | ✅ | Supabase serverless endpoints |

**API Authentication:**
```http
POST /sms-api/send
x-api-key: sk_live_xxx_xxx
Content-Type: application/json
```

**Current Security:**
- ✅ Row Level Security (RLS) on all tables
- ✅ Tenant isolation at database level
- ✅ Supabase Auth for user authentication
- ✅ API key system with create/activate/deactivate
- ✅ Rate limiting (100 req/min per key)
- ✅ API usage tracking in sms_requests table

📌 **Status:** Completed December 28, 2025

---

### 🔸 Phase 2.5 – Revenue Enablement (Sender ID Integration) 🔲 PLANNED

**Objective:** Support internet-based SMS providers for branded Sender ID and revenue generation.

**Commercial Value:**
- 🏢 Branded Sender ID (e.g., "MYSCHOOL" instead of phone number)
- � White-label reselling opportunity
- 📊 High-volume enterprise clients
- 🌍 International SMS delivery

**Use Cases:**
- �💳 No SIM balance / SIM not available
- � Regulatory requirements (some countries require Sender ID)
- 🏢 Corporate branding requirements
- 📈 Campaigns exceeding device capacity

**Channel Selection:**

| Channel | Internet | SIM | Sender | Cost |
|---------|----------|-----|--------|------|
| **Manual UI → SIM** | ❌ | ✅ | Phone Number | Carrier rates |
| **API → SIM** | ✅ | ✅ | Phone Number | Carrier rates |
| **API → Provider** | ✅ | ❌ | Sender ID | Provider rates |

**Provider Integration Priority:**
1. **Africa's Talking** (Africa-focused)
2. **Beem Africa** (East Africa)
3. **Twilio** (International)
4. **Custom Webhook** (bring your own provider)

📌 Provider use is **optional**, not mandatory.

---

### 🔸 Phase 2.6 – Settings Backup & Cross-Device Sync ✅ COMPLETE

**Objective:** Allow users to backup their settings to Supabase and restore on different devices.

| Feature | Status | Description |
|---------|--------|-------------|
| User Settings Backup | ✅ | SMS channel, theme, language, notifications |
| Tenant Settings Backup | ✅ | Workspace quotas and feature flags |
| Cross-Device Restore | ✅ | Sync preferences across devices |
| Audit Trail | ✅ | Track all backup/restore operations |
| RLS Security | ✅ | User & tenant data isolation |
| UI Integration | ✅ | Backup/restore buttons in Settings |

**Implementation Details:**

Settings backed up include:
- **User Level**: SMS channel (Native/QuickSMS), auto-start queue, theme mode, language, notification preferences
- **Tenant Level**: Default SMS channel, daily/monthly quotas, feature flags (bulk, scheduled, groups, API), plan type

**Service Architecture:**
```
SettingsBackupService (Singleton)
├── backupUserSettings() → SharedPreferences → RPC → user_settings table
├── restoreUserSettings() → RPC → user_settings table → SharedPreferences
├── backupTenantSettings() → SharedPreferences → REST → tenant_settings table
└── restoreTenantSettings() → REST → tenant_settings table → SharedPreferences
```

**Database Tables:**
- `user_settings` - Per-user preferences with unique(user_id, tenant_id)
- `tenant_settings` - Workspace configuration unique per tenant
- `settings_sync_log` - Audit trail of all sync operations

**RLS Policies:**
- Users can only view/update their own settings
- Tenant admins can update workspace settings
- All operations logged for audit trail

**User Flow:**
```
Device A:
1. Configure SMS settings
2. Go to Settings → Backup Settings to Supabase
3. ✅ Settings saved to cloud

Device B:
1. Login with same account
2. Go to Settings → Restore Settings from Supabase
3. ✅ Settings match Device A automatically
```

📌 **Status:** Completed December 2024

---

### 🔸 Phase 2.7 – Marketing Automation Engine 🔄 IN PROGRESS

**Objective:** Enable controlled, ethical, and rate-limited SMS marketing campaigns using organization's own Android SIM cards.

**Status:** Q1 2026 - Week 2 Complete (Core Workers + Services)

**Terminology Note:** Previously called "Auto Marketing Engine" - standardized to "Marketing Automation Engine" for enterprise positioning.

**✅ Completed (Feb 4, 2026):**
- Week 1: Database schema deployed to Supabase (6 tables, RLS policies)
- Week 2: Android Workers (3 files) + Services (5 files) - 2,377 lines Java
- Week 2.5: Flutter UI integration (marketing_settings_screen.dart)
- Foreground Service SMS sending (MarketingSmsService.java)
- Permission architecture fix (removed Worker permission check)
- Access token flow (RLS authentication working)
- Week 3: Campaign Management UI complete!
  - Campaign list screen with stats and progress bars
  - Campaign create/edit screen with contact selection
  - Campaign models (MarketingCampaign, CampaignContact)
  - Message template preview with dynamic fields
  - Contact model updated (firstName, lastName support)
  - Database migration for contacts table

**🔄 Current Status:**
- Core architecture complete and tested ✅
- SMS sending verified (Foreground Service working) ✅
- Campaign creation and management UI complete ✅
- Contact personalization ready ({first_name}, {last_name}, {phone}) ✅
- JWT token refresh: disable/re-enable marketing after app restart

**📋 Remaining:**
- Week 4: CSV import, phonebook sync
- Week 5-6: Campaign analytics dashboard
- Week 7: Web platform integration
- Week 8: Final testing and optimization

---

#### 📊 Overview

Enable organizations to run automated SMS marketing campaigns through their Android devices with strict anti-spam controls and ethical sending practices.

**Core Architecture:**
```
Web/Android UI → Campaign Creation → WorkManager (Android) → SIM → Recipients
                       ↓                        ↓
                 Supabase Sync          Rate Limiting + Logging
```

**Key Principles:**
- ✅ Tenant-scoped (per-organization)
- ✅ Opt-in only (disabled by default)
- ✅ Strict frequency limits
- ✅ Battery-efficient execution
- ✅ Full user control and transparency

---

#### ✅ Features Specification

| Feature | Status | Description |
|---------|--------|-------------|
| **Campaign Management** | 🔄 | Create, edit, activate multiple campaigns |
| **Contact Sources** | 🔄 | CSV import, phonebook sync, existing contacts |
| **Message Templates** | 🔄 | Save multiple templates with dynamic fields |
| **Dynamic Personalization** | 🔄 | {first_name}, {last_name}, {phone} merge fields |
| **Daily Sending Limit** | 🔄 | Max 100 SMS/day per tenant |
| **Per-Number Frequency** | 🔄 | Max 2 SMS per 30 days (rolling window) |
| **Rate Limiting** | 🔄 | 2 SMS/minute with randomized delays |
| **Opt-Out Management** | 🔄 | Manual blacklist via UI |
| **Web + Android Sync** | 🔄 | Create campaigns on web, execute on Android |
| **Campaign Analytics** | 🔄 | Sent, pending, failed, opted-out tracking |
| **WorkManager Integration** | 🔄 | Background execution with battery optimization |

---

#### 🛡️ Anti-Spam Safeguards

**Hard Limits (Enforced at Database Level):**

| Rule | Limit | Enforcement |
|------|-------|-------------|
| Daily SMS per Tenant | 100 SMS | Resets at 00:00 local time |
| SMS per Number (30-day) | 2 SMS | Rolling 30-day window |
| Send Rate | 2 SMS/min | Programmatic delay (30-60 sec) |
| Campaign Pause | Automatic | When daily limit reached |

**User Controls:**
- ✅ Global kill switch (disable instantly)
- ✅ Campaign-level enable/disable
- ✅ Preview before activation
- ✅ Real-time quota display
- ✅ Manual blacklist management

---

#### 🗄️ Database Schema

**New Tables:**

```sql
-- Campaign definitions
CREATE TABLE sms_gateway.marketing_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id),
  name VARCHAR(100) NOT NULL,
  message_template TEXT NOT NULL,
  status VARCHAR(20) DEFAULT 'draft', -- draft, active, paused, completed
  daily_sent_count INTEGER DEFAULT 0,
  total_sent_count INTEGER DEFAULT 0,
  total_contact_count INTEGER DEFAULT 0,
  created_by UUID REFERENCES sms_gateway.users(id),
  created_at TIMESTAMP DEFAULT now(),
  activated_at TIMESTAMP,
  completed_at TIMESTAMP
);

-- Campaign contacts (junction table)
CREATE TABLE sms_gateway.marketing_campaign_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES sms_gateway.marketing_campaigns(id),
  contact_id UUID REFERENCES sms_gateway.contacts(id),
  phone_number VARCHAR(20) NOT NULL,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  status VARCHAR(20) DEFAULT 'pending', -- pending, sent, failed, skipped
  sent_at TIMESTAMP,
  failure_reason TEXT
);

-- Tenant marketing settings
CREATE TABLE sms_gateway.marketing_settings (
  tenant_id UUID PRIMARY KEY REFERENCES sms_gateway.tenants(id),
  enabled BOOLEAN DEFAULT false,
  daily_limit INTEGER DEFAULT 100,
  per_number_limit INTEGER DEFAULT 2,
  per_number_days INTEGER DEFAULT 30,
  send_interval_seconds INTEGER DEFAULT 45,
  last_reset_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- Frequency tracker (30-day rolling window) - EVENT-BASED
CREATE TABLE sms_gateway.marketing_frequency_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id),
  phone_number VARCHAR(20) NOT NULL,
  campaign_id UUID REFERENCES sms_gateway.marketing_campaigns(id),
  sent_at TIMESTAMP NOT NULL DEFAULT now(),
  message_preview TEXT, -- First 50 chars for audit
  INDEX idx_frequency_lookup (tenant_id, phone_number, sent_at)
);

-- Query to check frequency (accurate rolling window):
-- SELECT COUNT(*) FROM marketing_frequency_events
-- WHERE tenant_id = ? AND phone_number = ?
--   AND sent_at >= NOW() - INTERVAL '30 days';

-- Opt-out blacklist
CREATE TABLE sms_gateway.marketing_optouts (
  phone_number VARCHAR(20) NOT NULL,
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id),
  opted_out_at TIMESTAMP DEFAULT now(),
  method VARCHAR(20) DEFAULT 'manual', -- manual, admin
  notes TEXT,
  PRIMARY KEY (phone_number, tenant_id)
);

-- Campaign execution logs
CREATE TABLE sms_gateway.marketing_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES sms_gateway.marketing_campaigns(id),
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id),
  phone_number VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(20) NOT NULL, -- sent, failed
  sent_at TIMESTAMP DEFAULT now(),
  failure_reason TEXT
);
```

---

#### 🔄 Workflow & Execution

**Campaign Creation Flow:**
```
1. User (Web/Android) → Create Campaign
2. Set name, message template with {first_name}, {last_name}, {phone}
3. Select contacts:
   ├── From existing SMS Gateway contacts
   ├── Import from CSV
   ├── Import from phone contacts (Android only)
   └── Manual entry
4. Preview rendered messages
5. Save as draft or activate immediately
6. Campaign stored in Supabase
```

**Campaign Execution (Android WorkManager):**
```
1. CampaignCheckWorker runs every 30 minutes (PeriodicWorkRequest)
2. Check: marketing_settings.enabled = true
3. Check: daily_sent_count < daily_limit
4. Fetch active campaigns with pending contacts (batch of 10)
5. For each contact, schedule OneTimeWorkRequest:
   ├── Calculate staggered delay (30-60 sec * index)
   ├── Create SendMarketingSmsWorker with contact data
   ├── Set initial delay for rate limiting
   └── Enqueue worker with tag "marketing_sms"
6. SendMarketingSmsWorker executes per contact:
   ├── Final checks (opt-out, frequency, daily limit)
   ├── Render template: "Hi {first_name}" → "Hi John"
   ├── Send SMS via SmsManager
   ├── Log to marketing_logs
   ├── Insert marketing_frequency_events record
   ├── Update campaign_contacts.status = 'sent'
   └── Sync logs to Supabase (async)
7. System automatically handles:
   ├── Battery optimization (no wake locks)
   ├── Device reboot (work persisted)
   ├── Rate limiting (via delayed workers)
   └── Retry on failure (WorkManager built-in)
```

**Daily Reset Logic:**
```
Daily at 00:00 device time:
├── Reset marketing_settings.daily_sent_count = 0
└── Reset marketing_campaigns.daily_sent_count = 0
```

**30-Day Frequency Check:**
```sql
-- Before sending, check (accurate rolling window):
SELECT COUNT(*) FROM marketing_frequency_events
WHERE phone_number = '+255...'
  AND tenant_id = 'xxx'
  AND sent_at >= NOW() - INTERVAL '30 days';
  
-- If count >= 2, skip this number
-- This event-based design ensures accuracy and auditability
```

---

#### 🎨 User Interface

**Web Platform (Campaign Management):**
```
Settings → Marketing Automation
├── Enable/Disable Toggle
├── Daily Limit Display (75/100 sent today)
├── Campaign List
│   ├── [+ New Campaign]
│   ├── Campaign Card:
│   │   ├── Name: "Spring Sale 2026"
│   │   ├── Status: Active | Draft | Paused
│   │   ├── Progress: 500/2000 sent
│   │   └── Actions: Edit | Pause | Delete
│   └── ...
├── Opt-Out Management
│   └── Blacklist numbers
└── Analytics Dashboard
    ├── Total Sent (Last 30 days)
    ├── Active Campaigns
    ├── Opted-Out Numbers
    └── Delivery Rate

📌 Web Platform Capabilities:
├── ✅ Campaign creation & editing
├── ✅ Analytics & reporting
├── ✅ Settings configuration
├── ✅ Contact management
├── ✅ Start/pause campaigns
└── ❌ NO direct SMS execution (Android only)
```

**Android Platform (Campaign Execution):**
```
Marketing Tab
├── Same UI as web
├── Additional:
│   ├── Import from Phone Contacts button
│   ├── WorkManager Status Indicator
│   ├── "Processing..." badge when sending
│   └── Local queue preview
└── Background Service Control
    ├── Auto-start toggle
    └── Manual "Process Now" button
```

---

#### 🔐 Permissions (Android)

**Required Permissions:**
```xml
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.READ_CONTACTS"/>
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
```

**Permission Request Flow:**
1. User activates marketing feature
2. App explains: "We need contact access to import phone contacts"
3. User grants permissions
4. Contact picker UI shown

---

#### 📊 Analytics & Reporting

**Campaign Analytics (Web + Android):**
```
Campaign: "Spring Sale 2026"
├── Status: Active
├── Created: Feb 1, 2026
├── Activated: Feb 2, 2026 10:30 AM
├── Progress: 756/2000 contacts (37.8%)
├── Sent Today: 100/100 (limit reached)
├── Total Sent: 756
├── Failed: 12
├── Skipped (frequency limit): 45
├── Skipped (opted out): 8
├── Pending: 1179
├── Est. Completion: Feb 23, 2026
└── Average Send Rate: 100/day
```

**Tenant Analytics:**
```
Marketing Dashboard
├── Last 30 Days
│   ├── Total SMS Sent: 2,450
│   ├── Active Campaigns: 3
│   ├── Opted-Out Numbers: 23
│   └── Delivery Rate: 98.5%
├── Top Campaigns
│   └── [Bar chart]
└── Daily Send Volume
    └── [Line chart]
```

---

#### ⚙️ Android Implementation (Java/Kotlin)

**WorkManager Setup (Correct Implementation):**

**🚨 CRITICAL: Do NOT use Thread.sleep() in Workers**

```java
// MarketingCoordinator.java - Main scheduler
public class MarketingCoordinator {
    
    public static void scheduleCampaignProcessing(Context context) {
        // Periodic check every 30 minutes
        PeriodicWorkRequest periodicWork = 
            new PeriodicWorkRequestBuilder<>(
                CampaignCheckWorker.class,
                30, TimeUnit.MINUTES
            )
            .setConstraints(new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .build())
            .build();
            
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(
                "marketing_coordinator",
                ExistingPeriodicWorkPolicy.KEEP,
                periodicWork
            );
    }
}

// CampaignCheckWorker.java - Check if work needed
public class CampaignCheckWorker extends Worker {
    
    @Override
    public Result doWork() {
        // 1. Quick checks
        if (!isMarketingEnabled()) return Result.success();
        if (isDailyLimitReached()) return Result.success();
        
        // 2. Get pending contacts (limit to batch size)
        List<CampaignContact> pending = getPendingContacts(10);
        if (pending.isEmpty()) return Result.success();
        
        // 3. Schedule individual SMS workers with delays
        for (int i = 0; i < pending.size(); i++) {
            CampaignContact contact = pending.get(i);
            
            // Calculate staggered delay (30-60 seconds apart)
            long delaySeconds = 30 + (long)(Math.random() * 30);
            long totalDelay = delaySeconds * i;
            
            // Create individual SMS worker
            Data inputData = new Data.Builder()
                .putString("phone_number", contact.phoneNumber)
                .putString("campaign_id", contact.campaignId)
                .putString("message", contact.message)
                .build();
                
            OneTimeWorkRequest smsWork = 
                new OneTimeWorkRequest.Builder(SendMarketingSmsWorker.class)
                    .setInputData(inputData)
                    .setInitialDelay(totalDelay, TimeUnit.SECONDS)
                    .addTag("marketing_sms")
                    .build();
                    
            WorkManager.getInstance(getApplicationContext())
                .enqueue(smsWork);
        }
        
        return Result.success();
    }
}

// SendMarketingSmsWorker.java - Send single SMS
public class SendMarketingSmsWorker extends Worker {
    
    @Override
    public Result doWork() {
        String phoneNumber = getInputData().getString("phone_number");
        String campaignId = getInputData().getString("campaign_id");
        String message = getInputData().getString("message");
        
        try {
            // 1. Final checks
            if (isDailyLimitReached()) {
                markContactSkipped(campaignId, phoneNumber, "Daily limit reached");
                return Result.success();
            }
            
            if (isOptedOut(phoneNumber)) {
                markContactSkipped(campaignId, phoneNumber, "Opted out");
                return Result.success();
            }
            
            if (exceedsFrequencyLimit(phoneNumber)) {
                markContactSkipped(campaignId, phoneNumber, "Frequency limit");
                return Result.success();
            }
            
            // 2. Send SMS
            SmsManager smsManager = SmsManager.getDefault();
            smsManager.sendTextMessage(
                phoneNumber,
                null,
                message,
                null,
                null
            );
            
            // 3. Log success
            logMarketingSMS(campaignId, phoneNumber, message, "sent");
            
            // 4. Update counters
            incrementDailyCount();
            recordFrequencyEvent(phoneNumber, campaignId);
            markContactSent(campaignId, phoneNumber);
            
            // 5. Sync to Supabase (async)
            syncLogsToSupabase();
            
            return Result.success();
            
        } catch (Exception e) {
            // Log failure
            logMarketingSMS(campaignId, phoneNumber, message, "failed");
            markContactFailed(campaignId, phoneNumber, e.getMessage());
            
            // Retry up to 3 times
            if (getRunAttemptCount() < 3) {
                return Result.retry();
            }
            return Result.failure();
        }
    }
}
```

**Why This Approach is Correct:**

| Aspect | ❌ Thread.sleep() | ✅ Delayed Workers |
|--------|-------------------|-------------------|
| **Battery** | Holds wake lock | System-managed |
| **Reliability** | ANR risk | WorkManager handles |
| **Cancellation** | Hard to stop | Easy to cancel |
| **Device reboot** | Loses state | Persisted |
| **Best Practice** | Violation | Recommended |

**Worker Chaining Benefits:**
```
✅ No blocking threads
✅ System handles scheduling
✅ Battery-optimized delays
✅ Survives app restart
✅ Easy to cancel/pause
✅ Built-in retry logic
```

---

#### 🚨 Safety & Compliance

**⚠️ Google Play Store Compliance:**
```
CRITICAL REQUIREMENTS:
├── ✅ Marketing Automation is DISABLED by default
├── ✅ Requires explicit user action to enable
├── ✅ NO silent or background SMS sending without user knowledge
├── ✅ Clear UI disclosure of message content before sending
├── ✅ Visible recipient list preview
├── ✅ Prominent opt-out mechanism
├── ✅ User can disable feature at any time (kill switch)
└── ✅ In-app explanation of feature purpose

Play Store Policy Compliance:
├── SMS & Call Log Permissions Policy (compliant)
├── User Privacy & Data Handling (compliant)
├── Deceptive Behavior Policy (compliant via transparency)
└── Background Service Restrictions (compliant via WorkManager)
```

**Mandatory Disclaimers:**
```
Before first use:
┌────────────────────────────────────────────┐
│  Marketing Automation Disclaimer           │
├────────────────────────────────────────────┤
│  You are responsible for:                  │
│  ✓ Obtaining recipient consent             │
│  ✓ Complying with local SMS laws           │
│  ✓ Respecting opt-out requests             │
│  ✓ Using appropriate message content       │
│                                             │
│  This app enforces technical limits but    │
│  cannot verify consent or legality.        │
│                                             │
│  [ ] I understand and agree                │
│                                             │
│  [Cancel]  [Accept & Continue]             │
└────────────────────────────────────────────┘
```

**Rate Limiting Visual Feedback:**
```
Status Bar:
├── ⏸️ Paused: Daily limit reached (100/100)
├── ✅ Active: Sending (75/100 today)
└── ⏳ Rate limiting: Next send in 45 seconds
```

---

#### 🧪 Testing Checklist

**Phase 1: Core Functionality**
- [ ] Create campaign with 10 contacts
- [ ] Send 5 SMS manually, verify logs
- [ ] Dynamic field rendering works
- [ ] Campaign status updates correctly

**Phase 2: Limits & Safety**
- [ ] Daily limit enforced (100/day)
- [ ] 30-day per-number limit enforced (2 SMS)
- [ ] Rate limiting works (30-60 sec delays)
- [ ] Opt-out blacklist prevents sending
- [ ] Daily counter resets at midnight

**Phase 3: Performance**
- [ ] WorkManager doesn't drain battery
- [ ] Large campaigns (5000+ contacts) handled
- [ ] App survives device reboot
- [ ] Sync to Supabase works offline
- [ ] No UI freezing during sends

**Phase 4: Multi-Tenant**
- [ ] Tenant A campaigns don't affect Tenant B
- [ ] Switching workspaces pauses old, starts new
- [ ] Daily limits per-tenant
- [ ] Frequency tracker per-tenant

**Phase 5: Web + Android**
- [ ] Create campaign on web, execute on Android
- [ ] Web analytics match Android reality
- [ ] Same user on both platforms works seamlessly

---

#### 📅 Implementation Timeline

**Week 1-2: Database & Backend**
- [ ] Create all tables with RLS policies
- [ ] Add indexes for performance
- [ ] Create Supabase functions for campaign CRUD
- [ ] Test tenant isolation

**Week 3-4: Android Core**
- [ ] AutoMarketingWorker implementation
- [ ] SMS sending with rate limiting
- [ ] Frequency tracker logic
- [ ] Daily reset scheduler
- [ ] Phone contact import

**Week 5-6: Flutter UI**
- [ ] Campaign list screen
- [ ] Campaign creation wizard
- [ ] Contact selection UI (CSV, phonebook, existing)
- [ ] Template editor with dynamic fields preview
- [ ] Opt-out management screen
- [ ] Analytics dashboard

**Week 7: Web Platform**
- [ ] Campaign management pages
- [ ] Same UI as mobile (responsive)
- [ ] Analytics charts
- [ ] Settings page

**Week 8: Testing & Polish**
- [ ] End-to-end testing
- [ ] Performance optimization
- [ ] Battery usage testing
- [ ] Documentation
- [ ] User onboarding flow

---

#### 🎯 Success Criteria

**Technical:**
- ✅ Daily limit never exceeded
- ✅ Per-number limit strictly enforced
- ✅ Battery usage < 5% per day
- ✅ 99%+ delivery rate (when network available)
- ✅ Logs sync correctly to Supabase
- ✅ Zero data leaks between tenants

**User Experience:**
- ✅ Campaign creation < 2 minutes
- ✅ Clear quota display (X/100 sent today)
- ✅ Instant kill switch works
- ✅ Web + Android seamlessly synced

**Compliance:**
- ✅ Opt-in by default (disabled)
- ✅ Clear consent disclaimers
- ✅ Opt-out mechanism works
- ✅ Anti-spam limits cannot be bypassed

---

#### 🔮 Future Enhancements (Phase 3)

**Advanced Features:**
- 📅 Schedule campaigns (start/stop times)
- 🔄 A/B testing (multiple message variants)
- 📊 Advanced analytics (open rates, if supported)
- 🤖 AI message optimization
- 📧 Multi-channel (SMS + Email)
- 🌍 Timezone-aware sending
- 📞 SMS reply listener for "STOP" auto-opt-out
- 🎯 Segment targeting (age, location, etc.)

**Enterprise Features:**
- 👥 Multi-device campaign execution (load balancing)
- 🔒 Approval workflows (manager must approve)
- 💰 Budget limits per campaign
- 📈 ROI tracking
- 🔗 CRM integration (Salesforce, HubSpot)

---

📌 **Status:** Specification complete, development starting Q1 2026

---

## 📋 Phase 3: Scale & Enterprise Features (PLANNED)

**Goal:** Enterprise-grade features for large organizations.

| Feature | Description |
|---------|-------------|
| Multi-User Roles | Admin, Manager, Staff with permissions |
| Multiple Devices | One org → multiple gateway phones |
| Delivery Reports | DLR where provider supports |
| Message Templates | Reusable message formats |
| Scheduled SMS | Send at specific time |
| Usage Analytics | Dashboard with charts |
| Billing & Quotas | Credit system, usage limits |
| High-Availability Routing | Failover between providers |

---

## 📱 Platform Support

| Platform | SMS Sending | Dashboard | API Relay | Status |
|----------|-------------|-----------|-----------|--------|
| **Android** | ✅ Full SIM | ✅ | ✅ | Primary |
| **iOS** | ❌ No SIM | ✅ View Only | ✅ | Planned |
| **Web** | ❌ | ✅ Admin | ✅ | Future |

📌 iOS **cannot send SMS programmatically via SIM** (Apple restriction).

---

## 📅 Timeline

| Phase | Milestone | Target | Status |
|-------|-----------|--------|--------|
| **1.0** | Local SMS Gateway | Q4 2024 | ✅ Complete |
| **2.1** | Organization & Auth | Q4 2024 | ✅ Complete |
| **2.2** | Backend & Sync | Q4 2024 | 🔄 In Progress |
| **2.3** | API-Triggered SMS | Q4 2025 | ✅ Complete |
| **2.4** | API Security | Q4 2025 | ✅ Complete |
| **2.6** | Settings Backup | Q4 2024 | ✅ Complete |
| **2.7** | Marketing Automation Engine | Q1 2026 | 🔄 In Progress |
| **2.5** | Sender ID | Q2 2026 | 🔲 Planned |
| **3.0** | Enterprise Features | Q3 2026 | 📋 Planned |

---

## 🎯 Feature Backlog

### 🔴 High Priority (Phase 2)

| Feature | Sub-Phase | Status |
|---------|-----------|--------|
| Organization Registration | 2.1 | ✅ Complete |
| Secure Authentication | 2.1 | ✅ Complete |
| Multi-Tenant Access | 2.1 | ✅ Complete |
| Settings Backup/Restore | 2.6 | ✅ Complete |
| Client-Product Access | 2.1 | ✅ Complete |
| REST API Endpoints | 2.3 | ✅ Complete |
| API Key Generation | 2.4 | ✅ Complete |
| Rate Limiting | 2.4 | ✅ Complete |
| **Auto Marketing Campaigns** | **2.7** | **🔄 In Progress** |
| **Marketing Analytics** | **2.7** | **🔄 In Progress** |
| **Phone Contact Import** | **2.7** | **🔄 In Progress** |
| Offline-First Storage | 2.2 | ✅ Complete |
| Message Sync to Cloud | 2.2 | 🔄 In Progress |

### 🟡 Medium Priority (Phase 2.5 / 3)

| Feature | Phase | Status |
|---------|-------|--------|
| Sender ID Support | 2.5 | 🔲 |
| Provider Integration | 2.5 | 🔲 |
| Message Templates | 3 | 🔲 |
| Scheduled SMS | 3 | 🔲 |
| Delivery Reports | 3 | 🔲 |
| Analytics Dashboard | 3 | 🔲 |

### 🟢 Low Priority (Future)

| Feature | Phase | Status |
|---------|-------|--------|
| iOS Dashboard | Future | 🔲 |
| Multi-User Roles | 3 | 🔲 |
| Multiple Devices | 3 | 🔲 |
| Two-Way SMS | Future | 🔲 |
| WhatsApp Integration | Future | 🔲 |
| Web Dashboard | Future | 🔲 |

---

## 🛡️ Security Roadmap

### ✅ Current (Phase 1 & 2.1)

- ✅ Supabase Auth (email/password)
- ✅ Row Level Security (RLS) on all tables
- ✅ Tenant Isolation (client_product_access verification)
- ✅ HTTPS/TLS encryption
- ✅ 8-step secure registration flow
- ✅ Session management
- ✅ Multi-tenant access control
- ✅ Settings encryption in SharedPreferences

### 🔲 Planned (Phase 2+)

| Feature | Phase | Priority |
|---------|-------|----------|
| API Key Encryption | 2.4 | High |
| Rate Limiting | 2.4 | High |
| Device Authorization | 2.4 | High |
| Audit Logging | 2.4 | High |
| IP Whitelisting | 3 | Medium |
| Two-Factor Auth (2FA) | 3 | Medium |
| OAuth2 Integration | 3 | Low |

---

## 💼 Business Model (Future)

### Free Tier
- ✅ Unlimited SMS via phone SIM
- ✅ Up to 500 contacts
- ✅ Basic local logs
- ❌ No API access

### Pro Tier
- ✅ Everything in Free
- ✅ API access
- ✅ Cloud sync & logs
- ✅ Unlimited contacts
- ✅ Priority support

### Enterprise Tier
- ✅ Everything in Pro
- ✅ Sender ID support
- ✅ Multiple devices
- ✅ Multi-user roles
- ✅ Custom integrations
- ✅ SLA guarantee

---

## 📣 Request a Feature

Have a feature request?
- Open an issue on [GitHub](https://github.com/LWENA27/sms_getway/issues)
- Label it as `enhancement`
- Describe the use case

---

## 📞 Contact

**Lwena TechWareAfrica**
- GitHub: [@LWENA27](https://github.com/LWENA27)
- Repository: [sms_getway](https://github.com/LWENA27/sms_getway)

---

## 📝 Recent Updates (February 2026)

### February 9, 2026
- ✅ Fixed sms_logs FK errors by ensuring user profile + membership before log push
- ✅ Marketing logging stabilized (campaign_contact_id handling, opt-out/frequency checks)
- ✅ Marketing campaign stats now load dynamically in UI
- ✅ Added marketing campaign link on Send SMS screen
- ✅ Settings screen cleanup and notification toggle completed

## 📝 Recent Updates (December 2025)

### December 28, 2025 - PHASE 2 COMPLETE! 🎉
- ✅ **MAJOR MILESTONE:** Phase 2 fully completed (2.1 - 2.4, 2.6)
- ✅ **Phase 2.3 Complete:** REST API with Edge Functions deployed
- ✅ **Phase 2.4 Complete:** API key management UI, rate limiting active
- ✅ API endpoints: POST /sms-api/send, /bulk, GET /status/:id, /docs
- ✅ Rate limiting: 100 requests/minute per API key
- ✅ Supabase Edge Function handling all API requests
- ✅ Complete API key CRUD in Settings → API Settings
- ✅ Registration fix: Added Step 8 (`client_product_access` record)
- ✅ Created RLS policies and cleanup scripts
- ✅ All code verified and tested
- ✅ Documentation updated across README and ROADMAP

**What's Working Now:**
- ✅ Complete 8-step registration with auto-login
- ✅ Multi-tenant workspace isolation
- ✅ Settings backup/restore across devices
- ✅ API SMS sending via external systems (CRM, ERP, etc.)
- ✅ API key management (create, activate, deactivate, delete)
- ✅ Rate limiting and security
- ✅ SMS queue processing (auto or manual)
- ✅ Native Android SMS sending
- ✅ Contact and group management

**Next Up: Phase 2.5 - Provider Integration (Sender ID)**
- ✅ **CRITICAL FIX:** Added Step 8 to registration (`client_product_access` record)
- ✅ **Root Cause Fixed:** Login requires product access record - registration now creates it
- ✅ Created RLS policies: `fix_clients_rls_policy.sql`, `fix_product_access_rls_policy.sql`
- ✅ Created cleanup script: `cleanup_incomplete_users.sql` (remove users with missing data)
- ✅ All code verified and tested
- ✅ Git committed and pushed (4 commits total)
- ✅ Documentation updated: README.md with 8-step flow and warnings

### December 24, 2025
- ✅ Completed Phase 2.6: Settings Backup & Cross-Device Sync
- ✅ Implemented user and tenant settings backup/restore
- ✅ Added audit trail for all backup/restore operations
- ✅ Created RLS policies for settings tables
- ✅ Added UI controls in Settings screen

### November-December 2025
- ✅ Completed Phase 2.1: Organization & Authentication
- ✅ Implemented complete 8-step registration flow
- ✅ Added multi-tenant architecture with workspace isolation
- ✅ Implemented tenant selector for users with multiple organizations
- ✅ Added auto-select for single-tenant users
- ✅ Created comprehensive RLS policies for data isolation

---

## 🎯 IMMEDIATE NEXT STEPS

### ✅ PHASE 2 CORE COMPLETE! All core tasks done.

**Completed December 28, 2025:**
1. ✅ Database Setup - RLS policies applied
2. ✅ Registration Flow - 8-step flow tested
3. ✅ Android Testing - SMS sending verified
4. ✅ Settings Backup - Cross-device sync working
5. ✅ API Implementation - Edge Functions deployed
6. ✅ API Security - Rate limiting active
7. ✅ API Key Management - Full CRUD in Settings

**Current Focus (Q1 2026):**
1. � Stabilize RLS policies for user profile + tenant membership
2. � Verify SMS log push reliability (online/offline)
3. 🔄 Marketing analytics dashboard (campaign stats)
4. 🔄 Phone contact import + CSV import
5. 🔄 Web campaign sync and cross-device testing

---

## 🚀 WHAT'S NEXT: Phase 2.7 - Marketing Automation Engine

### Phase 2.7 - Marketing Automation Engine (Current Development Phase)
**Status:** 🔄 IN PROGRESS - Q1 2026

**Goal:** Enable controlled, ethical SMS marketing campaigns via Android SIM with strict anti-spam safeguards.

**Key Features:**
1. Campaign management (create, edit, activate multiple campaigns)
2. Multi-source contact import (CSV, phonebook, existing contacts)
3. Message templates with dynamic fields ({first_name}, {last_name}, {phone})
4. Strict frequency limits (100 SMS/day per tenant, 2 SMS/30 days per number)
5. Rate limiting (2 SMS/minute with randomized delays)
6. Manual opt-out blacklist
7. Web + Android sync (create on web, execute on Android)
8. Campaign analytics and reporting
9. WorkManager background execution (battery-optimized)

**Implementation Timeline:**
- **Week 1-2:** Database schema + RLS policies
- **Week 3-4:** Android WorkManager + SMS sending logic
- **Week 5-6:** Flutter UI (campaigns, analytics, opt-outs)
- **Week 7:** Web platform integration
- **Week 8:** Testing, optimization, documentation

**Files to Create:**
- `database/marketing_schema.sql` (6 new tables)
- `android/app/src/main/java/.../workers/MarketingCoordinator.java`
- `android/app/src/main/java/.../workers/CampaignCheckWorker.java`
- `android/app/src/main/java/.../workers/SendMarketingSmsWorker.java`
- `lib/screens/marketing/campaign_list_screen.dart`
- `lib/screens/marketing/campaign_create_screen.dart`
- `lib/screens/marketing/campaign_analytics_screen.dart`
- `lib/screens/marketing/optout_management_screen.dart`
- `lib/services/marketing_service.dart`
- `lib/models/marketing_campaign.dart`
- `lib/models/campaign_contact.dart`

**Estimated Completion:** End of Q1 2026

---

### Phase 2.5 - Sender ID Support (Next After Marketing)
**Status:** 🔲 READY TO START - Q2 2026

**Goal:** Integrate SMS providers for branded Sender ID (e.g., "MYSCHOOL" instead of phone number)

**Priority Providers:**
1. **Africa's Talking** - Most popular in Africa
2. **Beem Africa** - East Africa specialist
3. **Twilio** - International fallback
4. **Custom Webhook** - Bring your own provider

**Implementation Tasks:**
1. Create provider configuration UI in Settings
2. Add provider credentials management (API keys, sender IDs)
3. Implement provider-specific API clients
4. Add channel selection: SIM vs Provider
5. Update SMS sending logic to route via provider
6. Add delivery receipt (DLR) handling
7. Cost tracking per provider
8. Fallback logic (provider fails → use SIM)

**Files to Create:**
- `lib/services/sms_providers/africas_talking_service.dart`
- `lib/services/sms_providers/beem_service.dart`
- `lib/services/sms_providers/twilio_service.dart`
- `lib/services/sms_providers/base_provider.dart`
- `lib/screens/provider_settings_screen.dart`
- `database/provider_integration.sql`

**Estimated Time:** 2-3 weeks

---

## 📋 Phase 3 - Enterprise Features (Long Term)

**Planning Phase - Q2 2026**

**Potential Features:**
- Offline-first storage (local SQLite + sync)
- Advanced scheduled SMS (time windows, timezone-aware)
- A/B testing for marketing campaigns
- AI message optimization
- SMS reply listener (auto-opt-out on "STOP")
- Multi-channel (SMS + Email + WhatsApp)
- Delivery reports and advanced analytics
- Multi-user roles with approval workflows
- Multiple devices per organization (load balancing)
- Usage analytics dashboard with charts
- Billing and quotas system
- Two-way SMS (receive and process replies)
- CRM integration (Salesforce, HubSpot)
- ROI tracking for campaigns

**Timeline:** Q3 2026

---

*Last Updated: February 9, 2026*
