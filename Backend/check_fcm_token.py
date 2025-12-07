"""
Check if FCM token exists in Supabase database
"""
import asyncio
from database.supabase_client import get_supabase_client

async def check_fcm_token():
    print("🔍 Checking FCM tokens in Supabase...")
    
    try:
        supabase = get_supabase_client()
        
        # Get all users with FCM tokens
        result = supabase.table("users").select("phone, fcm_token, store_name, created_at").execute()
        
        if result.data:
            print(f"✅ Found {len(result.data)} user(s) in database:\n")
            for user in result.data:
                phone = user.get("phone", "N/A")
                token = user.get("fcm_token", "N/A")
                store_name = user.get("store_name", "N/A")
                created_at = user.get("created_at", "N/A")
                
                print(f"📱 Phone: {phone}")
                print(f"🏪 Store: {store_name}")
                print(f"🔑 Token: {token[:50]}..." if token != "N/A" else "🔑 Token: None")
                print(f"📅 Created: {created_at}")
                print("-" * 60)
        else:
            print("❌ No users found in database")
            
    except Exception as e:
        print(f"❌ Error checking database: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(check_fcm_token())
