# Android APK Distribution & Google Play Protect Guide

## 1. Building Optimized Release APKs (Split per ABI)

To build lightweight, optimized APKs (~32MB instead of 75MB):

```bash
flutter build apk --release --split-per-abi --dart-define-from-file=.env
```

This generates three target APKs in `build/app/outputs/flutter-apk/`:
- **`app-arm64-v8a-release.apk`** (~32 MB) — **Distribute this version.** Fits 99% of modern Android smartphones.
- **`app-armeabi-v7a-release.apk`** (~30 MB) — For older 32-bit Android phones.
- **`app-x86_64-release.apk`** (~33 MB) — For Android emulators and Chromebooks.

To copy the ARM64 APK to the web download folder:
```bash
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk web/downloads/sms_gateway_pro.apk
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk build/web/downloads/sms_gateway_pro.apk
```

---

## 2. Why Google Play Protect Prompts Sideloaded APKs

When an APK is downloaded directly from a web browser (sideloaded) instead of the Google Play Store, Google Play Protect's cloud heuristic scanners check:
1. **Developer Certificate Reputation**: If the signing key is new or not yet cataloged in Google's cloud database, Play Protect warns that the developer is "unknown".
2. **Sensitive Permissions**: The app declares `android.permission.SEND_SMS` (required to act as a local SIM gateway). Because malware often abuses SMS, Google flags unverified sideloaded apps that request SMS permissions.

> **Note on Permissions**: We have eliminated `READ_SMS` and `RECEIVE_SMS` from `AndroidManifest.xml` because the app only sends outgoing SMS. This removes the "SMS Spyware / OTP Interception" heuristic flag entirely.

---

## 3. How to Whitelist the App Permanently with Google (Play Protect Appeal)

Google provides an official verification portal for developers whose sideloaded enterprise apps are flagged:

### Official Submission Link:
👉 **[Google Play Protect Developer Appeal Form](https://support.google.com/googleplay/android-developer/contact/protectappeals)**

### Form Fields & Values to Submit:
- **Developer Name**: `Lwena Adam`
- **Company / Organization**: `TechWare Africa`
- **Application Name**: `SMS Gateway Pro`
- **Package Name**: `com.lwenatech.sms_gateway`
- **Certificate SHA-256 Fingerprint**:
  ```
  3F:2E:13:8A:03:BA:F5:B0:DF:6F:C9:5D:1E:B0:2E:7A:EE:B0:64:6C:79:B3:66:13:C8:EE:BA:D4:9C:92:27:84
  ```
- **Certificate SHA-1 Fingerprint**:
  ```
  A4:31:D0:EC:98:12:B4:E6:AA:EF:7D:B6:58:ED:F9:0F:03:D0:6A:36
  ```
- **Direct Download Link**: Link to your hosted APK (or Google Drive share link to `app-arm64-v8a-release.apk`).
- **Explanation / Comments for Google Reviewers**:
  > "SMS Gateway Pro is an enterprise SMS gateway software developed by TechWare Africa. It enables authorized businesses to send SMS notifications and sync business contacts with full user consent. The app does not intercept, read, or forward personal incoming SMS messages (READ_SMS and RECEIVE_SMS permissions have been removed). The app is securely signed with our TechWare Africa release keystore and strictly complies with all Android security guidelines. We request Google Play Protect whitelisting for our application package and certificate."

Google typically reviews and whitelists submitted APKs within **24 to 48 hours**. Once approved, the warning disappears across all Android devices worldwide.

---

## 4. Immediate Installation Instructions for Clients

Until Google completes the certificate whitelisting, instruct your clients to follow these standard sideloading steps on their Android devices:

1. When opening the downloaded APK, if **"Blocked by Play Protect"** or **"Unsafe app blocked"** appears:
2. Tap **"More details"** (or *"Maelezo zaidi"* in Swahili).
3. Tap **"Install anyway"** (or *"Sakinisha hata hivyo"*).
4. If prompted to send the app to Google for scanning, tap **"Send"** (this accelerates Google's automated safety analysis of your APK).
