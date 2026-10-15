# SMS Gateway API Documentation

## Overview

The SMS Gateway API allows external systems to send SMS messages through your SMS Gateway Pro application. Messages are queued in Supabase and processed by the mobile app.

> [!TIP]
> **Interactive OpenAPI 3.0 (Swagger) Specification Available**:
> You can import or view the complete machine-readable specification in [openapi.yaml](openapi.yaml) to generate client SDKs or test requests interactively.
> 
> **Maintainer Portfolio**: [lwena.techwareafrica.tech](https://lwena.techwareafrica.tech) | **GitHub**: [@LwenaAdam](https://github.com/LwenaAdam)

## Base URL

```
https://[YOUR_SUPABASE_PROJECT_REF].supabase.co/functions/v1/sms-api
```

## Authentication

All API requests require an API key in the header:

```
x-api-key: sgw_your_api_key_here
```

To create an API key:
1. Open SMS Gateway Pro app
2. Go to Settings → API Integration
3. Click "Create New API Key"
4. Copy and securely store the key (it's only shown once!)

## Endpoints

### Send Single SMS

**POST** `/sms-api/send`

Send a single SMS message.

**Request Body:**
```json
{
  "phone_number": "+255683274343",
  "message": "Hello from API!",
  "external_id": "order-123",
  "priority": 0,
  "scheduled_at": "2025-12-25T10:00:00Z",
  "metadata": {
    "order_id": 12345,
    "customer_name": "John Doe"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| phone_number | string | Yes | Recipient phone number (E.164 format recommended) |
| message | string | Yes | SMS message content |
| external_id | string | No | Your reference ID for tracking |
| priority | integer | No | Higher values = higher priority (default: 0) |
| scheduled_at | ISO 8601 | No | Schedule SMS for future delivery |
| metadata | object | No | Additional data to store with the request |

**Response:**
```json
{
  "success": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "pending",
  "message": "SMS request queued successfully"
}
```

---

### Send Bulk SMS

**POST** `/sms-api/bulk`

Send the same message to multiple recipients.

**Request Body:**
```json
{
  "phone_numbers": [
    "+25568327434343",
    "+0987654321",
    "+1122334455"
  ],
  "message": "Hello from API!",
  "external_id": "campaign-456",
  "priority": 0
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| phone_numbers | array | Yes | List of recipient phone numbers (max 1000) |
| message | string | Yes | SMS message content |
| external_id | string | No | Your reference ID for tracking |
| priority | integer | No | Higher values = higher priority (default: 0) |
| scheduled_at | ISO 8601 | No | Schedule SMS for future delivery |
| metadata | object | No | Additional data to store with the request |

**Response:**
```json
{
  "success": true,
  "request_ids": [
    "550e8400-e29b-41d4-a716-446655440000",
    "550e8400-e29b-41d4-a716-446655440001",
    "550e8400-e29b-41d4-a716-446655440002"
  ],
  "count": 3,
  "status": "pending",
  "message": "3 SMS requests queued successfully"
}
```

---

### Check Status

**GET** `/sms-api/status/:request_id`

Check the status of a specific SMS request.

**Response:**
```json
{
  "success": true,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "phone_number": "+25568327434343",
  "status": "sent",
  "external_id": "order-123",
  "created_at": "2025-12-23T10:00:00Z",
  "processed_at": "2025-12-23T10:00:05Z",
  "error_message": null
}
```

**Status Values:**
| Status | Description |
|--------|-------------|
| pending | Waiting to be processed |
| processing | Currently being sent |
| sent | Successfully sent |
| failed | Failed to send (check error_message) |
| cancelled | Cancelled by user |

---

### API Documentation

**GET** `/sms-api/docs`

Returns API documentation in JSON format.

---

## Rate Limits

- **100 requests per minute** per API key
- **1000 recipients** maximum per bulk request

## Error Responses

All errors return a JSON response with `success: false`:

```json
{
  "success": false,
  "error": "Error message here"
}
```

**Common Errors:**
| HTTP Code | Error | Description |
|-----------|-------|-------------|
| 401 | Missing API key | Include `x-api-key` header |
| 401 | Invalid API key | The API key doesn't exist |
| 401 | API key is inactive | The API key has been deactivated |
| 400 | Missing required fields | Check request body |
| 400 | Invalid phone number | Phone number must be at least 10 digits |
| 400 | Message cannot be empty | Provide a message |
| 429 | Rate limit exceeded | Wait and retry |
| 500 | Internal server error | Contact support |

## Code Examples

### cURL

```bash
# Send single SMS
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/sms-api/send" \
  -H "Content-Type: application/json" \
  -H "x-api-key: sgw_your_api_key_here" \
  -d '{
    "phone_number": "+255683274343",
    "message": "Hello from API!"
  }'

# Send bulk SMS
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/sms-api/bulk" \
  -H "Content-Type: application/json" \
  -H "x-api-key: sgw_your_api_key_here" \
  -d '{
    "phone_numbers": ["+255683274343", "+0987654321"],
    "message": "Hello everyone!"
  }'

# Check status
curl -X GET "https://YOUR_PROJECT.supabase.co/functions/v1/sms-api/status/REQUEST_ID" \
  -H "x-api-key: sgw_your_api_key_here"
```

### JavaScript (Node.js)

```javascript
const axios = require('axios');

const API_URL = 'https://YOUR_PROJECT.supabase.co/functions/v1/sms-api';
const API_KEY = 'sgw_your_api_key_here';

// Send single SMS
async function sendSms(phoneNumber, message) {
  const response = await axios.post(`${API_URL}/send`, {
    phone_number: phoneNumber,
    message: message
  }, {
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': API_KEY
    }
  });
  return response.data;
}

// Send bulk SMS
async function sendBulkSms(phoneNumbers, message) {
  const response = await axios.post(`${API_URL}/bulk`, {
    phone_numbers: phoneNumbers,
    message: message
  }, {
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': API_KEY
    }
  });
  return response.data;
}
```

### Python

```python
import requests

API_URL = 'https://YOUR_PROJECT.supabase.co/functions/v1/sms-api'
API_KEY = 'sgw_your_api_key_here'

headers = {
    'Content-Type': 'application/json',
    'x-api-key': API_KEY
}

# Send single SMS
def send_sms(phone_number, message):
    response = requests.post(f'{API_URL}/send', json={
        'phone_number': phone_number,
        'message': message
    }, headers=headers)
    return response.json()

# Send bulk SMS
def send_bulk_sms(phone_numbers, message):
    response = requests.post(f'{API_URL}/bulk', json={
        'phone_numbers': phone_numbers,
        'message': message
    }, headers=headers)
    return response.json()
```

### PHP

```php
<?php
$apiUrl = 'https://YOUR_PROJECT.supabase.co/functions/v1/sms-api';
$apiKey = 'sgw_your_api_key_here';

function sendSms($phoneNumber, $message) {
    global $apiUrl, $apiKey;
    
    $ch = curl_init("$apiUrl/send");
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode([
        'phone_number' => $phoneNumber,
        'message' => $message
    ]));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
        "x-api-key: $apiKey"
    ]);
    
    $response = curl_exec($ch);
    curl_close($ch);
    
    return json_decode($response, true);
}
?>
```

## Webhook Callbacks (Coming Soon)

Future versions will support webhook callbacks for delivery notifications.

## Support

For support, please contact your SMS Gateway administrator.

---

## 🏗️ Implementation Architecture

### Service Layer Overview

**NativeSmsService** → **SmsService** → **ApiSmsQueueService**

Three-layered architecture for SMS delivery:

1. **NativeSmsService**: Platform channel to Android SMS
2. **SmsService**: Routes based on user's SMS channel preference
3. **ApiSmsQueueService**: Background processor polling database

### Channel Selection

Users can choose SMS delivery method in Settings:

- **"This Phone"** (Default) → Native Android SMS via device SIM
- **"QuickSMS API"** → HTTP API to QuickSMS provider

The queue respects this preference:
```
Check user setting → Route to correct service → Update status
```

### Settings Backup Integration

User's SMS channel preference is **backed up to Supabase** via Settings Backup feature:

```
Device A:
  Settings → SMS Channel = "This Phone" → Backup to Supabase
  
Device B:
  Login → Restore from Supabase → SMS Channel = "This Phone"
  → Queue automatically uses restored preference
```

### Database Schema

**sms_requests table:**
- status: pending → processing → sent/failed
- phone_number, message, priority, scheduled_at
- metadata for external references

**sms_logs table:**
- Audit trail of all SMS attempts
- Tracks delivery method used (native/API)
- Stores success/failure reason

### Complete Flow

```
External API
     ↓
POST /sms-api/send
     ↓
Validate API key
     ↓
Insert into sms_requests (status=pending)
     ↓
Flutter App (ApiSmsQueueService)
     ↓
Poll every 30 seconds
     ↓
Fetch pending requests
     ↓
Get user's SMS channel from SharedPreferences
(or restored from Settings Backup)
     ↓
    ┌────────────────┐
    ↓                ↓
"This Phone"    "QuickSMS API"
    ↓                ↓
NativeSms       HTTP POST
    ↓                ↓
  SIM           QuickSMS
    ↓                ↓
Update sms_requests (status=sent/failed)
     ↓
Log to sms_logs
     ↓
SMS Delivered!
```

---
