package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"al-mathina-backend/config"
	"al-mathina-backend/database"
	"al-mathina-backend/models"
	"al-mathina-backend/utils"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ===== USER PROFILE HANDLERS =====

// GetUserProfile retrieves user profile by phone number
// GET /api/profile/:phone
// Auto-creates user if not found (matching FastAPI behavior)
func GetUserProfile(c *gin.Context) {
	phone := c.Param("phone")
	log.Printf("🔵 GetUserProfile: phone=%s", phone)

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")
	var user models.User

	err := usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		// User not found - auto-create with defaults (matching FastAPI)
		log.Printf("📝 GetUserProfile: Creating new user for phone=%s", phone)
		newUser := models.User{
			Phone:     phone,
			Name:      "",
			Email:     "",
			CreatedAt: time.Now(),
		}

		_, insertErr := usersCol.InsertOne(ctx, newUser)
		if insertErr != nil {
			log.Printf("❌ GetUserProfile: Failed to create user: %v", insertErr)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
			return
		}

		log.Printf("✅ GetUserProfile: Created new user for phone=%s", phone)
		// Match FastAPI response structure: {"success": true, "user": {...}}
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"user":    newUser,
		})
		return
	}

	log.Printf("✅ GetUserProfile: Found existing user for phone=%s", phone)
	// Match FastAPI response structure: {"success": true, "user": {...}}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"user":    user,
	})
}

// UpdateUserProfile updates user profile information
// PUT /api/profile/:phone
// Body: {name: string, email: string, delivery_address: string}
func UpdateUserProfile(c *gin.Context) {
	phone := c.Param("phone")

	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")

	// Update or insert user profile with upsert option
	filter := bson.M{"phone": phone}
	update := bson.M{
		"$set": updates,
		"$setOnInsert": bson.M{
			"phone":      phone,
			"created_at": time.Now(),
		},
	}

	opts := database.GetMongoOptions()
	opts.Upsert = &[]bool{true}[0]

	_, err := usersCol.UpdateOne(ctx, filter, update, opts)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Profile updated successfully"})
}

// GetUserOrders retrieves all orders for a user
// GET /api/orders/:phone
func GetUserOrders(c *gin.Context) {
	phone := c.Param("phone")
	ctx, cancel := database.GetDBContext()
	defer cancel()

	ordersCol := database.GetCollection("orders")

	// options for sorting by created_at desc
	// options for sorting by created_at desc
	opts := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}})

	cursor, err := ordersCol.Find(ctx, bson.M{"user_phone": phone}, opts)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch orders"})
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse orders"})
		return
	}

	if orders == nil {
		orders = []models.Order{}
	}

	// Match FastAPI response structure: {"success": true, "orders": [...]}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"orders":  orders,
	})
}

// CreateOrder creates a new order and sends email notification
// POST /api/orders
// Body: {user_phone, user_name, delivery_address, items[], total_amount, notes}
func CreateOrder(c *gin.Context) {
	var req struct {
		UserPhone       string                 `json:"user_phone" binding:"required"`
		UserName        string                 `json:"user_name"` // Optional - will be fetched from DB if not provided
		DeliveryAddress models.DeliveryAddress `json:"delivery_address" binding:"required"`
		Items           []models.OrderItem     `json:"items" binding:"required,min=1"`
		TotalAmount     float64                `json:"total_amount"`
		PaymentMethod   string                 `json:"payment_method"` // Optional - defaults to "cod"
		Notes           string                 `json:"notes"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("❌ CreateOrder: Binding error: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	log.Printf("🔵 CreateOrder: phone=%s, items=%d, total=%.2f", req.UserPhone, len(req.Items), req.TotalAmount)

	ctx, cancel := database.GetDBContext()
	defer cancel()

	// Fetch user name from database if not provided (matching FastAPI)
	userName := req.UserName
	if userName == "" {
		usersCol := database.GetCollection("users")
		var user models.User
		err := usersCol.FindOne(ctx, bson.M{"phone": req.UserPhone}).Decode(&user)
		if err == nil && user.Name != "" {
			userName = user.Name
			log.Printf("📝 CreateOrder: Fetched user name from DB: %s", userName)
		} else {
			userName = "Guest"
			log.Printf("⚠️  CreateOrder: User not found or no name, using 'Guest'")
		}
	}

	// Set default payment method if not provided
	paymentMethod := req.PaymentMethod
	if paymentMethod == "" {
		paymentMethod = "cod"
	}

	// Ensure item subtotals are calculated
	for i := range req.Items {
		if req.Items[i].Subtotal == 0 {
			req.Items[i].Subtotal = float64(req.Items[i].Quantity) * req.Items[i].Price
		}
	}

	// Group items by section (SPLIT ORDER LOGIC)
	itemsBySection := make(map[string][]models.OrderItem)
	for _, item := range req.Items {
		section := item.Section
		if section == "" {
			section = "Unknown"
		}
		itemsBySection[section] = append(itemsBySection[section], item)
	}

	log.Printf("📊 CreateOrder: Split into %d section(s): %v", len(itemsBySection), getMapKeys(itemsBySection))

	// Track created orders for response
	type CreatedOrder struct {
		OrderID     string  `json:"order_id"`
		Section     string  `json:"section"`
		ItemsCount  int     `json:"items_count"`
		TotalAmount float64 `json:"total_amount"`
		Status      string  `json:"status"`
	}

	var createdOrders []CreatedOrder
	var allOrders []models.Order // For email notifications
	totalItemsCount := 0

	// Create separate order for each section
	ordersCol := database.GetCollection("orders")
	for section, sectionItems := range itemsBySection {
		// Calculate section total
		sectionTotal := 0.0
		for _, item := range sectionItems {
			sectionTotal += item.Subtotal
		}

		// Generate order ID for this section
		orderID := fmt.Sprintf("ORD-%d", time.Now().UnixNano()/1000000)

		// Create order document for this section
		order := models.Order{
			OrderID:         orderID,
			UserPhone:       req.UserPhone,
			UserName:        userName,
			Section:         section,
			DeliveryAddress: req.DeliveryAddress,
			Items:           sectionItems,
			TotalAmount:     sectionTotal,
			PaymentMethod:   paymentMethod,
			Status:          "pending",
			CreatedAt:       time.Now(),
			Notes:           req.Notes,
			Metadata:        map[string]interface{}{},
		}

		// Insert section order into MongoDB
		_, err := ordersCol.InsertOne(ctx, order)
		if err != nil {
			log.Printf("❌ CreateOrder: Failed to insert order for section %s: %v", section, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order"})
			return
		}

		log.Printf("✅ CreateOrder: Section order created: %s - %s (%.2f, %d items)", orderID, section, sectionTotal, len(sectionItems))

		// Track created order for response
		createdOrders = append(createdOrders, CreatedOrder{
			OrderID:     orderID,
			Section:     section,
			ItemsCount:  len(sectionItems),
			TotalAmount: sectionTotal,
			Status:      "pending",
		})

		// Store order for email notifications
		allOrders = append(allOrders, order)
		totalItemsCount += len(sectionItems)
	}

	log.Printf("✅ CreateOrder: All %d section orders created successfully", len(createdOrders))

	// Send email notification for EACH split order (async - don't block response)
	log.Printf("📧 CreateOrder: Scheduling %d email notifications...", len(allOrders))
	for i, order := range allOrders {
		go sendOrderEmailNotification(order)
		log.Printf("   ✓ Email task %d/%d: %s (section: %s)", i+1, len(allOrders), order.OrderID, order.Section)
	}

	// Send single FCM push notification to user for combined order (async)
	go sendFCMOrderNotification(req.UserPhone, createdOrders[0].OrderID, req.TotalAmount, totalItemsCount, userName)

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"message":      fmt.Sprintf("Created %d order(s) - split by section", len(createdOrders)),
		"orders":       createdOrders,
		"total_orders": len(createdOrders),
	})
}

// Helper function to get map keys for logging
func getMapKeys(m map[string][]models.OrderItem) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

// sendOrderEmailNotification sends order notification to admin via Vercel webhook
// Runs asynchronously in background (goroutine)
func sendOrderEmailNotification(order models.Order) {
	cfg := config.AppConfig

	if cfg.EmailWebhookURL == "" {
		log.Println("⚠️  Email webhook URL not configured, skipping email notification")
		return
	}

	// Safely resolve order date string (OrderDate is a legacy optional pointer)
	var orderDateStr string
	if order.OrderDate != nil {
		orderDateStr = order.OrderDate.Format("2006-01-02 15:04:05")
	} else if !order.CreatedAt.IsZero() {
		orderDateStr = order.CreatedAt.Format("2006-01-02 15:04:05")
	} else {
		orderDateStr = time.Now().Format("2006-01-02 15:04:05")
	}

	// Build email subject with section info for split orders (matching FastAPI)
	subject := fmt.Sprintf("🛒 New Order - %s - %s", order.Section, order.OrderID)
	if order.Section == "" {
		subject = fmt.Sprintf("🛒 New Order: %s - ₹%.2f", order.OrderID, order.TotalAmount)
	}

	// Build email payload matching Vercel webhook structure
	payload := map[string]interface{}{
		"to":      cfg.AdminEmail, // comma-separated admin emails
		"subject": subject,
		"html": fmt.Sprintf(`
			<h2>New Order Received</h2>
			<p><strong>Order ID:</strong> %s</p>
			<p><strong>Customer:</strong> %s (%s)</p>
			<p><strong>Delivery Address:</strong> %s</p>
			<p><strong>Total Amount:</strong> ₹%.2f</p>
			<p><strong>Items:</strong></p>
			<ul>%s</ul>
			<p><strong>Notes:</strong> %s</p>
			<p><strong>Order Date:</strong> %s</p>
		`,
			order.OrderID,
			order.UserName,
			order.UserPhone,
			order.DeliveryAddress,
			order.TotalAmount,
			buildItemsHTML(order.Items),
			order.Notes,
			orderDateStr,
		),
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		log.Printf("❌ Failed to marshal email payload: %v", err)
		return
	}

	// Send POST request to Vercel webhook with optional secret header
	req, err := http.NewRequest(http.MethodPost, cfg.EmailWebhookURL, bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("❌ Failed to create email request: %v", err)
		return
	}
	req.Header.Set("Content-Type", "application/json")
	if cfg.EmailWebhookSecret != "" {
		req.Header.Set("x-api-key", cfg.EmailWebhookSecret)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("❌ Failed to send email notification: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("⚠️  Email webhook returned status %d", resp.StatusCode)
		return
	}

	log.Printf("✅ Email notification sent for order %s", order.OrderID)
}

// sendFCMOrderNotification sends FCM push notification to user
// Runs asynchronously in background (goroutine)
func sendFCMOrderNotification(userPhone, orderID string, totalAmount float64, itemsCount int, storeName string) {
	// Get FCM token from Supabase
	if database.SupabaseDB == nil {
		log.Println("⚠️  Supabase not initialized - cannot send FCM notification")
		return
	}

	fcmToken, err := database.SupabaseDB.GetFCMToken(userPhone)
	if err != nil || fcmToken == "" {
		log.Printf("⚠️  No FCM token found for user %s", userPhone)
		return
	}

	log.Printf("📱 FCM: Found token for user %s, sending notification...\n", userPhone)

	// Send notification
	if utils.SendOrderNotification(fcmToken, orderID, totalAmount, itemsCount, storeName, userPhone) {
		log.Printf("✅ FCM notification sent for order %s\n", orderID)
	} else {
		log.Printf("❌ Failed to send FCM notification for order %s\n", orderID)
	}
}

// buildItemsHTML formats order items as HTML list
func buildItemsHTML(items []models.OrderItem) string {
	html := ""
	for _, item := range items {
		html += fmt.Sprintf(
			"<li>%s - Qty: %d - ₹%.2f (Subtotal: ₹%.2f)</li>",
			item.ProductName,
			item.Quantity,
			item.Price,
			item.Subtotal,
		)
	}
	return html
}

// GetAppVersion returns API version info
// GET /api/version
func GetAppVersion(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"version":     "1.0.0",
		"environment": config.AppConfig.Environment,
		"backend":     "Go",
	})
}

// ===== ADDRESS MANAGEMENT =====

// AddAddress adds a new delivery address to user's addresses array
// POST /api/address/:phone
// Body: {label, street, city, state, pincode, landmark, is_default}
func AddAddress(c *gin.Context) {
	phone := c.Param("phone")

	var address map[string]interface{}
	if err := c.ShouldBindJSON(&address); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")

	// If this is default address, unset other defaults
	if isDefault, ok := address["is_default"].(bool); ok && isDefault {
		usersCol.UpdateOne(ctx, bson.M{"phone": phone}, bson.M{
			"$set": bson.M{"addresses.$[].is_default": false},
		})
	}

	// Add new address to array
	update := bson.M{
		"$push": bson.M{"addresses": address},
		"$set":  bson.M{"updated_at": time.Now()},
	}

	result, err := usersCol.UpdateOne(ctx, bson.M{"phone": phone}, update)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add address"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Address added successfully",
	})
}

// UpdateAddress updates an existing address at specific index
// PUT /api/address/:phone/:index
func UpdateAddress(c *gin.Context) {
	phone := c.Param("phone")
	index := c.Param("index")

	var address map[string]interface{}
	if err := c.ShouldBindJSON(&address); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")

	// Get user to verify address exists
	var user models.User
	err := usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Check if address index is valid
	addressIdx := 0
	fmt.Sscanf(index, "%d", &addressIdx)

	// If this is default address, unset other defaults
	if isDefault, ok := address["is_default"].(bool); ok && isDefault {
		// Unset all other defaults except current index
		usersCol.UpdateOne(ctx, bson.M{"phone": phone}, bson.M{
			"$set": bson.M{"addresses.$[].is_default": false},
		})
	}

	// Update specific address by index
	updateField := fmt.Sprintf("addresses.%d", addressIdx)
	update := bson.M{
		"$set": bson.M{
			updateField:  address,
			"updated_at": time.Now(),
		},
	}

	result, err := usersCol.UpdateOne(ctx, bson.M{"phone": phone}, update)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update address"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Address updated successfully",
	})
}

// DeleteAddress removes an address at specific index
// DELETE /api/address/:phone/:index
func DeleteAddress(c *gin.Context) {
	phone := c.Param("phone")
	index := c.Param("index")

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")

	// Get user to access addresses array
	var user struct {
		Phone     string                   `bson:"phone"`
		Addresses []map[string]interface{} `bson:"addresses"`
	}

	err := usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Parse index
	addressIdx := 0
	fmt.Sscanf(index, "%d", &addressIdx)

	if addressIdx < 0 || addressIdx >= len(user.Addresses) {
		c.JSON(http.StatusNotFound, gin.H{"error": "Address not found"})
		return
	}

	// Remove address from array
	newAddresses := append(user.Addresses[:addressIdx], user.Addresses[addressIdx+1:]...)

	update := bson.M{
		"$set": bson.M{
			"addresses":  newAddresses,
			"updated_at": time.Now(),
		},
	}

	_, err = usersCol.UpdateOne(ctx, bson.M{"phone": phone}, update)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete address"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Address deleted successfully",
	})
}

// ===== STORE DETAILS =====

// GetStoreDetails retrieves store information for a user
// GET /api/store-details/:phone
func GetStoreDetails(c *gin.Context) {
	phone := c.Param("phone")
	log.Printf("🔵 GetStoreDetails: phone=%s", phone)

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")

	var user struct {
		StoreDetails map[string]interface{} `bson:"store_details"`
	}

	err := usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		// User not found - auto-create with defaults (matching FastAPI)
		log.Printf("📝 GetStoreDetails: Creating new user for phone=%s", phone)
		newUser := models.User{
			Phone:     phone,
			Name:      "",
			Email:     "",
			CreatedAt: time.Now(),
		}

		_, insertErr := usersCol.InsertOne(ctx, newUser)
		if insertErr != nil {
			log.Printf("❌ GetStoreDetails: Failed to create user: %v", insertErr)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
			return
		}

		log.Printf("✅ GetStoreDetails: Created new user for phone=%s", phone)
		// Return empty store details
		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"store_details": map[string]interface{}{
				"store_name": nil,
				"street":     nil,
				"city":       nil,
				"state":      nil,
				"pincode":    nil,
				"landmark":   nil,
			},
		})
		return
	}

	// Return store details or empty structure
	storeDetails := user.StoreDetails
	if storeDetails == nil {
		storeDetails = map[string]interface{}{
			"store_name": nil,
			"street":     nil,
			"city":       nil,
			"state":      nil,
			"pincode":    nil,
			"landmark":   nil,
		}
	}

	log.Printf("✅ GetStoreDetails: Returning store details for phone=%s", phone)
	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"store_details": storeDetails,
	})
}

// UpdateStoreDetails updates store information for a user
// PUT /api/store-details/:phone
func UpdateStoreDetails(c *gin.Context) {
	phone := c.Param("phone")

	var storeDetails map[string]interface{}
	if err := c.ShouldBindJSON(&storeDetails); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")

	// Check if user exists
	var user models.User
	err := usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Update store details
	update := bson.M{
		"$set": bson.M{
			"store_details": storeDetails,
			"updated_at":    time.Now(),
		},
	}

	_, err = usersCol.UpdateOne(ctx, bson.M{"phone": phone}, update)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update store details"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"message":       "Store details updated successfully",
		"store_details": storeDetails,
	})
}

// ===== FAVORITES =====

// GetFavorites retrieves user's favorite products with full product details
// GET /api/favorites/:phone
func GetFavorites(c *gin.Context) {
	phone := c.Param("phone")

	log.Printf("🔵 GetFavorites: phone=%s", phone)

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")
	productsCol := database.GetCollection("products")

	// Get user's favorites array
	var user struct {
		Favorites []string `bson:"favorites"`
	}

	err := usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		// User not found - auto-create with defaults (matching FastAPI)
		log.Printf("📝 GetFavorites: Creating new user for phone=%s", phone)
		newUser := bson.M{
			"phone":      phone,
			"name":       "",
			"email":      "",
			"favorites":  []string{},
			"created_at": time.Now(),
		}

		_, insertErr := usersCol.InsertOne(ctx, newUser)
		if insertErr != nil {
			log.Printf("❌ GetFavorites: Failed to create user: %v", insertErr)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
			return
		}

		log.Printf("✅ GetFavorites: Created new user for phone=%s (0 favorites)", phone)
		c.JSON(http.StatusOK, gin.H{"favorites": []interface{}{}})
		return
	}

	log.Printf("🔍 GetFavorites: Found %d favorites for user %s", len(user.Favorites), phone)

	// Parallel batch processing: Fetch all favorite products concurrently
	type productResult struct {
		product map[string]interface{}
		err     error
	}

	resultChans := make([]chan productResult, len(user.Favorites))

	// Launch goroutines for each favorite
	for i, itemID := range user.Favorites {
		resultChans[i] = make(chan productResult, 1)
		go func(id string, ch chan productResult, index int) {
			var product map[string]interface{}
			err := productsCol.FindOne(ctx, bson.M{"item_id": id}).Decode(&product)
			ch <- productResult{product: product, err: err}
		}(itemID, resultChans[i], i)
	}

	// Collect results from all goroutines
	favoriteProducts := []map[string]interface{}{}
	for i, itemID := range user.Favorites {
		result := <-resultChans[i]
		if result.err != nil {
			log.Printf("⚠️ GetFavorites: Product not found: %s", itemID)
			continue // Skip if product not found
		}
		product := result.product

		// Safely convert stock to int (handle int, int32, int64, float64)
		stock := 0
		if s, ok := product["stock"]; ok {
			switch v := s.(type) {
			case int:
				stock = v
			case int32:
				stock = int(v)
			case int64:
				stock = int(v)
			case float64:
				stock = int(v)
			}
		}

		// Extract category fields (MongoDB uses category_section, category_main, category_sub)
		categorySection := ""
		if val, ok := product["category_section"]; ok && val != nil {
			categorySection = val.(string)
		}
		categoryMain := ""
		if val, ok := product["category_main"]; ok && val != nil {
			categoryMain = val.(string)
		}
		categorySub := ""
		if val, ok := product["category_sub"]; ok && val != nil {
			categorySub = val.(string)
		}

		// Map product fields to Flutter-friendly format (matching FastAPI response)
		favoriteProducts = append(favoriteProducts, map[string]interface{}{
			"item_id":             product["item_id"],
			"section":             categorySection,
			"main_category":       categoryMain,
			"subcategory":         categorySub,
			"product_name":        product["product_name"],
			"weight":              product["weight"], // FastAPI uses 'weight'
			"price":               product["price"],
			"image_url":           product["image_url"],
			"stock":               stock,
			"in_stock":            stock > 0,
			"is_best_seller":      product["is_best_seller"],
			"description":         product["description"],
			"category_section":    categorySection,
			"category_main":       categoryMain,
			"category_breadcrumb": categorySection + " > " + categoryMain + " > " + categorySub,
		})
	}

	log.Printf("✅ GetFavorites: Returning %d products for user %s", len(favoriteProducts), phone)
	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"favorites": favoriteProducts,
	})
}

// AddFavorite adds a product to user's favorites
// POST /api/favorites/:phone
// Body: {item_id: string}
func AddFavorite(c *gin.Context) {
	phone := c.Param("phone")

	var req struct {
		ItemID string `json:"item_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")
	productsCol := database.GetCollection("products")

	// Verify product exists
	var product models.Product
	err := productsCol.FindOne(ctx, bson.M{"item_id": req.ItemID}).Decode(&product)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	// Check if user exists
	var user models.User
	err = usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)

	if err != nil {
		// Create user with favorites array
		newUser := bson.M{
			"phone":      phone,
			"favorites":  []string{req.ItemID},
			"created_at": time.Now(),
			"updated_at": time.Now(),
		}
		_, err = usersCol.InsertOne(ctx, newUser)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
			return
		}
	} else {
		// Add to favorites using $addToSet (avoids duplicates)
		update := bson.M{
			"$addToSet": bson.M{"favorites": req.ItemID},
			"$set":      bson.M{"updated_at": time.Now()},
		}
		_, err = usersCol.UpdateOne(ctx, bson.M{"phone": phone}, update)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add favorite"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Product added to favorites",
	})
}

// RemoveFavorite removes a product from user's favorites
// DELETE /api/favorites/:phone/:item_id
func RemoveFavorite(c *gin.Context) {
	phone := c.Param("phone")
	itemID := c.Param("item_id")

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")

	// Remove from favorites using $pull
	update := bson.M{
		"$pull": bson.M{"favorites": itemID},
		"$set":  bson.M{"updated_at": time.Now()},
	}

	result, err := usersCol.UpdateOne(ctx, bson.M{"phone": phone}, update)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove favorite"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Product removed from favorites",
	})
}

// ===== USER MANAGEMENT =====

// ChangePhoneNumber updates user's phone number across MongoDB and Supabase
// PUT /api/phone/:old_phone
// Body: {new_phone: string}
func ChangePhoneNumber(c *gin.Context) {
	oldPhone := c.Param("old_phone")

	var req struct {
		NewPhone string `json:"new_phone" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate phone format (+91XXXXXXXXXX)
	if len(req.NewPhone) != 13 || req.NewPhone[:3] != "+91" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid phone format. Must be +91XXXXXXXXXX"})
		return
	}

	if oldPhone == req.NewPhone {
		c.JSON(http.StatusBadRequest, gin.H{"error": "New phone number is the same as current"})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")
	ordersCol := database.GetCollection("orders")

	// Check if new phone already exists
	var existingUser models.User
	err := usersCol.FindOne(ctx, bson.M{"phone": req.NewPhone}).Decode(&existingUser)
	if err == nil {
		c.JSON(http.StatusConflict, gin.H{"error": "Phone number already registered to another user"})
		return
	}

	// Get old user data
	var oldUser models.User
	err = usersCol.FindOne(ctx, bson.M{"phone": oldPhone}).Decode(&oldUser)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	log.Printf("📱 Updating phone number: %s -> %s", oldPhone, req.NewPhone)

	// Update phone in users collection
	_, err = usersCol.UpdateOne(
		ctx,
		bson.M{"phone": oldPhone},
		bson.M{
			"$set": bson.M{
				"phone":      req.NewPhone,
				"updated_at": time.Now(),
			},
		},
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update phone in users"})
		return
	}

	// Update phone in all orders
	ordersCol.UpdateMany(
		ctx,
		bson.M{"user_phone": oldPhone},
		bson.M{
			"$set": bson.M{"user_phone": req.NewPhone},
		},
	)

	// Update phone in Supabase users table (for FCM tokens)
	if database.SupabaseDB != nil {
		// Note: Supabase update requires custom implementation
		// For now, we'll keep old token and user can re-login to save new phone
		log.Printf("⚠️  Manual Supabase update required for phone: %s -> %s", oldPhone, req.NewPhone)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Phone number updated successfully",
	})
}

// DeleteUserProfile deletes user profile from MongoDB and Supabase
// DELETE /api/profile/:phone
func DeleteUserProfile(c *gin.Context) {
	phone := c.Param("phone")

	ctx, cancel := database.GetDBContext()
	defer cancel()

	usersCol := database.GetCollection("users")

	// Delete user from MongoDB
	result, err := usersCol.DeleteOne(ctx, bson.M{"phone": phone})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user"})
		return
	}

	if result.DeletedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Note: Supabase deletion requires custom implementation
	// For production, add Supabase DELETE API call here

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "User profile deleted successfully",
	})
}

// GetOrderDetails retrieves detailed information for a specific order
// GET /api/orders/:phone/:order_id
func GetOrderDetails(c *gin.Context) {
	phone := c.Param("phone")
	orderID := c.Param("order_id")

	ctx, cancel := database.GetDBContext()
	defer cancel()

	ordersCol := database.GetCollection("orders")
	usersCol := database.GetCollection("users")
	productsCol := database.GetCollection("products")

	// Find order for this user
	var order models.Order
	err := ordersCol.FindOne(ctx, bson.M{
		"user_phone": phone,
		"order_id":   orderID,
	}).Decode(&order)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	// Enrich order with user's store details for delivery address
	var user models.User
	err = usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)

	// If delivery_address is not in order or is empty, use store_details
	// Matching FastAPI logic
	if user.StoreDetails != nil {
		if order.DeliveryAddress.Street == "" {
			order.DeliveryAddress = models.DeliveryAddress{
				Street:   user.StoreDetails.Street,
				City:     user.StoreDetails.City,
				State:    user.StoreDetails.State,
				Pincode:  user.StoreDetails.Pincode,
				Landmark: user.StoreDetails.Landmark,
			}
		}
	}

	// Enrich items with product images if not already present
	// Matching FastAPI logic to ensure icons appear in UI
	for i, item := range order.Items {
		if item.ImageURL == "" {
			var product models.Product

			// Try to find product by item_id first
			filter := bson.M{"item_id": item.ItemID}
			err := productsCol.FindOne(ctx, filter).Decode(&product)

			// If not found by item_id, try by category fields and product name
			if err != nil && item.Section != "" {
				filter = bson.M{
					"category_section": item.Section,
					"category_main":    item.MainCategory,
					"category_sub":     item.Subcategory,
					"product_name":     item.ProductName,
				}
				productsCol.FindOne(ctx, filter).Decode(&product)
			}

			// Add image_url if product found
			if product.ImageURL != "" {
				order.Items[i].ImageURL = makeAbsolute(c, product.ImageURL)
			}
		} else {
			// Ensure existing URL is absolute
			order.Items[i].ImageURL = makeAbsolute(c, item.ImageURL)
		}
	}

	// Build response matching FastAPI structure: {success: true, order: {...}}
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"order":   order,
	})
}
