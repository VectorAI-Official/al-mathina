package handlers

import (
	"context"
	"fmt"
	"log"
	"math"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"al-mathina-backend/database"
	"al-mathina-backend/models"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
	"golang.org/x/text/collate"
	"golang.org/x/text/language"
)

// GetHome returns the home screen data: Most Bought + all sections with main categories
// GET /api/flutter/home
// Response matches FastAPI exactly: {best_sellers: {...}, sections: [...]}
func GetHome(c *gin.Context) {
	// Home payload builds many section/category cards; use a longer timeout than
	// the global 5s default to avoid context deadline on large catalogs.
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	// Use goroutines for parallel batch processing (FastAPI uses async)
	type mostBoughtResult struct {
		docs []models.MostBought
		err  error
	}
	type hierarchyDoc struct {
		Section        string              `bson:"section"`
		MainCategories map[string][]string `bson:"main_categories"`
	}
	type sectionsResult struct {
		docs []hierarchyDoc
		err  error
	}

	mostBoughtChan := make(chan mostBoughtResult, 1)
	sectionsChan := make(chan sectionsResult, 1)

	// Parallel batch 1: Fetch Most Bought categories
	go func() {
		mostBoughtCol := database.GetCollection("most_bought")
		cursor, err := mostBoughtCol.Find(ctx, bson.M{})
		if err != nil {
			mostBoughtChan <- mostBoughtResult{err: err}
			return
		}
		defer cursor.Close(ctx)

		var docs []models.MostBought
		err = cursor.All(ctx, &docs)
		mostBoughtChan <- mostBoughtResult{docs: docs, err: err}
	}()

	// Parallel batch 2: Fetch raw section hierarchy docs
	go func() {
		hierarchyCol := database.GetCollection("category_hierarchy")
		cursor, err := hierarchyCol.Find(ctx, bson.M{})
		if err != nil {
			sectionsChan <- sectionsResult{err: err}
			return
		}
		defer cursor.Close(ctx)

		var hierarchyDocs []hierarchyDoc
		if err := cursor.All(ctx, &hierarchyDocs); err != nil {
			sectionsChan <- sectionsResult{err: err}
			return
		}

		sectionsChan <- sectionsResult{docs: hierarchyDocs, err: nil}
	}()

	// Wait for both parallel batches to complete
	mostBoughtRes := <-mostBoughtChan
	sectionsRes := <-sectionsChan

	if mostBoughtRes.err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch Most Bought"})
		return
	}
	if sectionsRes.err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch sections"})
		return
	}

	// Batch product counts once (avoid N+1 CountDocuments per main category)
	productsCol := database.GetCollection("products")
	countPipeline := []bson.D{
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: bson.D{
				{Key: "section", Value: "$category_section"},
				{Key: "main", Value: "$category_main"},
			}},
			{Key: "count", Value: bson.D{{Key: "$sum", Value: 1}}},
		}}},
	}
	countCursor, err := productsCol.Aggregate(ctx, countPipeline)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to aggregate product counts"})
		return
	}
	defer countCursor.Close(ctx)

	var countRows []struct {
		ID struct {
			Section string `bson:"section"`
			Main    string `bson:"main"`
		} `bson:"_id"`
		Count int32 `bson:"count"`
	}
	if err := countCursor.All(ctx, &countRows); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode product counts"})
		return
	}

	key := func(section, main string) string { return section + "||" + main }
	productCounts := make(map[string]int, len(countRows))
	for _, row := range countRows {
		productCounts[key(row.ID.Section, row.ID.Main)] = int(row.Count)
	}

	// Batch metadata once (avoid per-card FindOne calls)
	metadataCol := database.GetCollection("category_metadata")
	metaCursor, err := metadataCol.Find(ctx, bson.M{}, options.Find().SetProjection(bson.M{
		"section": 1, "name": 1, "main_category": 1, "image_url": 1,
	}))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch category metadata"})
		return
	}
	defer metaCursor.Close(ctx)

	var metaRows []struct {
		Section      string `bson:"section"`
		Name         string `bson:"name"`
		MainCategory string `bson:"main_category"`
		ImageURL     string `bson:"image_url"`
	}
	if err := metaCursor.All(ctx, &metaRows); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode category metadata"})
		return
	}

	imageByExact := make(map[string]string, len(metaRows)) // section + name
	imageByName := make(map[string]string, len(metaRows))
	imageByLegacyMain := make(map[string]string, len(metaRows))
	for _, m := range metaRows {
		if m.ImageURL == "" {
			continue
		}
		if m.Section != "" && m.Name != "" {
			if _, ok := imageByExact[key(m.Section, m.Name)]; !ok {
				imageByExact[key(m.Section, m.Name)] = m.ImageURL
			}
		}
		if m.Name != "" {
			if _, ok := imageByName[m.Name]; !ok {
				imageByName[m.Name] = m.ImageURL
			}
		}
		if m.MainCategory != "" {
			if _, ok := imageByLegacyMain[m.MainCategory]; !ok {
				imageByLegacyMain[m.MainCategory] = m.ImageURL
			}
		}
	}

	buildMainCategoryCard := func(section, mainCategory string) models.MainCategory {
		imageURL := imageByExact[key(section, mainCategory)]
		if imageURL == "" {
			imageURL = imageByName[mainCategory]
		}
		if imageURL == "" {
			imageURL = imageByLegacyMain[mainCategory]
		}
		if imageURL == "" {
			imageURL = "/static/placeholder.png"
		}

		return models.MainCategory{
			Name:         mainCategory,
			ImageURL:     imageURL,
			ProductCount: productCounts[key(section, mainCategory)],
			Section:      section,
			MainCategory: mainCategory,
		}
	}

	// Build Most Bought section with title and icon (matching FastAPI)
	bestSellers := models.BestSellers{
		Title:          "Most Bought",
		Icon:           "⭐",
		MainCategories: []models.MainCategory{},
	}
	for _, mb := range mostBoughtRes.docs {
		bestSellers.MainCategories = append(bestSellers.MainCategories, buildMainCategoryCard(mb.Section, mb.MainCategory))
	}

	// Convert hierarchy docs to section array with title/icon/section_name
	var sections []models.HomeSection
	tamilCollator := collate.New(language.Tamil)
	for _, h := range sectionsRes.docs {
		sectionName := h.Section
		if sectionName == "" || sectionName == "Most Bought" {
			continue
		}

		mainCategories := []models.MainCategory{}
		if h.MainCategories != nil && len(h.MainCategories) > 0 {
			mainCatNames := make([]string, 0, len(h.MainCategories))
			for mainCatName := range h.MainCategories {
				mainCatNames = append(mainCatNames, mainCatName)
			}
			tamilCollator.SortStrings(mainCatNames)
			for _, mainCatName := range mainCatNames {
				mainCategories = append(mainCategories, buildMainCategoryCard(sectionName, mainCatName))
			}
		}

		sections = append(sections, models.HomeSection{
			Title:          sectionName, // Display name (use sectionName for now, can add localization later)
			Icon:           "📂",         // Default icon (matching FastAPI)
			SectionName:    sectionName, // Original name for queries
			MainCategories: mainCategories,
		})
	}

	// Sort sections alphabetically by title (matching FastAPI behavior)
	sort.Slice(sections, func(i, j int) bool {
		return sections[i].Title < sections[j].Title
	})

	// Return response matching FastAPI structure
	c.JSON(http.StatusOK, models.HomeResponse{
		BestSellers: bestSellers,
		Sections:    sections,
	})
}

// GetProducts returns paginated products with optional filters
// GET /api/flutter/products?user_phone=xxx&subcategory=xxx&page=1&limit=20
// CRITICAL: Admin users get buying_price field, regular users don't
func GetProducts(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	// Parse query parameters
	userPhone := c.Query("user_phone")
	subcategory := c.Query("subcategory")
	section := c.Query("section")
	mainCategory := c.Query("main_category")

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	// Validate limits
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	// Check if user is admin (for buying_price field)
	isAdmin := false
	if userPhone != "" && database.SupabaseDB != nil {
		var err error
		isAdmin, err = database.SupabaseDB.CheckIsAdmin(userPhone)
		if err != nil {
			log.Printf("⚠️  Admin check failed for %s: %v", userPhone, err)
		} else {
			log.Printf("🔐 GetProducts: User %s admin status: %v", userPhone, isAdmin)
		}
	}

	// Build MongoDB filter
	filter := bson.M{}
	if subcategory != "" {
		filter["category_sub"] = subcategory
	}
	if section != "" {
		filter["category_section"] = section
	}
	if mainCategory != "" {
		filter["category_main"] = mainCategory
	}

	// Count total products matching filter
	productsCol := database.GetCollection("products")
	totalCount, err := productsCol.CountDocuments(ctx, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count products"})
		return
	}

	// Calculate pagination
	totalPages := int(math.Ceil(float64(totalCount) / float64(limit)))
	skip := (page - 1) * limit

	// Fetch products using Find (returning to simple query)
	opts := options.Find().
		SetSkip(int64(skip)).
		SetLimit(int64(limit)).
		SetSort(bson.M{"product_name": 1})

	cursor, err := productsCol.Find(ctx, filter, opts)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
		return
	}
	defer cursor.Close(ctx)

	var products []models.Product
	if err := cursor.All(ctx, &products); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse products"})
		return
	}

	// Process products to set computed fields and handle admin-only data
	for i := range products {
		// Set in_stock computed field (matching FastAPI)
		products[i].InStock = products[i].Stock > 0

		// Remove buying_price for non-admin users
		// CRITICAL: Must match FastAPI behavior exactly
		if !isAdmin {
			products[i].BuyingPrice = nil
		}
	}

	// Build pagination info
	pagination := models.PaginationInfo{
		CurrentPage:  page,
		TotalPages:   totalPages,
		TotalItems:   int(totalCount),
		ItemsPerPage: limit,
		HasNext:      page < totalPages,
		HasPrev:      page > 1,
	}

	// Return response matching FastAPI structure
	c.JSON(http.StatusOK, models.ProductsResponse{
		Products:   products,
		IsAdmin:    isAdmin,
		Pagination: pagination,
	})
}

// SearchProducts searches products by query string across multiple fields
// GET /api/flutter/search?q=rice&page=1&limit=20
// Searches: product_name, section, main_category, subcategory
func SearchProducts(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	query := c.Query("q")
	log.Printf("🔵 SearchProducts: query=%s", query)

	if query == "" {
		log.Printf("❌ SearchProducts: Missing query parameter")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Query parameter 'q' is required"})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	log.Printf("🔍 SearchProducts: page=%d, limit=%d", page, limit)

	// Build search filter (case-insensitive regex across multiple fields)
	searchRegex := bson.M{"$regex": query, "$options": "i"}
	filter := bson.M{
		"active": true,
		"$or": []bson.M{
			{"product_name": searchRegex},
			{"category_section": searchRegex},
			{"category_main": searchRegex},
			{"category_sub": searchRegex},
			{"description": searchRegex},
		},
	}

	// Parallel batch: Count total + Fetch products concurrently
	type countResult struct {
		count int64
		err   error
	}
	type productsResult struct {
		products []models.Product
		err      error
	}

	countChan := make(chan countResult, 1)
	productsChan := make(chan productsResult, 1)

	// Goroutine 1: Count total results
	go func() {
		productsCol := database.GetCollection("products")
		totalCount, err := productsCol.CountDocuments(ctx, filter)
		if err != nil {
			log.Printf("❌ SearchProducts: Count error: %v", err)
		}
		countChan <- countResult{count: totalCount, err: err}
	}()

	// Goroutine 2: Fetch products using simple Find
	go func() {
		productsCol := database.GetCollection("products")
		skip := (page - 1) * limit
		opts := options.Find().
			SetSkip(int64(skip)).
			SetLimit(int64(limit)).
			SetSort(bson.M{"product_name": 1})

		cursor, err := productsCol.Find(ctx, filter, opts)
		if err != nil {
			log.Printf("❌ SearchProducts: Query error: %v", err)
			productsChan <- productsResult{err: err}
			return
		}
		defer cursor.Close(ctx)

		var products []models.Product
		if err := cursor.All(ctx, &products); err != nil {
			log.Printf("❌ SearchProducts: Parse error: %v", err)
			productsChan <- productsResult{err: err}
			return
		}
		if products == nil {
			products = []models.Product{}
		}
		productsChan <- productsResult{products: products, err: nil}
	}()

	// Wait for parallel batches
	countRes := <-countChan
	productsRes := <-productsChan

	if countRes.err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count search results"})
		return
	}
	if productsRes.err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search products"})
		return
	}

	// Calculate pagination
	totalPages := int(math.Ceil(float64(countRes.count) / float64(limit)))

	// Build pagination info
	pagination := models.PaginationInfo{
		CurrentPage:  page,
		TotalPages:   totalPages,
		TotalItems:   int(countRes.count),
		ItemsPerPage: limit,
		HasNext:      page < totalPages,
		HasPrev:      page > 1,
	}

	// Check if user is admin (for buying_price field) - Copied from GetProducts
	userPhone := c.Query("user_phone")
	isAdmin := false
	if userPhone != "" && database.SupabaseDB != nil {
		var err error
		isAdmin, err = database.SupabaseDB.CheckIsAdmin(userPhone)
		if err != nil {
			log.Printf("⚠️  SearchProducts: Admin check failed for %s: %v", userPhone, err)
		}
	}

	// Process products to handle admin-only data
	for i := range productsRes.products {
		// Set in_stock computed field
		productsRes.products[i].InStock = productsRes.products[i].Stock > 0

		// Remove buying_price for non-admin users
		if !isAdmin {
			productsRes.products[i].BuyingPrice = nil
		}
	}

	log.Printf("✅ SearchProducts: Found %d total results, returning %d products (page %d/%d)", countRes.count, len(productsRes.products), page, totalPages)

	// Return response matching FastAPI structure: {results: [...], is_admin: bool, ...}
	// CRITICAL: Flutter app expects "results" key, not "products"
	c.JSON(http.StatusOK, gin.H{
		"results":    productsRes.products,
		"is_admin":   isAdmin,
		"query":      query,
		"pagination": pagination,
	})
}

// GetSubcategories returns all subcategories for a given section/main_category
// GET /api/flutter/main-category/:section/:main_category/subcategories
// Returns: {section, main_category, subcategories: [...]} matching FastAPI
func GetSubcategories(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	section := c.Param("section")
	mainCategory := c.Param("main_category")

	log.Printf("🔵 GetSubcategories: section=%s, main_category=%s", section, mainCategory)

	if section == "" || mainCategory == "" {
		log.Printf("❌ GetSubcategories: Missing parameters")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Section and main_category are required"})
		return
	}

	// Parallel batch processing: Count products + Fetch metadata in parallel
	type subcategoryResult struct {
		subcategories []models.SubcategoryInfo
		err           error
	}

	subcategoryChan := make(chan subcategoryResult, 1)

	go func() {
		// Aggregate subcategories with product counts
		productsCol := database.GetCollection("products")
		pipeline := bson.A{
			bson.M{"$match": bson.M{
				"category_section": section,
				"category_main":    mainCategory,
				"active":           true,
			}},
			bson.M{"$group": bson.M{
				"_id":   "$category_sub",
				"count": bson.M{"$sum": 1},
			}},
			bson.M{"$sort": bson.M{"_id": 1}},
		}

		cursor, err := productsCol.Aggregate(ctx, pipeline)
		if err != nil {
			log.Printf("❌ GetSubcategories: Aggregation error: %v", err)
			subcategoryChan <- subcategoryResult{err: err}
			return
		}
		defer cursor.Close(ctx)

		var subcategories []models.SubcategoryInfo
		metadataCol := database.GetCollection("category_metadata")

		for cursor.Next(ctx) {
			var result struct {
				ID    string `bson:"_id"`
				Count int    `bson:"count"`
			}
			if err := cursor.Decode(&result); err != nil {
				log.Printf("⚠️ GetSubcategories: Decode error for subcategory: %v", err)
				continue
			}

			// Get metadata for this subcategory (matching FastAPI logic)
			var metadata models.CategoryMetadata
			filter := bson.M{
				"section":       section,
				"main_category": mainCategory,
				"type":          "subcategory",
				"$or": []bson.M{
					{"subcategory": result.ID},
					{"name": result.ID},
				},
			}
			metadataCol.FindOne(ctx, filter).Decode(&metadata)

			imageURL := metadata.ImageURL
			icon := metadata.Icon

			// Fallback: if no subcategory image, use main_category image (matching FastAPI)
			if imageURL == "" {
				var mainCatMetadata models.CategoryMetadata
				mainFilter := bson.M{
					"section": section,
					"type":    "main_category",
					"$or": []bson.M{
						{"main_category": mainCategory},
						{"name": mainCategory},
					},
				}
				metadataCol.FindOne(ctx, mainFilter).Decode(&mainCatMetadata)
				if mainCatMetadata.ImageURL != "" {
					imageURL = mainCatMetadata.ImageURL
					log.Printf("📷 Subcategory %s: Using main_category fallback image", result.ID)
				}
			}

			log.Printf("📷 Subcategory metadata: %s - image_url=%s", result.ID, imageURL)

			subcategories = append(subcategories, models.SubcategoryInfo{
				Name:         result.ID,
				ProductCount: result.Count,
				Icon:         icon,
				ImageURL:     imageURL,
			})
		}

		log.Printf("✅ GetSubcategories: Found %d subcategories", len(subcategories))
		subcategoryChan <- subcategoryResult{subcategories: subcategories, err: nil}
	}()

	// Wait for parallel batch to complete
	result := <-subcategoryChan

	if result.err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch subcategories"})
		return
	}

	// Return response matching FastAPI structure (object, not array)
	response := gin.H{
		"section":       section,
		"main_category": mainCategory,
		"subcategories": result.subcategories,
	}

	log.Printf("🎯 GetSubcategories: Returning %d subcategories for %s/%s", len(result.subcategories), section, mainCategory)
	c.JSON(http.StatusOK, response)
}

// GetProductDetails returns detailed information for a single product
// GET /api/flutter/product/:item_id
// Matches FastAPI /api/flutter/product/{item_id} endpoint
func GetProductDetails(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	itemID := c.Param("item_id")
	if itemID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "item_id is required"})
		return
	}

	// Parse product using FindOne
	productsCol := database.GetCollection("products")
	var product models.Product

	err := productsCol.FindOne(ctx, bson.M{"item_id": itemID, "active": true}).Decode(&product)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("Product not found: %s", itemID)})
		return
	}

	// Check if user is admin (for buying_price field)
	userPhone := c.Query("user_phone")
	isAdmin := false
	if userPhone != "" && database.SupabaseDB != nil {
		var err error
		isAdmin, err = database.SupabaseDB.CheckIsAdmin(userPhone)
		if err != nil {
			log.Printf("⚠️  GetProductDetails: Admin check failed for %s: %v", userPhone, err)
		}
	}

	// Build response matching FastAPI structure
	response := gin.H{
		"item_id":         itemID,
		"product_name":    product.ProductName,
		"product_name_ta": "", // Add if field exists in model
		"section":         product.Section,
		"main_category":   product.MainCategory,
		"subcategory":     product.Subcategory,
		"category": gin.H{
			"section":       product.Section,
			"main_category": product.MainCategory,
			"subcategory":   product.Subcategory,
		},
		"weight":         product.Weight,
		"unit":           product.Unit,
		"price":          product.Price,
		"stock":          product.Stock,
		"in_stock":       product.Stock > 0,
		"is_best_seller": false,
		"description":    product.Description,
		"image_url":      makeAbsolute(c, product.ImageURL),
		"images":         []string{makeAbsolute(c, product.ImageURL)}, // Can be extended
		"is_admin":       isAdmin,
	}

	// Add buying_price only for admins
	if isAdmin && product.BuyingPrice != nil {
		response["buying_price"] = *product.BuyingPrice
	}

	log.Printf("Retrieved product details for %s", itemID)
	c.JSON(http.StatusOK, response)
}

// makeAbsolute converts relative image URLs to absolute URLs
// Matches FastAPI behavior: /static/uploads/... → http://host:port/static/uploads/...
func makeAbsolute(c *gin.Context, path string) string {
	if path == "" {
		return ""
	}

	// Already absolute URL
	if strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://") {
		return path
	}

	// Relative path - make absolute
	scheme := "http"
	if c.Request.TLS != nil {
		scheme = "https"
	}

	host := c.Request.Host
	return fmt.Sprintf("%s://%s%s", scheme, host, path)
}
