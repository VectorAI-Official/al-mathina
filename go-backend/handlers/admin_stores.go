package handlers

import (
	"al-mathina-backend/database"
	"log"
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// GetStoresList - GET /admin/api/stores/list
func GetStoresList(c *gin.Context) {
	search := c.Query("search")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	limit := 50 // Default limit
	skip := 0   // Default skip

	if limitStr := c.Query("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil {
			limit = l
		}
	}
	if skipStr := c.Query("skip"); skipStr != "" {
		if s, err := strconv.Atoi(skipStr); err == nil {
			skip = s
		}
	}

	// Heavy aggregation → longer timeout (configurable via DB_LONG_TIMEOUT)
	ctx, cancel := database.GetLongDBContext()
	defer cancel()
	usersCollection := database.GetCollection("users")
	ordersCollection := database.GetCollection("orders")

	// Build user query for store filtering
	userQuery := bson.M{}
	if search != "" {
		// Escape the term: admins paste store names straight from other pages,
		// and an unescaped "(", "+" or "[" is an invalid regex that MongoDB
		// rejects, which breaks the search on the Revenue page itself.
		pattern := regexp.QuoteMeta(search)
		userQuery["$or"] = []bson.M{
			{"store_details.store_name": bson.M{"$regex": pattern, "$options": "i"}},
			{"phone": bson.M{"$regex": pattern, "$options": "i"}},
			{"name": bson.M{"$regex": pattern, "$options": "i"}},
		}
	}

	// Get total count for pagination
	totalCount, err := usersCollection.CountDocuments(ctx, userQuery)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count stores"})
		return
	}

	// Fetch users with pagination
	findOptions := options.Find().SetSkip(int64(skip)).SetLimit(int64(limit))
	cursor, err := usersCollection.Find(ctx, userQuery, findOptions)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch stores"})
		return
	}
	defer cursor.Close(ctx)

	var users []bson.M
	if err := cursor.All(ctx, &users); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode stores"})
		return
	}

	// Get all user phones for order stats
	userPhones := make([]string, len(users))
	for i, user := range users {
		if phone, ok := user["phone"].(string); ok {
			userPhones[i] = phone
		}
	}

	// Build the in-range condition once. When no date filter is supplied every
	// order counts, so the date-filtered accumulators collapse to "all-time".
	// The boundary semantics match the previous implementation exactly:
	// time.Parse("2006-01-02") (UTC) for start, and end-date + 1 day for the end.
	var inRange interface{} = true
	var dateBounds []interface{}
	if startDate != "" {
		if startTime, err := time.Parse("2006-01-02", startDate); err == nil {
			dateBounds = append(dateBounds, bson.D{{Key: "$gte", Value: []interface{}{"$created_at", startTime}}})
		}
	}
	if endDate != "" {
		if endTime, err := time.Parse("2006-01-02", endDate); err == nil {
			endTime = endTime.AddDate(0, 0, 1)
			dateBounds = append(dateBounds, bson.D{{Key: "$lte", Value: []interface{}{"$created_at", endTime}}})
		}
	}
	if len(dateBounds) == 1 {
		inRange = dateBounds[0]
	} else if len(dateBounds) > 1 {
		inRange = bson.D{{Key: "$and", Value: dateBounds}}
	}

	// ONE pipeline serves both the date-filtered stats and the all-time revenue:
	// conditional accumulation = one scan instead of the previous two.
	pipeline := []bson.D{
		{{Key: "$match", Value: bson.M{"user_phone": bson.M{"$in": userPhones}}}},
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: "$user_phone"},
			{Key: "order_count", Value: bson.D{{Key: "$sum", Value: bson.D{{Key: "$cond", Value: []interface{}{inRange, 1, 0}}}}}},
			{Key: "total_revenue", Value: bson.D{{Key: "$sum", Value: bson.D{{Key: "$cond", Value: []interface{}{inRange, "$total_amount", 0}}}}}},
			{Key: "latest_order", Value: bson.D{{Key: "$max", Value: bson.D{{Key: "$cond", Value: []interface{}{inRange, "$created_at", nil}}}}}},
			{Key: "all_time_revenue", Value: bson.D{{Key: "$sum", Value: "$total_amount"}}},
		}}},
	}

	start := time.Now()
	aggCursor, err := ordersCollection.Aggregate(ctx, pipeline)
	if err != nil {
		log.Printf("❌ GET /admin/api/stores/list AGGREGATE failed after %v: %v (ctx: %v)", time.Since(start), err, ctx.Err())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get order stats"})
		return
	}
	defer aggCursor.Close(ctx)

	var orderStatsResults []struct {
		UserPhone      string     `bson:"_id"`
		OrderCount     int        `bson:"order_count"`
		TotalRevenue   float64    `bson:"total_revenue"`
		LatestOrder    *time.Time `bson:"latest_order"`
		AllTimeRevenue float64    `bson:"all_time_revenue"`
	}
	if err := aggCursor.All(ctx, &orderStatsResults); err != nil {
		log.Printf("❌ GET /admin/api/stores/list CURSOR failed after %v: %v (ctx: %v)", time.Since(start), err, ctx.Err())
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode order stats"})
		return
	}

	// Create lookup maps (date-filtered stats + all-time revenue)
	orderStats := make(map[string]struct {
		OrderCount   int
		TotalRevenue float64
		LatestOrder  time.Time
	})
	allTimeStats := make(map[string]float64)
	for _, stat := range orderStatsResults {
		var latest time.Time
		if stat.LatestOrder != nil {
			latest = *stat.LatestOrder
		}
		orderStats[stat.UserPhone] = struct {
			OrderCount   int
			TotalRevenue float64
			LatestOrder  time.Time
		}{stat.OrderCount, stat.TotalRevenue, latest}
		allTimeStats[stat.UserPhone] = stat.AllTimeRevenue
	}

	if elapsed := time.Since(start); elapsed > 2*time.Second {
		log.Printf("⚠️ GET /admin/api/stores/list SLOW: %v (%d stores)", elapsed, len(orderStatsResults))
	}

	// Build response with enriched store data
	stores := make([]gin.H, 0, len(users))
	for _, user := range users {
		phone, _ := user["phone"].(string)
		stats := orderStats[phone]
		allTimeRevenue := allTimeStats[phone]

		var totalPaid float64
		if paid, ok := user["total_paid"].(float64); ok {
			totalPaid = paid
		} else if paid, ok := user["total_paid"].(int32); ok {
			totalPaid = float64(paid)
		}

		allTimeBalance := allTimeRevenue - totalPaid

		storeDetails := bson.M{}
		if sd, ok := user["store_details"].(bson.M); ok {
			storeDetails = sd
		}

		var createdAt *string
		if ct, ok := user["created_at"].(primitive.DateTime); ok {
			t := ct.Time().Format(time.RFC3339)
			createdAt = &t
		}

		var latestOrder *string
		if !stats.LatestOrder.IsZero() {
			t := stats.LatestOrder.Format(time.RFC3339)
			latestOrder = &t
		}

		storeInfo := gin.H{
			"_id":              user["_id"],
			"phone":            phone,
			"name":             user["name"],
			"email":            user["email"],
			"store_name":       storeDetails["store_name"],
			"city":             storeDetails["city"],
			"state":            storeDetails["state"],
			"created_at":       createdAt,
			"order_count":      stats.OrderCount,
			"total_revenue":    stats.TotalRevenue,
			"all_time_due":     allTimeRevenue,
			"all_time_paid":    totalPaid,
			"all_time_balance": allTimeBalance,
			"latest_order":     latestOrder,
		}
		stores = append(stores, storeInfo)
	}

	// Sort stores by all_time_due (total revenue) in descending order (highest first)
	sort.Slice(stores, func(i, j int) bool {
		iRevenue, _ := stores[i]["all_time_due"].(float64)
		jRevenue, _ := stores[j]["all_time_due"].(float64)
		return iRevenue > jRevenue // Descending order
	})

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"stores":   stores,
		"total":    totalCount,
		"has_more": (int64(skip) + int64(limit)) < totalCount,
	})
}

// GetStoresStatistics - GET /admin/api/stores/statistics
func GetStoresStatistics(c *gin.Context) {
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	search := c.Query("search")

	// Heavy aggregation → longer timeout (configurable via DB_LONG_TIMEOUT)
	ctx, cancel := database.GetLongDBContext()
	defer cancel()
	start := time.Now()
	usersCollection := database.GetCollection("users")
	ordersCollection := database.GetCollection("orders")

	// Build user query for store count (never filtered by date)
	userQuery := bson.M{}
	if search != "" {
		// Escape the term: admins paste store names straight from other pages,
		// and an unescaped "(", "+" or "[" is an invalid regex that MongoDB
		// rejects, which breaks the search on the Revenue page itself.
		pattern := regexp.QuoteMeta(search)
		userQuery["$or"] = []bson.M{
			{"store_details.store_name": bson.M{"$regex": pattern, "$options": "i"}},
			{"phone": bson.M{"$regex": pattern, "$options": "i"}},
			{"name": bson.M{"$regex": pattern, "$options": "i"}},
		}
	}

	// Get total store count (ALL stores, never filtered by date)
	totalStores, err := usersCollection.CountDocuments(ctx, userQuery)
	if err != nil {
		respondDBError(c, "GET /admin/api/stores/statistics (count)", start, err)
		return
	}

	// Get all user phones for order filtering
	cursor, err := usersCollection.Find(ctx, userQuery)
	if err != nil {
		respondDBError(c, "GET /admin/api/stores/statistics (find)", start, err)
		return
	}
	defer cursor.Close(ctx)

	var users []struct {
		Phone string `bson:"phone"`
	}
	if err := cursor.All(ctx, &users); err != nil {
		respondDBError(c, "GET /admin/api/stores/statistics (decode phones)", start, err)
		return
	}

	userPhones := make([]string, len(users))
	for i, user := range users {
		userPhones[i] = user.Phone
	}

	// Build order match query with date filter if applicable
	orderMatch := bson.M{}
	if len(userPhones) > 0 {
		orderMatch["user_phone"] = bson.M{"$in": userPhones}
	}
	if startDate != "" || endDate != "" {
		dateQuery := bson.M{}
		if startDate != "" {
			// Parse start date
			startTime, err := time.Parse("2006-01-02", startDate)
			if err == nil {
				dateQuery["$gte"] = startTime
			}
		}
		if endDate != "" {
			// Parse end date and add 1 day
			endTime, err := time.Parse("2006-01-02", endDate)
			if err == nil {
				endTime = endTime.AddDate(0, 0, 1) // Add 1 day
				dateQuery["$lte"] = endTime
			}
		}
		if len(dateQuery) > 0 {
			orderMatch["created_at"] = dateQuery
		}
	}

	// Calculate aggregated statistics
	pipeline := []bson.D{
		{{Key: "$match", Value: orderMatch}},
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: nil},
			{Key: "total_orders", Value: bson.D{{Key: "$sum", Value: 1}}},
			{Key: "total_revenue", Value: bson.D{{Key: "$sum", Value: "$total_amount"}}},
			{Key: "delivered_orders", Value: bson.D{{Key: "$sum", Value: bson.D{{Key: "$cond", Value: []interface{}{
				bson.D{{Key: "$eq", Value: []interface{}{"$status", "delivered"}}},
				1,
				0,
			}}}}}},
			{Key: "delivered_revenue", Value: bson.D{{Key: "$sum", Value: bson.D{{Key: "$cond", Value: []interface{}{
				bson.D{{Key: "$eq", Value: []interface{}{"$status", "delivered"}}},
				"$total_amount",
				0,
			}}}}}},
		}}},
	}

	aggCursor, err := ordersCollection.Aggregate(ctx, pipeline)
	if err != nil {
		respondDBError(c, "GET /admin/api/stores/statistics (aggregate)", start, err)
		return
	}
	defer aggCursor.Close(ctx)

	var results []struct {
		TotalOrders      int     `bson:"total_orders"`
		TotalRevenue     float64 `bson:"total_revenue"`
		DeliveredOrders  int     `bson:"delivered_orders"`
		DeliveredRevenue float64 `bson:"delivered_revenue"`
	}
	if err := aggCursor.All(ctx, &results); err != nil {
		respondDBError(c, "GET /admin/api/stores/statistics (decode stats)", start, err)
		return
	}

	logSlowQuery("GET /admin/api/stores/statistics", start, len(results))

	var stats struct {
		TotalOrders      int     `json:"total_orders"`
		TotalRevenue     float64 `json:"total_revenue"`
		DeliveredOrders  int     `json:"delivered_orders"`
		DeliveredRevenue float64 `json:"delivered_revenue"`
		AvgOrderValue    float64 `json:"avg_order_value"`
	}

	if len(results) > 0 {
		stats.TotalOrders = results[0].TotalOrders
		stats.TotalRevenue = results[0].TotalRevenue
		stats.DeliveredOrders = results[0].DeliveredOrders
		stats.DeliveredRevenue = results[0].DeliveredRevenue
		if stats.TotalOrders > 0 {
			stats.AvgOrderValue = stats.TotalRevenue / float64(stats.TotalOrders)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"statistics": gin.H{
			"total_stores":      totalStores,
			"total_orders":      stats.TotalOrders,
			"total_revenue":     stats.TotalRevenue,
			"delivered_orders":  stats.DeliveredOrders,
			"delivered_revenue": stats.DeliveredRevenue,
			"avg_order_value":   stats.AvgOrderValue,
		},
	})
}

// GetStoreDetail - GET /admin/api/stores/detail/:phone
func GetStoreDetail(c *gin.Context) {
	phone := c.Param("phone")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	// Heavy full-detail read → longer timeout (configurable via DB_LONG_TIMEOUT)
	ctx, cancel := database.GetLongDBContext()
	defer cancel()
	start := time.Now()
	usersCollection := database.GetCollection("users")
	ordersCollection := database.GetCollection("orders")

	// Find user
	var user bson.M
	err := usersCollection.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Store not found"})
		return
	}

	// Build orders query with date filter
	ordersQuery := bson.M{"user_phone": phone}
	if startDate != "" || endDate != "" {
		dateQuery := bson.M{}
		if startDate != "" {
			startTime, err := time.Parse("2006-01-02", startDate)
			if err == nil {
				dateQuery["$gte"] = startTime
			}
		}
		if endDate != "" {
			endTime, err := time.Parse("2006-01-02", endDate)
			if err == nil {
				endTime = endTime.AddDate(0, 0, 1)
				dateQuery["$lte"] = endTime
			}
		}
		if len(dateQuery) > 0 {
			ordersQuery["created_at"] = dateQuery
		}
	}

	// Fetch orders (date-filtered, sorted by created_at desc)
	findOptions := options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}})
	cursor, err := ordersCollection.Find(ctx, ordersQuery, findOptions)
	if err != nil {
		respondDBError(c, "GET /admin/api/stores/detail", start, err)
		return
	}
	defer cursor.Close(ctx)

	var orders []bson.M
	if err := cursor.All(ctx, &orders); err != nil {
		log.Printf("⚠️ GET /admin/api/stores/detail CURSOR decode failed after %v: %v", time.Since(start), err)
		orders = []bson.M{}
	}
	if orders == nil {
		orders = []bson.M{}
	}

	logSlowQuery("GET /admin/api/stores/detail", start, len(orders))

	// Calculate revenue statistics (date-filtered)
	totalOrders := len(orders)
	var totalRevenue, deliveredRevenue float64
	pendingOrders, confirmedOrders, deliveredOrders, cancelledOrders := 0, 0, 0, 0

	for _, order := range orders {
		if amount, ok := order["total_amount"].(float64); ok {
			totalRevenue += amount
			if status, ok := order["status"].(string); ok {
				switch status {
				case "pending":
					pendingOrders++
				case "confirmed":
					confirmedOrders++
				case "delivered":
					deliveredOrders++
					deliveredRevenue += amount
				case "cancelled":
					cancelledOrders++
				}
			}
		} else if amount, ok := order["total_amount"].(int32); ok {
			amt := float64(amount)
			totalRevenue += amt
			if status, ok := order["status"].(string); ok && status == "delivered" {
				deliveredRevenue += amt
			}
		}
	}

	// Fetch ALL-TIME totals (independent of date filter)
	allTimePipeline := []bson.D{
		{{Key: "$match", Value: bson.M{"user_phone": phone}}},
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: nil},
			{Key: "all_time_revenue", Value: bson.D{{Key: "$sum", Value: "$total_amount"}}},
		}}},
	}

	allTimeCursor, _ := ordersCollection.Aggregate(ctx, allTimePipeline)
	var allTimeResults []struct {
		AllTimeRevenue float64 `bson:"all_time_revenue"`
	}
	if allTimeCursor != nil {
		allTimeCursor.All(ctx, &allTimeResults)
		allTimeCursor.Close(ctx)
	}

	var allTimeDue, allTimePaid, allTimeBalance float64
	if len(allTimeResults) > 0 {
		allTimeDue = allTimeResults[0].AllTimeRevenue
	}
	if paid, ok := user["total_paid"].(float64); ok {
		allTimePaid = paid
	} else if paid, ok := user["total_paid"].(int32); ok {
		allTimePaid = float64(paid)
	}
	allTimeBalance = allTimeDue - allTimePaid

	// Payment history
	paymentHistory := []gin.H{}
	if ph, ok := user["payment_history"].(primitive.A); ok {
		for _, entry := range ph {
			if e, ok := entry.(bson.M); ok {
				amount := 0.0
				if a, ok := e["amount"].(float64); ok {
					amount = a
				} else if a, ok := e["amount"].(int32); ok {
					amount = float64(a)
				}

				var timestamp *string
				if ts, ok := e["timestamp"].(primitive.DateTime); ok {
					t := ts.Time().Format(time.RFC3339)
					timestamp = &t
				} else if ts, ok := e["timestamp"].(time.Time); ok {
					t := ts.Format(time.RFC3339)
					timestamp = &t
				}

				paymentHistory = append(paymentHistory, gin.H{
					"amount":    amount,
					"timestamp": timestamp,
				})
			}
		}
	}

	// Build store data
	var createdAt, updatedAt *string
	if ct, ok := user["created_at"].(primitive.DateTime); ok {
		t := ct.Time().Format(time.RFC3339)
		createdAt = &t
	}
	if ut, ok := user["updated_at"].(primitive.DateTime); ok {
		t := ut.Time().Format(time.RFC3339)
		updatedAt = &t
	}

	storeData := gin.H{
		"_id":              user["_id"],
		"phone":            user["phone"],
		"name":             user["name"],
		"email":            user["email"],
		"created_at":       createdAt,
		"updated_at":       updatedAt,
		"store_details":    user["store_details"],
		"addresses":        user["addresses"],
		"all_time_due":     allTimeDue,
		"all_time_paid":    allTimePaid,
		"all_time_balance": allTimeBalance,
		"payment_history":  paymentHistory,
	}

	revenueStats := gin.H{
		"total_orders":      totalOrders,
		"total_revenue":     totalRevenue,
		"delivered_revenue": deliveredRevenue,
		"pending_orders":    pendingOrders,
		"confirmed_orders":  confirmedOrders,
		"delivered_orders":  deliveredOrders,
		"cancelled_orders":  cancelledOrders,
		"average_order_value": func() float64 {
			if totalOrders > 0 {
				return totalRevenue / float64(totalOrders)
			}
			return 0
		}(),
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"store":   storeData,
		"orders":  orders,
		"revenue": revenueStats,
	})
}

// GetRevenueSummary - GET /admin/api/stores/revenue-summary
func GetRevenueSummary(c *gin.Context) {
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	// Heavy aggregation → longer timeout (configurable via DB_LONG_TIMEOUT)
	ctx, cancel := database.GetLongDBContext()
	defer cancel()
	ordersCollection := database.GetCollection("orders")

	// Build query with date filter
	query := bson.M{}
	if startDate != "" || endDate != "" {
		dateQuery := bson.M{}
		if startDate != "" {
			startTime, err := time.Parse("2006-01-02", startDate)
			if err == nil {
				dateQuery["$gte"] = startTime
			}
		}
		if endDate != "" {
			endTime, err := time.Parse("2006-01-02", endDate)
			if err == nil {
				endTime = endTime.AddDate(0, 0, 1)
				dateQuery["$lte"] = endTime
			}
		}
		if len(dateQuery) > 0 {
			query["created_at"] = dateQuery
		}
	}

	// Single aggregation returns ONE document — nothing but the summary crosses
	// the wire, so memory/GC pressure from shipping every order into Go is gone.
	pipeline := []bson.D{
		{{Key: "$match", Value: query}},
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: nil},
			{Key: "total_orders", Value: bson.D{{Key: "$sum", Value: 1}}},
			{Key: "total_revenue", Value: bson.D{{Key: "$sum", Value: "$total_amount"}}},
			{Key: "delivered_revenue", Value: bson.D{{Key: "$sum", Value: bson.D{{Key: "$cond", Value: []interface{}{
				bson.D{{Key: "$eq", Value: []interface{}{"$status", "delivered"}}},
				"$total_amount",
				0,
			}}}}}},
			{Key: "stores", Value: bson.D{{Key: "$addToSet", Value: "$user_phone"}}},
		}}},
	}

	start := time.Now()
	cursor, err := ordersCollection.Aggregate(ctx, pipeline)
	if err != nil {
		log.Printf("❌ GET /admin/api/stores/revenue-summary AGGREGATE failed after %v: %v (ctx: %v)", time.Since(start), err, ctx.Err())
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to fetch orders"})
		return
	}
	defer cursor.Close(ctx)

	var results []struct {
		TotalOrders      int           `bson:"total_orders"`
		TotalRevenue     float64       `bson:"total_revenue"`
		DeliveredRevenue float64       `bson:"delivered_revenue"`
		Stores           []interface{} `bson:"stores"`
	}
	if err := cursor.All(ctx, &results); err != nil {
		log.Printf("❌ GET /admin/api/stores/revenue-summary CURSOR failed after %v: %v (ctx: %v)", time.Since(start), err, ctx.Err())
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to decode orders"})
		return
	}

	var totalOrders int
	var totalRevenue, deliveredRevenue float64
	activeStores := 0
	if len(results) > 0 {
		totalOrders = results[0].TotalOrders
		totalRevenue = results[0].TotalRevenue
		deliveredRevenue = results[0].DeliveredRevenue
		// $addToSet includes null/missing user_phone; count only real phones,
		// matching the previous `phone != ""` filtering exactly.
		for _, s := range results[0].Stores {
			if phone, ok := s.(string); ok && phone != "" {
				activeStores++
			}
		}
	}

	averagePerStore := 0.0
	if activeStores > 0 {
		averagePerStore = totalRevenue / float64(activeStores)
	}

	if elapsed := time.Since(start); elapsed > 2*time.Second {
		log.Printf("⚠️ GET /admin/api/stores/revenue-summary SLOW: %v", elapsed)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"summary": gin.H{
			"total_orders":      totalOrders,
			"total_revenue":     totalRevenue,
			"delivered_revenue": deliveredRevenue,
			"active_stores":     activeStores,
			"average_per_store": averagePerStore,
		},
	})
}

// GetPaymentHistory - GET /admin/api/stores/:phone/payment-history
func GetPaymentHistory(c *gin.Context) {
	phone := c.Param("phone")

	// Reads full user document (incl. payment history) → longer timeout
	ctx, cancel := database.GetLongDBContext()
	defer cancel()
	usersCollection := database.GetCollection("users")

	var user bson.M
	err := usersCollection.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Store not found"})
		return
	}

	// Extract payment history
	paymentHistory := []gin.H{}
	if ph, ok := user["payment_history"].(primitive.A); ok {
		for _, entry := range ph {
			if e, ok := entry.(bson.M); ok {
				amount := 0.0
				if a, ok := e["amount"].(float64); ok {
					amount = a
				} else if a, ok := e["amount"].(int32); ok {
					amount = float64(a)
				}

				var timestamp *string
				if ts, ok := e["timestamp"].(primitive.DateTime); ok {
					t := ts.Time().Format(time.RFC3339)
					timestamp = &t
				} else if ts, ok := e["timestamp"].(time.Time); ok {
					t := ts.Format(time.RFC3339)
					timestamp = &t
				}

				paymentHistory = append(paymentHistory, gin.H{
					"amount":    amount,
					"timestamp": timestamp,
				})
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success":         true,
		"payment_history": paymentHistory,
	})
}

// AddPaymentHistory - POST /admin/api/stores/:phone/payment-history
func AddPaymentHistory(c *gin.Context) {
	phone := c.Param("phone")

	var req struct {
		Amount    float64 `json:"amount" binding:"required"`
		Timestamp string  `json:"timestamp"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()
	usersCollection := database.GetCollection("users")

	// Parse timestamp
	var timestamp time.Time
	if req.Timestamp != "" {
		if t, err := time.Parse(time.RFC3339, req.Timestamp); err == nil {
			timestamp = t
		} else {
			timestamp = time.Now()
		}
	} else {
		timestamp = time.Now()
	}

	// Create payment history entry
	historyEntry := bson.M{
		"amount":    req.Amount,
		"timestamp": primitive.NewDateTimeFromTime(timestamp),
	}

	// Get current total_paid
	var user bson.M
	err := usersCollection.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Store not found"})
		return
	}

	currentPaid := 0.0
	if paid, ok := user["total_paid"].(float64); ok {
		currentPaid = paid
	} else if paid, ok := user["total_paid"].(int32); ok {
		currentPaid = float64(paid)
	}

	newTotalPaid := currentPaid + req.Amount

	// Update user with new total_paid and append payment history
	result, err := usersCollection.UpdateOne(
		ctx,
		bson.M{"phone": phone},
		bson.M{
			"$set":  bson.M{"total_paid": newTotalPaid},
			"$push": bson.M{"payment_history": historyEntry},
		},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to add payment"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Store not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"message":       "Payment added successfully",
		"phone":         phone,
		"paid_amount":   req.Amount,
		"total_paid":    newTotalPaid,
		"history_entry": gin.H{"amount": req.Amount, "timestamp": timestamp.Format(time.RFC3339)},
	})
}

// RemovePaymentHistory - DELETE /admin/api/stores/:phone/payment-history/:timestamp
func RemovePaymentHistory(c *gin.Context) {
	phone := c.Param("phone")
	timestamp := c.Param("timestamp")

	ctx, cancel := database.GetDBContext()
	defer cancel()
	usersCollection := database.GetCollection("users")

	// Parse timestamp
	var targetTime time.Time
	var err error
	if targetTime, err = time.Parse(time.RFC3339, timestamp); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Invalid timestamp format"})
		return
	}

	// Find user and their payment history
	var user bson.M
	err = usersCollection.FindOne(ctx, bson.M{"phone": phone}).Decode(&user)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Store not found"})
		return
	}

	// Find the payment entry to remove
	var paymentAmount float64 = 0
	var foundPayment bool = false

	if ph, ok := user["payment_history"].(primitive.A); ok {
		for _, entry := range ph {
			if e, ok := entry.(bson.M); ok {
				if ts, ok := e["timestamp"].(primitive.DateTime); ok {
					if ts.Time().Format(time.RFC3339) == targetTime.Format(time.RFC3339) {
						if amt, ok := e["amount"].(float64); ok {
							paymentAmount = amt
							foundPayment = true
							break
						}
					}
				}
			}
		}
	}

	if !foundPayment {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Payment entry not found"})
		return
	}

	// Calculate new total_paid
	currentTotalPaid := 0.0
	if paid, ok := user["total_paid"].(float64); ok {
		currentTotalPaid = paid
	} else if paid, ok := user["total_paid"].(int32); ok {
		currentTotalPaid = float64(paid)
	}

	newTotalPaid := currentTotalPaid - paymentAmount
	if newTotalPaid < 0 {
		newTotalPaid = 0
	}

	// Update database: remove from payment_history array and update total_paid
	targetTimePrimitive := primitive.NewDateTimeFromTime(targetTime)
	update := bson.M{
		"$set": bson.M{"total_paid": newTotalPaid},
		"$pull": bson.M{
			"payment_history": bson.M{"timestamp": targetTimePrimitive},
		},
	}

	result, err := usersCollection.UpdateOne(ctx, bson.M{"phone": phone}, update)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to remove payment"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Store not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":        true,
		"message":        "Payment removed successfully",
		"phone":          phone,
		"removed_amount": paymentAmount,
		"new_total_paid": newTotalPaid,
	})
}

// UpdatePaidAmount - PUT /admin/api/stores/:phone/paid-amount
func UpdatePaidAmount(c *gin.Context) {
	phone := c.Param("phone")

	var req struct {
		PaidAmount float64 `json:"paid_amount" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": err.Error()})
		return
	}

	if req.PaidAmount < 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "error": "Paid amount cannot be negative"})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()
	usersCollection := database.GetCollection("users")

	// Create payment history entry
	historyEntry := bson.M{
		"amount":    req.PaidAmount,
		"timestamp": primitive.NewDateTimeFromTime(time.Now()),
	}

	// Update total_paid and append payment history
	result, err := usersCollection.UpdateOne(
		ctx,
		bson.M{"phone": phone},
		bson.M{
			"$set":  bson.M{"total_paid": req.PaidAmount},
			"$push": bson.M{"payment_history": historyEntry},
		},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to update paid amount"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "error": "Store not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"message":       "Paid amount updated successfully",
		"phone":         phone,
		"paid_amount":   req.PaidAmount,
		"history_entry": gin.H{"amount": req.PaidAmount, "timestamp": time.Now().Format(time.RFC3339)},
	})
}
