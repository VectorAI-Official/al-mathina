package handlers

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"sync/atomic"
	"time"

	"al-mathina-backend/config"
	"al-mathina-backend/database"
	"al-mathina-backend/models"
	"al-mathina-backend/utils"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// orderCounter ensures unique order IDs even when multiple sections are created
// at the same nanosecond on fast hardware
var orderCounter uint64

// ===== USER PROFILE HANDLERS =====

func isMongoNotFound(err error) bool {
	return errors.Is(err, mongo.ErrNoDocuments)
}

func respondMongoUnavailable(c *gin.Context, operation string, err error) {
	log.Printf("❌ %s: MongoDB unavailable: %v", operation, err)
	c.JSON(http.StatusServiceUnavailable, gin.H{
		"error":   "Database temporarily unavailable",
		"message": "MongoDB is temporarily unable to serve this request. Please retry shortly.",
	})
}

func respondWriteFailure(c *gin.Context, operation, message string, err error) {
	log.Printf("❌ %s: %s: %v", operation, message, err)
	respondMongoUnavailable(c, operation, err)
}

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
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "GetUserProfile", err)
			return
		}

		// User not found - auto-create with defaults (matching FastAPI)
		log.Printf("📝 GetUserProfile: No user found, creating default user for phone=%s", phone)
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
		respondWriteFailure(c, "UpdateUserProfile", "failed to update profile", err)
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
		respondMongoUnavailable(c, "GetUserOrders", err)
		return
	}
	defer cursor.Close(ctx)

	var orders []models.Order
	if err := cursor.All(ctx, &orders); err != nil {
		respondMongoUnavailable(c, "GetUserOrders", err)
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

	// Use a generous timeout for order creation: large orders (100-500 items) do N+1
	// product enrichment queries (up to 2 DB calls per item) + one insert per section.
	// 500 items × 2 slow Atlas roundtrips = 1000 queries; 15 minutes ensures even the
	// largest realistic order completes without a spurious context-deadline 500 error.
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()

	// Set default payment method if not provided
	paymentMethod := req.PaymentMethod
	if paymentMethod == "" {
		paymentMethod = "cod"
	}

	// ── Step 1: collect unique product names in-memory (O(n), zero DB calls) ─
	uniqueProdNames := make([]string, 0, len(req.Items))
	seenNames := make(map[string]bool, len(req.Items))
	for _, item := range req.Items {
		name := item.ProductName
		if name == "" {
			name = item.Brand
		}
		if name != "" && !seenNames[name] {
			seenNames[name] = true
			uniqueProdNames = append(uniqueProdNames, name)
		}
	}

	// ── Step 2: user lookup + product batch fetch IN PARALLEL ────────────────
	// Both are independent Atlas round-trips; running them concurrently cuts
	// wall time from (user_ms + batch_ms) down to max(user_ms, batch_ms).
	type userFetchResult struct{ name string }
	type prodBatchResult struct {
		exact map[string]models.Product
		lower map[string]models.Product
	}
	userCh := make(chan userFetchResult, 1)
	prodCh := make(chan prodBatchResult, 1)

	go func() {
		name := req.UserName
		if name == "" {
			usersCol := database.GetCollection("users")
			var user models.User
			if err := usersCol.FindOne(ctx, bson.M{"phone": req.UserPhone}).Decode(&user); err == nil && user.Name != "" {
				name = user.Name
				log.Printf("📝 CreateOrder: Fetched user name from DB: %s", name)
			} else {
				name = "Guest"
				log.Printf("⚠️  CreateOrder: User not found or no name, using 'Guest'")
			}
		}
		userCh <- userFetchResult{name: name}
	}()

	go func() {
		exact := make(map[string]models.Product, len(uniqueProdNames))
		lower := make(map[string]models.Product, len(uniqueProdNames))
		if len(uniqueProdNames) > 0 {
			productsCol := database.GetCollection("products")
			proj := options.Find().SetProjection(bson.M{
				"item_id": 1, "product_name": 1, "weight": 1,
				"image_url": 1, "category_section": 1, "category_main": 1, "category_sub": 1,
			})
			cursor, err := productsCol.Find(ctx, bson.M{"product_name": bson.M{"$in": uniqueProdNames}}, proj)
			if err != nil {
				log.Printf("⚠️  CreateOrder: batch product fetch error: %v", err)
			} else {
				var results []models.Product
				if err2 := cursor.All(ctx, &results); err2 != nil {
					log.Printf("⚠️  CreateOrder: cursor.All error: %v", err2)
				}
				cursor.Close(ctx) // close eagerly — don't hold the cursor open for 15 min
				for _, p := range results {
					exact[p.ProductName] = p
					lower[strings.ToLower(p.ProductName)] = p
				}
				log.Printf("📦 CreateOrder: batch-fetched %d/%d unique products", len(results), len(uniqueProdNames))
			}
		}
		prodCh <- prodBatchResult{exact: exact, lower: lower}
	}()

	// Wait for both parallel fetches (channels are buffered — no deadlock risk)
	userRes := <-userCh
	prodRes := <-prodCh
	userName := userRes.name
	batchExact := prodRes.exact
	batchLower := prodRes.lower

	// ── Step 3: second-pass case-insensitive $in with collation ─────────────
	// MongoDB collation (strength=2) matches names case-insensitively without
	// regex — it stays index-friendly and costs exactly ONE round-trip for any
	// number of unmatched names.
	// Old $or[regex…] approach: evaluated each /^name$/i against every document
	// without index benefit → O(N×collection_size) for N unmatched names.
	// With 1000-item orders even 100 unmatched names would cause seconds of lag.
	var unmatchedNames []string
	for _, name := range uniqueProdNames {
		if _, ok := batchExact[name]; !ok {
			if _, ok := batchLower[strings.ToLower(name)]; !ok {
				unmatchedNames = append(unmatchedNames, name)
			}
		}
	}
	if len(unmatchedNames) > 0 {
		log.Printf("🔍 CreateOrder: second-pass collation $in for %d unmatched name(s)", len(unmatchedNames))
		productsCol2 := database.GetCollection("products")
		proj2 := options.Find().
			SetProjection(bson.M{
				"item_id": 1, "product_name": 1, "weight": 1,
				"image_url": 1, "category_section": 1, "category_main": 1, "category_sub": 1,
			}).
			SetCollation(&options.Collation{Locale: "en", Strength: 2})
		if cur2, err := productsCol2.Find(ctx,
			bson.M{"product_name": bson.M{"$in": unmatchedNames}}, proj2); err == nil {
			var results2 []models.Product
			cur2.All(ctx, &results2)
			cur2.Close(ctx)
			for _, p := range results2 {
				batchExact[p.ProductName] = p
				batchLower[strings.ToLower(p.ProductName)] = p
			}
			log.Printf("📦 CreateOrder: second-pass resolved %d product(s)", len(results2))
		}
	}

	// ── Step 4: enrich items from in-memory maps (zero DB calls) ─────────────
	for i := range req.Items {
		// Map legacy/Flutter fields
		if req.Items[i].ProductName == "" && req.Items[i].Brand != "" {
			req.Items[i].ProductName = req.Items[i].Brand
		}
		if req.Items[i].MainCategory == "" && req.Items[i].Category != "" {
			req.Items[i].MainCategory = req.Items[i].Category
		}

		// Enrich from map — no DB call
		if req.Items[i].ProductName != "" {
			product, found := batchExact[req.Items[i].ProductName]
			if !found {
				product, found = batchLower[strings.ToLower(req.Items[i].ProductName)]
			}
			if found && product.ItemID != "" {
				if req.Items[i].ItemID == "" {
					req.Items[i].ItemID = product.ItemID
				}
				if req.Items[i].Weight == "" {
					req.Items[i].Weight = product.Weight
				}
				if req.Items[i].ImageURL == "" {
					req.Items[i].ImageURL = product.ImageURL
				}
				if req.Items[i].Section == "" {
					req.Items[i].Section = product.Section
				}
				if req.Items[i].MainCategory == "" {
					req.Items[i].MainCategory = product.MainCategory
				}
				if req.Items[i].Subcategory == "" {
					req.Items[i].Subcategory = product.Subcategory
				}
				log.Printf("✨ Enriched item: %s -> ID: %s, Weight: %s",
					req.Items[i].ProductName, product.ItemID, product.Weight)
			}
		}

		// Ensure subtotal
		if req.Items[i].Subtotal == 0 {
			req.Items[i].Subtotal = float64(req.Items[i].Quantity) * req.Items[i].Price
		}
	}

	// Grouping by section removed - consolidated into one order
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
	totalItemsCount := len(req.Items)
	totalAmount := 0.0
	for _, item := range req.Items {
		totalAmount += item.Subtotal
	}

	// ── Step 5: build single order doc and write in ONE InsertOne call ────────
	ordersCol := database.GetCollection("orders")
	
	// nanoseconds + atomic counter guarantees uniqueness
	ordering := atomic.AddUint64(&orderCounter, 1)
	orderID := fmt.Sprintf("ORD-%d-%d", time.Now().UnixNano(), ordering)

	order := models.Order{
		OrderID:         orderID,
		UserPhone:       req.UserPhone,
		UserName:        userName,
		Section:         "Combined", // Set to "Combined" or leave as default
		DeliveryAddress: req.DeliveryAddress,
		Items:           req.Items,
		TotalAmount:     totalAmount,
		PaymentMethod:   paymentMethod,
		Status:          "pending",
		CreatedAt:       time.Now(),
		Notes:           req.Notes,
		Metadata:        map[string]interface{}{},
	}

	if _, err := ordersCol.InsertOne(ctx, order); err != nil {
		log.Printf("❌ CreateOrder: InsertOne failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create order"})
		return
	}

	createdOrders = append(createdOrders, CreatedOrder{
		OrderID:     orderID,
		Section:     "Combined",
		ItemsCount:  totalItemsCount,
		TotalAmount: totalAmount,
		Status:      "pending",
	})
	allOrders = append(allOrders, order)

	log.Printf("✅ CreateOrder: Consolidated order created (%d items total)", totalItemsCount)

	// Send email notification for the order (async - don't block response)
	log.Printf("📧 CreateOrder: Scheduling email notification...")
	if utils.GlobalEmailService != nil {
		go utils.GlobalEmailService.SendOrderNotificationToAdmin(order)
	}

	// Send single FCM push notification to user for combined order (async)
	go sendFCMOrderNotification(req.UserPhone, orderID, totalAmount, totalItemsCount, userName)

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"message":      "Order created successfully",
		"orders":       createdOrders,
		"total_orders": len(createdOrders),
	})
}

// sendOrderEmailNotification sends order notification to admin via Vercel webhook
// Runs asynchronously in background (goroutine)

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

// buildItemsHTML formats order items as HTML table rows using fmt.Sprintf
// Matches the structure required by the new email template

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
		respondWriteFailure(c, "AddAddress", "failed to add address", err)
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
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "UpdateAddress", err)
			return
		}
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
		respondWriteFailure(c, "UpdateAddress", "failed to update address", err)
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
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "DeleteAddress", err)
			return
		}
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
		respondWriteFailure(c, "DeleteAddress", "failed to delete address", err)
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
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "GetStoreDetails", err)
			return
		}

		// User not found - auto-create with defaults (matching FastAPI)
		log.Printf("📝 GetStoreDetails: No user found, creating default user for phone=%s", phone)
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
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "UpdateStoreDetails", err)
			return
		}
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
		respondWriteFailure(c, "UpdateStoreDetails", "failed to update store details", err)
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
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "GetFavorites", err)
			return
		}

		// User not found - auto-create with defaults (matching FastAPI)
		log.Printf("📝 GetFavorites: No user found, creating default user for phone=%s", phone)
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

	// Batch-fetch all favorite products in ONE query instead of N goroutines
	// Old approach: spawn N goroutines → N FindOne calls → risk of context timeout
	// before slow goroutines complete → "broken pipe" errors.
	// New approach: single $in query for all favorite IDs → 1 round-trip.
	favoriteProducts := []map[string]interface{}{}
	if len(user.Favorites) == 0 {
		log.Printf("✅ GetFavorites: User has no favorites")
		c.JSON(http.StatusOK, gin.H{
			"success":   true,
			"favorites": favoriteProducts,
		})
		return
	}

	// Batch-fetch all products by item_id in single Find call
	cursor, err := productsCol.Find(ctx, bson.M{"item_id": bson.M{"$in": user.Favorites}})
	if err != nil {
		log.Printf("⚠️ GetFavorites: Batch fetch error: %v", err)
		c.JSON(http.StatusOK, gin.H{
			"success":   true,
			"favorites": []map[string]interface{}{},
		})
		return
	}
	defer cursor.Close(ctx)

	var products []map[string]interface{}
	if err := cursor.All(ctx, &products); err != nil {
		log.Printf("⚠️ GetFavorites: Parse error: %v", err)
		c.JSON(http.StatusOK, gin.H{
			"success":   true,
			"favorites": []map[string]interface{}{},
		})
		return
	}

	// Build lookup map for fast O(1) access by item_id
	productMap := make(map[string]map[string]interface{}, len(products))
	for _, p := range products {
		if itemID, ok := p["item_id"].(string); ok {
			productMap[itemID] = p
		}
	}

	// Reconstruct products in original favorite order (preserve user's ordering intent)
	missingItemIDs := make([]string, 0)
	for _, itemID := range user.Favorites {
		product, ok := productMap[itemID]
		if !ok {
			log.Printf("⚠️ GetFavorites: Product not found or missing item_id: %s", itemID)
			missingItemIDs = append(missingItemIDs, itemID)
			continue // Skip if product not found
		}

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

	// Self-heal orphaned favorites caused by product deletions that did not
	// clean up users.favorites at write time.
	if len(missingItemIDs) > 0 {
		if _, err := usersCol.UpdateOne(ctx, bson.M{"phone": phone}, bson.M{
			"$pullAll": bson.M{"favorites": missingItemIDs},
			"$set":     bson.M{"updated_at": time.Now()},
		}); err != nil {
			log.Printf("⚠️ GetFavorites: Failed to prune orphan favorites for %s: %v", phone, err)
		} else {
			log.Printf("🧹 GetFavorites: Pruned %d orphan favorite(s) for user %s", len(missingItemIDs), phone)
		}
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
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "AddFavorite", err)
			return
		}
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	// Check if user exists
	var user models.User
	err = usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)

	if err != nil {
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "AddFavorite", err)
			return
		}

		// Create user with favorites array
		newUser := bson.M{
			"phone":      phone,
			"favorites":  []string{req.ItemID},
			"created_at": time.Now(),
			"updated_at": time.Now(),
		}
		_, err = usersCol.InsertOne(ctx, newUser)
		if err != nil {
			respondWriteFailure(c, "AddFavorite", "failed to create user", err)
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
			respondWriteFailure(c, "AddFavorite", "failed to add favorite", err)
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
		respondWriteFailure(c, "RemoveFavorite", "failed to remove favorite", err)
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
	if err != nil && !isMongoNotFound(err) {
		respondMongoUnavailable(c, "ChangePhoneNumber", err)
		return
	}

	// Get old user data
	var oldUser models.User
	err = usersCol.FindOne(ctx, bson.M{"phone": oldPhone}).Decode(&oldUser)
	if err != nil {
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "ChangePhoneNumber", err)
			return
		}
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
		respondWriteFailure(c, "ChangePhoneNumber", "failed to update phone in users", err)
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
		respondWriteFailure(c, "DeleteUserProfile", "failed to delete user", err)
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
		if !isMongoNotFound(err) {
			respondMongoUnavailable(c, "GetOrderDetails", err)
			return
		}
		c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
		return
	}

	// Enrich order with user's store details for delivery address
	var user models.User
	err = usersCol.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil && !isMongoNotFound(err) {
		respondMongoUnavailable(c, "GetOrderDetails", err)
		return
	}

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
