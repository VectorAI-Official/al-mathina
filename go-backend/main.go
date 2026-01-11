package main

import (
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"al-mathina-backend/config"
	"al-mathina-backend/database"
	"al-mathina-backend/handlers"
	"al-mathina-backend/utils"

	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	cfg := config.LoadConfig()

	// Connect to MongoDB
	if err := database.ConnectMongoDB(cfg.MongoURI); err != nil {
		log.Fatalf("Failed to connect to MongoDB: %v", err)
	}
	defer database.DisconnectMongoDB()

	// Connect to Supabase (optional - log warning if missing)
	if cfg.SupabaseURL != "" {
		if err := database.ConnectSupabase(cfg.SupabaseURL, cfg.SupabaseAnonKey, cfg.SupabaseServiceKey); err != nil {
			log.Printf("⚠️  Supabase connection failed: %v", err)
		}
	} else {
		log.Println("⚠️  Supabase not configured - admin features will not work")
	}

	// Initialize Cloudinary for image uploads (optional - will fallback to local storage)
	if err := utils.InitCloudinary(); err != nil {
		log.Printf("⚠️  Cloudinary not configured: %v (using local file storage)", err)
	}

	// Initialize Firebase for FCM push notifications (optional)
	if cfg.FirebaseServiceAccountPath != "" {
		if err := utils.InitFirebase(cfg.FirebaseServiceAccountPath); err != nil {
			log.Printf("⚠️  Firebase not configured: %v (FCM notifications disabled)", err)
		}
	} else {
		log.Println("⚠️  Firebase service account path not set - FCM notifications disabled")
	}

	// Initialize Email Service
	utils.InitEmailService()

	// Initialize Gin router
	// Use release mode in production for better performance
	if cfg.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// CORS middleware - allow Flutter web and mobile apps
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE, PATCH")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Cache-busting headers (critical for Flutter - prevents stale data)
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		c.Writer.Header().Set("Pragma", "no-cache")
		c.Writer.Header().Set("Expires", "0")
		c.Next()
	})

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":  "healthy",
			"service": "AL-Madhina Go Backend",
			"version": "1.0.0",
		})
	})

	// Flutter API routes (public endpoints for mobile app)
	flutterAPI := router.Group("/api/flutter")
	{
		flutterAPI.GET("/home", handlers.GetHome)
		flutterAPI.GET("/products", handlers.GetProducts)
		flutterAPI.GET("/product/:item_id", handlers.GetProductDetails)
		flutterAPI.GET("/search", handlers.SearchProducts)
		flutterAPI.GET("/main-category/:section/:main_category/subcategories", handlers.GetSubcategories)
	}

	// Admin API routes (for web dashboard)
	adminAPI := router.Group("/admin/api")
	{
		// Products - Read
		adminAPI.GET("/products/all", handlers.GetAllProducts)
		adminAPI.GET("/generate-item-id", handlers.GenerateItemID)

		// Products - CRUD
		adminAPI.POST("/products/add", handlers.AddProduct)
		adminAPI.PUT("/products/:product_id", handlers.UpdateProduct)
		adminAPI.DELETE("/products/:product_id", handlers.DeleteProduct)

		// Product-Inventory Linking
		adminAPI.POST("/products/:product_id/link-inventory", handlers.LinkProductToInventory)
		adminAPI.DELETE("/products/:product_id/link-inventory", handlers.UnlinkProductFromInventory)

		// Image uploads
		adminAPI.POST("/upload-image", handlers.UploadCategoryImage)
		adminAPI.POST("/upload/image/:product_id", handlers.UploadProductImage)

		// Categories - Read operations
		adminAPI.GET("/categories/all", handlers.GetAllCategories)
		adminAPI.GET("/categories/sections", handlers.GetSections)
		adminAPI.GET("/categories/main/:section", handlers.GetMainCategories)
		adminAPI.GET("/categories/sub/:section/:main_category", handlers.GetSubcategoriesAdmin)
		adminAPI.GET("/categories/metadata", handlers.GetCategoryMetadata)

		// Categories - CRUD operations
		adminAPI.POST("/categories/section", handlers.CreateSection)
		adminAPI.POST("/categories/main", handlers.CreateMainCategory)
		adminAPI.PUT("/categories/main/:main_category_name", handlers.UpdateMainCategory)
		adminAPI.POST("/categories/sub", handlers.CreateSubcategory)
		adminAPI.DELETE("/categories/section/:section_name", handlers.DeleteSection)
		adminAPI.DELETE("/categories/main/:section_name/:main_category", handlers.DeleteMainCategory)
		adminAPI.DELETE("/categories/sub/:section_name/:main_category/:subcategory", handlers.DeleteSubcategory)

		// Most Bought management
		adminAPI.GET("/most-bought", handlers.GetMostBought)
		adminAPI.POST("/most-bought", handlers.AddMostBought)
		adminAPI.DELETE("/most-bought", handlers.RemoveMostBought)

		// Stores management
		adminAPI.GET("/stores/list", handlers.GetStoresList)
		adminAPI.GET("/stores/statistics", handlers.GetStoresStatistics)
		adminAPI.GET("/stores/detail/:phone", handlers.GetStoreDetail)
		adminAPI.GET("/stores/revenue-summary", handlers.GetRevenueSummary)
		adminAPI.GET("/stores/:phone/payment-history", handlers.GetPaymentHistory)
		adminAPI.POST("/stores/:phone/payment-history", handlers.AddPaymentHistory)
		adminAPI.DELETE("/stores/:phone/payment-history/:timestamp", handlers.RemovePaymentHistory)
		adminAPI.PUT("/stores/:phone/paid-amount", handlers.UpdatePaidAmount)
	}

	// Admin Orders API routes
	ordersAPI := router.Group("/api/admin")
	{
		ordersAPI.GET("/orders", handlers.GetAllOrders)
		ordersAPI.GET("/orders/:order_id", handlers.GetOrderByID)
		ordersAPI.PUT("/orders/:order_id/status", handlers.UpdateOrderStatus)
		ordersAPI.PUT("/orders/:order_id/update-items", handlers.UpdateOrderItems)
		ordersAPI.DELETE("/orders/:order_id", handlers.DeleteOrder)
		ordersAPI.GET("/orders/stats/summary", handlers.GetOrderStats)
		ordersAPI.GET("/orders/products/search", handlers.SearchProductsAdmin)
	}

	// General API routes (dashboard utilities)
	apiRoutes := router.Group("/api")
	{
		apiRoutes.GET("/generate-item-id", handlers.GenerateItemID)
	}

	// Inventory Management routes (centralized inventory system)
	inventoryAPI := router.Group("/admin/api/inventory")
	{
		inventoryAPI.GET("", handlers.GetAllInventory)
		inventoryAPI.GET("/search", handlers.SearchInventory)
		inventoryAPI.GET("/alerts", handlers.GetInventoryAlerts)
		inventoryAPI.GET("/:inventory_id", handlers.GetInventoryByID)
		inventoryAPI.GET("/:inventory_id/history", handlers.GetInventoryHistory)
		inventoryAPI.POST("", handlers.CreateInventory)
		inventoryAPI.PUT("/:inventory_id", handlers.UpdateInventory)
		inventoryAPI.POST("/:inventory_id/stock", handlers.UpdateInventoryStock)
		inventoryAPI.DELETE("/:inventory_id", handlers.DeleteInventory)
	}

	// FCM routes (push notifications - Session 4)
	fcmAPI := router.Group("/api")
	{
		fcmAPI.POST("/fcm-token", handlers.SaveFCMToken)
		fcmAPI.GET("/fcm-token/:phone", handlers.GetFCMToken)
	}

	// User Profile routes (Session 4)
	userAPI := router.Group("/api")
	{
		userAPI.GET("/version", handlers.GetAppVersion)
		userAPI.GET("/profile/:phone", handlers.GetUserProfile)
		userAPI.PUT("/profile/:phone", handlers.UpdateUserProfile)
		userAPI.DELETE("/profile/:phone", handlers.DeleteUserProfile)
		userAPI.PUT("/phone/:old_phone", handlers.ChangePhoneNumber)

		// Address management
		userAPI.POST("/address/:phone", handlers.AddAddress)
		userAPI.PUT("/address/:phone/:index", handlers.UpdateAddress)
		userAPI.DELETE("/address/:phone/:index", handlers.DeleteAddress)

		// Orders
		userAPI.GET("/orders/:phone", handlers.GetUserOrders)
		userAPI.POST("/orders", handlers.CreateOrder)
		userAPI.GET("/orders/:phone/:order_id", handlers.GetOrderDetails)

		// Store details
		userAPI.GET("/store-details/:phone", handlers.GetStoreDetails)
		userAPI.PUT("/store-details/:phone", handlers.UpdateStoreDetails)

		// Favorites
		userAPI.GET("/favorites/:phone", handlers.GetFavorites)
		userAPI.POST("/favorites/:phone", handlers.AddFavorite)
		userAPI.DELETE("/favorites/:phone/:item_id", handlers.RemoveFavorite)
	}

	// Legacy Flutter Routes (for compatibility with older APKs/FastAPI structure)
	// These mirror the /api/flutter/user/... structure
	legacyAPI := router.Group("/api/flutter/user")
	{
		legacyAPI.GET("/profile/:phone", handlers.GetUserProfile)
		legacyAPI.PUT("/profile/:phone", handlers.UpdateUserProfile)
		legacyAPI.DELETE("/profile/:phone", handlers.DeleteUserProfile)
		legacyAPI.PUT("/phone/:old_phone", handlers.ChangePhoneNumber)

		legacyAPI.GET("/store-details/:phone", handlers.GetStoreDetails)
		legacyAPI.PUT("/store-details/:phone", handlers.UpdateStoreDetails)

		legacyAPI.GET("/favorites/:phone", handlers.GetFavorites)
		legacyAPI.POST("/favorites/:phone", handlers.AddFavorite)
		legacyAPI.DELETE("/favorites/:phone/:item_id", handlers.RemoveFavorite)

		legacyAPI.GET("/orders/:phone", handlers.GetUserOrders)
		legacyAPI.POST("/orders", handlers.CreateOrder)
		legacyAPI.GET("/orders/:phone/:order_id", handlers.GetOrderDetails)

		legacyAPI.POST("/address/:phone", handlers.AddAddress)
		legacyAPI.PUT("/address/:phone/:index", handlers.UpdateAddress)
		legacyAPI.DELETE("/address/:phone/:index", handlers.DeleteAddress)
	}

	// Static file serving (matches FastAPI pattern)
	router.Static("/static", "./static")

	// Admin Authentication Routes
	router.GET("/admin", func(c *gin.Context) {
		// Check if already logged in
		if cookie, err := c.Cookie("admin_session"); err == nil && cookie != "" {
			c.Redirect(http.StatusSeeOther, "/admin/dashboard")
			return
		}

		c.File("./static/admin/login.html")
	})

	router.GET("/admin/login", func(c *gin.Context) {
		c.Redirect(http.StatusSeeOther, "/admin")
	})

	router.POST("/admin/login", handlers.AdminLogin)
	router.POST("/admin/logout", handlers.AdminLogout)

	// Admin UI routes (Protected)
	adminUI := router.Group("/admin")
	adminUI.Use(handlers.AuthMiddleware())
	{
		adminUI.GET("/dashboard", func(c *gin.Context) {
			c.File("./static/admin/dashboard.html")
		})

		adminUI.GET("/inventory", func(c *gin.Context) {
			c.File("./static/admin/inventory.html")
		})
		adminUI.GET("/orders", func(c *gin.Context) {
			c.File("./static/admin/orders.html")
		})
		adminUI.GET("/revenue", func(c *gin.Context) {
			c.File("./static/admin/stores.html")
		})
	}

	// Start server
	port := cfg.Port
	log.Printf("🚀 Server starting on port %s", port)
	log.Printf("📱 Flutter API: http://localhost:%s/api/flutter/home", port)
	log.Printf("🏥 Health check: http://localhost:%s/health", port)

	// Graceful shutdown
	go func() {
		if err := router.Run(":" + port); err != nil {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("👋 Shutting down server...")
}
