"""
Quick FCM token check - Run this on Render shell
"""
from database.supabase_client import get_supabase_client

print("Checking Supabase for FCM tokens...")
try:
    supabase = get_supabase_client()
    result = supabase.table("users").select("phone, fcm_token, store_name, created_at").execute()
    
    if result.data:
        print(f"\nFound {len(result.data)} users:")
        for user in result.data:
            token = user.get('fcm_token')
            print(f"\n📱 Phone: {user.get('phone')}")
            print(f"🏪 Store: {user.get('store_name', 'N/A')}")
            print(f"🔑 Token: {token[:50] + '...' if token else '❌ NONE'}")
    else:
        print("❌ No users found! FCM tokens NOT being saved!")
except Exception as e:
    print(f"❌ Error: {e}")
