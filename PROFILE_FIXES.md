# Profile Update Fixes

## Issues Fixed

### 1. ✅ Profile Update Error - "Bad request. Please check your input"

**Problem:** The `updateUserProfile` method was sending null/empty values to the backend, causing validation errors.

**Solution:** Updated [NetworkService.swift:556-618](Sources/NetworkService.swift#L556-L618) to:
- Only send non-empty field values
- Filter out nil and empty strings before sending to API
- Added debug logging to see exactly what's being sent
- Added better error message handling

**Changes:**
```swift
// Before: Sent all fields including empty ones
let userData: [String: Any?] = [
    "first_name": user.firstName,  // Could be nil or empty
    ...
]

// After: Only send non-empty values
var userData: [String: Any] = [:]
if let firstName = user.firstName, !firstName.isEmpty {
    userData["first_name"] = firstName
}
```

### 2. ✅ Change Photo Button Not Working

**Problem:** The "Change Photo" button did nothing when clicked.

**Solution:** Updated [EditProfileView.swift](Sources/EditProfileView.swift) to:
- Added `import PhotosUI` for photo picker support
- Added `@State` variables for image picker:
  - `showImagePicker` - Controls sheet display
  - `selectedImage` - Stores selected photo
- Connected button to show photo picker
- Updated profile image display to show selected image
- Integrated image upload into save flow

**Changes:**
- Button now opens photo library picker
- Selected image displays immediately in UI
- Image uploads to Supabase storage when saving
- Profile image URL updates in user profile

## How It Works Now

### Profile Update Flow:
1. User edits fields (First Name, Last Name, Phone, Role)
2. Optionally selects a new profile photo
3. Clicks "Save"
4. **If photo selected:**
   - Uploads image to Supabase Storage
   - Gets back image URL
   - Adds URL to profile data
5. Sends PATCH request with only non-empty fields
6. Updates local user object
7. Dismisses sheet

### Photo Upload Flow:
1. User clicks "Change Photo"
2. Photo library picker opens
3. User selects photo
4. Image displays immediately in circle preview
5. On save:
   - Image uploads to `/skin-images/{userId}/{uuid}.jpg`
   - URL format: `https://{supabase-url}/storage/v1/object/public/skin-images/{userId}/{uuid}.jpg`
   - Profile updated with new URL

## Testing Checklist

After rebuilding:
- [ ] Profile update works without photo (First Name, Last Name, Phone, Role)
- [ ] "Change Photo" button opens photo picker
- [ ] Selected photo displays in circle preview
- [ ] Photo uploads and saves with profile
- [ ] Profile image displays on Profile screen after save
- [ ] Error messages show helpful information if something fails

## Debug Output

When updating profile, you'll now see console logs:
```
-> Request: Update User Profile
-> PATCH: https://your-supabase-url/rest/v1/users?id=eq.{userId}
-> Body: ["first_name": "Dustin", "last_name": "Schaaf", "phone_number": "6143026000", "role": "IT"]
<- Response: Update User Profile
<- Status Code: 200
```

If there's an error:
```
<- Error Response: {"code":"...", "message":"..."}
```

## Files Modified

1. **[NetworkService.swift](Sources/NetworkService.swift)** (Lines 556-618)
   - Improved `updateUserProfile` method
   - Only sends non-empty values
   - Added debug logging
   - Better error handling

2. **[EditProfileView.swift](Sources/EditProfileView.swift)**
   - Added PhotosUI import
   - Added image picker state management
   - Updated "Change Photo" button to work
   - Integrated image upload into save flow
   - Shows selected image in preview

## Next Steps

If you still see the "Bad request" error:
1. Check the console output for the debug logs
2. The logs will show exactly what data is being sent
3. Share the error response to diagnose further

If photo upload fails:
1. Verify Supabase Storage bucket `skin-images` exists
2. Check bucket permissions allow authenticated uploads
3. Verify the storage URL is correctly configured in AppConstants

---

**Note:** Make sure to add `EditProfileView.swift` and `CompanyProfileView.swift` to your Xcode project if you haven't already!
