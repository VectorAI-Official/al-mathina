"""
Direct Supabase FCM token check with hardcoded credentials
"""
from supabase import create_client, Client

# Your credentials from .env.local.template
SUPABASE_URL = "https://zuhkndylyavedmfrovsj.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1aGtuZHlseWF2ZWRtZnJvdnNqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTA4NzY0MCwiZXhwIjoyMDgwNjYzNjQwfQ.a9TkJJSVbFjmFQ8BkB1Vnzp1uGFpPKVCTjteCdAu_Pw"

print("=" * 80)
print("🔍 DIRECT SUPABASE FCM TOKEN CHECK")
print("=" * 80)
print(f"📡 URL: {SUPABASE_URL}")
print("=" * 80)

try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    print("✅ Supabase client created\n")
    
    # Query users table
    print("📋 Querying users table for FCM tokens...")
    result = supabase.table("users").select("phone, fcm_token, store_name, created_at, updated_at").execute()
    
    print(f"✅ Query successful!\n")
    print(f"📊 Total users found: {len(result.data)}\n")
    
    if result.data:
        for i, user in enumerate(result.data, 1):
            print("=" * 80)
            print(f"👤 USER #{i}")
            print("=" * 80)
            phone = user.get('phone', 'N/A')
            fcm_token = user.get('fcm_token')
            store_name = user.get('store_name', 'N/A')
            
            print(f"📱 Phone: {phone}")
            print(f"🏪 Store: {store_name}")
            
            if fcm_token:
                print(f"✅ FCM Token EXISTS!")
                print(f"   First 50 chars: {fcm_token[:50]}...")
                print(f"   Length: {len(fcm_token)} characters")
            else:
                print(f"❌ FCM Token: NONE (Not saved)")
            
            print(f"📅 Created: {user.get('created_at', 'N/A')}")
            print(f"📅 Updated: {user.get('updated_at', 'N/A')}")
            print()
        
        # Check specifically for your phone
        your_phone = "+918870986738"
        your_user = next((u for u in result.data if u.get('phone') == your_phone), None)
        
        print("=" * 80)
        print(f"🔍 CHECKING YOUR PHONE: {your_phone}")
        print("=" * 80)
        if your_user:
            if your_user.get('fcm_token'):
                print("✅ YOUR FCM TOKEN IS SAVED!")
                print("✅ Notifications SHOULD work (if backend sends them)")
            else:
                print("❌ YOUR FCM TOKEN IS NOT SAVED!")
                print("❌ This is why you're not getting notifications")
                print("⚠️  Flutter app needs to save the token after login")
        else:
            print("❌ YOUR PHONE NUMBER NOT FOUND IN DATABASE!")
            print("❌ FCM token was never saved")
            print("⚠️  Check Flutter logs for token save errors")
        
    else:
        print("❌ NO USERS IN DATABASE!")
        print("❌ FCM tokens are NOT being saved at all")
        print("\n🔍 Possible issues:")
        print("   1. Flutter app not calling /api/user/fcm-token endpoint")
        print("   2. Backend FCM route not working")
        print("   3. Table 'users' doesn't exist in Supabase")
    
except Exception as e:
    print(f"\n❌ ERROR: {e}")
    print(f"❌ Error type: {type(e).__name__}")
    import traceback
    print(f"\n📋 Traceback:")
    print(traceback.format_exc())

print("=" * 80)
