# Apply Multi-Device FCM Migration

## ⚠️ CRITICAL: Apply this migration to Supabase BEFORE testing

The backend code has been updated to support multiple devices per phone number, but the database schema needs to be updated first.

## Steps to Apply Migration

### 1. Open Supabase SQL Editor

1. Go to https://zuhkndylyavedmfrovsj.supabase.co
2. Login to your Supabase dashboard
3. Navigate to **SQL Editor** (left sidebar)

### 2. Execute Migration

1. Click **New Query**
2. Copy the entire contents of `Backend/database/migrations/002_add_multi_device_support.sql`
3. Paste into the SQL editor
4. Click **Run** or press `Ctrl+Enter`

### 3. Verify Migration

After running the migration, verify it worked:

```sql
-- Check if user_devices table exists
SELECT * FROM user_devices;

-- Should see 1 row with your existing FCM token migrated
-- Phone: +918870986738
-- Token: dfwymzH4Sj6WCV98Bt1KhW...
```

### 4. What the Migration Does

- ✅ Creates `user_devices` table with proper schema
- ✅ Adds indexes for performance (phone, fcm_token, last_active)
- ✅ Creates auto-update trigger for `updated_at` field
- ✅ Migrates your existing FCM token from `users` table
- ✅ Keeps `users.fcm_token` for backward compatibility

### 5. Backend Changes (Already Deployed)

The following backend changes are already pushed to production and will activate once migration is applied:

**fcm.py:**
- Token save now writes to `user_devices` table using upsert
- GET endpoint returns all devices for a phone number
- Maintains backward compatibility with `users` table

**user_profile.py:**
- Order creation queries `user_devices` for all FCM tokens
- Sends notification to EACH device individually
- Logs success/failure for each send
- Shows summary: "X sent, Y failed out of Z device(s)"

### 6. Test Multi-Device Flow

After applying migration:

1. **Login on Device 1** (your phone):
   - Phone authenticates → FCM token saved
   - Check database: `SELECT * FROM user_devices WHERE phone = '+918870986738'`
   - Should see 1 row

2. **Login on Device 2** (dad's phone) with same number:
   - Phone authenticates → Different FCM token saved
   - Check database again
   - Should see 2 rows now (both tokens for same phone)

3. **Place Order**:
   - Create order via Flutter app
   - Check Render logs:
     ```
     📱 ORDER: Found 2 device(s) for user +918870986738
     📤 ORDER: [1/2] Sending to device: dfwymzH4...
     ✅ ORDER: [1/2] Notification sent successfully!
     📤 ORDER: [2/2] Sending to device: abc123...
     ✅ ORDER: [2/2] Notification sent successfully!
     🎉 ORDER: Notification summary: 2 sent, 0 failed out of 2 device(s)
     ```
   - Both devices should receive notification!

### 7. Verify on Render

After migration applied, Render will auto-deploy the new backend code (already pushed). Check deployment status:

- Dashboard: https://dashboard.render.com
- Logs should show: "🚀 FCM: Firebase Admin SDK initialized successfully!"

### 8. Expected Behavior

**Before Migration:**
- Only last logged-in device receives notifications
- Token overwrites on each login

**After Migration:**
- ALL devices logged in with same phone number receive notifications
- Each device has separate token in `user_devices` table
- Tokens don't overwrite each other

## Troubleshooting

**If migration fails:**
- Check for syntax errors in SQL
- Verify you have proper permissions
- Check Supabase logs for detailed error

**If devices still not receiving notifications:**
- Verify `user_devices` table has multiple rows for your phone
- Check Render logs for "Found X device(s)" message
- Ensure both devices have logged in AFTER migration applied

**If only one device receives notification:**
- Migration may not be applied yet
- Backend might still be using old code (check deployment status)
- Check FCM tokens are different between devices

## Production Status

- ✅ Migration file created: `002_add_multi_device_support.sql`
- ✅ Backend updated: `fcm.py` and `user_profile.py`
- ✅ Code pushed to GitHub (commit a062dce)
- ✅ Render will auto-deploy
- ⏳ **WAITING**: Migration needs to be applied in Supabase
- ⏳ **WAITING**: Test with multiple devices

## Next Steps

1. Apply migration in Supabase SQL Editor ⬅️ **DO THIS NOW**
2. Wait for Render deployment to complete
3. Login on both devices
4. Place test order
5. Verify both devices receive notification
