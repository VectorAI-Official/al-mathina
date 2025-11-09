"""Backfill missing deterministic category UUID fields for existing products.

Why: Earlier products inserted via compatibility endpoint lacked category_section_id,
category_main_id, and category_sub_id. Cascading renames based only on UUID missed
those products, so their displayed main category names did not update.

Run:
    cd Backend
    python tools/backfill_missing_category_ids.py

This script:
 1. Scans products missing any of the category_*_id fields.
 2. Generates deterministic UUID v5 using generate_category_id(section, main, sub)
    from admin_production route logic (duplicated minimally here to avoid import side effects).
 3. Updates products atomically.
 4. Prints summary counts.

Safe: Only writes missing *_id fields; does not alter existing values.
"""
from datetime import datetime
import uuid
from config_production import get_mongo_db


def generate_category_id(section: str, main_category: str = None, subcategory: str = None) -> str:
    key = f"{section or ''}|{main_category or ''}|{subcategory or ''}"
    return str(uuid.uuid5(uuid.NAMESPACE_DNS, key))


def main():
    db = get_mongo_db()
    products = db.products

    cursor = products.find({})
    total = 0
    updated_section = 0
    updated_main = 0
    updated_sub = 0

    for prod in cursor:
        total += 1
        section = prod.get("category_section")
        main = prod.get("category_main")
        sub = prod.get("category_sub")

        update_doc = {}
        if section and not prod.get("category_section_id"):
            update_doc["category_section_id"] = generate_category_id(section)
        if section and main and not prod.get("category_main_id"):
            update_doc["category_main_id"] = generate_category_id(section, main)
        if section and main and sub and not prod.get("category_sub_id"):
            update_doc["category_sub_id"] = generate_category_id(section, main, sub)

        if update_doc:
            update_doc["updated_at"] = datetime.utcnow()
            res = products.update_one({"_id": prod["_id"]}, {"$set": update_doc})
            if res.modified_count:
                if "category_section_id" in update_doc:
                    updated_section += 1
                if "category_main_id" in update_doc:
                    updated_main += 1
                if "category_sub_id" in update_doc:
                    updated_sub += 1

    print("Backfill complete:")
    print(f"  Total products scanned: {total}")
    print(f"  Added section UUIDs: {updated_section}")
    print(f"  Added main UUIDs: {updated_main}")
    print(f"  Added sub UUIDs: {updated_sub}")


if __name__ == "__main__":
    main()
