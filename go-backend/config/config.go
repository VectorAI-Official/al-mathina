package config

import (
	"log"
	"os"
	"strings"

	"github.com/joho/godotenv"
)

// Config holds all application configuration
type Config struct {
	// Database
	MongoURI           string
	SupabaseURL        string
	SupabaseAnonKey    string
	SupabaseServiceKey string

	// Firebase
	FirebaseServiceAccountPath string

	// Email
	EmailWebhookURL    string
	EmailWebhookSecret string
	AdminEmail         string // Comma-separated admin emails
	AdminEmails        []string

	// Cloudinary
	CloudinaryCloudName string
	CloudinaryAPIKey    string
	CloudinaryAPISecret string

	// Server
	Port        string
	Environment string
	Host        string

	// Admin
	AdminPhones []string
}

var AppConfig *Config

// LoadConfig loads environment variables and initializes configuration
func LoadConfig() *Config {
	// Load .env file (ignore error in production where env vars are set directly)
	_ = godotenv.Load()

	config := &Config{
		// Database
		MongoURI:           getEnv("MONGO_URI", ""),
		SupabaseURL:        getEnv("SUPABASE_URL", ""),
		SupabaseAnonKey:    getEnv("SUPABASE_ANON_KEY", ""),
		SupabaseServiceKey: getEnv("SUPABASE_SERVICE_KEY", ""),

		// Firebase
		FirebaseServiceAccountPath: getEnv("FIREBASE_SERVICE_ACCOUNT_PATH", "./firebase-service-account.json"),

		// Email
		EmailWebhookURL:    fixURL(getEnv("EMAIL_WEBHOOK_URL", "")),
		EmailWebhookSecret: getEnv("EMAIL_WEBHOOK_SECRET", ""),
		AdminEmail:         getEnv("ADMIN_EMAIL", "faizalbashafaizalbasha07@gmail.com"),
		AdminEmails:        getEnvList("ADMIN_EMAIL", []string{"faizalbashafaizalbasha07@gmail.com"}),

		// Cloudinary
		CloudinaryCloudName: getEnv("CLOUDINARY_CLOUD_NAME", ""),
		CloudinaryAPIKey:    getEnv("CLOUDINARY_API_KEY", ""),
		CloudinaryAPISecret: getEnv("CLOUDINARY_API_SECRET", ""),

		// Server
		Port:        getEnv("PORT", "9000"),
		Environment: getEnv("ENVIRONMENT", "development"),
		Host:        getEnv("HOST", "0.0.0.0"),

		// Admin
		AdminPhones: getEnvList("ADMIN_PHONES", []string{"+917339651541", "+918870503350", "+919487715568"}),
	}

	// Validate required fields
	if config.MongoURI == "" {
		log.Fatal("❌ CONFIG: MONGO_URI is required")
	}
	if config.SupabaseURL == "" || config.SupabaseServiceKey == "" {
		log.Println("⚠️ CONFIG: Supabase not configured - admin features will be limited")
	}
	if config.FirebaseServiceAccountPath == "" {
		log.Println("⚠️ CONFIG: Firebase not configured - push notifications will be disabled")
	}

	log.Println("✅ CONFIG: Configuration loaded successfully")
	log.Printf("✅ CONFIG: Environment: %s", config.Environment)
	log.Printf("✅ CONFIG: Port: %s", config.Port)
	log.Printf("✅ CONFIG: Admin Phones: %d configured", len(config.AdminPhones))

	AppConfig = config
	return config
}

// Helper function to get environment variable with default
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}

// Helper function to get comma-separated list from environment
func getEnvList(key string, defaultValue []string) []string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}

	items := strings.Split(value, ",")
	result := make([]string, 0, len(items))
	for _, item := range items {
		trimmed := strings.TrimSpace(item)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}

	if len(result) == 0 {
		return defaultValue
	}
	return result
}

// IsProduction returns true if running in production environment
func (c *Config) IsProduction() bool {
	return c.Environment == "production"
}

// IsDevelopment returns true if running in development environment
func (c *Config) IsDevelopment() bool {
	return c.Environment == "development"
}

// GetBaseURL returns the base URL for the server
func (c *Config) GetBaseURL() string {
	if c.IsProduction() {
		return "https://al-mathina.onrender.com"
	}
	return "http://localhost:" + c.Port
}

// Helper function to ensure URL has scheme and endpoint
func fixURL(url string) string {
	if url == "" {
		return ""
	}

	// Add scheme if missing
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		url = "https://" + url
	}

	// Add endpoint if missing (Vercel email service specific)
	if !strings.HasSuffix(url, "/api/send-email") {
		// Avoid double slash if user added trailing slash
		url = strings.TrimSuffix(url, "/")
		url = url + "/api/send-email"
	}

	return url
}
