package database

import (
	"context"
	"errors"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// isIndexConflict reports whether an index build failed only because an
// equivalent index already exists under a different name. MongoDB uses code 85
// (IndexOptionsConflict) and 86 (IndexKeySpecsConflict) for this. Such indexes
// still serve queries, so they are treated as success rather than a warning.
func isIndexConflict(err error) bool {
	var cmdErr mongo.CommandError
	if errors.As(err, &cmdErr) {
		return cmdErr.Code == 85 || cmdErr.Code == 86
	}
	return false
}

// indexSpec names an index so a failure can be reported precisely.
type indexSpec struct {
	name string
	keys bson.D
	opts *options.IndexOptions
}

// EnsureIndexes creates all required indexes for the AL-Madhina database.
//
// It is idempotent and safe to call on every boot: MongoDB skips indexes that
// already exist with the same key pattern. Index builds on MongoDB 4.2+ are
// non-blocking for concurrent reads, so startup cost is negligible.
//
// Each index is created individually (CreateOne) rather than via CreateMany so
// that a single failure — e.g. a historical duplicate order_id blocking the
// unique index — cannot prevent the other indexes from being created.
//
// These indexes back the two full-collection read endpoints that used to time
// out (/admin/api/products/all and /api/admin/orders) by turning COLLSCAN +
// blocking in-memory sorts into IXSCAN, and by indexing the foreign side of
// $lookup.
func EnsureIndexes() error {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	indexes := map[string][]indexSpec{
		"products": {
			// Matches the $sort in GetAllProducts → IXSCAN instead of COLLSCAN + blocking sort
			{
				name: "products_category_sort",
				keys: bson.D{
					{Key: "category_section", Value: 1},
					{Key: "category_main", Value: 1},
					{Key: "category_sub", Value: 1},
					{Key: "product_name", Value: 1},
				},
			},
			// Local side of the $lookup
			{
				name: "products_inventory_id",
				keys: bson.D{{Key: "inventory_id", Value: 1}},
			},
		},
		"orders": {
			// matches Find() Sort → no in-memory sort
			{
				name: "orders_created_at",
				keys: bson.D{{Key: "created_at", Value: -1}},
			},
			// unique also prevents duplicate orders
			{
				name: "orders_order_id_unique",
				keys: bson.D{{Key: "order_id", Value: 1}},
				opts: options.Index().SetUnique(true),
			},
			// Revenue pages: $match {user_phone: {$in}, created_at: range} → single seek
			{
				name: "orders_user_phone_created_at",
				keys: bson.D{
					{Key: "user_phone", Value: 1},
					{Key: "created_at", Value: -1},
				},
			},
			// Covered aggregation for stats/revenue ($group on status + total_amount)
			{
				name: "orders_status_total_amount",
				keys: bson.D{
					{Key: "status", Value: 1},
					{Key: "total_amount", Value: 1},
				},
			},
		},
		"inventory": {
			// FOREIGN side of the $lookup — critical for join performance
			{
				name: "inventory_inventory_id",
				keys: bson.D{{Key: "inventory_id", Value: 1}},
			},
		},
		"users": {
			// GetAllOrders batch user enrichment ($in)
			{
				name: "users_phone",
				keys: bson.D{{Key: "phone", Value: 1}},
			},
		},
		"category_hierarchy": {
			{
				name: "category_hierarchy_section",
				keys: bson.D{{Key: "section", Value: 1}},
			},
		},
		"category_metadata": {
			{
				name: "category_metadata_section_name_type",
				keys: bson.D{
					{Key: "section", Value: 1},
					{Key: "name", Value: 1},
					{Key: "type", Value: 1},
				},
			},
		},
	}

	for coll, defs := range indexes {
		created := 0
		for _, def := range defs {
			opts := def.opts
			if opts == nil {
				opts = options.Index()
			}
			opts.SetName(def.name)

			model := mongo.IndexModel{Keys: def.keys, Options: opts}
			name, err := GetCollection(coll).Indexes().CreateOne(ctx, model)
			if err != nil {
				// An equivalent index under another name is fine.
				if isIndexConflict(err) {
					log.Printf("✅ INDEXES: %s.%s already exists (equivalent index)", coll, def.name)
					created++
					continue
				}
				// Warn, don't fatal: keep the server up even if Atlas hiccups
				// during a deploy, and continue with the remaining indexes.
				log.Printf("⚠️ INDEXES: %s.%s creation failed (queries may be slow): %v", coll, def.name, err)
				continue
			}
			log.Printf("✅ INDEXES: %s.%s ready", coll, name)
			created++
		}
		if created == 0 && len(defs) > 0 {
			log.Printf("⚠️ INDEXES: %s — no indexes confirmed (see warnings above)", coll)
		}
	}

	return nil
}
