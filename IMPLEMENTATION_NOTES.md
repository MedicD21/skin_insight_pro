# Implementation Progress - Company Features

## Completed Features

### 1. Data Model Updates ✅
Updated `Models.swift` to support company-wide features:

**AppUser Model:**
- Added `companyId` - Links users to their company
- Added `firstName`, `lastName` - User's full name
- Added `phoneNumber` - Contact number
- Added `profileImageUrl` - Profile photo
- Added `role` - User's role (e.g., "Esthetician", "Manager")

**AppClient Model:**
- Added `companyId` - Links clients to a company (for company-wide sharing)
- Added `profileImageUrl` - Client's profile photo (will be auto-updated with latest analysis)

**New Company Model:**
- `id`, `name`, `address`, `phone`, `email`
- `logoUrl` - Company logo
- `website` - Company website
- `createdAt` - Creation timestamp

**New CreateCompanyRequest:**
- Request model for creating/updating companies

### 2. User Profile Editor ✅
Created `EditProfileView.swift`:
- Edit first name, last name, phone number, and role
- View-only email field (cannot be changed)
- Profile image placeholder (ready for future image upload)
- Save functionality (requires backend integration)

### 3. Company Profile Management ✅
Created `CompanyProfileView.swift`:
- View company details (name, address, phone, email, website)
- Company logo display
- Edit company information
- Create new company profile
- Team members section (placeholder for future)

**Included EditCompanyView:**
- Create/edit company name, address, phone, email, website
- Logo upload placeholder
- Form validation

### 4. Profile View Integration ✅
Updated `ProfileView.swift`:
- Added "Edit Profile" button to account section
- Added "Company Profile" button to account section
- Both open as sheets when clicked
- Only visible for authenticated users (not guests)

## Remaining Tasks

### 1. Update Client Profile Picture with Latest Analysis Photo
**Location:** `AddClientView.swift`, `ClientDetailView.swift`
**What's needed:**
- After a skin analysis is completed, automatically update the client's `profileImageUrl` with the analysis image
- Modify the analysis save logic to update the client record

### 2. Backend Integration
**NetworkService.swift needs updates:**

```swift
// Add these methods to NetworkService:
func updateUserProfile(_ user: AppUser) async throws -> AppUser
func createCompany(_ company: CreateCompanyRequest) async throws -> Company
func updateCompany(_ company: Company) async throws -> Company
func fetchCompany(id: String) async throws -> Company
func fetchUsersByCompany(companyId: String) async throws -> [AppUser]
```

### 3. Company-Wide Client Access
**Current State:** Clients are filtered by `userId`
**Needed Changes:**
- Update `ClientDashboardViewModel.loadClients()` to fetch clients by `companyId` instead of (or in addition to) `userId`
- Modify backend queries to support company-wide client access
- Add proper permissions (only users in the same company can see clients)

**Files to Update:**
- `ClientDashboardView.swift` - Update `loadClients()` method
- `NetworkService.swift` - Add `fetchClientsByCompany(companyId:)` method

### 4. Link Users to Companies
**What's needed:**
- When creating a company, automatically link the creator
- Add ability to invite users to join a company (email invite system)
- Add user management within company profile
- Allow users to accept/decline company invitations

## Backend Database Schema Changes Required

### Users Table:
```sql
-- Add columns to users table (will skip if already exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='users' AND column_name='company_id') THEN
        ALTER TABLE users ADD COLUMN company_id TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='users' AND column_name='first_name') THEN
        ALTER TABLE users ADD COLUMN first_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='users' AND column_name='last_name') THEN
        ALTER TABLE users ADD COLUMN last_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='users' AND column_name='phone_number') THEN
        ALTER TABLE users ADD COLUMN phone_number TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='users' AND column_name='profile_image_url') THEN
        ALTER TABLE users ADD COLUMN profile_image_url TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='users' AND column_name='role') THEN
        ALTER TABLE users ADD COLUMN role TEXT;
    END IF;
END $$;
```

### Clients Table:
```sql
-- Add columns to clients table (will skip if already exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='clients' AND column_name='company_id') THEN
        ALTER TABLE clients ADD COLUMN company_id TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name='clients' AND column_name='profile_image_url') THEN
        ALTER TABLE clients ADD COLUMN profile_image_url TEXT;
    END IF;
END $$;
```

### New Companies Table:
```sql
-- Create companies table (will skip if already exists)
CREATE TABLE IF NOT EXISTS companies (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    email TEXT,
    logo_url TEXT,
    website TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add index on company_id for users table
CREATE INDEX IF NOT EXISTS idx_users_company_id ON users(company_id);

-- Add index on company_id for clients table
CREATE INDEX IF NOT EXISTS idx_clients_company_id ON clients(company_id);
```

## API Endpoints Needed

1. `POST /api/companies` - Create company
2. `PUT /api/companies/:id` - Update company
3. `GET /api/companies/:id` - Get company details
4. `GET /api/companies/:id/users` - Get company team members
5. `PUT /api/users/:id/profile` - Update user profile
6. `GET /api/clients?companyId=:id` - Get company-wide clients
7. `PUT /api/clients/:id/profile-image` - Update client profile image

## Quick Implementation Guide

### To Complete Client Profile Picture Auto-Update:

1. Find where skin analysis is saved in `SkinAnalysisInputView.swift`
2. After successful analysis save, add:
```swift
if let imageUrl = analysis.imageUrl {
    var updatedClient = client
    updatedClient.profileImageUrl = imageUrl
    try await NetworkService.shared.updateClient(updatedClient)
}
```

### To Enable Company-Wide Clients:

1. Update `NetworkService.swift`:
```swift
func fetchClientsByCompany(companyId: String) async throws -> [AppClient] {
    // Fetch clients where company_id = companyId
}
```

2. Update `ClientDashboardViewModel`:
```swift
func loadClients() async {
    if let companyId = AuthenticationManager.shared.currentUser?.companyId {
        clients = try await NetworkService.shared.fetchClientsByCompany(companyId: companyId)
    }
}
```

## Testing Checklist

- [ ] User can edit their profile
- [ ] User can create a company profile
- [ ] User can edit company profile
- [ ] Client profile picture updates after analysis
- [ ] All users in same company see same clients
- [ ] Profile images display correctly
- [ ] Form validation works properly
- [ ] Error handling works for network failures

## Notes

- All UI components are fully styled with dark mode support
- Profile image upload functionality needs to be connected to file upload service
- Company logo upload needs similar implementation
- Consider adding role-based permissions (admin vs regular user)
