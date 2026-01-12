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
	client, err := mongo.Connect(context.Background(), options.Client().ApplyURI("mongodb://localhost:27017"))
	if err != nil {
		log.Fatal(err)
	}
	defer client.Disconnect(context.Background())

	db := client.Database("almadhinadb")
	productsCol := db.Collection("products")
	inventoryCol := db.Collection("inventory")

	targetNames := []string{"CrashTest", "DedupeTestPS", "dedupetestps", "crashtest"}

	// Delete Products
	pResult, err := productsCol.DeleteMany(context.Background(), bson.M{"product_name": bson.M{"$in": targetNames}})
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Deleted %d products with names %v\n", pResult.DeletedCount, targetNames)

	// Delete Inventory
	iResult, err := inventoryCol.DeleteMany(context.Background(), bson.M{"inventory_name": bson.M{"$in": targetNames}})
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("Deleted %d inventory items with names %v\n", iResult.DeletedCount, targetNames)

	// Also check for "undefined" name?
	// Just solely based on user request "CrashTest" "DedupeTestPS".
}
