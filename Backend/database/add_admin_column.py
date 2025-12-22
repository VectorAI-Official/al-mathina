"""
Database Migration: Add is_admin column to users table
Marks specific phone numbers as admin users
"""
import os
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

def add_admin_column():
    """Add is_admin column to users table and mark admin phone numbers"""
    
    # Initialize Supabase client
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY")
    
    if not supabase_url or not supabase_service_key:
        print("❌ ERROR: Supabase credentials not found in environment")
        return False
    
    supabase: Client = create_client(supabase_url, supabase_service_key)
    
    print("=" * 80)
    print("🔧 DATABASE MIGRATION: Adding is_admin column to users table")
    print("=" * 80)
    
    # Admin phone numbers
    admin_phones = ["7339651541", "8870503350", "9487715568"]
    
    try:
        # Step 1: Check current table structure
        print("\n📊 Step 1: Checking current users table structure...")
        response = supabase.table('users').select('*').limit(1).execute()
        if response.data:
            print(f"✅ Current columns: {list(response.data[0].keys())}")
        
        # Step 2: Add is_admin column (if not exists)
        # Note: This uses Supabase's SQL editor or needs to be done via SQL
        print("\n🔧 Step 2: Adding is_admin column...")
        print("⚠️  Note: Column addition should be done via Supabase SQL Editor:")
        print("    ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;")
        
        # Step 3: Fetch all users to check admin phones
        print("\n📋 Step 3: Fetching all users...")
        all_users = supabase.table('users').select('*').execute()
        print(f"✅ Found {len(all_users.data)} users in database")
        
        # Step 4: Update admin users
        print("\n👑 Step 4: Marking admin users...")
        admin_count = 0
        
        for phone in admin_phones:
            # Check if user exists
            user_response = supabase.table('users').select('*').eq('phone', phone).execute()
            
            if user_response.data:
                # User exists - update to admin
                update_response = supabase.table('users').update({
                    'is_admin': True
                }).eq('phone', phone).execute()
                
                print(f"   ✅ {phone} - Marked as ADMIN (existing user)")
                admin_count += 1
            else:
                # User doesn't exist - create admin user
                insert_response = supabase.table('users').insert({
                    'phone': phone,
                    'is_admin': True,
                    'name': f'Admin {phone[-4:]}',
                    'email': f'admin{phone[-4:]}@almathina.com'
                }).execute()
                
                print(f"   ✅ {phone} - Created as NEW ADMIN user")
                admin_count += 1
        
        # Step 5: Set all non-admin users to is_admin = false
        print("\n👤 Step 5: Setting non-admin users to is_admin = false...")
        for user in all_users.data:
            if user['phone'] not in admin_phones:
                supabase.table('users').update({
                    'is_admin': False
                }).eq('phone', user['phone']).execute()
        
        print(f"✅ Set {len(all_users.data) - admin_count} users to non-admin")
        
        # Step 6: Verify admin users
        print("\n🔍 Step 6: Verifying admin users...")
        admin_users = supabase.table('users').select('*').eq('is_admin', True).execute()
        
        print(f"\n{'='*80}")
        print(f"📊 MIGRATION SUMMARY")
        print(f"{'='*80}")
        print(f"Total users: {len(all_users.data)}")
        print(f"Admin users: {len(admin_users.data)}")
        print(f"\n👑 Admin Users:")
        for admin in admin_users.data:
            print(f"   - {admin['phone']} ({admin.get('name', 'N/A')}) - {admin.get('email', 'N/A')}")
        
        print(f"\n{'='*80}")
        print("✅ MIGRATION COMPLETED SUCCESSFULLY")
        print(f"{'='*80}\n")
        
        return True
        
    except Exception as e:
        print(f"\n❌ ERROR during migration: {str(e)}")
        print(f"Error type: {type(e).__name__}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("\n🚀 Starting database migration...\n")
    success = add_admin_column()
    
    if success:
        print("\n✅ Migration completed successfully!")
        print("⚠️  IMPORTANT: If is_admin column doesn't exist, run this SQL in Supabase:")
        print("    ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;")
    else:
        print("\n❌ Migration failed!")
    
    print("\n" + "="*80 + "\n")
