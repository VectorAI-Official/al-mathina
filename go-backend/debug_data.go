package main

import (
	"context"
	"encoding/json"
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

	// Find products with names "CrashTest" or "DedupeTestPS"
	filter := bson.M{"product_name": bson.M{"$in": []string{"CrashTest", "DedupeTestPS"}}}
	cursor, err := productsCol.Find(context.Background(), filter)
	if err != nil {
		log.Fatal(err)
	}

	var products []bson.M
	if err := cursor.All(context.Background(), &products); err != nil {
		log.Fatal(err)
	}

	fmt.Printf("Found %d products\n", len(products))
	for _, p := range products {
		jsonBytes, _ := json.MarshalIndent(p, "", "  ")
		fmt.Println(string(jsonBytes))
	}
}
