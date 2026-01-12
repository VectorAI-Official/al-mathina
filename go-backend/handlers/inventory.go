package handlers

import (
	"fmt"
	"log"
	"math"
	"net/http"
	"strconv"
	"time"

	"al-mathina-backend/database"
	"al-mathina-backend/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ===== INVENTORY MANAGEMENT HANDLERS =====

// GetAllInventory retrieves all inventory items with optional filters
// GET /admin/api/inventory?search=sugar&section=Provisions&low_stock=true
// GetAllInventory retrieves all inventory items with optional filters and pagination
// GET /admin/api/inventory?page=1&limit=50&search=sugar&section=Provisions&low_stock=true
func GetAllInventory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	inventoryCol := database.GetCollection("inventory")

	// Pagination parameters
	pageStr := c.DefaultQuery("page", "1")
	limitStr := c.DefaultQuery("limit", "20")
	page, _ := strconv.Atoi(pageStr)
	limit, _ := strconv.Atoi(limitStr)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}
	skip := (page - 1) * limit

	// Build filter
	filter := bson.M{"is_active": true}

	// Search by inventory name
	if search := c.Query("search"); search != "" {
		filter["inventory_name"] = bson.M{"$regex": search, "$options": "i"}
	}

	// Filter by section
	if section := c.Query("section"); section != "" {
		filter["section"] = section
	}

	// Filter by low stock
	if lowStock := c.Query("low_stock"); lowStock == "true" {
		filter["$expr"] = bson.M{"$lte": []interface{}{"$stock_quantity", "$low_stock_threshold"}}
	} else if stockStatus := c.Query("stock_status"); stockStatus != "" {
		// Support precise stock status filtering if needed by frontend
		if stockStatus == "out_of_stock" {
			filter["stock_quantity"] = 0
		} else if stockStatus == "in_stock" {
			filter["$expr"] = bson.M{"$gt": []interface{}{"$stock_quantity", "$low_stock_threshold"}}
		}
	}

	// Get total count for pagination
	totalCount, err := inventoryCol.CountDocuments(ctx, filter)
	if err != nil {
		log.Printf("❌ Error counting inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count inventory"})
		return
	}

	// Sort by inventory name
	opts := options.Find().
		SetSort(bson.D{{Key: "inventory_name", Value: 1}}).
		SetSkip(int64(skip)).
		SetLimit(int64(limit))

	cursor, err := inventoryCol.Find(ctx, filter, opts)
	if err != nil {
		log.Printf("❌ Error fetching inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory"})
		return
	}
	defer cursor.Close(ctx)

	var inventoryItems []models.Inventory
	if err := cursor.All(ctx, &inventoryItems); err != nil {
		log.Printf("❌ Error decoding inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode inventory"})
		return
	}

	// If no items found on this page, return empty list immediately
	if len(inventoryItems) == 0 {
		c.JSON(http.StatusOK, gin.H{
			"inventory":   []models.Inventory{}, // Empty list
			"count":       0,
			"total_count": totalCount,
			"page":        page,
			"total_pages": int(math.Ceil(float64(totalCount) / float64(limit))),
		})
		return
	}

	// Count linked products efficiently using Aggregation (avoids N+1 problem)
	productsCol := database.GetCollection("products")
	type InventoryWithCount struct {
		models.Inventory    `bson:",inline"`
		LinkedProductsCount int `json:"linked_products_count" bson:"linked_products_count"`
	}

	// 1. Extract all Inventory IDs for CURRENT PAGE ONLY
	inventoryIDs := make([]string, len(inventoryItems))
	for i, item := range inventoryItems {
		inventoryIDs[i] = item.InventoryID
	}

	// 2. Aggregate counts for these IDs
	pipeline := mongo.Pipeline{
		{{Key: "$match", Value: bson.M{
			"inventory_id": bson.M{"$in": inventoryIDs},
			"$or": []bson.M{
				{"active": true},
				{"active": bson.M{"$exists": false}}, // Legacy support
			},
		}}},
		{{Key: "$group", Value: bson.M{
			"_id":   "$inventory_id",
			"count": bson.M{"$sum": 1},
		}}},
	}

	cursorCounts, err := productsCol.Aggregate(ctx, pipeline)
	countsMap := make(map[string]int)

	if err == nil {
		defer cursorCounts.Close(ctx)
		var results []struct {
			ID    string `bson:"_id"`
			Count int    `bson:"count"`
		}
		if err := cursorCounts.All(ctx, &results); err == nil {
			for _, res := range results {
				countsMap[res.ID] = res.Count
			}
		} else {
			log.Printf("⚠️ Error decoding aggregated counts: %v", err)
		}
	} else {
		log.Printf("⚠️ Error aggregating product counts: %v", err)
	}

	// 3. Map counts back to inventory items
	var inventoryWithCounts []InventoryWithCount
	for _, item := range inventoryItems {
		inventoryWithCounts = append(inventoryWithCounts, InventoryWithCount{
			Inventory:           item,
			LinkedProductsCount: countsMap[item.InventoryID],
		})
	}

	log.Printf("✅ Retrieved page %d inventory items (%d items)", page, len(inventoryWithCounts))
	c.JSON(http.StatusOK, gin.H{
		"inventory":   inventoryWithCounts,
		"count":       len(inventoryWithCounts),
		"total_count": totalCount,
		"page":        page,
		"total_pages": int(math.Ceil(float64(totalCount) / float64(limit))),
	})
}

// GetInventoryByID retrieves a single inventory item with linked products
// GET /admin/api/inventory/:inventory_id
func GetInventoryByID(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	inventoryID := c.Param("inventory_id")
	inventoryCol := database.GetCollection("inventory")
	productsCol := database.GetCollection("products")

	// Get inventory item
	var inventory models.Inventory
	err := inventoryCol.FindOne(ctx, bson.M{"inventory_id": inventoryID}).Decode(&inventory)
	if err == mongo.ErrNoDocuments {
		c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found"})
		return
	}
	if err != nil {
		log.Printf("❌ Error fetching inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory"})
		return
	}

	// Get linked products
	cursor, err := productsCol.Find(ctx, bson.M{"inventory_id": inventoryID})
	if err != nil {
		log.Printf("❌ Error fetching linked products: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch linked products"})
		return
	}
	defer cursor.Close(ctx)

	var linkedProducts []bson.M
	if err := cursor.All(ctx, &linkedProducts); err != nil {
		log.Printf("❌ Error decoding linked products: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode linked products"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"inventory":       inventory,
		"linked_products": linkedProducts,
	})
}

// CreateInventory creates a new inventory item
// POST /admin/api/inventory
func CreateInventory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	var inventory models.Inventory
	if err := c.ShouldBindJSON(&inventory); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data", "details": err.Error()})
		return
	}

	// Generate inventory ID
	inventory.InventoryID = fmt.Sprintf("INV-%d", time.Now().Unix())
	inventory.CreatedAt = time.Now()
	inventory.UpdatedAt = time.Now()
	inventory.IsActive = true

	// Set default low stock threshold if not provided
	if inventory.LowStockThreshold == 0 {
		inventory.LowStockThreshold = 10
	}

	// Check if inventory name already exists (Unique Constraint)
	inventoryCol := database.GetCollection("inventory")
	count, err := inventoryCol.CountDocuments(ctx, bson.M{"inventory_name": inventory.InventoryName})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check inventory uniqueness"})
		return
	}
	if count > 0 {
		c.JSON(http.StatusConflict, gin.H{"error": fmt.Sprintf("Inventory item with name '%s' already exists", inventory.InventoryName)})
		return
	}

	// Initialize PiecesPerUnit and TotalStock if needed
	if inventory.PiecesPerUnit < 1 {
		inventory.PiecesPerUnit = 1
	}
	// If TotalStock is not provided (or 0), calculate it from StockQuantity * PPU
	// Note: We allow TotalStock to be 0 if StockQuantity is 0.
	if inventory.TotalStock == 0 && inventory.StockQuantity > 0 {
		inventory.TotalStock = inventory.StockQuantity * inventory.PiecesPerUnit
	} else if inventory.TotalStock == 0 && inventory.StockQuantity == 0 {
		inventory.TotalStock = 0
	}
	// If it is provided, we trust the frontend

	_, err = inventoryCol.InsertOne(ctx, inventory)
	if err != nil {
		log.Printf("❌ Error creating inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create inventory"})
		return
	}

	log.Printf("✅ Created inventory: %s (%s)", inventory.InventoryName, inventory.InventoryID)
	c.JSON(http.StatusCreated, gin.H{
		"message":      "Inventory created successfully",
		"inventory_id": inventory.InventoryID,
		"inventory":    inventory,
	})
}

// UpdateInventory updates an existing inventory item
// PUT /admin/api/inventory/:inventory_id
func UpdateInventory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	inventoryID := c.Param("inventory_id")
	var updates bson.M
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data", "details": err.Error()})
		return
	}

	// Always update the updated_at timestamp
	updates["updated_at"] = time.Now()

	inventoryCol := database.GetCollection("inventory")

	// Check for unique name conflict if name is being updated
	if newName, ok := updates["inventory_name"].(string); ok && newName != "" {
		// Find any OTHER item with this name
		count, err := inventoryCol.CountDocuments(ctx, bson.M{
			"inventory_name": newName,
			"inventory_id":   bson.M{"$ne": inventoryID}, // Exclude self
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check name uniqueness"})
			return
		}
		if count > 0 {
			c.JSON(http.StatusConflict, gin.H{"error": fmt.Sprintf("Inventory item with name '%s' already exists", newName)})
			return
		}
	}
	result, err := inventoryCol.UpdateOne(
		ctx,
		bson.M{"inventory_id": inventoryID},
		bson.M{"$set": updates},
	)

	if err != nil {
		log.Printf("❌ Error updating inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update inventory"})
		return
	}

	// NO AUTO-SYNC: stock_quantity and total_stock are independent
	// Admin manually sets both. Flutter reads stock_quantity via product.stock.

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found"})
		return
	}

	// AUTO-SYNC: If stock_quantity was updated, sync it to linked products
	if newQty, ok := updates["stock_quantity"].(float64); ok { // JSON numbers often come as float64
		go func() {
			ctx, cancel := database.GetDBContext()
			defer cancel()
			_, err := database.GetCollection("products").UpdateMany(
				ctx,
				bson.M{"inventory_id": inventoryID},
				bson.M{"$set": bson.M{"stock": int(newQty), "updated_at": time.Now()}},
			)
			if err != nil {
				log.Printf("⚠️ Failed to auto-sync products for inventory %s: %v", inventoryID, err)
			} else {
				log.Printf("✅ Auto-synced products for inventory %s to stock %d", inventoryID, int(newQty))
			}
		}()
	} else if newQty, ok := updates["stock_quantity"].(int32); ok {
		go func() {
			ctx, cancel := database.GetDBContext()
			defer cancel()
			_, err := database.GetCollection("products").UpdateMany(
				ctx,
				bson.M{"inventory_id": inventoryID},
				bson.M{"$set": bson.M{"stock": int(newQty), "updated_at": time.Now()}},
			)
			if err != nil {
				log.Printf("⚠️ Failed to auto-sync products for inventory %s: %v", inventoryID, err)
			} else {
				log.Printf("✅ Auto-synced products for inventory %s to stock %d", inventoryID, int(newQty))
			}
		}()
	}

	log.Printf("✅ Updated inventory: %s", inventoryID)
	c.JSON(http.StatusOK, gin.H{
		"message":      "Inventory updated successfully",
		"inventory_id": inventoryID,
	})
}

// UpdateInventoryStock updates stock quantity with history tracking
// POST /admin/api/inventory/:inventory_id/stock
func UpdateInventoryStock(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	inventoryID := c.Param("inventory_id")

	var update models.InventoryStockUpdate
	if err := c.ShouldBindJSON(&update); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data", "details": err.Error()})
		return
	}

	update.InventoryID = inventoryID
	update.Timestamp = time.Now()

	inventoryCol := database.GetCollection("inventory")
	historyCol := database.GetCollection("inventory_history")

	// Get current inventory
	var inventory models.Inventory
	err := inventoryCol.FindOne(ctx, bson.M{"inventory_id": inventoryID}).Decode(&inventory)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found"})
		return
	}

	// Calculate new quantity
	quantityBefore := inventory.StockQuantity
	quantityAfter := quantityBefore + update.Quantity

	// Calculate new Total Stock
	ppu := inventory.PiecesPerUnit
	if ppu < 1 {
		ppu = 1
	}
	totalBefore := inventory.TotalStock
	// Change in pieces = Change in units * PPU
	totalChange := update.Quantity * ppu
	totalAfter := totalBefore + totalChange

	// Prevent negative stock
	if quantityAfter < 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":            "Insufficient stock",
			"current_stock":    quantityBefore,
			"requested_change": update.Quantity,
		})
		return
	}

	// Update stock quantity AND total stock
	updateFields := bson.M{
		"stock_quantity": quantityAfter,
		"total_stock":    totalAfter,
		"updated_at":     time.Now(),
	}

	// Update last_restocked_at if adding stock
	if update.Quantity > 0 && update.Reason == "restock" {
		updateFields["last_restocked_at"] = time.Now()
	}

	_, err = inventoryCol.UpdateOne(
		ctx,
		bson.M{"inventory_id": inventoryID},
		bson.M{"$set": updateFields},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update inventory"})
		return
	}

	// SYNC: Update all linked products with new stock quantity
	productsCol := database.GetCollection("products")
	_, err = productsCol.UpdateMany(
		ctx,
		bson.M{"inventory_id": inventoryID},
		bson.M{"$set": bson.M{"stock": quantityAfter}},
	)
	if err != nil {
		log.Printf("⚠️  Warning: Failed to sync stock to linked products: %v", err)
		// Don't fail the request, just log warning
	} else {
		log.Printf("✅ Synced stock (%d) to linked products for inventory %s", quantityAfter, inventoryID)
	}

	// Record history
	history := models.InventoryHistory{
		InventoryID:     inventoryID,
		InventoryName:   inventory.InventoryName,
		QuantityBefore:  quantityBefore,
		QuantityAfter:   quantityAfter,
		QuantityChanged: update.Quantity,
		Reason:          update.Reason,
		ChangedBy:       update.ChangedBy,
		Timestamp:       time.Now(),
	}

	_, err = historyCol.InsertOne(ctx, history)
	if err != nil {
		log.Printf("⚠️  Warning: Failed to record inventory history: %v", err)
	}

	// Check for low stock alert
	if quantityAfter <= inventory.LowStockThreshold {
		go createInventoryAlert(inventoryID, inventory.InventoryName, quantityAfter, inventory.LowStockThreshold)
	}

	log.Printf("✅ Updated stock for %s: %d → %d (change: %+d, reason: %s)",
		inventory.InventoryName, quantityBefore, quantityAfter, update.Quantity, update.Reason)

	c.JSON(http.StatusOK, gin.H{
		"message":          "Stock updated successfully",
		"inventory_id":     inventoryID,
		"quantity_before":  quantityBefore,
		"quantity_after":   quantityAfter,
		"quantity_changed": update.Quantity,
	})
}

// DeleteInventory soft deletes an inventory item
// DELETE /admin/api/inventory/:inventory_id?force=true
func DeleteInventory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	inventoryID := c.Param("inventory_id")
	force := c.Query("force") == "true"

	inventoryCol := database.GetCollection("inventory")
	productsCol := database.GetCollection("products")

	// Check for linked products
	linkedCount, err := productsCol.CountDocuments(ctx, bson.M{"inventory_id": inventoryID})
	if err != nil {
		log.Printf("❌ Error checking linked products: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check linked products"})
		return
	}

	if linkedCount > 0 && !force {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":                 "Cannot delete inventory with linked products",
			"linked_products_count": linkedCount,
			"message":               "Remove product links first or use force=true to unlink all products",
		})
		return
	}

	// If force, unlink all products
	if force && linkedCount > 0 {
		_, err := productsCol.UpdateMany(
			ctx,
			bson.M{"inventory_id": inventoryID},
			bson.M{"$unset": bson.M{"inventory_id": ""}},
		)
		if err != nil {
			log.Printf("❌ Error unlinking products: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unlink products"})
			return
		}
		log.Printf("⚠️  Unlinked %d products from inventory %s", linkedCount, inventoryID)
	}

	// Soft delete (set is_active to false)
	result, err := inventoryCol.UpdateOne(
		ctx,
		bson.M{"inventory_id": inventoryID},
		bson.M{"$set": bson.M{"is_active": false, "updated_at": time.Now()}},
	)

	if err != nil {
		log.Printf("❌ Error deleting inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete inventory"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found"})
		return
	}

	log.Printf("✅ Deleted inventory: %s (unlinked %d products)", inventoryID, linkedCount)
	c.JSON(http.StatusOK, gin.H{
		"message":           "Inventory deleted successfully",
		"inventory_id":      inventoryID,
		"products_unlinked": linkedCount,
	})
}

// SearchInventory searches inventory items for product linking
// GET /admin/api/inventory/search?q=sugar
func SearchInventory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Search query required"})
		return
	}

	inventoryCol := database.GetCollection("inventory")

	// Search by inventory name (case-insensitive)
	filter := bson.M{
		"is_active":      true,
		"inventory_name": bson.M{"$regex": query, "$options": "i"},
	}

	opts := options.Find().SetLimit(20).SetSort(bson.D{{Key: "inventory_name", Value: 1}})

	cursor, err := inventoryCol.Find(ctx, filter, opts)
	if err != nil {
		log.Printf("❌ Error searching inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search inventory"})
		return
	}
	defer cursor.Close(ctx)

	var results []models.Inventory
	if err := cursor.All(ctx, &results); err != nil {
		log.Printf("❌ Error decoding inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode inventory"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"results": results,
		"count":   len(results),
	})
}

// GetInventoryHistory retrieves stock change history
// GET /admin/api/inventory/:inventory_id/history?limit=50
func GetInventoryHistory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	inventoryID := c.Param("inventory_id")
	limitStr := c.DefaultQuery("limit", "50")
	limit, _ := strconv.Atoi(limitStr)

	historyCol := database.GetCollection("inventory_history")

	opts := options.Find().
		SetLimit(int64(limit)).
		SetSort(bson.D{{Key: "timestamp", Value: -1}})

	cursor, err := historyCol.Find(ctx, bson.M{"inventory_id": inventoryID}, opts)
	if err != nil {
		log.Printf("❌ Error fetching inventory history: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch history"})
		return
	}
	defer cursor.Close(ctx)

	var history []models.InventoryHistory
	if err := cursor.All(ctx, &history); err != nil {
		log.Printf("❌ Error decoding history: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode history"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"history": history,
		"count":   len(history),
	})
}

// GetInventoryAlerts retrieves active inventory alerts
// GET /admin/api/inventory/alerts?resolved=false
func GetInventoryAlerts(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	alertsCol := database.GetCollection("inventory_alerts")

	filter := bson.M{}
	if resolved := c.Query("resolved"); resolved == "false" {
		filter["is_resolved"] = false
	}

	opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}})

	cursor, err := alertsCol.Find(ctx, filter, opts)
	if err != nil {
		log.Printf("❌ Error fetching inventory alerts: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch alerts"})
		return
	}
	defer cursor.Close(ctx)

	var alerts []models.InventoryAlert
	if err := cursor.All(ctx, &alerts); err != nil {
		log.Printf("❌ Error decoding alerts: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode alerts"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"alerts": alerts,
		"count":  len(alerts),
	})
}

// GetInventoryStats retrieves global inventory statistics
// GET /admin/api/inventory/stats
func GetInventoryStats(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	inventoryCol := database.GetCollection("inventory")

	// 1. Total Count
	totalCount, err := inventoryCol.CountDocuments(ctx, bson.M{"is_active": true})
	if err != nil {
		log.Printf("❌ Error counting total inventory: %v", err)
	}

	// 2. Out of Stock (stock == 0)
	outOfStockCount, err := inventoryCol.CountDocuments(ctx, bson.M{
		"is_active":      true,
		"stock_quantity": 0,
	})

	// 3. Low Stock (0 < stock <= threshold)
	// We need an aggregation or explicit query for comparing fields
	// simpler: count all where stock > 0 AND stock <= threshold (but threshold varies per item)
	lowStockCount, err := inventoryCol.CountDocuments(ctx, bson.M{
		"is_active": true,
		"$expr": bson.M{
			"$and": []interface{}{
				bson.M{"$gt": []interface{}{"$stock_quantity", 0}},
				bson.M{"$lte": []interface{}{"$stock_quantity", "$low_stock_threshold"}},
			},
		},
	})

	// 4. In Stock
	// Easier to calculate: Total - (Out + Low)
	// Or query: stock > threshold
	inStockCount := totalCount - outOfStockCount - lowStockCount

	// Safety check if counts don't align (e.g. concurrent edits), ensure non-negative
	if inStockCount < 0 {
		inStockCount = 0
	}

	c.JSON(http.StatusOK, gin.H{
		"total_items":  totalCount,
		"out_of_stock": outOfStockCount,
		"low_stock":    lowStockCount,
		"in_stock":     inStockCount,
	})
}

// Helper function to create inventory alert
func createInventoryAlert(inventoryID, inventoryName string, currentStock, threshold int) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	alertsCol := database.GetCollection("inventory_alerts")

	alertType := "low_stock"
	if currentStock == 0 {
		alertType = "out_of_stock"
	}

	alert := models.InventoryAlert{
		InventoryID:   inventoryID,
		InventoryName: inventoryName,
		CurrentStock:  currentStock,
		Threshold:     threshold,
		AlertType:     alertType,
		CreatedAt:     time.Now(),
		IsResolved:    false,
	}

	// Check if unresolved alert already exists
	count, _ := alertsCol.CountDocuments(ctx, bson.M{
		"inventory_id": inventoryID,
		"is_resolved":  false,
	})

	if count == 0 {
		_, err := alertsCol.InsertOne(ctx, alert)
		if err != nil {
			log.Printf("⚠️  Warning: Failed to create inventory alert: %v", err)
		} else {
			log.Printf("🚨 Created %s alert for %s (stock: %d, threshold: %d)",
				alertType, inventoryName, currentStock, threshold)
		}
	}
}
