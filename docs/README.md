# 📱 SMS Gateway Pro

**Professional Multi-Tenant SMS Management System**

A production-ready, enterprise-grade SMS gateway application for bulk messaging with complete data isolation. Built with Flutter and Supabase, enabling organizations to send SMS through Android devices or REST API with multi-tenant architecture.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.24.5-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL_15-3ECF8E?logo=supabase)](https://supabase.com)
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen)](https://github.com/LwenaAdam/sms_getway/releases)
[![OpenAPI](https://img.shields.io/badge/OpenAPI-3.0.3-brightgreen?logo=openapi-initiative)](openapi.yaml)

---

## 🚀 Quick Links

| Documentation | Purpose |
|---------------|---------|
| **[📡 API Documentation](API_DOCUMENTATION.md)** | REST API integration guide |
| **[📑 OpenAPI Spec](openapi.yaml)** | Interactive OpenAPI 3.0 (Swagger) specification |
| **[🗄️ Database & Architecture](SUPABASE.md)** | Multi-tenant database schema and architecture |
| **[🚀 Features & Roadmap](ROADMAP.md)** | Current features and future plans |
| **[📡 API Documentation](API_DOCUMENTATION.md)** | REST API integration guide |
| **[💻 Developer Guide](DEVELOPER.md)** | Technical documentation and patterns |
| **[👨‍💻 Developer Onboarding](DEVELOPER_ONBOARDING.md)** | Setup guide for new developers |
| **[🌐 Netlify Deployment](NETLIFY_DEPLOYMENT.md)** | Deploy web admin to smsgetway.techwareafrica.tech |
| **[📦 Release Checklist](RELEASE_CHECKLIST.md)** | Mobile app release process |
| **[🗄️ Supabase Schema](SUPABASE.md)** | SMS Gateway database schema |

---

## ✨ Features

### 📞 SMS Management
- **Native Android SMS** - Send SMS directly via device SIM card
- **Bulk Messaging** - Send to multiple contacts with one click
- **SMS Logs** - Track delivery status and history
- **Automatic Sending** - No manual intervention required

### 👥 Contact Management
- **Contact List** - Add, edit, delete contacts
- **CSV Import** - Bulk import contacts from CSV files
- **Phone Validation** - Automatic phone number formatting
- **Search & Filter** - Quick contact lookup

### 📁 Group Management
- **Create Groups** - Organize contacts into groups
- **Member Management** - Add/remove group members
- **Bulk Send to Groups** - Message all group members instantly

### 🏢 Multi-Tenant Architecture
- **Workspace Isolation** - Each organization's data is completely separate
- **Multiple Workspaces** - Users can belong to multiple organizations
- **Auto-Select** - Single workspace users skip selection screen
- **Workspace Switcher** - Easy switching between organizations

### 🔐 Security
- **Supabase Authentication** - Secure email/password login
- **Row Level Security (RLS)** - Database-level access control
- **Tenant Isolation** - Data protected at database level
- **API Key Authentication** - ✅ Secure external access with rate limiting
- **Rate Limiting** - ✅ 100 requests per minute per API key

### 🔄 Settings Backup
- **Cross-Device Sync** - ✅ Backup settings to cloud, restore on another device
- **User Settings** - ✅ Sync SMS channel, theme, language, notifications
- **Tenant Settings** - ✅ Sync workspace quotas and feature flags
- **Audit Trail** - ✅ Complete history of all backup/restore operations

### 🚀 API Integration (NEW!)
- **REST API Endpoints** - ✅ POST /sms-api/send, /bulk, GET /status
- **API Key Management** - ✅ Create, activate, deactivate, delete keys
- **External System Integration** - ✅ Send SMS from CRM, ERP, school systems
- **Queue Processing** - ✅ Automatic background SMS processing
- **Rate Limiting** - ✅ Prevent abuse with 100 req/min limit
- **Edge Functions** - ✅ Serverless API on Supabase

### 🎨 User Experience
- **Dark Mode** - Full dark theme support
- **Modern UI** - Clean, intuitive interface
- **Responsive Design** - Works on all screen sizes
- **Real-time Feedback** - Success/failure notifications

---

## 🧭 Platform Rules

**Web and other non-Android platforms MUST:**
- Create/edit campaigns
- View analytics
- Manage contacts
- Manage settings

**Web platform MUST NOT:**
- Send SMS
- Trigger WorkManager/background workers
- Bypass Android sending limits

---

## � Download & Install

### ⚡ Quick Start (5 minutes)

Get SMS Gateway Pro running **super fast**:

```bash
git clone https://github.com/LWENA27/sms_getway.git
cd sms_getway
flutter pub get
flutter run
```

**That's it!** The app will build and launch on your Android device.

👉 **[See DEVELOPER_ONBOARDING.md for detailed setup guide](DEVELOPER_ONBOARDING.md)**

### 📚 Full Installation & Development Guide

For detailed setup instructions, database architecture, and development workflow:

👉 **[See DEVELOPER_ONBOARDING.md for complete setup guide](DEVELOPER_ONBOARDING.md)**
👉 **[See DEVELOPER.md for technical documentation](DEVELOPER.md)**
👉 **[See SUPABASE.md for database schema and multi-tenant architecture](SUPABASE.md)**

### 🔗 Download Options

| Method | Link |
|--------|------|
| **Clone with Git** | `git clone https://github.com/LWENA27/sms_getway.git` |
| **Download ZIP** | [GitHub Releases](https://github.com/LWENA27/sms_getway/releases) |
| **GitHub Repository** | https://github.com/LWENA27/sms_getway |

### Prerequisites
- **Flutter SDK 3.0+** - [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Git** - [Install Git](https://git-scm.com/download)
- **Android Device** - Android 5.0 (API 21) or higher
- **USB Cable** - To connect your phone

### Installation Steps

```bash
# 1. Clone the repository
git clone https://github.com/LWENA27/sms_getway.git
cd sms_getway

# 2. Install dependencies
flutter pub get

# 3. Connect your Android phone with USB debugging enabled

# 4. Run the app
flutter run

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Configuration

1. **Supabase Setup** (already configured)
   - Project URL: `https://kzjgdeqfmxkmpmadtbpb.supabase.co`
   - See [SUPABASE.md](SUPABASE.md) for database details

2. **Android Permissions** (already configured in AndroidManifest.xml)
   - `SEND_SMS` - Send SMS messages
   - `READ_SMS` - Track SMS status
   - `READ_PHONE_STATE` - Check device status

3. **Run on Device**
   ```bash
   # List connected devices
   flutter devices
   
   # Run on specific device
   flutter run -d <device_id>
   ```

---

## 🔐 User Registration & Authentication

### For Developers: Adding Registration Form

This section provides complete instructions for developers implementing user registration on a website to enable users to sign up and access SMS Gateway Pro service.

#### **Overview**

SMS Gateway Pro uses **Supabase Authentication** with a multi-tenant architecture. Users can register via a web form, and their account will be automatically linked to a tenant workspace.

#### **Registration Flow (8 Required Steps)**

```
┌─────────────────────────────────────────────────────────┐
│           COMPLETE REGISTRATION FLOW                     │
└─────────────────────────────────────────────────────────┘

1. Create auth.users account (Supabase Auth)
                        ↓
2. Create public.clients record (top-level organization)
                        ↓
3. Create sms_gateway.tenants record (product tenant)
                        ↓
4. Create sms_gateway.users record (user profile)
                        ↓
5. Create sms_gateway.tenant_members record (membership)
                        ↓
6. Create sms_gateway.user_settings record (preferences)
                        ↓
7. Create sms_gateway.tenant_settings record (org config)
                        ↓
8. Create public.client_product_access record (CRITICAL!)
   ⚠️  Required for login - without this, user cannot access app
                        ↓
✅ User can now login to app
```

**⚠️ IMPORTANT:** Step 8 (`client_product_access`) is critical! Without it, users will see "You do not have access to SMS Gateway" error when trying to login, even though registration succeeded. The login system checks this table to verify product access.

**Required RLS Policies:**
- `public.clients` - INSERT policy for authenticated users
- `public.client_product_access` - INSERT and SELECT policies
- See `fix_clients_rls_policy.sql` and `fix_product_access_rls_policy.sql`

#### **Step 1: Set Up Supabase Client**

First, install Supabase JavaScript client:

```bash
npm install @supabase/supabase-js
# or
yarn add @supabase/supabase-js
```

Create Supabase client configuration:

```javascript
// supabaseClient.js
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://kzjgdeqfmxkmpmadtbpb.supabase.co'
const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY' // Get from Supabase Dashboard

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

**⚠️ Important:** Get your `SUPABASE_ANON_KEY` from:
- Supabase Dashboard → Project Settings → API → `anon` `public` key

#### **Step 2: Create Registration Form (HTML)**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SMS Gateway Pro - Register</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
        }
        .register-container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 450px;
            width: 100%;
        }
        h2 {
            color: #333;
            margin-bottom: 10px;
            text-align: center;
        }
        .subtitle {
            color: #666;
            text-align: center;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            color: #333;
            font-weight: 500;
        }
        input {
            width: 100%;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 14px;
            transition: border-color 0.3s;
            box-sizing: border-box;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        .error-message {
            background: #fee;
            color: #c33;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 20px;
            display: none;
        }
        .success-message {
            background: #efe;
            color: #3c3;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 20px;
            display: none;
        }
        .login-link {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 14px;
        }
        .login-link a {
            color: #667eea;
            text-decoration: none;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="register-container">
        <h2>📱 SMS Gateway Pro</h2>
        <p class="subtitle">Create your account to start sending bulk SMS</p>
        
        <div id="errorMessage" class="error-message"></div>
        <div id="successMessage" class="success-message"></div>
        
        <form id="registerForm">
            <div class="form-group">
                <label for="name">Full Name *</label>
                <input type="text" id="name" name="name" required 
                       placeholder="Enter your full name">
            </div>
            
            <div class="form-group">
                <label for="email">Email Address *</label>
                <input type="email" id="email" name="email" required 
                       placeholder="your.email@example.com">
            </div>
            
            <div class="form-group">
                <label for="phone">Phone Number *</label>
                <input type="tel" id="phone" name="phone" required 
                       placeholder="+255683274343">
            </div>
            
            <div class="form-group">
                <label for="companyName">Company/Organization Name *</label>
                <input type="text" id="companyName" name="companyName" required 
                       placeholder="Your company name">
            </div>
            
            <div class="form-group">
                <label for="password">Password *</label>
                <input type="password" id="password" name="password" required 
                       placeholder="Minimum 6 characters">
            </div>
            
            <div class="form-group">
                <label for="confirmPassword">Confirm Password *</label>
                <input type="password" id="confirmPassword" name="confirmPassword" required 
                       placeholder="Re-enter your password">
            </div>
            
            <button type="submit" id="submitBtn">Create Account</button>
        </form>
        
        <div class="login-link">
            Already have an account? <a href="login.html">Sign in</a>
        </div>
    </div>

    <script type="module" src="register.js"></script>
</body>
</html>
```

#### **Step 3: Implement Registration Logic (JavaScript)**

```javascript
// register.js
import { supabase } from './supabaseClient.js'

// Get form elements
const form = document.getElementById('registerForm')
const submitBtn = document.getElementById('submitBtn')
const errorMessage = document.getElementById('errorMessage')
const successMessage = document.getElementById('successMessage')

// Helper functions
function showError(message) {
    errorMessage.textContent = message
    errorMessage.style.display = 'block'
    successMessage.style.display = 'none'
}

function showSuccess(message) {
    successMessage.textContent = message
    successMessage.style.display = 'block'
    errorMessage.style.display = 'none'
}

function hideMessages() {
    errorMessage.style.display = 'none'
    successMessage.style.display = 'none'
}

// Validate phone number format
function validatePhone(phone) {
    const phoneRegex = /^\+?[1-9]\d{1,14}$/
    return phoneRegex.test(phone.replace(/[\s-]/g, ''))
}

// Generate tenant slug from company name
function generateSlug(companyName) {
    return companyName
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
}

// Main registration function
async function registerUser(userData) {
    try {
        // Step 1: Create auth user
        const { data: authData, error: authError } = await supabase.auth.signUp({
            email: userData.email,
            password: userData.password,
            options: {
                data: {
                    full_name: userData.name,
                    phone: userData.phone
                }
            }
        })

        if (authError) throw authError
        if (!authData.user) throw new Error('User creation failed')

        const userId = authData.user.id

        // Step 2: Create tenant (organization/workspace)
        const tenantSlug = generateSlug(userData.companyName)
        const { data: tenantData, error: tenantError } = await supabase
            .from('sms_gateway_tenants')
            .insert([
                {
                    name: userData.companyName,
                    slug: tenantSlug,
                    status: 'active'
                }
            ])
            .select()
            .single()

        if (tenantError) throw tenantError
        const tenantId = tenantData.id

        // Step 3: Link user to tenant as owner
        const { error: memberError } = await supabase
            .from('tenant_members')
            .insert([
                {
                    tenant_id: tenantId,
                    user_id: userId,
                    role: 'owner'
                }
            ])

        if (memberError) throw memberError

        // Step 4: Create user profile in SMS Gateway schema
        const { error: profileError } = await supabase
            .from('users')
            .insert([
                {
                    id: userId,
                    email: userData.email,
                    name: userData.name,
                    phone_number: userData.phone,
                    tenant_id: tenantId,
                    role: 'admin'
                }
            ])

        if (profileError) throw profileError

        // Step 5: Initialize user settings
        const { error: settingsError } = await supabase
            .from('user_settings')
            .insert([
                {
                    user_id: userId,
                    sms_channel: 'native',
                    theme: 'light',
                    language: 'en',
                    notifications_enabled: true
                }
            ])

        if (settingsError) console.warn('Settings creation failed:', settingsError)

        return { success: true, userId, tenantId }

    } catch (error) {
        console.error('Registration error:', error)
        throw error
    }
}

// Form submission handler
form.addEventListener('submit', async (e) => {
    e.preventDefault()
    hideMessages()

    // Get form values
    const name = document.getElementById('name').value.trim()
    const email = document.getElementById('email').value.trim()
    const phone = document.getElementById('phone').value.trim()
    const companyName = document.getElementById('companyName').value.trim()
    const password = document.getElementById('password').value
    const confirmPassword = document.getElementById('confirmPassword').value

    // Validation
    if (!name || !email || !phone || !companyName || !password) {
        showError('Please fill in all required fields')
        return
    }

    if (password.length < 6) {
        showError('Password must be at least 6 characters long')
        return
    }

    if (password !== confirmPassword) {
        showError('Passwords do not match')
        return
    }

    if (!validatePhone(phone)) {
        showError('Please enter a valid phone number with country code (e.g., +255683274343)')
        return
    }

    // Disable submit button
    submitBtn.disabled = true
    submitBtn.textContent = 'Creating Account...'

    try {
        // Register user
        await registerUser({
            name,
            email,
            phone,
            companyName,
            password
        })

        // Show success message
        showSuccess('✅ Account created successfully! Please check your email to verify your account.')
        
        // Reset form
        form.reset()

        // Redirect to login after 3 seconds
        setTimeout(() => {
            window.location.href = 'login.html'
        }, 3000)

    } catch (error) {
        // Show error message
        let errorMsg = 'Registration failed. Please try again.'
        
        if (error.message.includes('duplicate key')) {
            errorMsg = 'An account with this email already exists.'
        } else if (error.message.includes('email')) {
            errorMsg = 'Invalid email address.'
        } else if (error.message) {
            errorMsg = error.message
        }
        
        showError(errorMsg)
        
    } finally {
        // Re-enable submit button
        submitBtn.disabled = false
        submitBtn.textContent = 'Create Account'
    }
})
```

#### **Step 4: Configure Supabase Database Policies**

Ensure Row Level Security (RLS) policies allow user creation:

```sql
-- Allow users to insert their own tenant (during registration)
CREATE POLICY "Users can create their own tenant"
ON sms_gateway_tenants
FOR INSERT
WITH CHECK (true);

-- Allow users to join tenants as members
CREATE POLICY "Users can insert tenant_members during registration"
ON tenant_members
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Allow users to create their own profile
CREATE POLICY "Users can create their own profile"
ON sms_gateway.users
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Allow users to create their own settings
CREATE POLICY "Users can create their own settings"
ON user_settings
FOR INSERT
WITH CHECK (auth.uid() = user_id);
```

#### **Step 5: Test Registration**

1. **Open registration page** in browser
2. **Fill in the form** with valid data:
   - Name: John Doe
   - Email: john@example.com
   - Phone: +255683274343
   - Company: My Business Inc
   - Password: securepassword123
3. **Click "Create Account"**
4. **Check email** for verification link (if email confirmation enabled)
5. **Login to mobile app** with registered credentials

#### **Step 6: Add Login Form**

Create `login.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SMS Gateway Pro - Login</title>
    <style>
        /* Use similar styles as registration form */
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
        }
        .login-container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            max-width: 400px;
            width: 100%;
        }
        h2 {
            color: #333;
            margin-bottom: 10px;
            text-align: center;
        }
        .subtitle {
            color: #666;
            text-align: center;
            margin-bottom: 30px;
            font-size: 14px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            color: #333;
            font-weight: 500;
        }
        input {
            width: 100%;
            padding: 12px;
            border: 1px solid #ddd;
            border-radius: 5px;
            font-size: 14px;
            transition: border-color 0.3s;
            box-sizing: border-box;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            width: 100%;
            padding: 14px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        button:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        .error-message {
            background: #fee;
            color: #c33;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 20px;
            display: none;
        }
        .register-link {
            text-align: center;
            margin-top: 20px;
            color: #666;
            font-size: 14px;
        }
        .register-link a {
            color: #667eea;
            text-decoration: none;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <h2>📱 SMS Gateway Pro</h2>
        <p class="subtitle">Sign in to your account</p>
        
        <div id="errorMessage" class="error-message"></div>
        
        <form id="loginForm">
            <div class="form-group">
                <label for="email">Email Address</label>
                <input type="email" id="email" name="email" required 
                       placeholder="your.email@example.com">
            </div>
            
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" name="password" required 
                       placeholder="Enter your password">
            </div>
            
            <button type="submit" id="submitBtn">Sign In</button>
        </form>
        
        <div class="register-link">
            Don't have an account? <a href="register.html">Create one</a>
        </div>
    </div>

    <script type="module" src="login.js"></script>
</body>
</html>
```

Create `login.js`:

```javascript
// login.js
import { supabase } from './supabaseClient.js'

const form = document.getElementById('loginForm')
const submitBtn = document.getElementById('submitBtn')
const errorMessage = document.getElementById('errorMessage')

function showError(message) {
    errorMessage.textContent = message
    errorMessage.style.display = 'block'
}

function hideError() {
    errorMessage.style.display = 'none'
}

form.addEventListener('submit', async (e) => {
    e.preventDefault()
    hideError()

    const email = document.getElementById('email').value.trim()
    const password = document.getElementById('password').value

    submitBtn.disabled = true
    submitBtn.textContent = 'Signing In...'

    try {
        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password
        })

        if (error) throw error

        // Redirect to dashboard or app
        window.location.href = 'dashboard.html'

    } catch (error) {
        showError(error.message || 'Login failed. Please check your credentials.')
    } finally {
        submitBtn.disabled = false
        submitBtn.textContent = 'Sign In'
    }
})
```

#### **Step 7: Mobile App Integration**

Users registered via web can login to the Flutter mobile app immediately:

1. **Open SMS Gateway Pro app** on Android
2. **Enter registered email and password**
3. **Tap "Login"**
4. **App automatically loads user's tenant workspace**
5. **User can start adding contacts and sending SMS**

#### **Security Best Practices**

✅ **Email Verification**: Enable in Supabase Dashboard → Authentication → Providers → Email
✅ **Password Requirements**: Enforce strong passwords (min 8 chars, uppercase, numbers)
✅ **Rate Limiting**: Enable in Supabase to prevent abuse
✅ **HTTPS Only**: Always use HTTPS in production
✅ **Anon Key Protection**: Never expose service role key on client side
✅ **RLS Policies**: Always enable Row Level Security on all tables
✅ **Input Validation**: Validate all user inputs on both client and server

#### **Troubleshooting**

**❌ "User already registered" error**
- Check if email exists in `auth.users` table
- Use "Forgot Password" feature to reset

**❌ "Invalid email" error**
- Verify email format is correct
- Check Supabase email provider is configured

**❌ "Tenant creation failed" error**
- Check RLS policies allow INSERT on `sms_gateway_tenants`
- Verify user has proper permissions

**❌ "Cannot read property of null" error**
- Ensure Supabase client is properly initialized
- Check network connectivity
- Verify Supabase project is active

#### **API Endpoints (Optional)**

If you prefer backend API registration:

```javascript
// server.js (Node.js/Express example)
const express = require('express')
const { createClient } = require('@supabase/supabase-js')

const app = express()
app.use(express.json())

const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY // Use service role key on server
)

app.post('/api/register', async (req, res) => {
    try {
        const { name, email, phone, companyName, password } = req.body

        // Create user with admin API
        const { data: user, error: authError } = await supabase.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: { full_name: name, phone }
        })

        if (authError) throw authError

        // Create tenant and link user (same as frontend flow)
        // ... (implement tenant creation logic)

        res.json({ success: true, userId: user.id })

    } catch (error) {
        res.status(400).json({ error: error.message })
    }
})

app.listen(3000)
```

#### **Next Steps After Registration**

Once registered, users can:

1. ✅ **Download mobile app** and login
2. ✅ **Add contacts** manually or via CSV import
3. ✅ **Create groups** to organize contacts
4. ✅ **Configure SMS channel** (Native Android or API)
5. ✅ **Send bulk SMS** to contacts or groups
6. ✅ **View logs** to track delivery status
7. ✅ **Invite team members** to their workspace
8. ✅ **Backup settings** to cloud for cross-device sync

---

## 📖 Usage

### 1. Login
- Open the app and login with your credentials
- New users can register via web form (see above section)

### 2. Add Contacts
- Navigate to **Contacts** tab
- Tap **+** button to add a contact
- Or use **Import CSV** for bulk import

### 3. Create Groups
- Go to **Groups** tab
- Create a new group
- Add contacts to the group

### 4. Send SMS
- Open **Send SMS** tab
- Select contacts or a group
- Type your message
- Tap **Send** - SMS sent automatically!

### 5. View Logs
- Check **Logs** tab for delivery status
- See sent, failed, and pending messages

---

## ⚙️ SMS Implementation Details

### Native Android SMS Sending

The app uses Android's native SMS sending capabilities via platform channels:

**How It Works:**
1. User selects "This Phone" as SMS channel in Settings
2. Taps "Send SMS" with selected contacts
3. Flutter calls Kotlin platform channel via MethodChannel
4. Kotlin invokes SmsManager to send SMS via device SIM
5. Delivery status logged to database

**Service Architecture:**
- **NativeSmsService** - Manages platform channel communication
- **SmsService** - Routes to correct SMS delivery method (Native or API)
- **ApiSmsQueueService** - Polls database for pending SMS requests

**Android Implementation (`MainActivity.kt`):**
```kotlin
private val channel = "com.example.sms_gateway.sms"

setupChannel(binaryMessenger) { call ->
    when (call.method) {
        "sendSms" -> {
            val phoneNumber = call.argument<String>("phoneNumber")!!
            val message = call.argument<String>("message")!!
            sendSmsViaNative(phoneNumber, message)
        }
    }
}

private fun sendSmsViaNative(phoneNumber: String, message: String) {
    val smsManager = SmsManager.getDefault()
    smsManager.sendTextMessage(phoneNumber, null, message, null, null)
}
```

**Flutter Implementation (`sms_service.dart`):**
```dart
Future<bool> sendViaNativeAndroid({
    required String phoneNumber,
    required String message,
}) async {
    try {
        final result = await platform.invokeMethod<bool>('sendSms', {
            'phoneNumber': phoneNumber,
            'message': message,
        });
        return result ?? false;
    } catch (e) {
        debugPrint('Error sending native SMS: $e');
        return false;
    }
}
```

### API Queue Processing

The app can also send SMS via external APIs like QuickSMS:

**Queue Flow:**
1. External system calls API endpoint with SMS request
2. Edge function creates record in `sms_requests` table with status='pending'
3. Flutter app polls database every 30 seconds (ApiSmsQueueService)
4. Service fetches pending requests
5. Checks user's selected SMS channel (Native or QuickSMS)
6. Routes to appropriate SMS service
7. Updates request status: pending → processing → sent/failed

**User's SMS Channel Choice:**
The app respects the user's preference in Settings:
- **"This Phone"** → Routes to native Android SMS via platform channel
- **"QuickSMS API"** → Routes to QuickSMS HTTP API

**Queue Service Code (`api_sms_queue_service.dart`):**
```dart
Future<void> _processSingleRequest(SmsRequest request) async {
    try {
        // Get user's selected SMS channel
        final channel = await SmsService.getSelectedChannel();
        
        bool success;
        if (channel == 'quickSMS') {
            // Send via QuickSMS API
            success = await SmsService.sendViaQuickSms(
                phoneNumber: request.phoneNumber,
                message: request.message,
            );
        } else {
            // Send via Native Android SMS
            success = await SmsService.sendViaNativeAndroid(
                phoneNumber: request.phoneNumber,
                message: request.message,
            );
        }
        
        // Update status in database
        await _updateRequestStatus(
            request.id,
            success ? 'sent' : 'failed'
        );
    } catch (e) {
        // Log error and mark as failed
    }
}
```

### Settings Backup During SMS Sending

When users backup settings, the SMS channel preference is included:
- If set to "This Phone", native SMS will be used
- If set to "QuickSMS", API-based sending will be used
- Backup restores this preference on different devices
- Queue service respects the restored preference

### Troubleshooting SMS Sending

**SMS not sending despite being pending?**
1. Check that user has selected an SMS channel in Settings
2. Verify Settings → API Queue Settings has "Auto-start" enabled
3. Check that app has SMS permissions in Android
4. Verify phone number is valid
5. Check Supabase database for error messages in sms_logs

**Native SMS fails silently?**
1. Ensure device has an active SIM card
2. Check Android OS permissions (not granted = silent failure)
3. Monitor logcat: `flutter logs`
4. Check sms_logs table for status='failed' entries

**API Queue not processing?**
1. Go to Settings → API Integration
2. Click "Start Processing" button manually
3. Or enable "Auto-start Queue Processing" in Settings
4. Verify API credentials are configured
5. Check network connectivity

---

```
┌─────────────────────────────────────────────┐
│              Flutter App                     │
│         (Multi-Tenant Aware)                 │
└──────────────────┬──────────────────────────┘
                   │
       ┌───────────┼───────────┐
       ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ Supabase │ │  Native  │ │   API    │
│   Auth   │ │   SMS    │ │ (Future) │
└──────────┘ └──────────┘ └──────────┘
       │           │           │
       ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│PostgreSQL│ │ Android  │ │ External │
│   RLS    │ │   SIM    │ │ Systems  │
└──────────┘ └──────────┘ └──────────┘
```

### Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | Flutter 3.0+ |
| Backend | Supabase (PostgreSQL) |
| Authentication | Supabase Auth |
| SMS Delivery | Native Android SmsManager |
| State Management | Provider |
| Local Storage | SharedPreferences |

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - Project overview |
| [SUPABASE.md](SUPABASE.md) | Database schema and setup |
| [DEVELOPER.md](DEVELOPER.md) | Technical guide for developers |
| [ROADMAP.md](ROADMAP.md) | Future features and phases |

---

## 🔒 Security Notes

- **Never commit credentials** - Supabase keys are in constants.dart
- **SMS permissions** - Required for native sending on Android
- **RLS policies** - All data protected at database level
- **Tenant isolation** - Organizations cannot see each other's data

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author
 
- **Lwena Adam Samson** (CEO & Lead Engineer, TechWare Africa)
- GitHub: [@LwenaAdam](https://github.com/LwenaAdam)
- Portfolio: [lwena.techwareafrica.tech](https://lwena.techwareafrica.tech)
- Website: [techwareafrica.tech](https://techwareafrica.tech)

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - UI framework
- [Supabase](https://supabase.com) - Backend and database
- [Material Design](https://material.io) - Design system

---

Made with ❤️ by Lwena Adam Samson (@TechWare Africa)
