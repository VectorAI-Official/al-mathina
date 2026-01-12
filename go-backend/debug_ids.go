package main

import (
	"context"
	"fmt"
	"log"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func main() {
	uri := "mongodb+srv://vectoraiautomations_db_user:VectoraI_123@al-mathina.9xt8cbd.mongodb.net/?retryWrites=true&w=majority&appName=al-mathina"
	client, err := mongo.Connect(context.Background(), options.Client().ApplyURI(uri))
	if err != nil {
		log.Fatal(err)
	}
	defer client.Disconnect(context.Background())

	db := client.Database("almadhinadb")

	// 1. Get Product
	prodCol := db.Collection("products")
	var product bson.M
	err = prodCol.FindOne(context.Background(), bson.M{"item_id": "ITEM526"}).Decode(&product)
	if err != nil {
		log.Fatalf("Product not found: %v", err)
	}

	pInvID, _ := product["inventory_id"].(string)
	fmt.Printf("Product InventoryID: '%s'\n Bytes: %x\n", pInvID, pInvID)

	// 2. Get Inventory
	invCol := db.Collection("inventory")
	var inventory bson.M
	// Try finding by the EXACT ID from product
	err = invCol.FindOne(context.Background(), bson.M{"inventory_id": pInvID}).Decode(&inventory)
	if err != nil {
		fmt.Printf("❌ Inventory NOT FOUND using exact match\n")

		// Try finding by name to see what the ID actually is
		name := product["product_name"].(string)
		fmt.Printf("Inventory NOT FOUND for ID '%s'. Searching by name: '%s'\n", pInvID, name)

		// Note: product name might also have issues, but let's try finding ANY inventory to comparing IDs
		// Actually, let's just list the first 5 inventory items and see their ID format
		cursor, _ := invCol.Find(context.Background(), bson.M{}, options.Find().SetLimit(5))
		var items []bson.M
		cursor.All(context.Background(), &items)
		for _, item := range items {
			id := item["inventory_id"].(string)
			fmt.Printf("Sample Inventory ID: '%s' Bytes: %x\n", id, id)
		}
	} else {
		iInvID := inventory["inventory_id"].(string)
		fmt.Printf("✅ Inventory Found! ID: '%s'\n Bytes: %x\n", iInvID, iInvID)
		fmt.Printf("Matches? %v\n", pInvID == iInvID)
	}
}
