package handlers

import (
	"net/http"

	"al-mathina-backend/database"
	"al-mathina-backend/models"

	"github.com/gin-gonic/gin"
)

// ===== FCM (Firebase Cloud Messaging) HANDLERS =====
// For push notifications to Flutter mobile app

// SaveFCMToken saves or updates FCM token for a user
// POST /api/fcm-token
// Body: {phone: string, fcm_token: string}
func SaveFCMToken(c *gin.Context) {
	var req models.FCMTokenRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if database.SupabaseDB == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Supabase not configured"})
		return
	}

	// Save token to Supabase (upsert operation)
	err := database.SupabaseDB.SaveFCMToken(req.Phone, req.FCMToken)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to save FCM token",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.FCMTokenResponse{
		Message: "FCM token saved successfully",
		Success: true,
	})
}

// GetFCMToken retrieves FCM token for a user by phone number
// GET /api/fcm-token/:phone
func GetFCMToken(c *gin.Context) {
	phone := c.Param("phone")

	if phone == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Phone number is required"})
		return
	}

	if database.SupabaseDB == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Supabase not configured"})
		return
	}

	token, err := database.SupabaseDB.GetFCMToken(phone)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to retrieve FCM token",
			"details": err.Error(),
		})
		return
	}

	if token == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "FCM token not found for this phone"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"phone":     phone,
		"fcm_token": token,
	})
}
