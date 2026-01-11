"""
Check Supabase user_devices table for FCM tokens
"""
import os
import sys

# Set environment to use production config
os.environ['ENVIRONMENT'] = 'production'

# Add current directory to path to find config_production
sys.path.append(os.getcwd())

from config_production import settings

print("=" * 80)
print("🔍 CHECKING SUPABASE FOR FCM TOKENS (USER_DEVICES)")
print("=" * 80)
print(f"📡 Supabase URL: {settings.supabase_url}")

try:
    from supabase import create_client, Client
    
    # Try with service key first
    if settings.supabase_service_key:
        print("\n🔐 Using SUPABASE_SERVICE_KEY...")
        supabase: Client = create_client(settings.supabase_url, settings.supabase_service_key)
    else:
        print("\n🔓 Using SUPABASE_ANON_KEY (service key not set)...")
        supabase: Client = create_client(settings.supabase_url, settings.supabase_anon_key)
    
    print("✅ Supabase client created")
    
    # Query all user_devices
    print("\n📋 Querying user_devices table...")
    result = supabase.table("user_devices").select("*").execute()
    
    print(f"✅ Query successful! Found {len(result.data)} device(s)\n")
    
    if result.data:
        for i, device in enumerate(result.data, 1):
            print("=" * 80)
            print(f"📱 DEVICE #{i}")
            print("=" * 80)
            print(f"📱 Phone: {device.get('phone', 'N/A')}")
            
            fcm_token = device.get('fcm_token')
            if fcm_token:
                print(f"✅ FCM Token: {fcm_token[:50]}... (length: {len(fcm_token)})")
            else:
                print("❌ FCM Token: NONE")
            
            print(f"📅 Created at: {device.get('created_at', 'N/A')}") 
            print()
    else:
        print("⚠️ No devices found in user_devices table")
        print("⚠️ This means FCM tokens are NOT being saved to user_devices!")
    
except Exception as e:
    print(f"\n❌ ERROR: {e}")
    import traceback
    print(traceback.format_exc())

print("=" * 80)
