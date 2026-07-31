package handlers

import (
	"al-mathina-backend/database"
	"al-mathina-backend/models"
	"al-mathina-backend/utils"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

// SubmitReturnRequest - POST /api/returns/notify
//
// Customer-initiated return request from the mobile app.
// This is a notify-and-forget endpoint: it does NOT write any return
// record to the database, does NOT touch inventory, and does NOT create
// an order. It simply looks up the user and emails the admin team.
func SubmitReturnRequest(c *gin.Context) {
	var req struct {
		UserPhone string             `json:"user_phone" binding:"required"`
		Items     []models.OrderItem `json:"items" binding:"required,min=1"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		log.Printf("❌ SubmitReturnRequest: Binding error: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	log.Printf("🔄 SubmitReturnRequest: phone=%s, items=%d", req.UserPhone, len(req.Items))

	ctx, cancel := database.GetDBContext()
	defer cancel()

	// Fetch user doc (name, email, store_details) for the notification
	var user models.User
	err := database.GetCollection("users").FindOne(ctx, bson.M{"phone": req.UserPhone}).Decode(&user)
	if err != nil {
		if err != mongo.ErrNoDocuments {
			log.Printf("❌ SubmitReturnRequest: DB error fetching user %s: %v", req.UserPhone, err)
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "error": "Failed to fetch user"})
			return
		}
		// User not found - still allow the notification with empty user info
		log.Printf("⚠️  SubmitReturnRequest: user %s not found, proceeding with defaults", req.UserPhone)
		user.Phone = req.UserPhone
	}

	// Compute informational total
	var totalAmount float64
	for _, item := range req.Items {
		subtotal := item.Subtotal
		if subtotal == 0 {
			subtotal = float64(item.Quantity) * item.Price
		}
		totalAmount += subtotal
	}

	// Fire-and-forget email notification (does not block the response)
	if utils.GlobalEmailService != nil {
		go utils.GlobalEmailService.SendReturnRequestNotification(user, req.Items, totalAmount)
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Return request sent"})
}
