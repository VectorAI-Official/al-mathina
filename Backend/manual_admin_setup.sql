-- Manual Admin Setup Script for Supabase
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/YOUR_PROJECT/editor

-- Step 1: Add is_admin column to users table (if not exists)
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;

-- Step 2: Mark admin users (with +91 country code prefix)
UPDATE users SET is_admin = true WHERE phone IN ('+917339651541', '+918870503350', '+919487715568');

-- Alternative: If phone numbers are stored WITHOUT +91 prefix, use this instead:
-- UPDATE users SET is_admin = true WHERE phone IN ('7339651541', '8870503350', '9487715568');

-- Step 3: Verify admin users
SELECT phone, is_admin, fcm_token FROM users WHERE is_admin = true;

-- Expected result:
-- | phone      | is_admin | fcm_token    |
-- |------------|----------|--------------|
-- | 7339651541 | true     | ...          |
-- | 8870503350 | true     | ...          |
-- | 9487715568 | true     | ...          |

-- Step 4: Verify all users table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- ✅ After running this script, admin system will be active!
