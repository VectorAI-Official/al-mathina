#!/usr/bin/env python3
"""
Check Most Bought Collection in MongoDB
Shows all entries and helps debug duplicates
"""

import sys
import os
from pymongo import MongoClient
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

MONGO_URI = os.getenv("MONGO_URI")
MONGO_DB_NAME = os.getenv("MONGO_DB_NAME", "almadhinadb")

def check_most_bought():
    """Check most_bought collection for duplicates and issues"""
    
    print("=" * 80)
    print("🔍 CHECKING MOST BOUGHT COLLECTION")
    print("=" * 80)
    
    # Connect to MongoDB
    client = MongoClient(MONGO_URI)
    db = client[MONGO_DB_NAME]
    most_bought = db.most_bought
    
    # Get all documents
    all_docs = list(most_bought.find({}))
    
    print(f"\n📊 Total documents in most_bought: {len(all_docs)}")
    print("=" * 80)
    
    if len(all_docs) == 0:
        print("✅ Collection is empty - no starred categories")
        return
    
    # Display all documents
    print("\n📋 ALL STARRED CATEGORIES:")
    print("-" * 80)
    
    for idx, doc in enumerate(all_docs, 1):
        print(f"\n{idx}. Document ID: {doc.get('_id')}")
        print(f"   Section: '{doc.get('section')}'")
        print(f"   Main Category: '{doc.get('main_category')}'")
        print(f"   Starred At: {doc.get('starred_at')}")
        
        # Check for potential issues
        section = doc.get('section', '')
        main_cat = doc.get('main_category', '')
        
        issues = []
        if not section:
            issues.append("❌ Missing section")
        if not main_cat:
            issues.append("❌ Missing main_category")
        if section and section != section.strip():
            issues.append(f"⚠️  Section has whitespace: '{section}'")
        if main_cat and main_cat != main_cat.strip():
            issues.append(f"⚠️  Main category has whitespace: '{main_cat}'")
        
        if issues:
            print(f"   ISSUES: {', '.join(issues)}")
    
    # Check for duplicates
    print("\n" + "=" * 80)
    print("🔍 CHECKING FOR DUPLICATES:")
    print("-" * 80)
    
    seen = {}
    duplicates = []
    
    for doc in all_docs:
        key = (doc.get('section'), doc.get('main_category'))
        if key in seen:
            duplicates.append({
                'key': key,
                'doc1_id': seen[key],
                'doc2_id': doc.get('_id')
            })
            print(f"❌ DUPLICATE FOUND!")
            print(f"   Section: '{key[0]}'")
            print(f"   Main Category: '{key[1]}'")
            print(f"   Document IDs: {seen[key]} and {doc.get('_id')}")
        else:
            seen[key] = doc.get('_id')
    
    if not duplicates:
        print("✅ No duplicates found")
    
    # Test query with "Stationary" and "station"
    print("\n" + "=" * 80)
    print("🧪 TESTING SPECIFIC QUERIES:")
    print("-" * 80)
    
    test_cases = [
        ("Stationary", "station"),
        ("Stationary", "Station"),
        ("stationary", "station"),
    ]
    
    for section, main_cat in test_cases:
        result = most_bought.find_one({
            "section": section,
            "main_category": main_cat
        })
        status = "✅ FOUND" if result else "❌ NOT FOUND"
        print(f"{status} - section='{section}', main_category='{main_cat}'")
        if result:
            print(f"         Document ID: {result.get('_id')}")
    
    print("\n" + "=" * 80)
    print("✅ CHECK COMPLETE")
    print("=" * 80)
    
    client.close()

if __name__ == "__main__":
    check_most_bought()
