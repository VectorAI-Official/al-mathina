package handlers

import (
	"context"
	"log"
	"net/http"
	"time"

	"al-mathina-backend/database"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
)

// SyncStockToProducts iterates through inventory and updates linked products' stock
// This is a "Plan B" fix for the aggregation failure
// POST /admin/api/migration/sync-stock
func SyncStockToProducts(c *gin.Context) {
	_, cancel := database.GetDBContext() // Use long timeout if needed? Default is 5s which might be short
	// Actually, let's use a longer timeout for this batch operation
	// But GetDBContext is hardcoded. Let's just create a new context here.
	cancel() // Cancel the default one immediately

	// Create a new context with 2 minute timeout
	longCtx, longCancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer longCancel()

	inventoryCol := database.GetCollection("inventory")
	productsCol := database.GetCollection("products")

	log.Println("🔄 Starting Stock Sync: Inventory -> Products")

	// 1. Fetch ALL inventory items
	cursor, err := inventoryCol.Find(longCtx, bson.M{})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory"})
		return
	}
	defer cursor.Close(longCtx)

	updatedCount := 0
	errorCount := 0

	for cursor.Next(longCtx) {
		var item struct {
			InventoryID   string `bson:"inventory_id"`
			StockQuantity int    `bson:"stock_quantity"`
		}
		if err := cursor.Decode(&item); err != nil {
			log.Printf("⚠️ Sync decode error: %v", err)
			continue
		}

		// 2. Update linked products
		// Set stock = item.StockQuantity
		filter := bson.M{"inventory_id": item.InventoryID}
		update := bson.M{
			"$set": bson.M{
				"stock": item.StockQuantity,
				// Also update in_stock/active status?
				// Python backend logic: if stock > 0 -> active=True?
				// User only asked for stock column. Let's stick to that to be safe.
			},
		}

		result, err := productsCol.UpdateMany(longCtx, filter, update)
		if err != nil {
			log.Printf("❌ Failed to sync stock for inv %s: %v", item.InventoryID, err)
			errorCount++
		} else {
			updatedCount += int(result.ModifiedCount)
		}
	}

	log.Printf("✅ Stock Sync Complete. Updated %d products. Errors: %d", updatedCount, errorCount)

	c.JSON(http.StatusOK, gin.H{
		"message":       "Stock sync completed",
		"updated_count": updatedCount,
		"errors":        errorCount,
	})
}
