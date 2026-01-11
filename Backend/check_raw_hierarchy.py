#!/usr/bin/env python3
from pymongo import MongoClient
import json

client = MongoClient('mongodb://localhost:27017/')
db = client['almadhinadb']

print("=== RAW HIERARCHY DOCUMENTS ===\n")
for doc in db['category_hierarchy'].find():
    print(json.dumps(doc, indent=2, default=str))
    print("\n" + "="*60 + "\n")
