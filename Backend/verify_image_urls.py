"""
Verify both old and new URLs to confirm migration success
"""
import requests

def check_image_urls():
    old_url = "https://res.cloudinary.com/vectorai/image/upload/v1762548713/almathina/1000644530_400x400.jpg"
    new_url = "https://res.cloudinary.com/al-mathina/image/upload/v1762878355/almathina/1000644530_400x400.jpg"
    
    print("=" * 80)
    print("🔍 VERIFYING IMAGE URLs")
    print("=" * 80)
    print()
    
    # Check OLD URL (should be deleted/not found)
    print("📥 Checking OLD URL...")
    print(f"   URL: {old_url}")
    try:
        response = requests.head(old_url, timeout=10)
        if response.status_code == 200:
            print(f"   ⚠️  Status: {response.status_code} - IMAGE STILL EXISTS (not deleted)")
        elif response.status_code == 404:
            print(f"   ✅ Status: {response.status_code} - IMAGE DELETED (as expected)")
        else:
            print(f"   Status: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    print()
    
    # Check NEW URL (should be accessible)
    print("📥 Checking NEW URL...")
    print(f"   URL: {new_url}")
    try:
        response = requests.head(new_url, timeout=10)
        if response.status_code == 200:
            print(f"   ✅ Status: {response.status_code} - IMAGE ACCESSIBLE")
            print(f"   ✅ Content-Type: {response.headers.get('Content-Type', 'N/A')}")
            print(f"   ✅ Content-Length: {response.headers.get('Content-Length', 'N/A')} bytes")
        else:
            print(f"   ❌ Status: {response.status_code} - IMAGE NOT ACCESSIBLE")
    except Exception as e:
        print(f"   ❌ Error: {e}")
    
    print()
    print("=" * 80)
    print("📝 SUMMARY")
    print("=" * 80)
    print()
    print("✅ Migration verification complete!")
    print()
    print("To view the image in browser, open:")
    print(new_url)
    print()

if __name__ == '__main__':
    check_image_urls()
