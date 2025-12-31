# Capabilities Setup Guide

This guide explains all the capabilities that have been added to Skin Insight Pro and how to configure them in Xcode.

## ✅ Capabilities Already Configured

### 1. **Sign in with Apple** ✅
- **Status:** Already enabled and working
- **What it does:** Allows users to authenticate using their Apple ID
- **Location:** `SkinInsightPro.entitlements` - Line 10-13
- **No additional setup needed** - Already implemented in your authentication flow

### 2. **Push Notifications** ✅
- **Status:** Enabled
- **What it does:** Allows the app to receive remote notifications for:
  - New client analyses from team members
  - Company invitations
  - Analysis reminders
  - Team collaboration updates
- **Location:**
  - `SkinInsightPro.entitlements` - Line 6-7
  - `Info.plist` - Line 54-57 (Background Modes)
- **Xcode Setup Required:**
  1. Open project in Xcode
  2. Select project target → "Signing & Capabilities"
  3. Verify "Push Notifications" capability is added
  4. When ready for production, change `aps-environment` to `production`

### 3. **Background Modes** ✅
- **Status:** Enabled
- **What it does:** Allows the app to:
  - Fetch data in background (`fetch`)
  - Receive remote notifications (`remote-notification`)
- **Location:** `Info.plist` - Line 54-57
- **Use Cases:**
  - Sync client data when app is in background
  - Update analysis results
  - Receive notifications about team activity

### 4. **iCloud** ✅
- **Status:** Enabled (CloudKit + CloudDocuments)
- **What it does:**
  - **CloudKit:** Sync data across user's devices
  - **CloudDocuments:** Store files in iCloud Drive
- **Location:** `SkinInsightPro.entitlements` - Line 16-30
- **Xcode Setup Required:**
  1. Select project target → "Signing & Capabilities"
  2. Click "+ Capability" → Add "iCloud"
  3. Check both:
     - ✅ CloudKit
     - ✅ iCloud Documents
  4. Container will auto-populate as `iCloud.$(CFBundleIdentifier)`

### 5. **App Groups** ✅
- **Status:** Enabled
- **What it does:** Share data between app and extensions (widgets, share extensions, etc.)
- **Location:** `SkinInsightPro.entitlements` - Line 33-36
- **Xcode Setup Required:**
  1. Select project target → "Signing & Capabilities"
  2. Click "+ Capability" → Add "App Groups"
  3. Click "+" to add group: `group.$(PRODUCT_BUNDLE_IDENTIFIER)`
- **Future Uses:**
  - Share extension to quickly add analysis photos
  - Widget showing recent analyses
  - Today extension for quick client lookup

### 6. **Keychain Sharing** ✅
- **Status:** Enabled
- **What it does:** Securely store and share credentials across apps with same team ID
- **Location:** `SkinInsightPro.entitlements` - Line 39-42
- **Xcode Setup Required:**
  1. Select project target → "Signing & Capabilities"
  2. Click "+ Capability" → Add "Keychain Sharing"
  3. Keychain group will auto-populate as `$(AppIdentifierPrefix)$(CFBundleIdentifier)`
- **Use Case:**
  - Secure storage of Supabase tokens
  - Share authentication state between app extensions

## 📋 Xcode Configuration Checklist

### Step-by-Step Setup:

1. **Open Xcode Project**
   ```bash
   open SkinInsightPro.xcodeproj
   ```

2. **Select Project Target**
   - Click on project name in navigator
   - Select "SkinInsightPro" target
   - Click "Signing & Capabilities" tab

3. **Verify Automatic Signing**
   - ✅ Check "Automatically manage signing"
   - Select your Team

4. **Add Missing Capabilities** (if not already present)

   Click "+ Capability" button and add each:

   a. **Push Notifications**
      - Just click to add, no configuration needed

   b. **Background Modes**
      - Check: ✅ Background fetch
      - Check: ✅ Remote notifications

   c. **iCloud**
      - Check: ✅ CloudKit
      - Check: ✅ iCloud Documents
      - Container: `iCloud.$(CFBundleIdentifier)`

   d. **App Groups**
      - Click "+" to add: `group.$(PRODUCT_BUNDLE_IDENTIFIER)`

   e. **Keychain Sharing**
      - Auto-populated: `$(AppIdentifierPrefix)$(CFBundleIdentifier)`

5. **Build and Test**
   ```bash
   xcodebuild -scheme SkinInsightPro -sdk iphonesimulator -configuration Debug build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
   ```

## 🔐 Security & Privacy

### Info.plist Privacy Descriptions (Already Configured):

- ✅ **Camera Usage** - "We need access to your camera to capture skin images for analysis"
- ✅ **Photo Library Usage** - "We need access to your photo library to select skin images for analysis"

### Additional Privacy Descriptions (Add if needed):

If you plan to use location services in the future, add:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to find nearby skincare professionals</string>
```

## 🚀 Production Deployment

### Before App Store Submission:

1. **Update Push Notification Environment**
   - In `SkinInsightPro.entitlements`, change:
   ```xml
   <key>aps-environment</key>
   <string>production</string>
   ```

2. **Configure Apple Developer Portal**
   - Enable Push Notifications for your App ID
   - Enable iCloud (CloudKit + CloudDocuments)
   - Enable App Groups
   - Enable Sign in with Apple
   - Generate provisioning profiles

3. **Test on Physical Device**
   - Push notifications only work on real devices
   - Test all background modes
   - Verify iCloud sync

## 💡 Feature Usage Examples

### Push Notifications
```swift
// Request permission (add to AuthenticationManager or AppDelegate)
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
    if granted {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
```

### Background Fetch
```swift
// Add to your App delegate or scene delegate
func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Fetch new data from Supabase
    Task {
        await NetworkService.shared.syncBackgroundData()
        completionHandler(.newData)
    }
}
```

### iCloud Storage
```swift
// Save to iCloud Documents
let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
    .appendingPathComponent("Documents")
// Use for storing analysis images
```

### App Groups
```swift
// Share data between app and extensions
let sharedDefaults = UserDefaults(suiteName: "group.$(PRODUCT_BUNDLE_IDENTIFIER)")
sharedDefaults?.set(value, forKey: "shared_key")
```

## 📊 Capability Matrix

| Capability | Status | Immediate Use | Future Use |
|-----------|--------|---------------|------------|
| Sign in with Apple | ✅ Active | User authentication | - |
| Push Notifications | ✅ Ready | - | Team notifications, reminders |
| Background Modes | ✅ Ready | - | Background sync |
| iCloud | ✅ Ready | - | Cross-device sync |
| App Groups | ✅ Ready | - | Widgets, share extensions |
| Keychain Sharing | ✅ Ready | Secure token storage | Cross-app credential sharing |

## ⚠️ Important Notes

1. **iCloud Containers** - Will be automatically created when you first run the app with iCloud enabled
2. **Push Notifications** - Require a physical device to test (don't work in simulator)
3. **Background Modes** - May drain battery; use judiciously
4. **Team ID Required** - Make sure you're signed in with an Apple Developer account
5. **Provisioning Profiles** - Will be automatically generated if using automatic signing

## 🆘 Troubleshooting

### "No matching provisioning profiles found"
- Solution: Enable "Automatically manage signing" in Xcode

### "An App ID with Identifier 'X' is not available"
- Solution: Change bundle identifier or use existing App ID from developer portal

### Push notifications not working
- Check: Using physical device (not simulator)
- Check: Granted notification permissions
- Check: APS environment matches (development/production)

### iCloud not syncing
- Check: Signed into iCloud on device
- Check: iCloud Drive enabled in Settings
- Check: Container identifier matches

## 📝 Next Steps

After Xcode configuration:
1. Test all capabilities on a physical device
2. Implement push notification handling
3. Set up background fetch for data sync
4. Configure iCloud storage for images
5. Prepare for App Store submission

---

All capabilities are now configured in your entitlements and Info.plist files. You just need to enable them in Xcode's "Signing & Capabilities" tab!
