package handlers

import (
	"al-mathina-backend/database"
	"al-mathina-backend/models"
	"al-mathina-backend/utils"
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// GetAllOrders - GET /api/admin/orders
func GetAllOrders(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()
	ordersCollection := database.GetCollection("orders")
	usersCollection := database.GetCollection("users")

	// Fetch all orders sorted by created_at (newest first)
	cursor, err := ordersCollection.Find(ctx, bson.M{}, &options.FindOptions{
		Sort: bson.D{{Key: "created_at", Value: -1}},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": fmt.Sprintf("Failed to fetch orders: %v", err)})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": fmt.Sprintf("Failed to decode orders: %v", err)})
		return
	}

	// Collect unique user phones for batch lookup
	userPhones := make(map[string]bool)
	for _, order := range orders {
		if order.UserPhone != "" {
			userPhones[order.UserPhone] = true
		}
	}

	// Batch fetch all users
	userPhoneList := make([]string, 0, len(userPhones))
	for phone := range userPhones {
		userPhoneList = append(userPhoneList, phone)
	}

	userLookup := make(map[string]*models.User)
	if len(userPhoneList) > 0 {
		userCursor, err := usersCollection.Find(ctx, bson.M{
			"phone": bson.M{"$in": userPhoneList},
		})
		if err == nil {
			defer userCursor.Close(ctx)
			var users []models.User
			if err := userCursor.All(ctx, &users); err == nil {
				for i := range users {
					userLookup[users[i].Phone] = &users[i]
				}
			}
		}
	}

	// Enrich orders with user details
	for i := range orders {
		if user, ok := userLookup[orders[i].UserPhone]; ok {
			orders[i].UserName = user.Name
			if user.StoreDetails != nil {
				orders[i].UserStoreName = user.StoreDetails.StoreName
			}
		} else {
			orders[i].UserName = "Unknown"
			orders[i].UserStoreName = ""
		}
	}

	// Return response matching JavaScript expectations: {"success": true, "orders": [...]}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"orders":  orders,
	})
}

// GetOrderByID - GET /api/admin/orders/:order_id
func GetOrderByID(c *gin.Context) {
	orderID := c.Param("order_id")

	ctx, cancel := database.GetDBContext()
	defer cancel()
	ordersCollection := database.GetCollection("orders")
	usersCollection := database.GetCollection("users")
	productsCollection := database.GetCollection("products")

	// Find order by order_id
	var orderDoc bson.M
	err := ordersCollection.FindOne(ctx, bson.M{"order_id": orderID}).Decode(&orderDoc)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Order not found"})
		return
	}

	// Get user details to enrich order
	userPhone := ""
	if up, ok := orderDoc["user_phone"].(string); ok {
		userPhone = up
	}

	var user bson.M
	if userPhone != "" {
		usersCollection.FindOne(ctx, bson.M{"phone": userPhone}).Decode(&user)
	}

	// Add user information to order
	if user != nil {
		if name, ok := user["name"].(string); ok {
			orderDoc["user_name"] = name
		} else {
			orderDoc["user_name"] = "Unknown"
		}

		// Get store details
		if storeDetails, ok := user["store_details"].(bson.M); ok {
			if storeName, ok := storeDetails["store_name"].(string); ok {
				orderDoc["user_store_name"] = storeName
			}
		}
	} else {
		orderDoc["user_name"] = "Unknown"
		orderDoc["user_store_name"] = ""
	}

	// Enrich items with product weights
	if items, ok := orderDoc["items"].(primitive.A); ok {
		enrichedItems := make([]bson.M, 0)
		for _, itemInterface := range items {
			if item, ok := itemInterface.(bson.M); ok {
				// Find product to get weight
				section := item["section"]
				mainCat := item["main_category"]
				subCat := item["subcategory"]
				itemID := item["item_id"]

				var product bson.M
				productsCollection.FindOne(ctx, bson.M{
					"section":       section,
					"main_category": mainCat,
					"subcategory":   subCat,
					"item_id":       itemID,
				}).Decode(&product)

				if product != nil {
					// Add weight from product
					if weight, ok := product["weight"]; ok {
						item["weight"] = weight
					}
					// Add unit from product
					if unit, ok := product["unit"]; ok {
						item["unit"] = unit
					}
					// Add current stock
					if stock, ok := product["stock"]; ok {
						item["current_stock"] = stock
					} else {
						item["current_stock"] = 0
					}
					// Add image URL
					if imageURL, ok := product["image_url"]; ok {
						item["image_url"] = imageURL
					}
				} else {
					// No product found - set defaults
					if _, hasWeight := item["weight"]; !hasWeight {
						item["weight"] = ""
					}
					item["unit"] = ""
					item["current_stock"] = 0
					item["image_url"] = ""
				}

				enrichedItems = append(enrichedItems, item)
			}
		}
		orderDoc["items"] = enrichedItems
	}

	// Compute net balance figures for store orders (used on the invoice/popup)
	balanceBefore, balanceTotal, isStoreOrder := computeOrderBalance(ctx, ordersCollection, usersCollection, orderDoc)

	orderDoc["balance_before"] = balanceBefore
	orderDoc["order_amount"] = orderDoc["total_amount"]
	orderDoc["balance_total"] = balanceTotal
	orderDoc["is_store_order"] = isStoreOrder

	// Return response matching JavaScript expectations: {"success": true, "order": {...}}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"order":   orderDoc,
	})
}

// computeOrderBalance calculates the store's net outstanding balance figures
// used on the invoice/popup, plus whether the order belongs to a registered store.
//
// The outstanding balance is derived from the authoritative all-time totals so it
// stays consistent with the Balance Update section for every order (not just the
// latest one):
//
//	balance_total = (sum of ALL orders' total_amount) - total_paid   // net outstanding
//	balance_before = balance_total - this_order_amount               // net outstanding before this order
//
// total_paid is read from the user document (same source GetStoreDetail uses).
// payment_history timestamps are record-time (when the admin entered them), not
// economically attributable to a given order, so summing them filtered by order
// creation time is unreliable and can wrongly report a gross balance.
func computeOrderBalance(ctx context.Context, ordersCollection, usersCollection *mongo.Collection, orderDoc bson.M) (balanceBefore float64, balanceTotal float64, isStore bool) {
	userPhone, _ := orderDoc["user_phone"].(string)
	if userPhone == "" {
		return 0, 0, false
	}

	// Determine whether this user is a registered store (has store_details)
	var user bson.M
	if err := usersCollection.FindOne(ctx, bson.M{"phone": userPhone}).Decode(&user); err == nil {
		if sd, ok := user["store_details"].(bson.M); ok && len(sd) > 0 {
			isStore = true
		}
	}

	if !isStore {
		return 0, 0, false
	}

	// Sum ALL orders' total_amount for this user (all-time due).
	var allTimeDue float64
	allDueCursor, err := ordersCollection.Aggregate(ctx, []bson.D{
		{{Key: "$match", Value: bson.M{"user_phone": userPhone}}},
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: nil},
			{Key: "due", Value: bson.D{{Key: "$sum", Value: "$total_amount"}}},
		}}},
	})
	if err == nil {
		var dueResults []struct {
			Due float64 `bson:"due"`
		}
		if err := allDueCursor.All(ctx, &dueResults); err == nil && len(dueResults) > 0 {
			allTimeDue = dueResults[0].Due
		}
		allDueCursor.Close(ctx)
	}

	// Net outstanding (total outstanding) = all-time due minus payments.
	var totalPaid float64
	if paid, ok := user["total_paid"].(float64); ok {
		totalPaid = paid
	} else if paid, ok := user["total_paid"].(int32); ok {
		totalPaid = float64(paid)
	}

	balanceTotal = allTimeDue - totalPaid
	balanceBefore = balanceTotal - toFloat(orderDoc["total_amount"])
	if balanceBefore < 0 {
		balanceBefore = 0
	}

	return balanceBefore, balanceTotal, true
}

// toFloat converts a bson value to float64.
func toFloat(v interface{}) float64 {
	switch val := v.(type) {
	case float64:
		return val
	case float32:
		return float64(val)
	case int:
		return float64(val)
	case int32:
		return float64(val)
	case int64:
		return float64(val)
	}
	return 0
}

// UpdateOrderStatus - PUT /api/admin/orders/:order_id/status
func UpdateOrderStatus(c *gin.Context) {
	orderID := c.Param("order_id")

	var req struct {
		Status string `json:"status" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()
	collection := database.GetCollection("orders")

	// Get the order before updating to check previous status
	var order bson.M
	err := collection.FindOne(ctx, bson.M{"order_id": orderID}).Decode(&order)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch order"})
		}
		return
	}

	previousStatus := ""
	if status, ok := order["status"].(string); ok {
		previousStatus = status
	}

	// Update order status
	result, err := collection.UpdateOne(
		ctx,
		bson.M{"order_id": orderID},
		bson.M{"$set": bson.M{
			"status":     req.Status,
			"updated_at": time.Now(),
		}},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update order status"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	// If order status changed to "delivered", reduce inventory stock
	log.Printf("🔹 Order Status Update: ID=%s, Old=%s, New=%s", orderID, previousStatus, req.Status)
	if req.Status == "delivered" && previousStatus != "delivered" {
		log.Printf("🚀 Triggering inventory reduction for order %s", orderID)
		go reduceInventoryForOrder(orderID, order)
	} else {
		log.Printf("ℹ️ Skipping inventory reduction (Not delivered or already delivered)")
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Order status updated successfully",
	})
}

// reduceInventoryForOrder reduces inventory stock when order is delivered
func reduceInventoryForOrder(orderID string, order bson.M) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	productsCol := database.GetCollection("products")
	inventoryCol := database.GetCollection("inventory")
	historyCol := database.GetCollection("inventory_history")

	// Get order items - handle both []interface{} and primitive.A
	var items []interface{}
	if rawItems, ok := order["items"].(primitive.A); ok {
		items = []interface{}(rawItems)
	} else if rawItems, ok := order["items"].([]interface{}); ok {
		items = rawItems
	} else {
		log.Printf("⚠️  Order %s has no items or unknown type: %T", orderID, order["items"])
		return
	}

	log.Printf("📦 Processing inventory reduction for order %s with %d raw items", orderID, len(items))

	for i, item := range items {
		log.Printf("🔎 Inspecting Item %d: %+v", i, item)
		itemMap, ok := item.(map[string]interface{})
		if !ok {
			// Try primitive.M if map[string]interface{} fails
			if pm, ok := item.(primitive.M); ok {
				itemMap = map[string]interface{}(pm)
			} else {
				log.Printf("⚠️  Item %d is not a map: %T", i, item)
				continue
			}
		}

		itemID, _ := itemMap["item_id"].(string)
		productName, _ := itemMap["product_name"].(string)

		// Handle quantity (int or float)
		var quantity int32
		if q, ok := itemMap["quantity"].(int32); ok {
			quantity = q
		} else if q, ok := itemMap["quantity"].(float64); ok {
			quantity = int32(q)
		}

		if quantity == 0 {
			continue
		}

		// Find product (Try ItemID first, then Name)
		var product bson.M
		var err error

		if itemID != "" {
			err = productsCol.FindOne(ctx, bson.M{"item_id": itemID}).Decode(&product)
		}

		// Fallback to name search if ID failed or was empty
		if (err != nil || itemID == "") && productName != "" {
			log.Printf("⚠️  Item ID missing for '%s', trying name lookup...", productName)
			// Try exact match
			err = productsCol.FindOne(ctx, bson.M{"product_name": productName}).Decode(&product)

			// Try fuzzy match
			if err != nil {
				err = productsCol.FindOne(ctx, bson.M{
					"product_name": bson.M{"$regex": primitive.Regex{Pattern: "^" + productName + "$", Options: "i"}},
				}).Decode(&product)
			}
		}

		if err != nil {
			log.Printf("❌ Product not found for order %s (ID: %s, Name: %s)", orderID, itemID, productName)
			continue
		}

		inventoryID, ok := product["inventory_id"].(string)
		if !ok || inventoryID == "" {
			log.Printf("⚠️  Product '%s' (ID: %s) not linked to inventory", productName, itemID)
			continue
		}

		// Retrieve current PiecesPerUnit first to calculate total deduction
		// We could fetch it, or if it's not in the 'product' doc, we must fetch inventory doc.
		// Since product might not have it, let's fetch inventory.
		var invDoc models.Inventory
		err = inventoryCol.FindOne(ctx, bson.M{"inventory_id": inventoryID}).Decode(&invDoc)
		if err != nil {
			log.Printf("⚠️  Checking inventory %s failed: %v", inventoryID, err)
			continue
		}

		ppu := invDoc.PiecesPerUnit
		if ppu < 1 {
			ppu = 1
		}
		piecesDeduction := int(quantity) * ppu

		// Deduct from total_stock (the editable inventory pieces)
		updateResult, err := inventoryCol.UpdateOne(
			ctx,
			bson.M{
				"inventory_id": inventoryID,
				"total_stock":  bson.M{"$gte": piecesDeduction}, // Ensure enough pieces
			},
			bson.M{
				"$inc": bson.M{"total_stock": -piecesDeduction},
				"$set": bson.M{"updated_at": time.Now()},
			},
		)

		// Force update if insufficient stock
		if err != nil || updateResult.MatchedCount == 0 {
			log.Printf("⚠️  Insufficient inventory pieces for %s. Forcing update...", inventoryID)
			_, err = inventoryCol.UpdateOne(
				ctx,
				bson.M{"inventory_id": inventoryID},
				[]bson.M{{
					"$set": bson.M{
						"total_stock": bson.M{
							"$cond": bson.M{
								"if":   bson.M{"$lt": []interface{}{bson.M{"$subtract": []interface{}{"$total_stock", piecesDeduction}}, 0}},
								"then": 0,
								"else": bson.M{"$subtract": []interface{}{"$total_stock", piecesDeduction}},
							},
						},
						"updated_at": time.Now(),
					},
				}},
			)
			if err != nil {
				log.Printf("❌ Failed to force update inventory %s: %v", inventoryID, err)
				continue
			}
		}
		// Deduct from stock_quantity (selling units) - Independent of total_stock but triggered by order
		_, err = inventoryCol.UpdateOne(
			ctx,
			bson.M{"inventory_id": inventoryID},
			bson.M{
				"$inc": bson.M{"stock_quantity": -int(quantity)},
			},
		)
		if err != nil {
			log.Printf("⚠️  Failed to update stock_quantity for inventory %s: %v", inventoryID, err)
		}

		// Update product stock (for the specific item sold)
		// We use the ID from the found product to ensure we target the correct one
		targetProductID, _ := product["item_id"].(string)
		if targetProductID != "" {
			_, err = productsCol.UpdateOne(
				ctx,
				bson.M{"item_id": targetProductID},
				bson.M{
					"$inc": bson.M{"stock": -int(quantity)},
					"$set": bson.M{"updated_at": time.Now()},
				},
			)
			if err != nil {
				log.Printf("⚠️  Failed to update product stock for item %s: %v", targetProductID, err)
			} else {
				log.Printf("✅ Reduced product stock for %s by %d", targetProductID, quantity)
			}
		}

		// Record history
		history := bson.M{
			"inventory_id":     inventoryID,
			"inventory_name":   invDoc.InventoryName,
			"quantity_changed": -int(quantity),
			"pieces_changed":   -piecesDeduction,
			"reason":           "order_delivered",
			"changed_by":       "system",
			"order_id":         orderID,
			"timestamp":        time.Now(),
		}
		historyCol.InsertOne(ctx, history)

		log.Printf("✅ Reduced inventory %s total_stock by %d pieces (Order: %s, Qty: %d)", inventoryID, piecesDeduction, orderID, quantity)

		// Check low stock alert
		go checkLowStock(inventoryID)
	}
}

// Helper to check low stock after update
func checkLowStock(inventoryID string) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	col := database.GetCollection("inventory")
	var inv bson.M
	if err := col.FindOne(ctx, bson.M{"inventory_id": inventoryID}).Decode(&inv); err != nil {
		return
	}

	stock := int32(0)
	if s, ok := inv["stock_quantity"].(int32); ok {
		stock = s
	}

	threshold := int32(10)
	if t, ok := inv["low_stock_threshold"].(int32); ok {
		threshold = t
	}

	if stock <= threshold {
		name, _ := inv["inventory_name"].(string)
		createInventoryAlert(inventoryID, name, int(stock), int(threshold))
	}
}

// UpdateOrderItems - PUT /api/admin/orders/:order_id/update-items
func UpdateOrderItems(c *gin.Context) {
	orderID := c.Param("order_id")

	var req struct {
		Items []models.OrderItem `json:"items" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()
	collection := database.GetCollection("orders")
	productsCol := database.GetCollection("products")

	// Apply weight-based price conversion for each item
	for i := range req.Items {
		item := &req.Items[i]
		if item.ItemID != "" {
			var product bson.M
			err := productsCol.FindOne(ctx, bson.M{"item_id": item.ItemID}).Decode(&product)
			if err == nil {
				unit := ""
				if u, ok := product["unit"].(string); ok {
					unit = u
				}
				effectivePrice := utils.CalculateEffectivePrice(item.Price, item.Weight, unit)
				item.Price = effectivePrice
			}
		} else if item.ProductName != "" {
			// Fallback: lookup by product name
			var product bson.M
			err := productsCol.FindOne(ctx, bson.M{"product_name": item.ProductName}).Decode(&product)
			if err == nil {
				unit := ""
				if u, ok := product["unit"].(string); ok {
					unit = u
				}
				effectivePrice := utils.CalculateEffectivePrice(item.Price, item.Weight, unit)
				item.Price = effectivePrice
			}
		}
		item.Subtotal = item.Price * float64(item.Quantity)
	}

	// Recalculate totals
	var totalAmount float64
	for _, item := range req.Items {
		totalAmount += item.Price * float64(item.Quantity)
	}

	result, err := collection.UpdateOne(
		ctx,
		bson.M{"order_id": orderID},
		bson.M{"$set": bson.M{
			"items":        req.Items,
			"total_amount": totalAmount,
			"grand_total":  totalAmount, // Assuming no extra charges for now, or fetch existing and adjust
			"updated_at":   time.Now(),
		}},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update order items"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"message":      "Order items updated successfully",
		"items":        req.Items,
		"total_amount": totalAmount,
		"grand_total":  totalAmount,
	})
}

// UpdateOrderReturnItems - PUT /api/admin/orders/:order_id/update-return-items
//
// Same pattern as UpdateOrderItems: binds []OrderItem, applies weight-based
// price conversion via the products collection, computes return_total, and
// $sets return_items + return_total + updated_at on the order document.
//
// IMPORTANT: does NOT call reduceInventoryForOrder — returns never touch
// inventory or the real order amount.
func UpdateOrderReturnItems(c *gin.Context) {
	orderID := c.Param("order_id")

	var req struct {
		Items []models.OrderItem `json:"items"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Allow saving an empty return list — this clears the order's return record.
	// Normalize a missing/null items field to an empty array so we never store null.
	if req.Items == nil {
		req.Items = []models.OrderItem{}
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()
	collection := database.GetCollection("orders")
	productsCol := database.GetCollection("products")

	// Apply weight-based price conversion for each item
	for i := range req.Items {
		item := &req.Items[i]
		if item.ItemID != "" {
			var product bson.M
			err := productsCol.FindOne(ctx, bson.M{"item_id": item.ItemID}).Decode(&product)
			if err == nil {
				unit := ""
				if u, ok := product["unit"].(string); ok {
					unit = u
				}
				effectivePrice := utils.CalculateEffectivePrice(item.Price, item.Weight, unit)
				item.Price = effectivePrice
			}
		} else if item.ProductName != "" {
			// Fallback: lookup by product name
			var product bson.M
			err := productsCol.FindOne(ctx, bson.M{"product_name": item.ProductName}).Decode(&product)
			if err == nil {
				unit := ""
				if u, ok := product["unit"].(string); ok {
					unit = u
				}
				effectivePrice := utils.CalculateEffectivePrice(item.Price, item.Weight, unit)
				item.Price = effectivePrice
			}
		}
		item.Subtotal = item.Price * float64(item.Quantity)
	}

	// Recalculate return total (informational only)
	var returnTotal float64
	for _, item := range req.Items {
		returnTotal += item.Price * float64(item.Quantity)
	}

	result, err := collection.UpdateOne(
		ctx,
		bson.M{"order_id": orderID},
		bson.M{"$set": bson.M{
			"return_items": req.Items,
			"return_total": returnTotal,
			"updated_at":   time.Now(),
		}},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update return items"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"message":      "Return items updated successfully",
		"return_items": req.Items,
		"return_total": returnTotal,
	})
}

// DeleteOrder - DELETE /api/admin/orders/:order_id
func DeleteOrder(c *gin.Context) {
	orderID := c.Param("order_id")

	ctx, cancel := database.GetDBContext()
	defer cancel()
	collection := database.GetCollection("orders")

	result, err := collection.DeleteOne(ctx, bson.M{"order_id": orderID})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete order"})
		return
	}

	if result.DeletedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Order deleted successfully",
	})
}

// GetOrderStats - GET /api/admin/orders/stats/summary
func GetOrderStats(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()
	collection := database.GetCollection("orders")

	// Aggregate stats by status
	statusPipeline := []bson.D{
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: "$status"},
			{Key: "count", Value: bson.D{{Key: "$sum", Value: 1}}},
		}}},
	}

	cursor, err := collection.Aggregate(ctx, statusPipeline)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to get stats"})
		return
	}
	defer cursor.Close(ctx)

	var stats []struct {
		ID    string `bson:"_id"`
		Count int    `bson:"count"`
	}

	if err := cursor.All(ctx, &stats); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to decode stats"})
		return
	}

	// Calculate totals
	pending := 0
	delivered := 0
	total := 0
	for _, stat := range stats {
		total += stat.Count
		if stat.ID == "pending" {
			pending = stat.Count
		} else if stat.ID == "delivered" {
			delivered = stat.Count
		}
	}

	// Calculate total revenue
	revenuePipeline := []bson.D{
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: nil},
			{Key: "total_revenue", Value: bson.D{{Key: "$sum", Value: "$total_amount"}}},
		}}},
	}

	revenueCursor, err := collection.Aggregate(ctx, revenuePipeline)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to calculate revenue"})
		return
	}
	defer revenueCursor.Close(ctx)

	var revenueResult []struct {
		TotalRevenue float64 `bson:"total_revenue"`
	}
	totalRevenue := 0.0
	if err := revenueCursor.All(ctx, &revenueResult); err == nil && len(revenueResult) > 0 {
		totalRevenue = revenueResult[0].TotalRevenue
	}

	// Return response matching JavaScript expectations
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"stats": gin.H{
			"total_orders":     total,
			"pending_orders":   pending,
			"delivered_orders": delivered,
			"total_revenue":    totalRevenue,
		},
	})
}

// SearchProductsAdmin - GET /api/admin/orders/products/search
func SearchProductsAdmin(c *gin.Context) {
	query := c.Query("q")

	if query == "" {
		c.JSON(http.StatusOK, gin.H{
			"success":  true,
			"products": []models.Product{},
		})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()
	collection := database.GetCollection("products")

	filter := bson.M{
		"$or": []bson.M{
			{"product_name": bson.M{"$regex": primitive.Regex{Pattern: query, Options: "i"}}},
			{"item_id": bson.M{"$regex": primitive.Regex{Pattern: query, Options: "i"}}},
		},
	}

	cursor, err := collection.Find(ctx, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Search failed"})
		return
	}
	defer cursor.Close(ctx)

	var products []models.Product
	if err := cursor.All(ctx, &products); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode products"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"products": products,
	})
}
