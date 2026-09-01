package utils

import (
	"al-mathina-backend/config"
	"al-mathina-backend/database"
	"al-mathina-backend/models"
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// EmailService represents the email notification service
type EmailService struct {
	Enabled       bool
	WebhookURL    string
	WebhookSecret string
	AdminEmails   []string
}

// Global instance
var GlobalEmailService *EmailService

// InitEmailService initializes the email service
func InitEmailService() {
	cfg := config.AppConfig

	service := &EmailService{
		WebhookURL:    cfg.EmailWebhookURL,
		WebhookSecret: cfg.EmailWebhookSecret,
		AdminEmails:   cfg.AdminEmails,
	}

	if service.WebhookURL != "" && service.WebhookSecret != "" {
		service.Enabled = true
		log.Println("✅ EMAIL: Service initialized (Vercel Webhook)")
		log.Printf("✅ EMAIL: Webhook: %s", service.WebhookURL)
		log.Printf("✅ EMAIL: Recipients: %v", service.AdminEmails)
	} else {
		service.Enabled = false
		log.Println("⚠️ EMAIL: Service disabled (Webhook not configured)")
	}

	GlobalEmailService = service
}

// IsEnabled checks if service is enabled
func (s *EmailService) IsEnabled() bool {
	return s.Enabled
}

// SendOrderNotificationToAdmin sends order notification to admin
func (s *EmailService) SendOrderNotificationToAdmin(order models.Order) bool {
	if !s.Enabled {
		log.Println("⚠️ EMAIL: Service disabled - skipping notification")
		return false
	}

	log.Println("\n============================================================")
	log.Println("📧 EMAIL: Sending admin notification via webhook")
	log.Printf("📧 EMAIL: Order ID: %s", order.OrderID)
	log.Printf("📧 EMAIL: Section: %s", order.Section)
	log.Printf("📧 EMAIL: Total: ₹%.2f", order.TotalAmount)
	log.Println("============================================================")

	// Build subject
	subject := fmt.Sprintf("🛒 New Order Received - %s", order.OrderID)
	if order.Section != "" {
		subject = fmt.Sprintf("🛒 New Order - %s - %s", order.Section, order.OrderID)
	}

	// Format Payment Method
	paymentMethod := "CASH ON DELIVERY"
	if order.PaymentMethod != "" {
		if strings.ToLower(order.PaymentMethod) == "online" {
			paymentMethod = "ONLINE PAYMENT"
		} else {
			paymentMethod = strings.ToUpper(order.PaymentMethod)
		}
	}

	// Build Address HTML
	addressHtml := "Not provided"
	if order.DeliveryAddress.Street != "" || order.DeliveryAddress.City != "" {
		var parts []string
		if order.DeliveryAddress.Street != "" {
			parts = append(parts, order.DeliveryAddress.Street)
		}
		if order.DeliveryAddress.City != "" {
			parts = append(parts, order.DeliveryAddress.City)
		}
		if order.DeliveryAddress.State != "" {
			parts = append(parts, order.DeliveryAddress.State)
		}
		if order.DeliveryAddress.Pincode != "" {
			parts = append(parts, fmt.Sprintf("PIN: %s", order.DeliveryAddress.Pincode))
		}
		if order.DeliveryAddress.Landmark != "" {
			parts = append(parts, fmt.Sprintf("Landmark: %s", order.DeliveryAddress.Landmark))
		}
		addressHtml = strings.Join(parts, "<br>")
	}

	// Build Items HTML
	itemsHtml := s.buildItemsHTML(order.Items)

	// Order Link
	orderLink := fmt.Sprintf("%s/admin/orders?search=%s", config.AppConfig.GetBaseURL(), order.OrderID)

	// User/Store Info
	storeName := "Not provided"
	if order.UserStoreName != "" {
		storeName = order.UserStoreName
	} else if order.UserName != "" {
		storeName = order.UserName // Fallback
	}

	// Compute the store's balance BEFORE this order was placed (for the invoice balance section)
	balanceBefore, orderAmount, balanceTotal, isStoreOrder := computeOrderBalanceForEmail(order)

	// Build balance summary HTML (shown above the ordered items)
	balanceHtml := ""
	if isStoreOrder {
		balanceHtml = fmt.Sprintf(`
				<div class="order-details" style="border: 2px solid #28a745;">
					<h2 style="color: #28a745; margin-top: 0;">Balance Summary</h2>
					<p style="margin: 4px 0;"><strong>Balance Before This Order:</strong> ₹%.2f</p>
					<p style="margin: 4px 0;"><strong>This Order Amount:</strong> ₹%.2f</p>
					<p style="margin: 4px 0; font-size: 16px; border-top: 1px solid #ddd; padding-top: 6px;"><strong>Total Outstanding:</strong> ₹%.2f</p>
				</div>
				`, balanceBefore, orderAmount, balanceTotal)
	}

	// HTML Body
	htmlBody := fmt.Sprintf(`
	<!DOCTYPE html>
	<html>
	<head>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<style>
			body { 
				font-family: Arial, 'Noto Sans Tamil', 'Lohit Tamil', sans-serif; 
				line-height: 1.6; 
				color: #333; 
				margin: 0; 
				padding: 0; 
			}
			.container { max-width: 600px; margin: 0 auto; padding: 10px; }
			@media screen and (max-width: 640px) {
				.container { max-width: 100%%; padding: 5px; }
			}
			.header { background: #28a745; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
			.content { background: #f8f9fa; padding: 20px; }
			.order-details { background: white; padding: 15px; border-radius: 5px; margin: 10px 0; }
			.table { 
				width: 100%%; 
				border-collapse: collapse; 
				table-layout: fixed; 
				font-family: Arial, 'Noto Sans Tamil', sans-serif;
			}
			.table th { 
				background: #28a745; 
				color: white; 
				padding: 8px 4px; 
				text-align: left; 
				font-size: 12px; 
				font-weight: 600;
			}
			.table td { 
				padding: 8px 4px; 
				border-bottom: 1px solid #ddd; 
				font-size: 13px; 
				word-wrap: break-word; 
				overflow-wrap: break-word;
				min-width: 0;
			}
			@media screen and (max-width: 640px) {
				.table th, .table td { 
					padding: 6px 2px; 
					font-size: 11px; 
				}
				.order-details { padding: 10px; }
			}
			.total { font-size: 18px; font-weight: bold; color: #28a745; text-align: right; padding: 10px 0; }
			.button { display: inline-block; background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 15px 0; }
			.footer { background: #e9ecef; padding: 15px; text-align: center; border-radius: 0 0 8px 8px; font-size: 12px; color: #6c757d; }
		</style>
	</head>
	<body>
		<div class="container">
			<div class="header">
				<h1 style="margin: 0;">🛒 New Order Received!</h1>
				<p style="margin: 5px 0 0 0;">Order ID: <strong>%s</strong></p>
			</div>
			
			<div class="content">
				<div class="order-details">
					<h2 style="color: #28a745; margin-top: 0;">Customer Information</h2>
					<p><strong>Store Name:</strong> %s</p>
					<p><strong>Phone:</strong> %s</p>
					<p><strong>Payment Method:</strong> %s</p>
				</div>
				
				<div class="order-details">
					<h2 style="color: #28a745; margin-top: 0;">Delivery Address</h2>
					<p>%s</p>
				</div>
				
				%s
				
				<div class="order-details">
					<h2 style="color: #28a745; margin-top: 0;">Order Items</h2>
					<table class="table">
						<thead>
							<tr>
								<th style="width: 6%%;">#</th>
								<th style="width: 42%%;">Item</th>
								<th style="width: 13%%; text-align: center;">Qty</th>
								<th style="width: 19%%; text-align: right;">Price</th>
								<th style="width: 20%%; text-align: right;">Total</th>
							</tr>
						</thead>
						<tbody>
							%s
						</tbody>
					</table>
					<div class="total">
						Total Amount: ₹%.2f
					</div>
				</div>
				
				<div style="text-align: center;">
					<a href="%s" class="button">
						📋 View Order in Admin Panel
					</a>
					<p style="font-size: 12px; color: #6c757d;">
						Click the button above to manage this order
					</p>
				</div>
			</div>
			
			<div class="footer">
				<p>AL-Madhina Wholesale Management System</p>
				<p>This is an automated notification. Please do not reply to this email.</p>
			</div>
		</div>
	</body>
	</html>
	`,
		order.OrderID,
		storeName,
		order.UserPhone,
		paymentMethod,
		addressHtml,
		balanceHtml,
		itemsHtml,
		order.TotalAmount,
		orderLink,
	)

	// Prepare payload
	payload := map[string]interface{}{
		"to":      s.AdminEmails,
		"subject": subject,
		"html":    htmlBody,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		log.Printf("❌ EMAIL: Failed to marshal payload: %v", err)
		return false
	}

	// Send Request
	req, err := http.NewRequest(http.MethodPost, s.WebhookURL, bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("❌ EMAIL: Failed to create request: %v", err)
		return false
	}
	req.Header.Set("Content-Type", "application/json")
	if s.WebhookSecret != "" {
		req.Header.Set("x-api-key", s.WebhookSecret)
	}

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("❌ EMAIL: Request failed: %v", err)
		return false
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		log.Printf("✅ EMAIL: Notification sent successfully to %d recipients", len(s.AdminEmails))
		return true
	}

	log.Printf("❌ EMAIL: Webhook failed with status %d", resp.StatusCode)
	return false
}

// computeOrderBalanceForEmail calculates the store's outstanding balance BEFORE a
// given order was placed, along with the order amount and the resulting total.
// Returns (balanceBefore, orderAmount, balanceTotal, isStoreOrder).
func computeOrderBalanceForEmail(order models.Order) (float64, float64, float64, bool) {
	if order.UserPhone == "" {
		return 0, order.TotalAmount, order.TotalAmount, false
	}

	ctx, cancel := database.GetDBContext()
	defer cancel()
	ordersCollection := database.GetCollection("orders")
	usersCollection := database.GetCollection("users")

	var user bson.M
	if err := usersCollection.FindOne(ctx, bson.M{"phone": order.UserPhone}).Decode(&user); err != nil {
		return 0, order.TotalAmount, order.TotalAmount, false
	}

	// Only registered stores with store_details get a balance summary
	if sd, ok := user["store_details"].(bson.M); !ok || len(sd) == 0 {
		return 0, order.TotalAmount, order.TotalAmount, false
	}

	// Sum prior orders' total_amount (before this order was created).
	// If created_at is missing, fall back to excluding this order by order_id
	// so the current order is never self-included in its own "before" balance.
	var dueBefore float64
	dueQuery := bson.M{"user_phone": order.UserPhone}
	if !order.CreatedAt.IsZero() {
		dueQuery["created_at"] = bson.M{"$lt": order.CreatedAt}
	} else if order.OrderID != "" {
		dueQuery["order_id"] = bson.M{"$ne": order.OrderID}
	}
	dueCursor, err := ordersCollection.Aggregate(ctx, []bson.D{
		{{Key: "$match", Value: dueQuery}},
		{{Key: "$group", Value: bson.D{
			{Key: "_id", Value: nil},
			{Key: "due", Value: bson.D{{Key: "$sum", Value: "$total_amount"}}},
		}}},
	})
	if err == nil {
		var dueResults []struct {
			Due float64 `bson:"due"`
		}
		if err := dueCursor.All(ctx, &dueResults); err == nil && len(dueResults) > 0 {
			dueBefore = dueResults[0].Due
		}
		dueCursor.Close(ctx)
	}

	// Sum payments made before this order was created.
	// Payments without a parseable timestamp are counted as made before the
	// order (safest for legacy data) so we never overstate the outstanding balance.
	var paidBefore float64
	if ph, ok := user["payment_history"].(primitive.A); ok {
		for _, entry := range ph {
			e, ok := entry.(bson.M)
			if !ok {
				continue
			}
			if !order.CreatedAt.IsZero() {
				var payTime *time.Time
				if ts, ok := e["timestamp"].(primitive.DateTime); ok {
					t := ts.Time()
					payTime = &t
				} else if ts, ok := e["timestamp"].(time.Time); ok {
					t := ts
					payTime = &t
				}
				// No timestamp -> assume it was paid before this order.
				if payTime != nil && !payTime.Before(order.CreatedAt) {
					continue
				}
			}
			if amount, ok := e["amount"].(float64); ok {
				paidBefore += amount
			} else if amount, ok := e["amount"].(int32); ok {
				paidBefore += float64(amount)
			}
		}
	}

	return dueBefore - paidBefore, order.TotalAmount, dueBefore - paidBefore + order.TotalAmount, true
}

func (s *EmailService) buildItemsHTML(items []models.OrderItem) string {
	var buffer bytes.Buffer
	for i, item := range items {
		displayName := item.ProductName
		if item.Weight != "" {
			displayName = fmt.Sprintf("%s (%s)", item.ProductName, item.Weight)
		}

		// Calculate subtotal if missing
		subtotal := item.Subtotal
		if subtotal == 0 {
			subtotal = float64(item.Quantity) * item.Price
		}

		row := fmt.Sprintf(`
		<tr>
			<td>%d</td>
			<td style="word-wrap: break-word; font-family: Arial, 'Noto Sans Tamil', sans-serif;">%s</td>
			<td style="text-align: center;">%d</td>
			<td style="text-align: right;">₹%.2f</td>
			<td style="text-align: right;">₹%.2f</td>
		</tr>
		`,
			i+1,
			displayName,
			item.Quantity,
			item.Price,
			subtotal,
		)
		buffer.WriteString(row)
	}
	return buffer.String()
}

// SendReturnRequestNotification sends a return request notification to admin
// via the same webhook mechanism as SendOrderNotificationToAdmin, reusing
// AdminEmails. Orange header to visually distinguish from order emails.
func (s *EmailService) SendReturnRequestNotification(user models.User, items []models.OrderItem, totalAmount float64) bool {
	if !s.Enabled {
		log.Println("⚠️ EMAIL: Service disabled - skipping return request notification")
		return false
	}

	log.Println("\n============================================================")
	log.Println("🔄 EMAIL: Sending return request notification via webhook")
	log.Printf("🔄 EMAIL: Phone: %s", user.Phone)
	log.Printf("🔄 EMAIL: Items: %d", len(items))
	log.Printf("🔄 EMAIL: Total: ₹%.2f", totalAmount)
	log.Println("============================================================")

	subject := fmt.Sprintf("🔄 Return Item Request - %s", user.Phone)

	// Build Address HTML from store_details
	addressHtml := "Not provided"
	if user.StoreDetails != nil {
		var parts []string
		if user.StoreDetails.Street != "" {
			parts = append(parts, user.StoreDetails.Street)
		}
		if user.StoreDetails.City != "" {
			parts = append(parts, user.StoreDetails.City)
		}
		if user.StoreDetails.State != "" {
			parts = append(parts, user.StoreDetails.State)
		}
		if user.StoreDetails.Pincode != "" {
			parts = append(parts, fmt.Sprintf("PIN: %s", user.StoreDetails.Pincode))
		}
		if user.StoreDetails.Landmark != "" {
			parts = append(parts, fmt.Sprintf("Landmark: %s", user.StoreDetails.Landmark))
		}
		if len(parts) > 0 {
			addressHtml = strings.Join(parts, "<br>")
		}
	}

	// Build Items HTML
	itemsHtml := s.buildItemsHTML(items)

	// Shop / Customer Info with fallbacks
	storeName := "Not provided"
	if user.StoreDetails != nil && user.StoreDetails.StoreName != "" {
		storeName = user.StoreDetails.StoreName
	}
	ownerName := "Not provided"
	if user.Name != "" {
		ownerName = user.Name
	}
	email := "Not provided"
	if user.Email != "" {
		email = user.Email
	}

	htmlBody := fmt.Sprintf(`
	<!DOCTYPE html>
	<html>
	<head>
		<meta charset="UTF-8">
		<meta name="viewport" content="width=device-width, initial-scale=1.0">
		<style>
			body { 
				font-family: Arial, 'Noto Sans Tamil', 'Lohit Tamil', sans-serif; 
				line-height: 1.6; 
				color: #333; 
				margin: 0; 
				padding: 0; 
			}
			.container { max-width: 600px; margin: 0 auto; padding: 10px; }
			@media screen and (max-width: 640px) {
				.container { max-width: 100%%; padding: 5px; }
			}
			.header { background: #F57C00; color: white; padding: 20px; border-radius: 8px 8px 0 0; }
			.content { background: #f8f9fa; padding: 20px; }
			.order-details { background: white; padding: 15px; border-radius: 5px; margin: 10px 0; }
			.table { 
				width: 100%%; 
				border-collapse: collapse; 
				table-layout: fixed; 
				font-family: Arial, 'Noto Sans Tamil', sans-serif;
			}
			.table th { 
				background: #F57C00; 
				color: white; 
				padding: 8px 4px; 
				text-align: left; 
				font-size: 12px; 
				font-weight: 600;
			}
			.table td { 
				padding: 8px 4px; 
				border-bottom: 1px solid #ddd; 
				font-size: 13px; 
				word-wrap: break-word; 
				overflow-wrap: break-word;
				min-width: 0;
			}
			@media screen and (max-width: 640px) {
				.table th, .table td { 
					padding: 6px 2px; 
					font-size: 11px; 
				}
				.order-details { padding: 10px; }
			}
			.total { font-size: 18px; font-weight: bold; color: #F57C00; text-align: right; padding: 10px 0; }
			.note { background: #FFF3E0; border-left: 4px solid #F57C00; padding: 12px 14px; border-radius: 4px; font-size: 13px; color: #795548; margin-top: 15px; }
			.footer { background: #e9ecef; padding: 15px; text-align: center; border-radius: 0 0 8px 8px; font-size: 12px; color: #6c757d; }
		</style>
	</head>
	<body>
		<div class="container">
			<div class="header">
				<h1 style="margin: 0;">🔄 Return Item Request</h1>
				<p style="margin: 5px 0 0 0;">Phone: <strong>%s</strong></p>
			</div>
			
			<div class="content">
				<div class="order-details">
					<h2 style="color: #F57C00; margin-top: 0;">Shop / Customer Information</h2>
					<p><strong>Shop Name:</strong> %s</p>
					<p><strong>Shop Owner:</strong> %s</p>
					<p><strong>Phone:</strong> %s</p>
					<p><strong>Email:</strong> %s</p>
				</div>
				
				<div class="order-details">
					<h2 style="color: #F57C00; margin-top: 0;">Shop Address</h2>
					<p>%s</p>
				</div>
				
				<div class="order-details">
					<h2 style="color: #F57C00; margin-top: 0;">Return Items</h2>
					<table class="table">
						<thead>
							<tr>
								<th style="width: 6%%;">#</th>
								<th style="width: 42%%;">Item</th>
								<th style="width: 13%%; text-align: center;">Qty</th>
								<th style="width: 19%%; text-align: right;">Price</th>
								<th style="width: 20%%; text-align: right;">Total</th>
							</tr>
						</thead>
						<tbody>
							%s
						</tbody>
					</table>
					<div class="total">
						Total Return Value: ₹%.2f
					</div>
				</div>
				
				<div class="note">
					<strong>Note:</strong> This is a customer-initiated return request. No order or inventory changes have been made automatically — please handle manually.
				</div>
			</div>
			
			<div class="footer">
				<p>AL-Madhina Wholesale Management System</p>
				<p>This is an automated notification. Please do not reply to this email.</p>
			</div>
		</div>
	</body>
	</html>
	`,
		user.Phone,
		storeName,
		ownerName,
		user.Phone,
		email,
		addressHtml,
		itemsHtml,
		totalAmount,
	)

	// Prepare payload
	payload := map[string]interface{}{
		"to":      s.AdminEmails,
		"subject": subject,
		"html":    htmlBody,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		log.Printf("❌ EMAIL: Failed to marshal return request payload: %v", err)
		return false
	}

	// Send Request
	req, err := http.NewRequest(http.MethodPost, s.WebhookURL, bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("❌ EMAIL: Failed to create return request: %v", err)
		return false
	}
	req.Header.Set("Content-Type", "application/json")
	if s.WebhookSecret != "" {
		req.Header.Set("x-api-key", s.WebhookSecret)
	}

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("❌ EMAIL: Return request webhook failed: %v", err)
		return false
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		log.Printf("✅ EMAIL: Return request sent successfully to %d recipients", len(s.AdminEmails))
		return true
	}

	log.Printf("❌ EMAIL: Return request webhook failed with status %d", resp.StatusCode)
	return false
}
