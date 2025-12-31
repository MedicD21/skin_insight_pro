# Team Members Implementation Plan

## Database Changes Needed

### 1. Add invite system (optional - for email invitations)
```sql
-- Create invitations table
CREATE TABLE IF NOT EXISTS company_invitations (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    invited_by TEXT NOT NULL REFERENCES users(id),
    status TEXT DEFAULT 'pending', -- pending, accepted, expired
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days',
    UNIQUE(company_id, email)
);

-- Enable RLS
ALTER TABLE company_invitations ENABLE ROW LEVEL SECURITY;

-- Policies for invitations
CREATE POLICY "Users can create invitations for their company"
ON company_invitations FOR INSERT
WITH CHECK (
    company_id IN (
        SELECT company_id FROM users WHERE id::TEXT = (auth.uid())::TEXT
    )
);

CREATE POLICY "Users can view invitations for their company"
ON company_invitations FOR SELECT
USING (
    company_id IN (
        SELECT company_id FROM users WHERE id::TEXT = (auth.uid())::TEXT
    )
);
```

### 2. Update RLS policies for users table
```sql
-- Allow users in same company to view each other
CREATE POLICY "Users can view team members in their company"
ON users FOR SELECT
USING (
    company_id IN (
        SELECT company_id FROM users WHERE id::TEXT = (auth.uid())::TEXT
    )
    OR
    id::TEXT = (auth.uid())::TEXT
);
```

## Implementation Options

### Option 1: Simple Approach (No email invitations)
Users join by:
1. Admin shares a company code/ID
2. New user creates account
3. During signup or in settings, they enter the company code
4. Their account is linked to the company

### Option 2: Email Invitation System (Recommended)
1. Admin invites user by email
2. Invitation is stored in database
3. User receives email with link
4. User creates account or logs in
5. Account is automatically linked to company

## Files to Create/Modify

1. **TeamMembersView.swift** - View to show and manage team members
2. **InviteTeamMemberView.swift** - Sheet to invite new members
3. **NetworkService.swift** - Add API methods for team management
4. **Models/TeamMember.swift** - Model for team members

## Which approach would you prefer?
- Simple (company code)
- Email invitations (more user-friendly)

Let me know and I'll implement it for you!
