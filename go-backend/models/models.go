package models

import (
	"time"
)

// Product represents a product document in MongoDB products collection
// BSON tags MUST match MongoDB field names exactly (case-sensitive)
// JSON tags are for API responses (match FastAPI output)
type Product struct {
	ItemID        string    `bson:"item_id" json:"item_id"`
	ProductName   string    `bson:"product_name" json:"product_name"`
	ProductNameTa string    `bson:"product_name_ta,omitempty" json:"product_name_ta"` // Tamil name
	Weight        string    `bson:"weight,omitempty" json:"weight"`                   // Product weight/size
	Price         float64   `bson:"price" json:"price"`
	BuyingPrice   *float64  `bson:"buying_price,omitempty" json:"buying_price,omitempty"` // Only for admin users
	Section       string    `bson:"category_section" json:"section"`
	MainCategory  string    `bson:"category_main" json:"main_category"`
	Subcategory   string    `bson:"category_sub" json:"subcategory"`
	InventoryID   string    `bson:"inventory_id,omitempty" json:"inventory_id,omitempty"` // Linked inventory item
	ImageURL      string    `bson:"image_url" json:"image_url"`                           // Changed from product_image to image_url (Cloudinary URLs)
	Description   string    `bson:"description" json:"description"`
	Unit          string    `bson:"unit" json:"unit"`
	Stock         int       `bson:"stock" json:"stock"`
	Active        bool      `bson:"active" json:"active"`                           // Status: true=active, false=inactive
	InStock       bool      `bson:"-" json:"in_stock"`                              // Computed field: stock > 0 (not stored in DB)
	IsBestSeller  bool      `bson:"is_best_seller,omitempty" json:"is_best_seller"` // Featured product flag
	CreatedAt     time.Time `bson:"created_at,omitempty" json:"created_at,omitempty"`
	UpdatedAt     time.Time `bson:"updated_at,omitempty" json:"updated_at,omitempty"`
}

// OrderItem represents a single item within an order
type OrderItem struct {
	ItemID       string  `bson:"item_id,omitempty" json:"item_id,omitempty"`
	Section      string  `bson:"section,omitempty" json:"section,omitempty"`
	MainCategory string  `bson:"main_category,omitempty" json:"main_category,omitempty"`
	Subcategory  string  `bson:"subcategory,omitempty" json:"subcategory,omitempty"`
	ProductName  string  `bson:"product_name" json:"product_name"`
	Weight       string  `bson:"weight,omitempty" json:"weight,omitempty"`
	Quantity     int     `bson:"quantity" json:"quantity"`
	Price        float64 `bson:"price" json:"price"`
	ImageURL     string  `bson:"image_url,omitempty" json:"image_url,omitempty"`
	Subtotal     float64 `bson:"subtotal,omitempty" json:"subtotal,omitempty"`

	// Compatibility fields for Flutter App (matches Python backend)
	Brand    string `bson:"brand,omitempty" json:"brand,omitempty"`       // Maps to ProductName
	Category string `bson:"category,omitempty" json:"category,omitempty"` // Maps to MainCategory
}

// DeliveryAddress represents the delivery address structure in orders
type DeliveryAddress struct {
	Street   string `bson:"street" json:"street"`
	City     string `bson:"city" json:"city"`
	State    string `bson:"state" json:"state"`
	Pincode  string `bson:"pincode" json:"pincode"`
	Landmark string `bson:"landmark,omitempty" json:"landmark,omitempty"`
}

// Order represents an order document in MongoDB orders collection
type Order struct {
	OrderID           string                 `bson:"order_id" json:"order_id"`
	UserPhone         string                 `bson:"user_phone" json:"user_phone"`
	UserName          string                 `bson:"user_name,omitempty" json:"user_name,omitempty"`
	UserStoreName     string                 `bson:"user_store_name,omitempty" json:"user_store_name,omitempty"` // Enriched from users collection
	Section           string                 `bson:"section,omitempty" json:"section,omitempty"`                 // Section for split orders
	DeliveryAddress   DeliveryAddress        `bson:"delivery_address" json:"delivery_address"`
	Items             []OrderItem            `bson:"items" json:"items"`
	TotalAmount       float64                `bson:"total_amount" json:"total_amount"`
	Status            string                 `bson:"status" json:"status"` // "pending", "confirmed", "delivered"
	PaymentMethod     string                 `bson:"payment_method,omitempty" json:"payment_method,omitempty"`
	CreatedAt         time.Time              `bson:"created_at" json:"created_at"`
	UpdatedAt         time.Time              `bson:"updated_at,omitempty" json:"updated_at,omitempty"`
	EstimatedDelivery string                 `bson:"estimated_delivery,omitempty" json:"estimated_delivery,omitempty"`
	OrderDate         *time.Time             `bson:"order_date,omitempty" json:"order_date,omitempty"` // Legacy field
	DeliveryDate      *time.Time             `bson:"delivery_date,omitempty" json:"delivery_date,omitempty"`
	Notes             string                 `bson:"notes,omitempty" json:"notes,omitempty"`
	Metadata          map[string]interface{} `bson:"metadata,omitempty" json:"metadata,omitempty"`
}

// StoreDetails represents the nested store_details in user documents
type StoreDetails struct {
	StoreName string `bson:"store_name" json:"store_name"`
	Street    string `bson:"street,omitempty" json:"street,omitempty"`
	City      string `bson:"city,omitempty" json:"city,omitempty"`
	State     string `bson:"state,omitempty" json:"state,omitempty"`
	Pincode   string `bson:"pincode,omitempty" json:"pincode,omitempty"`
	Landmark  string `bson:"landmark,omitempty" json:"landmark,omitempty"`
}

// User represents a user document in MongoDB users collection
// Supabase users table stores ONLY is_admin and fcm_token
// MongoDB users collection stores full user profiles
type User struct {
	Phone           string        `bson:"phone" json:"phone"`
	Name            string        `bson:"name" json:"name"`
	Email           string        `bson:"email,omitempty" json:"email,omitempty"`
	DeliveryAddress string        `bson:"delivery_address,omitempty" json:"delivery_address,omitempty"`
	StoreDetails    *StoreDetails `bson:"store_details,omitempty" json:"store_details,omitempty"`
	CreatedAt       time.Time     `bson:"created_at" json:"created_at"`
	LastLogin       time.Time     `bson:"last_login,omitempty" json:"last_login,omitempty"`
}

// FCMTokenRequest is the request body for saving FCM tokens
type FCMTokenRequest struct {
	Phone    string `json:"phone" binding:"required"`
	FCMToken string `json:"fcm_token" binding:"required"`
}

// FCMTokenResponse is the response for FCM token save operation
type FCMTokenResponse struct {
	Message string `json:"message"`
	Success bool   `json:"success"`
}

// CategoryMetadata represents a category_metadata document in MongoDB
// Stores image URLs for sections, main_categories, and subcategories
// CRITICAL: Main category metadata uses "name" field (not "main_category")
type CategoryMetadata struct {
	Type         string `bson:"type,omitempty" json:"type,omitempty"` // section, main_category, subcategory
	Section      string `bson:"section,omitempty" json:"section,omitempty"`
	Name         string `bson:"name,omitempty" json:"name,omitempty"`                   // Main category or subcategory name
	NameTA       string `bson:"name_ta,omitempty" json:"name_ta,omitempty"`             // Tamil name
	MainCategory string `bson:"main_category,omitempty" json:"main_category,omitempty"` // For subcategories
	Subcategory  string `bson:"subcategory,omitempty" json:"subcategory,omitempty"`
	ImageURL     string `bson:"image_url,omitempty" json:"image_url,omitempty"`
	Icon         string `bson:"icon,omitempty" json:"icon,omitempty"`
}

// MostBought represents a most_bought document in MongoDB
// Stars main categories to appear in "Most Bought" section
type MostBought struct {
	Section      string    `bson:"section" json:"section"`
	MainCategory string    `bson:"main_category" json:"main_category"`
	StarredAt    time.Time `bson:"starred_at" json:"starred_at"`
}

// PaginationInfo contains pagination metadata for API responses
// Matches FastAPI pagination structure exactly
type PaginationInfo struct {
	CurrentPage  int  `json:"current_page"`
	TotalPages   int  `json:"total_pages"`
	TotalItems   int  `json:"total_items"`
	ItemsPerPage int  `json:"items_per_page"`
	HasNext      bool `json:"has_next"`
	HasPrev      bool `json:"has_prev"`
}

// ProductsResponse is the response structure for GET /api/flutter/products
// CRITICAL: Must match FastAPI response structure exactly for Flutter compatibility
type ProductsResponse struct {
	Products   []Product      `json:"products"`
	IsAdmin    bool           `json:"is_admin"`
	Pagination PaginationInfo `json:"pagination"`
}

// MainCategory represents a main category card in home screen
// Used in HomeResponse.Sections
type MainCategory struct {
	Name         string `json:"name"`
	ImageURL     string `json:"image_url"`
	ProductCount int    `json:"product_count"`
	Section      string `json:"section"`
	MainCategory string `json:"main_category"`
}

// BestSellers represents the "Most Bought" section in home screen
// Contains array of starred main categories
type BestSellers struct {
	Title          string         `json:"title"`
	Icon           string         `json:"icon"`
	MainCategories []MainCategory `json:"main_categories"`
}

// HomeSection represents a section with its main categories
// Used in GET /api/flutter/home response
type HomeSection struct {
	Title          string         `json:"title"`        // Display name (localized)
	Icon           string         `json:"icon"`         // Section icon
	SectionName    string         `json:"section_name"` // Original section name (for queries)
	MainCategories []MainCategory `json:"main_categories"`
}

// HomeResponse is the response structure for GET /api/flutter/home
// Must match FastAPI exactly - Flutter depends on this structure
type HomeResponse struct {
	BestSellers BestSellers   `json:"best_sellers"`
	Sections    []HomeSection `json:"sections"`
}

// SubcategoryInfo represents a subcategory with metadata
// Used in GET /api/flutter/main-category/{section}/{main_category}/subcategories
type SubcategoryInfo struct {
	Name         string `json:"name"`
	ProductCount int    `json:"product_count"`
	Icon         string `json:"icon"`
	ImageURL     string `json:"image_url"`
}

// SearchResponse is the response structure for GET /api/flutter/search
type SearchResponse struct {
	Products   []Product      `json:"products"`
	Query      string         `json:"query"`
	Pagination PaginationInfo `json:"pagination"`
}
