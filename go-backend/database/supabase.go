package database

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

// SupabaseClient wraps HTTP client for Supabase REST API calls
// Supabase is used ONLY for admin authentication (users.is_admin column)
// All other data (products, orders, catalog) lives in MongoDB
type SupabaseClient struct {
	BaseURL    string       // e.g., "https://zuhkndylyavedmfrovsj.supabase.co"
	AnonKey    string       // Public anon key for authenticated requests
	ServiceKey string       // Service role key for admin operations (bypasses RLS)
	HTTPClient *http.Client // Reusable HTTP client with timeout
}

// Global Supabase client instance
var SupabaseDB *SupabaseClient

// ConnectSupabase initializes the Supabase client
// Does NOT make a network request - just sets up the client
// Actual connectivity is verified when first query is made
func ConnectSupabase(baseURL, anonKey, serviceKey string) error {
	if baseURL == "" {
		return fmt.Errorf("SUPABASE_URL is required")
	}
	if anonKey == "" {
		return fmt.Errorf("SUPABASE_ANON_KEY is required")
	}
	// Service key is optional - some operations work with anon key only

	log.Println("🔌 Initializing Supabase client...")

	SupabaseDB = &SupabaseClient{
		BaseURL:    baseURL,
		AnonKey:    anonKey,
		ServiceKey: serviceKey,
		HTTPClient: &http.Client{
			Timeout: 10 * time.Second, // Supabase queries should be fast
		},
	}

	log.Println("✅ Supabase client initialized")
	return nil
}

// User represents a row in the Supabase users table
// Only fields we actually use - admin check and FCM tokens
type User struct {
	ID       int    `json:"id"`
	Phone    string `json:"phone"`
	IsAdmin  bool   `json:"is_admin"`
	FCMToken string `json:"fcm_token"`
}

// CheckIsAdmin queries Supabase to determine if a phone number belongs to an admin
// Handles both phone formats: "7339651541" and "+917339651541"
// Returns (isAdmin bool, error)
// This is the CRITICAL function for admin buying price feature
func (s *SupabaseClient) CheckIsAdmin(phone string) (bool, error) {
	// Try exact match first (phone as provided)
	isAdmin, err := s.queryIsAdmin(phone)
	if err == nil {
		return isAdmin, nil
	}

	// If no match, try with +91 prefix (Supabase stores with country code)
	phoneWithPrefix := "+91" + phone
	isAdmin, err = s.queryIsAdmin(phoneWithPrefix)
	if err != nil {
		return false, fmt.Errorf("failed to check admin status for phone %s: %w", phone, err)
	}

	return isAdmin, nil
}

// queryIsAdmin performs the actual Supabase REST API call
// GET /rest/v1/users?phone=eq.{phone}&select=is_admin
// Returns true if user exists and is_admin=true, false otherwise
func (s *SupabaseClient) queryIsAdmin(phone string) (bool, error) {
	// Construct Supabase REST API URL
	// Filter: phone=eq.{phone} (exact match)
	// Select: only is_admin column (reduce payload)
	// URL encode the phone number to handle '+' correctly
	encodedPhone := strings.ReplaceAll(phone, "+", "%2B")
	url := fmt.Sprintf("%s/rest/v1/users?phone=eq.%s&select=is_admin", s.BaseURL, encodedPhone)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return false, fmt.Errorf("failed to create request: %w", err)
	}

	// Supabase requires these headers for authentication
	req.Header.Set("apikey", s.AnonKey)
	req.Header.Set("Authorization", "Bearer "+s.AnonKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.HTTPClient.Do(req)
	if err != nil {
		return false, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return false, fmt.Errorf("Supabase returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response - Supabase returns array of matching rows
	var users []User
	if err := json.NewDecoder(resp.Body).Decode(&users); err != nil {
		return false, fmt.Errorf("failed to decode response: %w", err)
	}

	// No user found with this phone number
	if len(users) == 0 {
		return false, nil
	}

	// Return is_admin status of first (and only) matching user
	return users[0].IsAdmin, nil
}

// SaveFCMToken updates or inserts FCM token for a user in Supabase
// Used when user logs in via phone auth in Flutter app
// Upsert operation: inserts if phone doesn't exist, updates if it does
// NOTE: Uses user_devices table (not users table) to match FastAPI backend
func (s *SupabaseClient) SaveFCMToken(phone, fcmToken string) error {
	url := fmt.Sprintf("%s/rest/v1/user_devices", s.BaseURL)

	// Payload for upsert operation
	payload := map[string]interface{}{
		"phone":     phone,
		"fcm_token": fcmToken,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal payload: %w", err)
	}

	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	// Use service key for admin operations (bypasses RLS)
	apiKey := s.ServiceKey
	if apiKey == "" {
		apiKey = s.AnonKey // Fallback to anon key if service key not configured
	}

	req.Header.Set("apikey", apiKey)
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Prefer", "resolution=merge-duplicates") // Upsert on conflict

	resp, err := s.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		// Handle 409 Conflict (Duplicate Key) gracefully - this is a success for us (idempotent)
		if resp.StatusCode == http.StatusConflict {
			log.Printf("✅ FCM token already exists for phone: %s (Status 409 ignored)", phone)
			return nil
		}

		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("Supabase returned status %d: %s", resp.StatusCode, string(body))
	}

	log.Printf("✅ FCM token saved for phone: %s", phone)
	return nil
}

// GetFCMToken retrieves the FCM token for a given phone number
// Returns empty string if user not found or no token stored
// NOTE: Uses user_devices table (not users table) to match FastAPI backend
// Handles both phone formats: "8870986738" and "+918870986738"
func (s *SupabaseClient) GetFCMToken(phone string) (string, error) {
	// Try exact match first (phone as provided)
	token, err := s.queryFCMToken(phone)
	if err == nil && token != "" {
		return token, nil
	}

	// If no match and phone doesn't start with +91, try with +91 prefix
	if !strings.HasPrefix(phone, "+91") {
		phoneWithPrefix := "+91" + phone
		token, err = s.queryFCMToken(phoneWithPrefix)
		if err == nil && token != "" {
			return token, nil
		}
	}

	// If no match and phone starts with +91, try without +91 prefix
	if strings.HasPrefix(phone, "+91") {
		phoneWithoutPrefix := strings.TrimPrefix(phone, "+91")
		token, err = s.queryFCMToken(phoneWithoutPrefix)
		if err == nil && token != "" {
			return token, nil
		}
	}

	return "", nil // No token found in any format
}

// queryFCMToken performs the actual Supabase REST API call for FCM token lookup
func (s *SupabaseClient) queryFCMToken(phone string) (string, error) {
	// URL-encode phone to handle + sign correctly
	encodedPhone := strings.ReplaceAll(phone, "+", "%2B")
	url := fmt.Sprintf("%s/rest/v1/user_devices?phone=eq.%s&select=fcm_token", s.BaseURL, encodedPhone)

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("apikey", s.AnonKey)
	req.Header.Set("Authorization", "Bearer "+s.AnonKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.HTTPClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("Supabase returned status %d: %s", resp.StatusCode, string(body))
	}

	var devices []struct {
		FCMToken string `json:"fcm_token"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&devices); err != nil {
		return "", fmt.Errorf("failed to decode response: %w", err)
	}

	if len(devices) == 0 {
		return "", nil // User device not found
	}

	return devices[0].FCMToken, nil
}
