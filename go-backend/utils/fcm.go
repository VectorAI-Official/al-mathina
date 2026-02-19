package utils

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

var firebaseApp *firebase.App
var fcmClient *messaging.Client

// InitFirebase initializes Firebase Admin SDK for FCM
func InitFirebase(serviceAccountPath string) error {
	// Try multiple paths to find firebase-service-account.json
	paths := []string{
		serviceAccountPath,
		"./firebase-service-account.json",
		"../Backend/firebase-service-account.json",
		"/app/firebase-service-account.json",
	}

	var credPath string
	// 1. Check for BASE64 environment variable (Render/Cloud)
	base64Creds := os.Getenv("FIREBASE_SERVICE_ACCOUNT_BASE64")
	if base64Creds != "" {
		log.Println("🔥 Firebase: Found FIREBASE_SERVICE_ACCOUNT_BASE64 environment variable")
		decoded, err := base64.StdEncoding.DecodeString(base64Creds)
		if err == nil {
			// Write to temp file
			tempFile := "firebase-creds-temp.json"
			err = os.WriteFile(tempFile, decoded, 0644)
			if err == nil {
				credPath = tempFile
				log.Println("✅ Firebase: Decoded base64 credentials to temp file")
			} else {
				log.Printf("❌ Firebase: Failed to write temp credentials file: %v", err)
			}
		} else {
			log.Printf("❌ Firebase: Failed to decode base64 credentials: %v", err)
		}
	}

	// 2. If not found in env, check paths
	if credPath == "" {
		for _, path := range paths {
			if path == "" {
				continue
			}
			absPath, err := filepath.Abs(path)
			if err != nil {
				continue
			}
			if _, err := os.Stat(absPath); err == nil {
				credPath = absPath
				break
			}
		}
	}

	if credPath == "" {
		log.Println("⚠️  Firebase service account file not found - FCM disabled")
		log.Println("   Tried paths:", paths)
		return fmt.Errorf("firebase service account file not found")
	}

	log.Printf("🔥 Firebase: Loading credentials from: %s\n", credPath)

	// Read and validate JSON
	data, err := os.ReadFile(credPath)
	if err != nil {
		log.Printf("❌ Firebase: Failed to read credentials: %v\n", err)
		return err
	}

	var creds map[string]interface{}
	if err := json.Unmarshal(data, &creds); err != nil {
		log.Printf("❌ Firebase: Invalid JSON in credentials: %v\n", err)
		return err
	}

	// Initialize Firebase app
	opt := option.WithCredentialsFile(credPath)
	ctx := context.Background()

	app, err := firebase.NewApp(ctx, nil, opt)
	if err != nil {
		log.Printf("❌ Firebase: Failed to initialize app: %v\n", err)
		return err
	}

	// Get FCM client
	client, err := app.Messaging(ctx)
	if err != nil {
		log.Printf("❌ Firebase: Failed to get FCM client: %v\n", err)
		return err
	}

	firebaseApp = app
	fcmClient = client

	log.Println("✅ Firebase Admin SDK initialized successfully")
	return nil
}

// IsFirebaseReady checks if Firebase/FCM is initialized
func IsFirebaseReady() bool {
	return fcmClient != nil
}

// SendOrderNotification sends FCM push notification for order confirmation
func SendOrderNotification(
	fcmToken string,
	orderID string,
	totalAmount float64,
	itemsCount int,
	storeName string,
	userPhone string,
) bool {
	if !IsFirebaseReady() {
		log.Println("⚠️  FCM: Firebase not initialized - cannot send notification")
		return false
	}

	log.Println("\n" + "============================================================")
	log.Println("📱 FCM: SENDING ORDER NOTIFICATION")
	log.Printf("📱 FCM: Order ID: %s\n", orderID)
	log.Printf("📱 FCM: Total Amount: ₹%.2f\n", totalAmount)
	log.Printf("📱 FCM: Items Count: %d\n", itemsCount)
	log.Printf("📱 FCM: Store Name: %s\n", storeName)
	log.Printf("📱 FCM: Token (first 30 chars): %s...\n", truncate(fcmToken, 30))
	log.Println("============================================================")

	// Prepare notification message with Al-Mathina branding
	title := "🎉 Order Received!"
	body := fmt.Sprintf("Your order #%s for ₹%.2f has been placed successfully.", lastChars(orderID, 6), totalAmount)

	if storeName != "" {
		body += fmt.Sprintf("\n\nThank you, %s! 🙏", storeName)
	}

	log.Printf("📝 FCM: Title: %s\n", title)
	log.Printf("📝 FCM: Body: %s\n", body)

	// Create FCM message
	message := &messaging.Message{
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: map[string]string{
			"type":         "order_confirmation",
			"order_id":     orderID,
			"user_phone":   userPhone,
			"total_amount": fmt.Sprintf("%.2f", totalAmount),
			"items_count":  fmt.Sprintf("%d", itemsCount),
			"timestamp":    fmt.Sprintf("%d", time.Now().UnixMilli()),
			"click_action": "FLUTTER_NOTIFICATION_CLICK",
		},
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				Sound:                 "default",
				Color:                 "#28a745", // Al-Mathina green
				ChannelID:             "orders",
				Priority:              messaging.PriorityHigh,
				DefaultSound:          true,
				DefaultVibrateTimings: true,
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Sound: "default",
					Badge: intPtr(1),
				},
			},
		},
		Token: fcmToken,
	}

	// Send message
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	response, err := fcmClient.Send(ctx, message)
	if err != nil {
		log.Printf("❌ FCM: Failed to send notification: %v\n", err)
		return false
	}

	log.Printf("✅ FCM: Notification sent successfully!\n")
	log.Printf("   Message ID: %s\n", response)
	log.Println("============================================================")

	return true
}

// Helper functions
func truncate(s string, length int) string {
	if len(s) <= length {
		return s
	}
	return s[:length]
}

func lastChars(s string, count int) string {
	if len(s) <= count {
		return s
	}
	return s[len(s)-count:]
}

func intPtr(i int) *int {
	return &i
}
