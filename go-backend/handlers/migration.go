package handlers

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"
	"unicode"

	"al-mathina-backend/database"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// MigrateStockToInventory wipes the inventory collection and creates new inventory items
// for each product, preserving the current stock level.
// POST /admin/api/migration/stock-to-inventory
func MigrateStockToInventory(c *gin.Context) {
	// Use a longer timeout for migration of many items
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	fmt.Println("🚀 STARTING MIGRATION: STOCK TO INVENTORY")

	// 1. Wipe Inventory Collection
	inventoryCol := database.GetCollection("inventory")
	if err := inventoryCol.Drop(ctx); err != nil {
		fmt.Printf("❌ Failed to drop inventory collection: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reset inventory collection"})
		return
	}
	fmt.Println("✅ Inventory collection wiped.")

	// 2. Get All Products
	productsCol := database.GetCollection("products")
	cursor, err := productsCol.Find(ctx, bson.M{})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
		return
	}
	defer cursor.Close(ctx)

	var products []bson.M
	if err := cursor.All(ctx, &products); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode products"})
		return
	}

	fmt.Printf("📦 Found %d products to migrate.\n", len(products))

	migratedCount := 0

	for _, product := range products {
		productID := product["_id"].(primitive.ObjectID)
		// Safely get product name
		productName := "Unknown Product"
		if name, ok := product["product_name"].(string); ok && name != "" {
			productName = name
		} else if name, ok := product["name"].(string); ok && name != "" {
			productName = name
		} else if name, ok := product["name_en"].(string); ok && name != "" {
			productName = name
		}

		fmt.Printf("🔄 Migrating Product: %s (ID: %s)\n", productName, productID.Hex())

		// Extract stock (handle various types if necessary, though usually int32/int64/float64/int)
		var currentStock int32 = 0
		if val, ok := product["stock"]; ok {
			switch v := val.(type) {
			case int32:
				currentStock = v
			case int64:
				currentStock = int32(v)
			case int:
				currentStock = int32(v)
			case float64:
				currentStock = int32(v)
			}
		}

		// Create New Inventory Item
		inventoryID := uuid.New().String()
		newInventoryItem := bson.M{
			"inventory_id":    inventoryID,
			"inventory_name":  productName, // Use Correct Product Name
			"stock_quantity":  currentStock,
			"unit":            "units", // Default unit
			"min_stock_level": 5,       // Default alert level
			"is_active":       true,    // Required for GetAllInventory filter
			"last_updated":    time.Now(),
		}

		_, err := inventoryCol.InsertOne(ctx, newInventoryItem)
		if err != nil {
			fmt.Printf("❌ Failed to create inventory for product %s: %v\n", product["name_en"], err)
			continue
		}

		// Update Product: Link to new inventory and remove 'stock' field
		_, err = productsCol.UpdateOne(
			ctx,
			bson.M{"_id": productID},
			bson.M{
				"$set": bson.M{
					"inventory_id": inventoryID,
					"updated_at":   time.Now(),
				},
				"$unset": bson.M{"stock": ""}, // Remove legacy stock field
			},
		)

		if err != nil {
			fmt.Printf("❌ Failed to update product linkage %s: %v\n", product["name_en"], err)
		} else {
			migratedCount++
		}
	}

	fmt.Printf("✅ MIGRATION COMPLETE. Processed %d products.\n", migratedCount)

	c.JSON(http.StatusOK, gin.H{
		"message":        "Migration completed successfully",
		"migrated_count": migratedCount,
	})
}

// DeduplicateInventory merges duplicate inventory items and updates product links
// POST /admin/api/migration/deduplicate-inventory
func DeduplicateInventory(c *gin.Context) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	fmt.Println("🚀 STARTING INVENTORY DEDUPLICATION")

	inventoryCol := database.GetCollection("inventory")
	productsCol := database.GetCollection("products")

	// 1. Get all inventory items
	cursor, err := inventoryCol.Find(ctx, bson.M{})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory"})
		return
	}
	defer cursor.Close(ctx)

	var items []bson.M
	if err := cursor.All(ctx, &items); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode inventory"})
		return
	}

	// 2. Group by Name (Case-Insensitive) -> List of Items
	grouped := make(map[string][]bson.M)
	for _, item := range items {
		name, ok := item["inventory_name"].(string)
		if !ok {
			continue
		}
		// Normalize name: trim space and whitespace
		if strings.Contains(name, "10ரூ லக்ஸ்") {
			fmt.Printf("DEBUG BYTES for '%s': %x\n", name, name)
		}

		// Aggressive trim function
		cleanName := strings.TrimFunc(name, func(r rune) bool {
			return unicode.IsSpace(r) || r == 0xFEFF || r == 0x200B // Remove BOM and Zero Width Space
		})
		// key := strings.ToLower(cleanName) // Optional: aggressive case-insensitive
		key := cleanName // Group by trimmed name

		grouped[key] = append(grouped[key], item)
	}

	mergedCount := 0
	deletedCount := 0

	// 3. Process groups
	for name, group := range grouped {
		// Even if len(group) == 1, we might want to fix the name if it has spaces?
		// But the loop key 'name' is the CLEAN version.
		// The items inside might have dirty names.

		// If group has only 1 item, but that item's name is dirty, we should clean it.
		if len(group) == 1 {
			item := group[0]
			originalName := item["inventory_name"].(string)
			if originalName != name {
				// Name needs trimming
				inventoryID := item["inventory_id"].(string)
				_, err := inventoryCol.UpdateOne(
					ctx,
					bson.M{"inventory_id": inventoryID},
					bson.M{"$set": bson.M{"inventory_name": name, "updated_at": time.Now()}},
				)
				if err == nil {
					fmt.Printf("✨ Cleaned up name for '%s' -> '%s'\n", originalName, name)
				}
			}
			continue
		}

		fmt.Printf("📦 Processing Duplicate Group: '%s' (%d items)\n", name, len(group))

		// Sort by creation time? Or just pick first as primary.
		// We'll pick the first one in the list as PRIMARY.
		primary := group[0]
		primaryID := primary["inventory_id"].(string)

		totalStock := int32(0)

		// Calculate total stock from all (including primary)
		// And collect IDs to delete (skipping primary)
		var idsToDelete []string

		for _, item := range group {
			// Add stock
			var s int32 = 0
			if val, ok := item["stock_quantity"]; ok {
				switch v := val.(type) {
				case int32:
					s = v
				case int:
					s = int32(v)
				case int64:
					s = int32(v)
				case float64:
					s = int32(v)
				}
			}
			totalStock += s

			itemID := item["inventory_id"].(string)
			if itemID != primaryID {
				idsToDelete = append(idsToDelete, itemID)

				// RE-LINK PRODUCTS associated with this duplicate item to PRIMARY
				_, err := productsCol.UpdateMany(
					ctx,
					bson.M{"inventory_id": itemID},
					bson.M{"$set": bson.M{"inventory_id": primaryID}},
				)
				if err != nil {
					fmt.Printf("❌ Failed to re-link products for duplicate inventory %s: %v\n", itemID, err)
				}
			}
		}

		// Update Primary Stock
		_, err := inventoryCol.UpdateOne(
			ctx,
			bson.M{"inventory_id": primaryID},
			bson.M{"$set": bson.M{
				"stock_quantity": totalStock,
				"inventory_name": name, // Ensure primary has the CLEAN name
				"updated_at":     time.Now(),
				"notes":          "Merged from duplicates",
			}},
		)
		if err != nil {
			fmt.Printf("❌ Failed to update primary item stock %s: %v\n", primaryID, err)
		} else {
			mergedCount++
		}

		// Delete Duplicates
		if len(idsToDelete) > 0 {
			_, err := inventoryCol.DeleteMany(
				ctx,
				bson.M{"inventory_id": bson.M{"$in": idsToDelete}},
			)
			if err != nil {
				fmt.Printf("❌ Failed to delete duplicates for %s: %v\n", name, err)
			} else {
				deletedCount += len(idsToDelete)
				fmt.Printf("✅ Merged %d items into %s (Total Stock: %d)\n", len(idsToDelete), primaryID, totalStock)
			}
		}
	}

	fmt.Printf("✅ DEDUPLICATION COMPLETE. Merged groups: %d, Deleted items: %d\n", mergedCount, deletedCount)

	c.JSON(http.StatusOK, gin.H{
		"message":       "Deduplication completed",
		"merged_groups": mergedCount,
		"deleted_items": deletedCount,
	})
}

// CleanupGarbageData removes specific test data (CrashTest, DedupeTestPS)
// POST /admin/api/migration/cleanup
func CleanupGarbageData(c *gin.Context) {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Minute)
	defer cancel()

	fmt.Println("🧹 STARTING GARBAGE DATA CLEANUP")

	targetNames := []string{"CrashTest", "DedupeTestPS", "dedupetestps", "crashtest"}

	// 1. Delete Products
	productsCol := database.GetCollection("products")
	pRes, err := productsCol.DeleteMany(ctx, bson.M{"product_name": bson.M{"$in": targetNames}})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete products"})
		return
	}
	fmt.Printf("🗑️ Deleted %d products\n", pRes.DeletedCount)

	// 2. Delete Inventory
	inventoryCol := database.GetCollection("inventory")
	iRes, err := inventoryCol.DeleteMany(ctx, bson.M{"inventory_name": bson.M{"$in": targetNames}})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete inventory"})
		return
	}
	fmt.Printf("🗑️ Deleted %d inventory items\n", iRes.DeletedCount)

	c.JSON(http.StatusOK, gin.H{
		"message":           "Cleanup complete",
		"deleted_products":  pRes.DeletedCount,
		"deleted_inventory": iRes.DeletedCount,
	})
}
