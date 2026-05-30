package models

import "time"

// Inventory represents a centralized inventory item that can be linked to multiple products
// Example: One "Sugar" inventory item linked to "Sugar 500g", "Sugar 1kg", "Sugar 1.5kg" products
type Inventory struct {
	InventoryID       string    `json:"inventory_id" bson:"inventory_id"`
	InventoryName     string    `json:"inventory_name" bson:"inventory_name"`
	StockQuantity     int       `json:"stock_quantity" bson:"stock_quantity"`   // Selling Units (e.g., Bundles)
	TotalStock        int       `json:"total_stock" bson:"total_stock"`         // Physical Total (e.g., Pieces)
	PiecesPerUnit     int       `json:"pieces_per_unit" bson:"pieces_per_unit"` // Ratio (e.g., 12 pieces per bundle)
	LowStockThreshold int       `json:"low_stock_threshold" bson:"low_stock_threshold"`
	Unit              string    `json:"unit" bson:"unit"` // e.g., "kg", "liters", "pieces"
	Category          string    `json:"category" bson:"category,omitempty"`
	Section           string    `json:"section" bson:"section,omitempty"`
	Notes             string    `json:"notes" bson:"notes,omitempty"`
	CreatedAt         time.Time `json:"created_at" bson:"created_at"`
	UpdatedAt         time.Time `json:"updated_at" bson:"updated_at"`
	LastRestockedAt   time.Time `json:"last_restocked_at,omitempty" bson:"last_restocked_at,omitempty"`
	IsActive          bool      `json:"is_active" bson:"is_active"`
}

// InventoryStockUpdate represents a stock quantity change operation
type InventoryStockUpdate struct {
	InventoryID string    `json:"inventory_id" bson:"inventory_id"`
	Quantity    int       `json:"quantity" bson:"quantity"` // Positive to add, negative to reduce
	Reason      string    `json:"reason" bson:"reason"`     // e.g., "restock", "order_delivered", "damaged", "expired"
	ChangedBy   string    `json:"changed_by" bson:"changed_by"`
	Timestamp   time.Time `json:"timestamp" bson:"timestamp"`
}

// InventoryHistory tracks all stock changes for audit trail
type InventoryHistory struct {
	ID              string    `json:"_id,omitempty" bson:"_id,omitempty"`
	InventoryID     string    `json:"inventory_id" bson:"inventory_id"`
	InventoryName   string    `json:"inventory_name" bson:"inventory_name"`
	QuantityBefore  int       `json:"quantity_before" bson:"quantity_before"`
	QuantityAfter   int       `json:"quantity_after" bson:"quantity_after"`
	QuantityChanged int       `json:"quantity_changed" bson:"quantity_changed"`
	Reason          string    `json:"reason" bson:"reason"`
	ChangedBy       string    `json:"changed_by" bson:"changed_by"`
	OrderID         string    `json:"order_id,omitempty" bson:"order_id,omitempty"` // If change was due to order
	Timestamp       time.Time `json:"timestamp" bson:"timestamp"`
}

// InventoryAlert represents low stock or out of stock alerts
type InventoryAlert struct {
	InventoryID   string    `json:"inventory_id" bson:"inventory_id"`
	InventoryName string    `json:"inventory_name" bson:"inventory_name"`
	CurrentStock  int       `json:"current_stock" bson:"current_stock"`
	Threshold     int       `json:"threshold" bson:"threshold"`
	AlertType     string    `json:"alert_type" bson:"alert_type"` // "low_stock" or "out_of_stock"
	CreatedAt     time.Time `json:"created_at" bson:"created_at"`
	IsResolved    bool      `json:"is_resolved" bson:"is_resolved"`
}

// LinkedProduct represents products linked to an inventory item
type LinkedProduct struct {
	ItemID       string `json:"item_id" bson:"item_id"`
	ProductName  string `json:"product_name" bson:"product_name"`
	Weight       string `json:"weight,omitempty" bson:"weight,omitempty"`
	Section      string `json:"section" bson:"section"`
	MainCategory string `json:"main_category" bson:"main_category"`
	Subcategory  string `json:"subcategory" bson:"subcategory"`
}
