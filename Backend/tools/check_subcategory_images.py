import requests
from urllib.parse import quote

BASE = "http://127.0.0.1:8000/api/flutter"


def safe_get(url):
    try:
        r = requests.get(url, timeout=5)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        print(f"ERROR calling {url}: {e}")
        return None


if __name__ == '__main__':
    home = safe_get(f"{BASE}/home")
    if not home:
        print("Failed to fetch home. Make sure backend is running and accessible at http://127.0.0.1:8000")
        exit(1)

    mains = []

    # Best sellers
    bs = home.get("best_sellers", {}).get("main_categories", [])
    for m in bs:
        mains.append((m.get("section", "Best Seller"), m.get("main_category")))

    # Regular sections
    for sec in home.get("sections", []):
        section_name = sec.get("section_name")
        for m in sec.get("main_categories", []):
            mains.append((section_name, m.get("main_category")))

    print(f"Found {len(mains)} main categories to inspect for subcategory images.")

    for section, main_cat in mains:
        if not section or not main_cat:
            continue
        url = f"{BASE}/main-category/{quote(section, safe='')}/{quote(main_cat, safe='')}/subcategories"
        data = safe_get(url)
        if not data:
            continue
        subcats = data.get("subcategories", [])
        print(f"\nSection: {section} -> Main: {main_cat} ({len(subcats)} subcategories)")
        for s in subcats:
            name = s.get("name")
            image_url = s.get("image_url")
            print(f"  - {name}: image_url={repr(image_url)}")
