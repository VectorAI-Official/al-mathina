"""
Check Supabase users table for FCM tokens
"""
import os
import sys

# Set environment to use production config
os.environ['ENVIRONMENT'] = 'production'

from config_production import settings

print("=" * 80)
print("🔍 CHECKING SUPABASE FOR FCM TOKENS")
print("=" * 80)
print(f"📡 Supabase URL: {settings.supabase_url}")
print(f"🔑 Service Key: {'✅ Set' if settings.supabase_service_key else '❌ Not Set'}")
print(f"🔑 Anon Key: {'✅ Set' if settings.supabase_anon_key else '❌ Not Set'}")
print("=" * 80)

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
    
    # Query all users with FCM tokens
    print("\n📋 Querying users table...")
    result = supabase.table("users").select("*").execute()
    
    print(f"✅ Query successful! Found {len(result.data)} user(s)\n")
    
    if result.data:
        for i, user in enumerate(result.data, 1):
            print("=" * 80)
            print(f"👤 USER #{i}")
            print("=" * 80)
            print(f"📱 Phone: {user.get('phone', 'N/A')}")
            print(f"👤 Name: {user.get('name', 'N/A')}")
            print(f"🏪 Store Name: {user.get('store_name', 'N/A')}")
            print(f"📧 Email: {user.get('email', 'N/A')}")
            
            fcm_token = user.get('fcm_token')
            if fcm_token:
                print(f"✅ FCM Token: {fcm_token[:50]}... (length: {len(fcm_token)})")
            else:
                print("❌ FCM Token: NONE")
            
            print(f"📅 Created: {user.get('created_at', 'N/A')}")
            print(f"📅 Updated: {user.get('updated_at', 'N/A')}")
            print()
    else:
        print("⚠️ No users found in database")
        print("⚠️ This means FCM tokens are NOT being saved!")
    
except Exception as e:
    print(f"\n❌ ERROR: {e}")
    print(f"❌ Error type: {type(e).__name__}")
    import traceback
    print(f"\n📋 Full traceback:")
    print(traceback.format_exc())

print("=" * 80)
