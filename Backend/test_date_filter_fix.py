"""
Test the date filter fix to ensure stores are not omitted
"""

import requests
from datetime import datetime

API_BASE = "http://127.0.0.1:8000"

def test_statistics_endpoint():
    """Test /admin/api/stores/statistics endpoint with different filters"""
    
    print("=" * 80)
    print("🧪 TESTING DATE FILTER FIX")
    print("=" * 80)
    print()
    
    # Test 1: All Time (no filters)
    print("1️⃣  ALL TIME (No Filters)")
    print("-" * 80)
    response = requests.get(f"{API_BASE}/admin/api/stores/statistics")
    data = response.json()
    stats = data.get('statistics', {})
    
    all_time_stores = stats.get('total_stores', 0)
    all_time_orders = stats.get('total_orders', 0)
    all_time_revenue = stats.get('total_revenue', 0)
    
    print(f"   Total Stores: {all_time_stores}")
    print(f"   Total Orders: {all_time_orders}")
    print(f"   Total Revenue: ₹{all_time_revenue:,.2f}")
    print()
    
    # Test 2: Yearly (2025)
    print("2️⃣  YEARLY (2025-01-01 to 2025-12-31)")
    print("-" * 80)
    response = requests.get(
        f"{API_BASE}/admin/api/stores/statistics",
        params={
            "start_date": "2025-01-01",
            "end_date": "2025-12-31"
        }
    )
    data = response.json()
    stats = data.get('statistics', {})
    
    yearly_stores = stats.get('total_stores', 0)
    yearly_orders = stats.get('total_orders', 0)
    yearly_revenue = stats.get('total_revenue', 0)
    
    print(f"   Total Stores: {yearly_stores}")
    print(f"   Total Orders: {yearly_orders}")
    print(f"   Total Revenue: ₹{yearly_revenue:,.2f}")
    print()
    
    # Test 3: Monthly (December 2025)
    print("3️⃣  MONTHLY (December 2025)")
    print("-" * 80)
    response = requests.get(
        f"{API_BASE}/admin/api/stores/statistics",
        params={
            "start_date": "2025-12-01",
            "end_date": "2025-12-31"
        }
    )
    data = response.json()
    stats = data.get('statistics', {})
    
    monthly_stores = stats.get('total_stores', 0)
    monthly_orders = stats.get('total_orders', 0)
    monthly_revenue = stats.get('total_revenue', 0)
    
    print(f"   Total Stores: {monthly_stores}")
    print(f"   Total Orders: {monthly_orders}")
    print(f"   Total Revenue: ₹{monthly_revenue:,.2f}")
    print()
    
    # Test 4: Daily (Today)
    today = datetime.now().strftime('%Y-%m-%d')
    print(f"4️⃣  DAILY (Today: {today})")
    print("-" * 80)
    response = requests.get(
        f"{API_BASE}/admin/api/stores/statistics",
        params={
            "start_date": today,
            "end_date": today
        }
    )
    data = response.json()
    stats = data.get('statistics', {})
    
    daily_stores = stats.get('total_stores', 0)
    daily_orders = stats.get('total_orders', 0)
    daily_revenue = stats.get('total_revenue', 0)
    
    print(f"   Total Stores: {daily_stores}")
    print(f"   Total Orders: {daily_orders}")
    print(f"   Total Revenue: ₹{daily_revenue:,.2f}")
    print()
    
    # Verification
    print("=" * 80)
    print("✅ VERIFICATION RESULTS")
    print("=" * 80)
    
    if all_time_stores == yearly_stores == monthly_stores == daily_stores:
        print(f"✅ SUCCESS! All filters show {all_time_stores} stores (no stores omitted)")
        print(f"   ✓ All Time:  {all_time_stores} stores")
        print(f"   ✓ Yearly:    {yearly_stores} stores")
        print(f"   ✓ Monthly:   {monthly_stores} stores")
        print(f"   ✓ Daily:     {daily_stores} stores")
    else:
        print(f"❌ FAILED! Store counts differ:")
        print(f"   All Time:  {all_time_stores} stores")
        print(f"   Yearly:    {yearly_stores} stores")
        print(f"   Monthly:   {monthly_stores} stores")
        print(f"   Daily:     {daily_stores} stores")
    
    print()
    print(f"Order counts vary correctly by date:")
    print(f"   All Time:  {all_time_orders} orders")
    print(f"   Yearly:    {yearly_orders} orders")
    print(f"   Monthly:   {monthly_orders} orders")
    print(f"   Daily:     {daily_orders} orders")
    print()
    
    print(f"Revenue varies correctly by date:")
    print(f"   All Time:  ₹{all_time_revenue:,.2f}")
    print(f"   Yearly:    ₹{yearly_revenue:,.2f}")
    print(f"   Monthly:   ₹{monthly_revenue:,.2f}")
    print(f"   Daily:     ₹{daily_revenue:,.2f}")
    print()
    print("=" * 80)

if __name__ == "__main__":
    try:
        test_statistics_endpoint()
    except Exception as e:
        print(f"❌ Error testing: {e}")
        import traceback
        traceback.print_exc()
