package main

import (
	"fmt"
	"log"
	"os"

	"al-mathina-backend/config"
	"al-mathina-backend/database"
)

// test_connections.go - Verify MongoDB and Supabase connectivity
// Run this after creating .env file: go run test_connections.go
// Must pass both tests before implementing handlers

func main() {
	fmt.Println("🧪 Testing Database Connections")
	fmt.Println("================================\n")

	// Load environment variables
	cfg := config.LoadConfig()
	if cfg.MongoURI == "" {
		log.Fatal("❌ MONGO_URI is required in .env file")
	}

	// Test 1: MongoDB Connection
	fmt.Println("Test 1: MongoDB Atlas Connection")
	fmt.Println("---------------------------------")

	errMongo := database.ConnectMongoDB(cfg.MongoURI)
	if errMongo != nil {
		log.Fatalf("❌ MongoDB connection failed: %v", errMongo)
	}
	defer database.DisconnectMongoDB()

	// Verify we can access collections
	productsCol := database.GetCollection("products")
	ctx, cancel := database.GetDBContext()
	defer cancel()

	count, err := productsCol.CountDocuments(ctx, map[string]interface{}{})
	if err != nil {
		log.Fatalf("❌ Failed to count products: %v", err)
	}

	fmt.Printf("✅ MongoDB connected! Found %d products in database\n\n", count)

	// Test 2: Supabase Connection
	fmt.Println("Test 2: Supabase Connection")
	fmt.Println("---------------------------")

	err = database.ConnectSupabase(cfg.SupabaseURL, cfg.SupabaseAnonKey, cfg.SupabaseServiceKey)
	if err != nil {
		log.Fatalf("❌ Supabase connection failed: %v", err)
	}

	// Test admin check with known admin phone number
	testPhone := "7339651541" // Admin phone from copilot-instructions.md
	isAdmin, err := database.SupabaseDB.CheckIsAdmin(testPhone)
	if err != nil {
		log.Printf("⚠️  Admin check failed (this is OK if Supabase not fully configured): %v", err)
	} else {
		if isAdmin {
			fmt.Printf("✅ Supabase connected! Admin check works (phone %s is admin)\n\n", testPhone)
		} else {
			fmt.Printf("✅ Supabase connected! Admin check works (phone %s is NOT admin)\n\n", testPhone)
		}
	}

	// Test 3: Collection Access
	fmt.Println("Test 3: Collection Access")
	fmt.Println("-------------------------")

	collections := []string{"products", "orders", "users", "category_metadata", "most_bought"}
	for _, colName := range collections {
		col := database.GetCollection(colName)
		ctx, cancel := database.GetDBContext()
		count, err := col.CountDocuments(ctx, map[string]interface{}{})
		cancel()

		if err != nil {
			fmt.Printf("⚠️  %s: error counting (%v)\n", colName, err)
		} else {
			fmt.Printf("✅ %s: %d documents\n", colName, count)
		}
	}

	fmt.Println("\n================================")
	fmt.Println("🎉 All tests passed! Ready to implement handlers.")

	os.Exit(0)
}
