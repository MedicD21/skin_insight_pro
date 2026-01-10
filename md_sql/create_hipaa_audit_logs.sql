-- Create HIPAA Audit Logs Table
-- This table stores permanent audit logs for HIPAA compliance
-- Run this in Supabase Dashboard > SQL Editor

-- Create audit logs table
CREATE TABLE IF NOT EXISTS hipaa_audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  user_email TEXT NOT NULL,
  event_type TEXT NOT NULL,
  resource_type TEXT,
  resource_id UUID,
  ip_address TEXT,
  device_info TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE hipaa_audit_logs ENABLE ROW LEVEL SECURITY;

-- Only admins can view audit logs
CREATE POLICY "Admins can view all audit logs"
ON hipaa_audit_logs FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.is_admin = true
  )
);

-- Anyone can insert their own audit logs
CREATE POLICY "Users can create audit logs"
ON hipaa_audit_logs FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON hipaa_audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON hipaa_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON hipaa_audit_logs(event_type);

-- Add comment
COMMENT ON TABLE hipaa_audit_logs IS 'HIPAA compliance audit logs - tracks all PHI access and modifications';

-- Verify the table was created
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'hipaa_audit_logs'
ORDER BY ordinal_position;
