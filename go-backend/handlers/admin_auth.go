package handlers

import (
	"al-mathina-backend/config"
	"log"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Session storage (thread-safe)
var (
	sessions = make(map[string]string) // sessionID -> username
	mu       sync.RWMutex
)

// Credentials (hardcoded for now, matching Python)
const (
	AdminUsername = "admin"
	AdminPassword = "admin123"
)

// AdminLogin handles the login form submission
func AdminLogin(c *gin.Context) {
	username := c.PostForm("username")
	password := c.PostForm("password")

	if username == AdminUsername && password == AdminPassword {
		// Create session
		sessionID := uuid.New().String()

		mu.Lock()
		sessions[sessionID] = username
		mu.Unlock()

		// Set cookie (HttpOnly, 8 hours)
		// MaxAge in seconds (8 * 60 * 60 = 28800)
		c.SetCookie("admin_session", sessionID, 28800, "/", "", false, true)

		log.Printf("✅ Admin logged in: %s (Session: %s)", username, sessionID)

		// Redirect to dashboard
		c.Redirect(http.StatusSeeOther, "/admin/dashboard")
	} else {
		log.Printf("❌ Admin login failed for user: %s", username)
		// Redirect back to login with error
		c.Redirect(http.StatusSeeOther, "/admin?error=1")
	}
}

// AdminLogout handles logout logic
func AdminLogout(c *gin.Context) {
	cookie, err := c.Cookie("admin_session")
	if err == nil {
		mu.Lock()
		delete(sessions, cookie)
		mu.Unlock()
	}

	// Delete cookie
	c.SetCookie("admin_session", "", -1, "/", "", false, true)

	log.Println("👋 Admin logged out")
	c.Redirect(http.StatusSeeOther, "/admin")
}

// AuthMiddleware checks for valid admin session
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		cookie, err := c.Cookie("admin_session")
		if err != nil {
			// No cookie, redirect to login
			c.Redirect(http.StatusSeeOther, "/admin")
			c.Abort()
			return
		}

		mu.RLock()
		username, exists := sessions[cookie]
		mu.RUnlock()

		if !exists {
			// DEV MODE: Allow login to persist across restarts if cookie exists
			if config.AppConfig.Environment == "development" {
				// Re-hydrate session
				mu.Lock()
				sessions[cookie] = "admin (dev)"
				mu.Unlock()
				c.Set("username", "admin (dev)")
				c.Next()
				return
			}

			// Invalid session, redirect to login
			c.SetCookie("admin_session", "", -1, "/", "", false, true)
			c.Redirect(http.StatusSeeOther, "/admin")
			c.Abort()
			return
		}

		// Store username in context for usage
		c.Set("username", username)
		c.Next()
	}
}
