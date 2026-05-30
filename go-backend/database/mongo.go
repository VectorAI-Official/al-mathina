package database

import (
	"context"
	"fmt"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/mongo/readpref"
)

// MongoDB client instance
var MongoClient *mongo.Client

// ConnectMongoDB initializes MongoDB connection with context handling and connection pooling
// Uses the MONGO_URI from environment variables (loaded via config package)
// Connection pool settings optimized for production workload
func ConnectMongoDB(mongoURI string) error {
	// Create context with timeout for connection attempt
	// 10 seconds should be enough for network handshake
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Client options with connection pool configuration
	// These settings match FastAPI backend's pymongo defaults
	clientOptions := options.Client().
		ApplyURI(mongoURI).
		SetMaxPoolSize(100).                       // Max connections in pool (same as Python)
		SetMinPoolSize(0).                         // Avoid forcing idle connections on small Render instances
		SetMaxConnIdleTime(30 * time.Second).      // Close idle connections after 30s
		SetConnectTimeout(10 * time.Second).       // Timeout for establishing new TCP/TLS connections
		SetSocketTimeout(30 * time.Second).        // Timeout for individual socket operations
		SetRetryReads(true).                       // Retry transient read failures when topology changes
		SetRetryWrites(true).                      // Retry transient write failures after elections/network blips
		SetServerSelectionTimeout(5 * time.Second) // Timeout for server selection

	// Connect to MongoDB
	log.Println("🔌 Connecting to MongoDB Atlas...")
	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		return fmt.Errorf("failed to connect to MongoDB: %w", err)
	}

	// Ping the database to verify connection
	// This is critical - connection might succeed but database might be unreachable
	pingCtx, pingCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer pingCancel()

	err = client.Ping(pingCtx, readpref.Primary())
	if err != nil {
		return fmt.Errorf("failed to ping MongoDB: %w", err)
	}

	MongoClient = client
	log.Println("✅ MongoDB connected successfully")
	return nil
}

// GetDatabase returns the MongoDB database instance
// Database name is "almadhinadb" (matches Python backend production config)
func GetDatabase() *mongo.Database {
	if MongoClient == nil {
		log.Fatal("MongoDB client is not initialized. Call ConnectMongoDB first.")
	}
	return MongoClient.Database("almadhinadb")
}

// GetCollection returns a MongoDB collection from the ALmathina database
// Common collections: products, orders, users, category_metadata, most_bought
// Example usage: GetCollection("products")
func GetCollection(collectionName string) *mongo.Collection {
	db := GetDatabase()
	return db.Collection(collectionName)
}

// DisconnectMongoDB closes the MongoDB connection gracefully
// Should be called when shutting down the server (deferred in main.go)
func DisconnectMongoDB() error {
	if MongoClient == nil {
		return nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	err := MongoClient.Disconnect(ctx)
	if err != nil {
		return fmt.Errorf("failed to disconnect MongoDB: %w", err)
	}

	log.Println("👋 MongoDB disconnected")
	return nil
}

// Helper function to create context with timeout for database operations
// Most CRUD operations should complete within 5 seconds
// Use this consistently across all handlers to prevent hanging requests
func GetDBContext() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 5*time.Second)
}

// GetMongoOptions returns a new UpdateOptions instance
// Used for MongoDB update operations with custom options
func GetMongoOptions() *options.UpdateOptions {
	return options.Update()
}
