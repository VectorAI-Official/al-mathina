-- Migration: Create users table with FCM token support
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/_/sql
-- Date: 2025-12-07

-- Create users table if it doesn't exist
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    phone TEXT UNIQUE NOT NULL,
    fcm_token TEXT,
    store_name TEXT,
    email TEXT,
    name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token);

-- Add comments to columns
COMMENT ON TABLE users IS 'User accounts with authentication and notification tokens';
COMMENT ON COLUMN users.phone IS 'User phone number (primary identifier)';
COMMENT ON COLUMN users.fcm_token IS 'Firebase Cloud Messaging device token for push notifications';
COMMENT ON COLUMN users.store_name IS 'Store name for personalized notifications';

-- Create or replace function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Verify the table was created successfully
SELECT 
    table_name,
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users'
ORDER BY ordinal_position;
