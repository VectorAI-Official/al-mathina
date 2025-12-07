-- Migration: Add multi-device FCM token support
-- This allows multiple devices per phone number to receive notifications

-- Create user_devices table for multiple FCM tokens
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone TEXT NOT NULL,
    fcm_token TEXT NOT NULL,
    device_id TEXT,  -- Optional: device identifier for future use
    device_name TEXT,  -- Optional: friendly device name
    last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique combination of phone and fcm_token
    UNIQUE(phone, fcm_token)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_user_devices_phone ON user_devices(phone);
CREATE INDEX IF NOT EXISTS idx_user_devices_fcm_token ON user_devices(fcm_token);
CREATE INDEX IF NOT EXISTS idx_user_devices_last_active ON user_devices(last_active);

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_devices_updated_at_trigger
    BEFORE UPDATE ON user_devices
    FOR EACH ROW
    EXECUTE FUNCTION update_user_devices_updated_at();

-- Add comments for documentation
COMMENT ON TABLE user_devices IS 'Stores FCM tokens for multiple devices per phone number';
COMMENT ON COLUMN user_devices.phone IS 'User phone number (can have multiple devices)';
COMMENT ON COLUMN user_devices.fcm_token IS 'Firebase Cloud Messaging token for push notifications';
COMMENT ON COLUMN user_devices.device_id IS 'Optional unique device identifier';
COMMENT ON COLUMN user_devices.device_name IS 'Optional friendly device name (e.g., "Dad Phone", "Work Phone")';
COMMENT ON COLUMN user_devices.last_active IS 'Last time this device was active (updated on token refresh)';

-- Migrate existing tokens from users table to user_devices
-- This preserves current FCM tokens when upgrading
INSERT INTO user_devices (phone, fcm_token, last_active)
SELECT phone, fcm_token, updated_at
FROM users
WHERE fcm_token IS NOT NULL
ON CONFLICT (phone, fcm_token) DO NOTHING;

-- Note: We keep the fcm_token column in users table for backward compatibility
-- but new code will use user_devices table
