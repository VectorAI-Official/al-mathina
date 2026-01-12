package handlers

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"al-mathina-backend/database"
	"al-mathina-backend/models"
	"al-mathina-backend/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ===== ADMIN API HANDLERS =====
// These endpoints power the admin dashboard in Backend/static/admin/

// GetAllProducts returns all products for admin dashboard product management
// GET /admin/api/products/all
func GetAllProducts(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	productsCol := database.GetCollection("products")

	// Use bson.D for ordered sort (bson.M doesn't guarantee order)
	opts := options.Find().SetSort(bson.D{
		{Key: "category_section", Value: 1},
		{Key: "category_main", Value: 1},
		{Key: "category_sub", Value: 1},
		{Key: "product_name", Value: 1},
	})
	cursor, err := productsCol.Find(ctx, bson.M{}, opts)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch products"})
		return
	}
	defer cursor.Close(ctx)

	// Use bson.M to preserve ALL fields from dashboard (item_id, buying_date, active, etc.)
	var products []bson.M
	if err := cursor.All(ctx, &products); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse products"})
		return
	}

	// Convert ObjectID to string for each product
	for i := range products {
		if products[i]["_id"] != nil {
			products[i]["_id"] = products[i]["_id"].(primitive.ObjectID).Hex()
		}
	}

	// Return empty array if no products (not null)
	if products == nil {
		products = []bson.M{}
	}

	// Match FastAPI response format: {products: [...]}
	c.JSON(http.StatusOK, gin.H{"products": products})
}

// GenerateItemID generates a unique item ID for a new product
// GET /admin/api/generate-item-id
func GenerateItemID(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	productsCol := database.GetCollection("products")

	// Generate item_id using timestamp (matches JavaScript frontend logic)
	// Format: prod_<timestamp>
	timestamp := time.Now().UnixMilli()
	itemID := fmt.Sprintf("prod_%d", timestamp)

	// Ensure uniqueness (check if it already exists)
	for {
		existing, err := productsCol.CountDocuments(ctx, bson.M{"item_id": itemID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check item_id uniqueness"})
			return
		}

		if existing == 0 {
			break // Unique ID found
		}

		// If collision (very rare), increment timestamp slightly
		timestamp++
		itemID = fmt.Sprintf("prod_%d", timestamp)
	}

	c.JSON(http.StatusOK, gin.H{"item_id": itemID})
}

// GetAllCategories returns complete category hierarchy for admin dashboard
// GET /admin/api/categories/all
// Reads from category_hierarchy collection (matches Python backend implementation)
func GetAllCategories(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	// Get hierarchy from category_hierarchy collection (same as Python backend)
	hierarchyCol := database.GetCollection("category_hierarchy")

	// Define struct matching MongoDB document structure
	type SectionNode struct {
		Section        string              `bson:"section" json:"section"`
		MainCategories map[string][]string `bson:"main_categories" json:"main_categories"`
	}

	cursor, err := hierarchyCol.Find(ctx, bson.M{}, options.Find().SetProjection(bson.M{"_id": 0}))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch categories from hierarchy collection"})
		return
	}
	defer cursor.Close(ctx)

	var hierarchy []SectionNode
	if err := cursor.All(ctx, &hierarchy); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode category hierarchy"})
		return
	}

	// Return empty array if no hierarchy found (not null)
	if hierarchy == nil {
		hierarchy = []SectionNode{}
	}

	// Match FastAPI response format: {hierarchy: [...]}
	c.JSON(http.StatusOK, gin.H{"hierarchy": hierarchy})
}

// GetSections returns all unique sections from category_hierarchy
// GET /admin/api/categories/sections
func GetSections(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	hierarchyCol := database.GetCollection("category_hierarchy")
	sections, err := hierarchyCol.Distinct(ctx, "section", bson.M{})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch sections"})
		return
	}

	// Match FastAPI response format: {sections: [...]}
	c.JSON(http.StatusOK, gin.H{"sections": sections})
}

// GetMainCategories returns main categories for a section from category_hierarchy
// GET /admin/api/categories/main/:section
func GetMainCategories(c *gin.Context) {
	section := c.Param("section")
	ctx, cancel := database.GetDBContext()
	defer cancel()

	hierarchyCol := database.GetCollection("category_hierarchy")

	type HierarchyDoc struct {
		MainCategories map[string][]string `bson:"main_categories"`
	}

	var doc HierarchyDoc
	err := hierarchyCol.FindOne(ctx, bson.M{"section": section}).Decode(&doc)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"main_categories": []string{}})
		return
	}

	// Extract keys from map
	mainCategories := make([]string, 0, len(doc.MainCategories))
	for key := range doc.MainCategories {
		mainCategories = append(mainCategories, key)
	}

	// Match FastAPI response format: {main_categories: [...]}
	c.JSON(http.StatusOK, gin.H{"main_categories": mainCategories})
}

// GetSubcategoriesAdmin returns subcategories for section/main_category from category_hierarchy
// GET /admin/api/categories/sub/:section/:main_category
func GetSubcategoriesAdmin(c *gin.Context) {
	section := c.Param("section")
	mainCategory := c.Param("main_category")

	ctx, cancel := database.GetDBContext()
	defer cancel()

	hierarchyCol := database.GetCollection("category_hierarchy")

	type HierarchyDoc struct {
		MainCategories map[string][]string `bson:"main_categories"`
	}

	var doc HierarchyDoc
	err := hierarchyCol.FindOne(ctx, bson.M{"section": section}).Decode(&doc)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"subcategories": []string{}})
		return
	}

	// Get subcategories for the specific main category
	subcategories, exists := doc.MainCategories[mainCategory]
	if !exists {
		subcategories = []string{}
	}

	// Match FastAPI response format: {subcategories: [...]}
	c.JSON(http.StatusOK, gin.H{"subcategories": subcategories})
}

// ===== CATEGORY CRUD OPERATIONS =====

// CreateSection creates a new section in category_hierarchy
// POST /admin/api/categories/section
func CreateSection(c *gin.Context) {
	var reqBody struct {
		Section   string `json:"section" binding:"required"`
		SectionTA string `json:"section_ta"` // Tamil name (optional)
	}

	if err := c.ShouldBindJSON(&reqBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Section name is required"})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	hierarchyCol := database.GetCollection("category_hierarchy")

	// Check if section already exists
	count, err := hierarchyCol.CountDocuments(ctx, bson.M{"section": reqBody.Section})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check section existence"})
		return
	}
	if count > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Section '%s' already exists", reqBody.Section)})
		return
	}

	// Insert new section
	doc := bson.M{
		"section":         reqBody.Section,
		"main_categories": bson.M{},
	}
	if reqBody.SectionTA != "" {
		doc["section_ta"] = reqBody.SectionTA
	}

	_, err = hierarchyCol.InsertOne(ctx, doc)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create section"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": fmt.Sprintf("Section '%s' created successfully", reqBody.Section)})
}

// CreateMainCategory creates a new main category under a section
// POST /admin/api/categories/main
func CreateMainCategory(c *gin.Context) {
	var reqBody struct {
		Section        string `json:"section" binding:"required"`
		MainCategory   string `json:"main_category" binding:"required"`
		MainCategoryTA string `json:"main_category_ta"` // Tamil name (optional)
		ImageURL       string `json:"image_url"`        // Optional
	}

	if err := c.ShouldBindJSON(&reqBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Section and main category are required"})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	hierarchyCol := database.GetCollection("category_hierarchy")

	// Add main category to section (creates empty subcategory array)
	update := bson.M{
		"$set": bson.M{
			fmt.Sprintf("main_categories.%s", reqBody.MainCategory): []string{},
		},
	}

	result, err := hierarchyCol.UpdateOne(
		ctx,
		bson.M{"section": reqBody.Section},
		update,
		options.Update().SetUpsert(true),
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create main category"})
		return
	}

	if result.MatchedCount == 0 && result.UpsertedCount == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to create main category"})
		return
	}

	// Save metadata if provided
	if reqBody.ImageURL != "" || reqBody.MainCategoryTA != "" {
		metadataCol := database.GetCollection("category_metadata")
		metadataDoc := bson.M{
			"section": reqBody.Section,
			"name":    reqBody.MainCategory,
			"type":    "main_category",
		}
		if reqBody.MainCategoryTA != "" {
			metadataDoc["name_ta"] = reqBody.MainCategoryTA
		}
		if reqBody.ImageURL != "" {
			metadataDoc["image_url"] = reqBody.ImageURL
		}

		_, err = metadataCol.UpdateOne(
			ctx,
			bson.M{"section": reqBody.Section, "name": reqBody.MainCategory, "type": "main_category"},
			bson.M{"$set": metadataDoc},
			options.Update().SetUpsert(true),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save metadata"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": fmt.Sprintf("Main category '%s' created successfully", reqBody.MainCategory)})
}

// UpdateMainCategory updates an existing main category's name, image, or Tamil name
// PUT /admin/api/categories/main/:main_category_name
func UpdateMainCategory(c *gin.Context) {
	mainCategoryName := c.Param("main_category_name")

	var reqBody struct {
		Section        string  `json:"section" binding:"required"`
		NewName        *string `json:"new_name"`         // Optional: rename
		ImageURL       *string `json:"image_url"`        // Optional: update image
		MainCategoryTA *string `json:"main_category_ta"` // Optional: Tamil name
	}

	if err := c.ShouldBindJSON(&reqBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Section is required"})
		return
	}

	// At least one update field required
	if reqBody.NewName == nil && reqBody.ImageURL == nil && reqBody.MainCategoryTA == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No update data provided"})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	hierarchyCol := database.GetCollection("category_hierarchy")
	metadataCol := database.GetCollection("category_metadata")
	productsCol := database.GetCollection("products")

	// Update main category name in hierarchy if new_name provided
	if reqBody.NewName != nil && *reqBody.NewName != mainCategoryName {
		newName := *reqBody.NewName

		// Find section document
		var sectionDoc bson.M
		err := hierarchyCol.FindOne(ctx, bson.M{"section": reqBody.Section}).Decode(&sectionDoc)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Section not found"})
			return
		}

		// Check if main category exists
		mainCategories, ok := sectionDoc["main_categories"].(bson.M)
		if !ok || mainCategories[mainCategoryName] == nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Main category not found"})
			return
		}

		// Get subcategories
		subcategories := mainCategories[mainCategoryName]

		// Rename main category (remove old, add new)
		_, err = hierarchyCol.UpdateOne(
			ctx,
			bson.M{"section": reqBody.Section},
			bson.M{
				"$unset": bson.M{fmt.Sprintf("main_categories.%s", mainCategoryName): ""},
				"$set":   bson.M{fmt.Sprintf("main_categories.%s", newName): subcategories},
			},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to rename main category"})
			return
		}

		// Update all products with this main category
		_, _ = productsCol.UpdateMany(
			ctx,
			bson.M{"category_section": reqBody.Section, "category_main": mainCategoryName},
			bson.M{"$set": bson.M{"category_main": newName}},
		)

		// Update metadata name
		metadataUpdate := bson.M{"name": newName}
		if reqBody.MainCategoryTA != nil {
			metadataUpdate["name_ta"] = *reqBody.MainCategoryTA
		}

		_, _ = metadataCol.UpdateOne(
			ctx,
			bson.M{"section": reqBody.Section, "name": mainCategoryName, "type": "main_category"},
			bson.M{"$set": metadataUpdate},
		)

		mainCategoryName = newName // Use new name for subsequent operations
	} else if reqBody.MainCategoryTA != nil {
		// Only updating Tamil name (no rename)
		_, _ = metadataCol.UpdateOne(
			ctx,
			bson.M{"section": reqBody.Section, "name": mainCategoryName, "type": "main_category"},
			bson.M{"$set": bson.M{"name_ta": *reqBody.MainCategoryTA}},
			options.Update().SetUpsert(true),
		)
	}

	// Update image URL in metadata
	if reqBody.ImageURL != nil {
		metadataUpdate := bson.M{
			"section": reqBody.Section,
			"name":    mainCategoryName,
			"type":    "main_category",
		}
		if *reqBody.ImageURL != "" {
			metadataUpdate["image_url"] = *reqBody.ImageURL
		}

		_, _ = metadataCol.UpdateOne(
			ctx,
			bson.M{"section": reqBody.Section, "name": mainCategoryName, "type": "main_category"},
			bson.M{"$set": metadataUpdate},
			options.Update().SetUpsert(true),
		)
	}

	c.JSON(http.StatusOK, gin.H{
		"message":  "Main category updated successfully",
		"new_name": mainCategoryName,
	})
}

// CreateSubcategory creates a new subcategory under a main category
// POST /admin/api/categories/sub
func CreateSubcategory(c *gin.Context) {
	var reqBody struct {
		Section       string `json:"section" binding:"required"`
		MainCategory  string `json:"main_category" binding:"required"`
		Subcategory   string `json:"subcategory" binding:"required"`
		SubcategoryTA string `json:"subcategory_ta"` // Tamil name (optional)
		ImageURL      string `json:"image_url"`      // Optional
	}

	if err := c.ShouldBindJSON(&reqBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Section, main category, and subcategory are required"})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	hierarchyCol := database.GetCollection("category_hierarchy")

	// Add subcategory to main category (using $addToSet to avoid duplicates)
	update := bson.M{
		"$addToSet": bson.M{
			fmt.Sprintf("main_categories.%s", reqBody.MainCategory): reqBody.Subcategory,
		},
	}

	result, err := hierarchyCol.UpdateOne(
		ctx,
		bson.M{"section": reqBody.Section},
		update,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create subcategory"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Section '%s' not found", reqBody.Section)})
		return
	}

	// Save metadata if provided
	if reqBody.ImageURL != "" || reqBody.SubcategoryTA != "" {
		metadataCol := database.GetCollection("category_metadata")
		metadataDoc := bson.M{
			"section":       reqBody.Section,
			"name":          reqBody.Subcategory,
			"type":          "subcategory",
			"main_category": reqBody.MainCategory,
		}
		if reqBody.SubcategoryTA != "" {
			metadataDoc["name_ta"] = reqBody.SubcategoryTA
		}
		if reqBody.ImageURL != "" {
			metadataDoc["image_url"] = reqBody.ImageURL
		}

		_, err = metadataCol.UpdateOne(
			ctx,
			bson.M{"section": reqBody.Section, "name": reqBody.Subcategory, "type": "subcategory", "main_category": reqBody.MainCategory},
			bson.M{"$set": metadataDoc},
			options.Update().SetUpsert(true),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save metadata"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": fmt.Sprintf("Subcategory '%s' created successfully", reqBody.Subcategory)})
}

// ===== MOST BOUGHT MANAGEMENT =====

// GetMostBought returns all starred categories (Most Bought section)
// GET /admin/api/most-bought
func GetMostBought(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	mostBoughtCol := database.GetCollection("most_bought")
	cursor, err := mostBoughtCol.Find(ctx, bson.M{}, options.Find().SetSort(bson.M{"starred_at": -1}))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch Most Bought"})
		return
	}
	defer cursor.Close(ctx)

	var mostBought []models.MostBought
	if err := cursor.All(ctx, &mostBought); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse Most Bought"})
		return
	}

	// Return empty array if nil
	if mostBought == nil {
		mostBought = []models.MostBought{}
	}

	// Match FastAPI response format: {items: [...]}
	c.JSON(http.StatusOK, gin.H{"items": mostBought})
}

// AddMostBought adds a main category to Most Bought section
// POST /admin/api/most-bought
// Body: {section: string, main_category: string}
func AddMostBought(c *gin.Context) {
	var req struct {
		Section      string `json:"section" binding:"required"`
		MainCategory string `json:"main_category" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	// Check if already starred
	mostBoughtCol := database.GetCollection("most_bought")
	filter := bson.M{
		"section":       req.Section,
		"main_category": req.MainCategory,
	}

	var existing models.MostBought
	err := mostBoughtCol.FindOne(ctx, filter).Decode(&existing)
	if err == nil {
		// Already exists
		c.JSON(http.StatusConflict, gin.H{"error": "Category already in Most Bought"})
		return
	}

	// Insert new
	newMostBought := models.MostBought{
		Section:      req.Section,
		MainCategory: req.MainCategory,
		StarredAt:    time.Now(),
	}

	_, err = mostBoughtCol.InsertOne(ctx, newMostBought)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add Most Bought"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"message": "Added to Most Bought",
		"data":    newMostBought,
	})
}

// RemoveMostBought removes a category from Most Bought section
// DELETE /admin/api/most-bought?section=X&main_category=Y
func RemoveMostBought(c *gin.Context) {
	section := c.Query("section")
	mainCategory := c.Query("main_category")

	if section == "" || mainCategory == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "section and main_category are required"})
		return
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()

	mostBoughtCol := database.GetCollection("most_bought")
	filter := bson.M{
		"section":       section,
		"main_category": mainCategory,
	}

	result, err := mostBoughtCol.DeleteOne(ctx, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove Most Bought"})
		return
	}

	if result.DeletedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Category not found in Most Bought"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Removed from Most Bought"})
}

// GetCategoryMetadata returns all category metadata (images, icons)
// GET /admin/api/categories/metadata
func GetCategoryMetadata(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	metadataCol := database.GetCollection("category_metadata")
	cursor, err := metadataCol.Find(ctx, bson.M{})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch metadata"})
		return
	}
	defer cursor.Close(ctx)

	var metadata []models.CategoryMetadata
	if err := cursor.All(ctx, &metadata); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to parse metadata"})
		return
	}

	// Return empty array if nil
	if metadata == nil {
		metadata = []models.CategoryMetadata{}
	}

	// Match FastAPI response format: {metadata: [...]}
	c.JSON(http.StatusOK, gin.H{"metadata": metadata})
}

// DeleteSection deletes a section and all its data with Cloudinary cleanup
// DELETE /admin/api/categories/section/:section_name
func DeleteSection(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	sectionName := c.Param("section_name")

	fmt.Printf("🗑️ DELETING SECTION:\n")
	fmt.Printf("   Section Name: %s\n", sectionName)

	productsCol := database.GetCollection("products")
	metadataCol := database.GetCollection("category_metadata")
	hierarchyCol := database.GetCollection("category_hierarchy")
	mostBoughtCol := database.GetCollection("most_bought")

	productImageCount := 0
	categoryImageCount := 0

	// STEP 1: Delete all product images in this section
	productCursor, err := productsCol.Find(ctx, bson.M{
		"category_section": sectionName,
		"image_url":        bson.M{"$exists": true, "$ne": ""},
	})
	if err == nil {
		var products []bson.M
		productCursor.All(ctx, &products)
		productCursor.Close(ctx)

		for _, product := range products {
			if imageURL, ok := product["image_url"].(string); ok && imageURL != "" {
				fmt.Printf("      Deleting product: %v - %s\n", product["product_name"], imageURL)
				if utils.DeleteImage(imageURL) {
					productImageCount++
				}
			}
		}
	}
	fmt.Printf("   ✓ Product images deleted: %d\n", productImageCount)

	// STEP 2: Delete all category metadata images
	metadataCursor, err := metadataCol.Find(ctx, bson.M{
		"section":   sectionName,
		"image_url": bson.M{"$exists": true, "$ne": ""},
	})
	if err == nil {
		var metadataItems []bson.M
		metadataCursor.All(ctx, &metadataItems)
		metadataCursor.Close(ctx)

		for _, metadata := range metadataItems {
			if imageURL, ok := metadata["image_url"].(string); ok && imageURL != "" {
				fmt.Printf("      Deleting %v: %v - %s\n", metadata["type"], metadata["name"], imageURL)
				if utils.DeleteImage(imageURL) {
					categoryImageCount++
				}
			}
		}
	}
	fmt.Printf("   ✓ Category images deleted: %d\n", categoryImageCount)

	// STEP 3: Delete hierarchy document
	hierarchyResult, _ := hierarchyCol.DeleteOne(ctx, bson.M{"section": sectionName})
	fmt.Printf("   Hierarchy deleted: %d document(s)\n", hierarchyResult.DeletedCount)

	// STEP 4: Delete metadata
	metadataResult, _ := metadataCol.DeleteMany(ctx, bson.M{"section": sectionName})
	fmt.Printf("   Metadata deleted: %d document(s)\n", metadataResult.DeletedCount)

	// STEP 5: Delete products
	productsResult, _ := productsCol.DeleteMany(ctx, bson.M{"category_section": sectionName})
	fmt.Printf("   Products deleted: %d document(s)\n", productsResult.DeletedCount)

	// STEP 6: Delete most_bought entries
	mostBoughtResult, _ := mostBoughtCol.DeleteMany(ctx, bson.M{"section": sectionName})
	fmt.Printf("   Most bought deleted: %d document(s)\n", mostBoughtResult.DeletedCount)

	totalImages := productImageCount + categoryImageCount
	fmt.Printf("✅ Section '%s' deleted with %d images from Cloudinary\n", sectionName, totalImages)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("Section deleted with %d images", totalImages),
	})
}

// DeleteMainCategory deletes a main category and all subcategories with Cloudinary cleanup
// DELETE /admin/api/categories/main/:section_name/:main_category
func DeleteMainCategory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	sectionName := c.Param("section_name")
	mainCategory := c.Param("main_category")

	fmt.Printf("🗑️ DELETING MAIN CATEGORY:\n")
	fmt.Printf("   Section: %s\n", sectionName)
	fmt.Printf("   Main Category: %s\n", mainCategory)

	productsCol := database.GetCollection("products")
	metadataCol := database.GetCollection("category_metadata")
	hierarchyCol := database.GetCollection("category_hierarchy")
	mostBoughtCol := database.GetCollection("most_bought")

	productImageCount := 0
	categoryImageCount := 0

	// STEP 1: Delete all product images
	productCursor, err := productsCol.Find(ctx, bson.M{
		"category_section": sectionName,
		"category_main":    mainCategory,
		"image_url":        bson.M{"$exists": true, "$ne": ""},
	})
	if err == nil {
		var products []bson.M
		productCursor.All(ctx, &products)
		productCursor.Close(ctx)

		for _, product := range products {
			if imageURL, ok := product["image_url"].(string); ok && imageURL != "" {
				if utils.DeleteImage(imageURL) {
					productImageCount++
				}
			}
		}
	}
	fmt.Printf("   ✓ Product images deleted: %d\n", productImageCount)

	// STEP 2: Delete main category image
	mainMetadata := metadataCol.FindOne(ctx, bson.M{
		"section": sectionName,
		"name":    mainCategory,
		"type":    "main_category",
	})
	var mainMeta bson.M
	if mainMetadata.Decode(&mainMeta) == nil {
		if imageURL, ok := mainMeta["image_url"].(string); ok && imageURL != "" {
			if utils.DeleteImage(imageURL) {
				categoryImageCount++
				fmt.Println("   ✓ Main category image deleted")
			}
		}
	}

	// STEP 3: Delete all subcategory images
	subMetadataCursor, err := metadataCol.Find(ctx, bson.M{
		"section":       sectionName,
		"main_category": mainCategory,
		"type":          "subcategory",
		"image_url":     bson.M{"$exists": true, "$ne": ""},
	})
	if err == nil {
		var subMetadata []bson.M
		subMetadataCursor.All(ctx, &subMetadata)
		subMetadataCursor.Close(ctx)

		for _, metadata := range subMetadata {
			if imageURL, ok := metadata["image_url"].(string); ok && imageURL != "" {
				if utils.DeleteImage(imageURL) {
					categoryImageCount++
				}
			}
		}
	}
	fmt.Printf("   ✓ Category images deleted: %d\n", categoryImageCount)

	// STEP 4: Remove from hierarchy (pull main category key)
	hierarchyCol.UpdateOne(ctx, bson.M{"section": sectionName}, bson.M{
		"$unset": bson.M{fmt.Sprintf("main_categories.%s", mainCategory): ""},
	})

	// STEP 5: Delete main category metadata
	metadataCol.DeleteMany(ctx, bson.M{
		"section": sectionName,
		"name":    mainCategory,
		"type":    "main_category",
	})

	// STEP 6: Delete all subcategory metadata
	metadataCol.DeleteMany(ctx, bson.M{
		"section":       sectionName,
		"main_category": mainCategory,
		"type":          "subcategory",
	})

	// STEP 7: Delete all products
	productsResult, _ := productsCol.DeleteMany(ctx, bson.M{
		"category_section": sectionName,
		"category_main":    mainCategory,
	})
	fmt.Printf("   Products deleted: %d document(s)\n", productsResult.DeletedCount)

	// STEP 8: Delete most_bought entries
	mostBoughtCol.DeleteMany(ctx, bson.M{
		"section":       sectionName,
		"main_category": mainCategory,
	})

	totalImages := productImageCount + categoryImageCount
	fmt.Printf("✅ Main category '%s' deleted with %d images\n", mainCategory, totalImages)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("Main category deleted with %d images", totalImages),
	})
}

// DeleteSubcategory deletes a subcategory and all its products with Cloudinary cleanup
// DELETE /admin/api/categories/sub/:section_name/:main_category/:subcategory
func DeleteSubcategory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	sectionName := c.Param("section_name")
	mainCategory := c.Param("main_category")
	subcategory := c.Param("subcategory")

	fmt.Printf("🗑️ DELETING SUBCATEGORY:\n")
	fmt.Printf("   Section: %s\n", sectionName)
	fmt.Printf("   Main Category: %s\n", mainCategory)
	fmt.Printf("   Subcategory: %s\n", subcategory)

	productsCol := database.GetCollection("products")
	metadataCol := database.GetCollection("category_metadata")
	hierarchyCol := database.GetCollection("category_hierarchy")

	imageDeleteCount := 0

	// STEP 1: Delete all product images
	productCursor, err := productsCol.Find(ctx, bson.M{
		"category_section": sectionName,
		"category_main":    mainCategory,
		"category_sub":     subcategory,
		"image_url":        bson.M{"$exists": true, "$ne": ""},
	})
	if err == nil {
		var products []bson.M
		productCursor.All(ctx, &products)
		productCursor.Close(ctx)

		for _, product := range products {
			if imageURL, ok := product["image_url"].(string); ok && imageURL != "" {
				if utils.DeleteImage(imageURL) {
					imageDeleteCount++
				}
			}
		}
	}
	fmt.Printf("   ✓ Product images deleted: %d\n", imageDeleteCount)

	// STEP 2: Delete subcategory image
	subMetadata := metadataCol.FindOne(ctx, bson.M{
		"section":       sectionName,
		"main_category": mainCategory,
		"name":          subcategory,
		"type":          "subcategory",
	})
	var subMeta bson.M
	if subMetadata.Decode(&subMeta) == nil {
		if imageURL, ok := subMeta["image_url"].(string); ok && imageURL != "" {
			if utils.DeleteImage(imageURL) {
				fmt.Println("   ✓ Subcategory image deleted")
			}
		}
	}

	// STEP 3: Remove from hierarchy
	hierarchyCol.UpdateOne(ctx, bson.M{"section": sectionName}, bson.M{
		"$pull": bson.M{fmt.Sprintf("main_categories.%s", mainCategory): subcategory},
	})

	// STEP 4: Delete subcategory metadata
	metadataCol.DeleteMany(ctx, bson.M{
		"section":       sectionName,
		"main_category": mainCategory,
		"name":          subcategory,
		"type":          "subcategory",
	})

	// STEP 5: Delete all products
	productsResult, _ := productsCol.DeleteMany(ctx, bson.M{
		"category_section": sectionName,
		"category_main":    mainCategory,
		"category_sub":     subcategory,
	})
	fmt.Printf("   Products deleted: %d document(s)\n", productsResult.DeletedCount)

	fmt.Printf("✅ Subcategory '%s' deleted with %d images\n", subcategory, imageDeleteCount)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": fmt.Sprintf("Subcategory deleted with %d images", imageDeleteCount),
	})
}

// UploadCategoryImage handles image uploads for categories (section, main, subcategory)
// POST /admin/api/upload-image
// Multipart form with 'file' field
func UploadCategoryImage(c *gin.Context) {
	// Get uploaded file
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}

	// Validate file type
	allowedTypes := map[string]bool{
		"image/jpeg": true,
		"image/jpg":  true,
		"image/png":  true,
		"image/webp": true,
	}

	contentType := file.Header.Get("Content-Type")
	if !allowedTypes[contentType] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file type. Only JPG, PNG, WebP allowed."})
		return
	}

	// Validate file size (max 2MB)
	if file.Size > 2*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "File size exceeds 2MB limit."})
		return
	}

	// Open uploaded file
	src, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to open uploaded file"})
		return
	}
	defer src.Close()

	// Read file bytes for Cloudinary upload
	fileBytes, err := io.ReadAll(src)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file content"})
		return
	}

	// Get category metadata from form (optional - used for folder organization)
	categoryType := c.PostForm("category_type") // "section", "main_category", "subcategory"
	categoryName := c.PostForm("category_name") // Actual category name

	var imageURL string
	storageType := "local"

	// Always try Cloudinary first if configured (like FastAPI does)
	if utils.IsCloudinaryReady() {
		var cloudURL string
		var err error

		// Use category-specific upload if metadata provided, otherwise generic upload
		if categoryType != "" && categoryName != "" {
			cloudURL, err = utils.UploadCategoryImage(fileBytes, file.Filename, categoryType, categoryName)
		} else {
			// Generic upload to almathina folder (matches FastAPI default)
			cloudURL, err = utils.UploadImage(fileBytes, file.Filename, "almathina")
		}

		if err != nil {
			fmt.Printf("⚠️  Cloudinary upload failed: %v, falling back to local storage\n", err)
		} else {
			imageURL = cloudURL
			storageType = "cloudinary"
			fmt.Printf("✓ Image uploaded to Cloudinary: %s\n", imageURL)
		}
	}

	// Fallback to local storage if Cloudinary not configured or failed
	if imageURL == "" {
		fileExt := filepath.Ext(file.Filename)
		uniqueFilename := fmt.Sprintf("category_%s%s", uuid.New().String(), fileExt)

		// Ensure upload directory exists
		uploadDir := "./static/uploads"
		if err := os.MkdirAll(uploadDir, 0755); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create upload directory"})
			return
		}

		// Save file to disk
		filePath := filepath.Join(uploadDir, uniqueFilename)
		if err := os.WriteFile(filePath, fileBytes, 0644); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save file"})
			return
		}

		imageURL = "/static/uploads/" + uniqueFilename
		fmt.Printf("⚠️  Using local storage: %s\n", imageURL)
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"url":       imageURL, // Compatible with admin dashboard
		"image_url": imageURL, // Compatible with FastAPI response
		"message":   "Image uploaded successfully",
		"storage":   storageType,
	})
}

// ===== PRODUCT CRUD OPERATIONS =====

// AddProduct creates a new product in MongoDB
// POST /admin/api/products/add
func AddProduct(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	var data map[string]interface{}
	if err := c.BindJSON(&data); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Add metadata
	data["created_at"] = time.Now()
	data["updated_at"] = time.Now()

	// Set default image if not provided
	if _, ok := data["image_url"]; !ok {
		data["image_url"] = ""
	}

	// Remove legacy fields (prevent duplicate key errors from old index)
	delete(data, "category")
	delete(data, "brand")

	// AUTO-CREATE OR LINK INVENTORY ITEM
	// 1. Extract stock (default to 0 if missing)
	var initialStock int32 = 0
	if val, ok := data["stock"]; ok {
		switch v := val.(type) {
		case float64:
			initialStock = int32(v)
		case int:
			initialStock = int32(v)
		case int32:
			initialStock = v
		case int64:
			initialStock = int32(v)
		}
	}

	productName := data["product_name"].(string)
	inventoryCol := database.GetCollection("inventory")

	// Check if inventory item with this name already exists (exact match)
	var existingInventory bson.M
	err := inventoryCol.FindOne(ctx, bson.M{"inventory_name": productName}).Decode(&existingInventory)

	var inventoryID string

	if err == nil {
		// FOUND EXISTING: Link to it
		inventoryID = existingInventory["inventory_id"].(string)
		fmt.Printf("🔗 Linking new product '%s' to EXISTING inventory '%s'\n", productName, inventoryID)

		// Optional: Add initial stock to existing?
		// User said "remove duplicate names", implying we should just reuse the item.
		// If the user is adding a variant, they might expect the stock to be shared.
		// If they provided stock, maybe we should ADD it to the existing pool?
		// For now, let's just LINK. If they want to add stock, they can do it via inventory management.
		// To be safe/helpful, if initialStock > 0, we could increase it.
		if initialStock > 0 {
			_, _ = inventoryCol.UpdateOne(
				ctx,
				bson.M{"inventory_id": inventoryID},
				bson.M{
					"$inc": bson.M{"stock_quantity": initialStock},
					"$set": bson.M{"updated_at": time.Now()},
				},
			)
		}

	} else {
		// NOT FOUND: Create New
		inventoryID = uuid.New().String()
		newInventoryItem := bson.M{
			"inventory_id":    inventoryID,
			"inventory_name":  productName,
			"stock_quantity":  initialStock,
			"unit":            "units",
			"min_stock_level": 5,
			"is_active":       true,
			"last_updated":    time.Now(),
		}

		if _, err := inventoryCol.InsertOne(ctx, newInventoryItem); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create associated inventory item"})
			return
		}
		fmt.Printf("✨ Created NEW inventory '%s' for product '%s'\n", inventoryID, productName)
	}

	// 4. Update Product Data
	data["inventory_id"] = inventoryID
	delete(data, "stock") // Remove stock from product document

	productsCol := database.GetCollection("products")
	result, err := productsCol.InsertOne(ctx, data)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add product"})
		return
	}

	// Get the inserted product
	var product bson.M
	if err := productsCol.FindOne(ctx, bson.M{"_id": result.InsertedID}).Decode(&product); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch created product"})
		return
	}

	// Convert ObjectID to string for JSON response
	product["_id"] = product["_id"].(interface{ Hex() string }).Hex()

	c.JSON(http.StatusOK, gin.H{
		"message": "Product added successfully",
		"product": product,
	})
}

// UpdateProduct updates an existing product in MongoDB
// PUT /admin/api/products/:product_id
func UpdateProduct(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	productID := c.Param("product_id")

	// Validate ObjectID
	objID, err := primitive.ObjectIDFromHex(productID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid product ID"})
		return
	}

	var data map[string]interface{}
	if err := c.BindJSON(&data); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Add update metadata
	data["updated_at"] = time.Now()

	// Remove item_id if it's in the data (prevent modification)
	delete(data, "item_id")
	delete(data, "stock") // Prevent direct stock updates (managed via inventory)

	productsCol := database.GetCollection("products")
	result, err := productsCol.UpdateOne(
		ctx,
		bson.M{"_id": objID},
		bson.M{"$set": data},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update product"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	// Get updated product
	var product bson.M
	if err := productsCol.FindOne(ctx, bson.M{"_id": objID}).Decode(&product); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch updated product"})
		return
	}

	// Convert ObjectID to string for JSON response
	product["_id"] = product["_id"].(interface{ Hex() string }).Hex()

	c.JSON(http.StatusOK, gin.H{
		"message": "Product updated successfully",
		"product": product,
	})
}

// DeleteProduct deletes a product from MongoDB and its Cloudinary image
// DELETE /admin/api/products/:product_id
func DeleteProduct(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	productID := c.Param("product_id")

	// Validate ObjectID
	objID, err := primitive.ObjectIDFromHex(productID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid product ID"})
		return
	}

	productsCol := database.GetCollection("products")

	// Get product to check for image
	var product bson.M
	err = productsCol.FindOne(ctx, bson.M{"_id": objID}).Decode(&product)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	fmt.Printf("🗑️ DELETING PRODUCT:\n")
	fmt.Printf("   Product ID: %s\n", productID)
	fmt.Printf("   Product Name: %v\n", product["product_name"])
	fmt.Printf("   Section: %v\n", product["category_section"])
	fmt.Printf("   Main Category: %v\n", product["category_main"])
	fmt.Printf("   Subcategory: %v\n", product["category_sub"])

	// Delete image from Cloudinary if exists
	if imageURL, ok := product["image_url"].(string); ok && imageURL != "" {
		fmt.Printf("   Image URL: %s\n", imageURL)
		if utils.DeleteImage(imageURL) {
			fmt.Println("   ✓ Image deleted from Cloudinary")
		} else {
			fmt.Println("   ⚠️  Failed to delete image from Cloudinary")
		}
	} else {
		fmt.Println("   No image to delete")
	}

	// Delete product from database
	result, err := productsCol.DeleteOne(ctx, bson.M{"_id": objID})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete product"})
		return
	}

	if result.DeletedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	fmt.Printf("   ✓ Product document deleted from database\n")
	fmt.Printf("✅ PRODUCT DELETION COMPLETE: %v\n", product["product_name"])

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Product deleted successfully",
	})
}

// UploadProductImage uploads a product image to Cloudinary or local storage
// POST /admin/api/upload/image/:product_id
func UploadProductImage(c *gin.Context) {
	productID := c.Param("product_id")

	// Validate ObjectID
	objID, err := primitive.ObjectIDFromHex(productID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid product ID"})
		return
	}

	// Get uploaded file
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}

	// Validate file type
	allowedTypes := map[string]bool{
		"image/jpeg": true,
		"image/jpg":  true,
		"image/png":  true,
		"image/webp": true,
	}

	// Open file to check content type
	src, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to open file"})
		return
	}
	defer src.Close()

	// Read first 512 bytes to detect content type
	buffer := make([]byte, 512)
	_, err = src.Read(buffer)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	// Reset file pointer to beginning
	src.Seek(0, 0)

	contentType := http.DetectContentType(buffer)
	if !allowedTypes[contentType] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file type. Only JPG, PNG, WebP allowed."})
		return
	}

	// Read file bytes
	fileBytes, err := io.ReadAll(src)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	var imageURL string
	storageType := "local"

	// Try Cloudinary first
	if utils.IsCloudinaryReady() {
		cloudURL, err := utils.UploadProductImage(fileBytes, productID, file.Filename)
		if err == nil {
			imageURL = cloudURL
			storageType = "cloudinary"
			fmt.Printf("✅ Cloudinary upload successful: %s\n", cloudURL)
		} else {
			fmt.Printf("⚠️  Cloudinary upload failed: %v\n", err)
		}
	}

	// Fallback to local storage
	if imageURL == "" {
		fileExt := filepath.Ext(file.Filename)
		uniqueFilename := fmt.Sprintf("product_%s_%s%s", productID, uuid.New().String(), fileExt)

		uploadDir := "./static/uploads"
		if err := os.MkdirAll(uploadDir, 0755); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create upload directory"})
			return
		}

		filePath := filepath.Join(uploadDir, uniqueFilename)
		if err := os.WriteFile(filePath, fileBytes, 0644); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save file"})
			return
		}

		imageURL = "/static/uploads/" + uniqueFilename
		fmt.Printf("⚠️  Using local storage: %s\n", imageURL)
	}

	// Update product in MongoDB
	ctx, cancel := database.GetDBContext()
	defer cancel()

	productsCol := database.GetCollection("products")
	_, err = productsCol.UpdateOne(
		ctx,
		bson.M{"_id": objID},
		bson.M{"$set": bson.M{
			"image":      imageURL,
			"image_url":  imageURL,
			"updated_at": time.Now(),
		}},
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update product with image URL"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"url":       imageURL,
		"image_url": imageURL,
		"message":   "Product image uploaded successfully",
		"storage":   storageType,
	})
}

// LinkProductToInventory links a product to an inventory item
// POST /admin/api/products/:product_id/link-inventory
func LinkProductToInventory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	productID := c.Param("product_id")

	// Validate ObjectID
	objID, err := primitive.ObjectIDFromHex(productID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid product ID"})
		return
	}

	var request struct {
		InventoryID string `json:"inventory_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "inventory_id is required"})
		return
	}

	// Verify inventory item exists
	inventoryCol := database.GetCollection("inventory")
	count, err := inventoryCol.CountDocuments(ctx, bson.M{
		"inventory_id": request.InventoryID,
		"is_active":    true,
	})

	if err != nil || count == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found"})
		return
	}

	// Link product to inventory
	productsCol := database.GetCollection("products")
	result, err := productsCol.UpdateOne(
		ctx,
		bson.M{"_id": objID},
		bson.M{"$set": bson.M{
			"inventory_id": request.InventoryID,
			"updated_at":   time.Now(),
		}},
	)

	if err != nil {
		log.Printf("❌ Error linking product to inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to link product"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	log.Printf("✅ Linked product %s to inventory %s", productID, request.InventoryID)
	c.JSON(http.StatusOK, gin.H{
		"message":      "Product linked to inventory successfully",
		"inventory_id": request.InventoryID,
	})
}

// UnlinkProductFromInventory removes inventory link from a product
// DELETE /admin/api/products/:product_id/link-inventory
func UnlinkProductFromInventory(c *gin.Context) {
	ctx, cancel := database.GetDBContext()
	defer cancel()

	productID := c.Param("product_id")

	// Validate ObjectID
	objID, err := primitive.ObjectIDFromHex(productID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid product ID"})
		return
	}

	productsCol := database.GetCollection("products")
	result, err := productsCol.UpdateOne(
		ctx,
		bson.M{"_id": objID},
		bson.M{
			"$unset": bson.M{"inventory_id": ""},
			"$set":   bson.M{"updated_at": time.Now()},
		},
	)

	if err != nil {
		log.Printf("❌ Error unlinking product from inventory: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unlink product"})
		return
	}

	if result.MatchedCount == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	log.Printf("✅ Unlinked product %s from inventory", productID)
	c.JSON(http.StatusOK, gin.H{
		"message": "Product unlinked from inventory successfully",
	})
}
