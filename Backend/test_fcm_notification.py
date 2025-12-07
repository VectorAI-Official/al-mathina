"""
Test FCM notification sending directly
Run this to test if notifications work
"""
import asyncio
from utils.fcm_service import fcm_service

async def test_notification():
    # Your FCM token from the logs
    fcm_token = "dfwymzH4Sj6WCV98Bt1KhW:APA91bGVXdtWnh7eBBdpseLKqQGSo-BDKI_aoy79LnOgH2SUmNQBGaA9YYa2pBL88HTgDTrmxyU09NTp4opT47AkED2iRtnOG2T7CuEgYc7LXIV9HsnRRRE"
    
    print("🧪 Testing FCM notification...")
    print(f"📱 Sending to token: {fcm_token[:50]}...")
    
    # Test sending order notification
    result = await fcm_service.send_order_notification(
        fcm_token=fcm_token,
        order_id="TEST123",
        total_amount=100.50,
        items_count=3,
        store_name="Test Store"
    )
    
    if result:
        print("✅ Notification sent successfully!")
    else:
        print("❌ Failed to send notification")

if __name__ == "__main__":
    asyncio.run(test_notification())
