# 📋 Changelog & Release Notes

All notable changes to SMS Gateway Pro are documented here.

## [Unreleased] - 2026-02-04

### ✨ Marketing Automation Engine (NEW!)

**Professional Marketing SMS Campaigns with Anti-Spam Safeguards**

#### 🚀 New Features Added

**Marketing Campaign Management**
- Create and manage SMS marketing campaigns
- Campaign lifecycle: draft → active → paused → completed
- Personalized message templates with dynamic fields ({first_name}, {last_name}, {phone})
- Progress tracking and real-time statistics
- Pause/resume campaigns at any time

**Anti-Spam Enforcement**
- Frequency limiting: Max 2 SMS per phone number per 30 days (rolling window)
- Daily tenant limits: Configurable (default 100 SMS/day)
- Opt-out blacklist management
- Event-based tracking for accurate rolling windows
- Automatic safety checks before every send

**Background Processing**
- WorkManager-based automation (battery optimized)
- Periodic campaign checks every 30 minutes
- Staggered SMS sending (30-60 seconds between messages)
- Automatic retry on failures (up to 3 attempts)
- Foreground Service for reliable SMS delivery

**Campaign UI**
- Campaign List Screen with progress indicators
- Campaign Create/Edit Screen with contact selection
- Message template preview with sample data
- Marketing Settings Screen for automation control
- Real-time statistics and analytics

**Database Schema**
- Event-based frequency tracking table
- Campaign management tables with RLS policies
- Opt-out blacklist with tenant isolation
- Comprehensive audit logging
- Optimized indexes for high-performance queries

#### 🔧 Technical Improvements

**Android Native Services**
- `MarketingService` - High-level business logic
- `MarketingSmsService` - Foreground service for SMS sending
- `FrequencyTrackerService` - Anti-spam enforcement
- `SupabaseClient` - Lightweight REST client for Android
- `CampaignRepository` - Database access layer

**Android Workers**
- `CampaignCheckWorker` - Periodic campaign processor
- `SendMarketingSmsWorker` - Individual SMS sender
- `MarketingCoordinator` - WorkManager scheduler

**Flutter Integration**
- `MarketingService` (Dart) - MethodChannel bridge
- `MarketingCampaign` model with progress calculations
- `CampaignContact` model with status tracking
- Campaign list and creation screens
- Marketing settings UI

**Phone Number Validation**
- E.164 format enforcement
- Max 15 digits + country code
- Normalization and formatting utilities
- Validation error messages
- Support for international numbers

**Database Optimizations**
- Critical indexes for frequency queries
- RLS policies for tenant isolation
- Helper functions for eligibility checks
- Trigger-based timestamp updates
- Comprehensive documentation

#### 📦 New Files Added

**Android Services** (5 files)
- `FrequencyTrackerService.java` - Anti-spam enforcement
- `MarketingService.java` - Business logic coordinator
- `MarketingSmsService.java` - Foreground SMS service
- `MarketingMethodChannelHandler.java` - Flutter bridge
- `SupabaseClient.java` - REST API client

**Android Workers** (3 files)
- `CampaignCheckWorker.java` - Campaign processor
- `SendMarketingSmsWorker.java` - SMS sender
- `MarketingCoordinator.java` - WorkManager scheduler

**Flutter Services** (2 files)
- `lib/services/marketing_service.dart` - MethodChannel wrapper
- `lib/core/phone_validator.dart` - Phone validation utility

**Flutter Models** (1 file)
- `lib/models/marketing_campaign.dart` - Campaign and contact models

**Flutter Screens** (3 files)
- `lib/screens/marketing/campaign_list_screen.dart` - Campaign list UI
- `lib/screens/marketing/campaign_create_screen.dart` - Campaign editor
- `lib/screens/marketing_settings_screen.dart` - Automation settings

**Database Schema** (2 files)
- `database/marketing_automation_schema.sql` - Full schema with 6 tables
- `database/verify_and_create_marketing_tables.sql` - Deployment script

#### 🐛 Fixes Applied

**Phone Validation**
- Fixed phone length errors (now enforces E.164 max 15 digits)
- Added normalization for international numbers
- Validation before database insertion

**API Queue Processing**
- Fixed null-safety errors in `SmsRequest.fromJson()`
- Added null-coalescing operators for required fields
- Improved error handling

**Database Operations**
- Changed from `.insert()` to `.upsert()` to handle duplicates
- Fixed "duplicate key value" errors
- Graceful conflict resolution

**RLS Policies**
- Fixed incorrect table references in marketing schema
- Updated to use `client_product_access` instead of `user_tenants`
- Matched application's actual multi-tenant architecture

#### 📊 Database Schema Details

**Tables Created** (6 total)
- `marketing_settings` - Tenant configuration
- `marketing_campaigns` - Campaign definitions
- `marketing_campaign_contacts` - Contact assignments
- `marketing_frequency_events` - Event-based tracking (CRITICAL)
- `marketing_optouts` - Blacklist management
- `marketing_logs` - Comprehensive audit trail

**Indexes Created** (15+)
- Optimized for frequency limit queries
- Campaign status lookups
- Tenant isolation
- Time-based filtering

**RLS Policies** (6 policies)
- Tenant-scoped data isolation
- User access control via `tenant_members`
- Secure multi-tenant architecture

**Helper Functions** (2 functions)
- `can_send_marketing_sms()` - Eligibility checker
- `get_campaign_analytics()` - Statistics aggregator

#### ⚠️ Breaking Changes
None - All changes are additive and backward compatible.

#### 🔄 Migration Required
Yes - Run `database/marketing_automation_schema.sql` to create marketing tables.

#### 📝 Documentation Updated
- `API_DOCUMENTATION.md` - No changes needed
- `DEVELOPER.md` - Updated with marketing architecture
- `SUPABASE.md` - Updated with marketing tables
- `CHANGELOG.md` - This file (comprehensive update)

---

## [1.0.0] - 2025-01-01

### 🎉 Initial Release

**Professional Bulk SMS Management System**

#### ✨ Features Added

**Core SMS Management**
- Native Android SMS sending via device SIM card
- Bulk messaging to multiple contacts
- Complete SMS logs with delivery tracking
- Automatic background SMS processing

**Contact & Group Management**
- Add, edit, delete contacts easily
- CSV/VCF import for bulk contact management
- Automatic phone number formatting and validation
- Create and manage contact groups
- Send to entire groups with one click

**Multi-Tenant Architecture**
- Complete workspace isolation
- Multiple organization support
- User can belong to multiple workspaces
- Automatic workspace selection for single-workspace users
- Easy workspace switching

**Security & Privacy**
- Supabase authentication (email/password)
- Row Level Security (RLS) at database level
- Tenant-level data isolation
- API Key authentication for external access
- Rate limiting (100 requests/minute)

**API Integration**
- REST API endpoints for SMS sending
- API key management (create, activate, deactivate, delete)
- External system integration (CRM, ERP, schools, etc.)
- Queue processing for reliable message delivery
- Serverless Edge Functions on Supabase

**Data & Synchronization**
- Settings backup to cloud
- Cross-device restore functionality
- User preference sync (theme, language, SMS channel)
- Tenant settings sync (quotas, feature flags)
- Complete audit trail

**User Experience**
- Dark mode support
- Clean, modern UI design
- Responsive layout for all screen sizes
- Real-time success/failure notifications
- Offline-first architecture with local SQLite

**Cross-Platform**
- Android native SMS (primary)
- Web interface available
- Offline functionality with automatic sync

#### 🔧 Technical Specifications

- **Min SDK**: Android 5.0 (API 21)
- **Target SDK**: Android 14 (API 34)
- **Flutter Version**: 3.0+
- **Database**: PostgreSQL (Supabase)
- **Local Storage**: SQLite (Drift)
- **Backend**: Supabase with Edge Functions
- **Authentication**: Supabase Auth

#### 📦 Deployment

- Package Name: `com.lwenatech.sms_gateway`
- Version: 1.0.0 (Build 1)
- Size: ~50-80 MB (varies by platform)
- Supported Devices: Android 5.0+

#### ✅ Testing Completed

- [x] Unit tests for core functionality
- [x] Integration tests for API
- [x] Manual testing on multiple Android devices
- [x] Security testing (RLS, API key validation)
- [x] Performance testing (bulk sending 1000+ contacts)
- [x] Offline functionality verification

---

## Installation

See [INSTALLATION.md](INSTALLATION.md) for detailed setup instructions.

Quick start:
```bash
git clone https://github.com/LWENA27/sms_getway.git
cd sms_getway
flutter pub get
flutter run
```

---

## Known Limitations

- SMS sending requires Android device (web uses Supabase backend)
- API rate limit: 100 requests/minute per key
- Maximum file upload: 5MB for CSV imports

---

## What's Next?

Check out [ROADMAP.md](ROADMAP.md) for upcoming features and improvements.

---

## Support

- 📧 Email: support@example.com
- 🐛 Report bugs on [GitHub Issues](https://github.com/LWENA27/sms_getway/issues)
- 📖 Read [API Documentation](API_DOCUMENTATION.md)
- 👨‍💻 See [Developer Guide](DEVELOPER.md)

---

## License

MIT License - See [LICENSE](LICENSE) file for details

---

## Contributors

- **Lead Developer**: LWENA Tech Ware
- **Contributors**: Open source community

---

**Thank you for using SMS Gateway Pro!** 🎉
