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
	invCol := db.Collection("inventory")

	var result bson.M
	err = invCol.FindOne(context.Background(), bson.M{"inventory_id": "2a024045-bb14-44cb-9d68-2efad3f48f74"}).Decode(&result)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("Inventory Item Stock: %v\n", result["stock_quantity"])
}
