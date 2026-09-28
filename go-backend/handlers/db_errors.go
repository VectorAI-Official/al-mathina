package handlers

import (
	"context"
	"errors"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// respondDBError logs the underlying database error so production 500s are no
// longer cause-less, then returns a stable, non-leaky JSON body. It also
// distinguishes context timeouts/cancellations from driver failures, which is
// the difference between "raise DB_LONG_TIMEOUT" and "fix the query".
func respondDBError(c *gin.Context, endpoint string, start time.Time, err error) {
	reason := "error"
	if errors.Is(err, context.DeadlineExceeded) {
		reason = "timeout"
	} else if errors.Is(err, context.Canceled) {
		reason = "canceled"
	}

	log.Printf("❌ %s failed (%s) after %v: %v", endpoint, reason, time.Since(start), err)

	c.JSON(http.StatusInternalServerError, gin.H{
		"success": false,
		"error":   "Database query failed",
	})
}

// logSlowQuery emits a warning for any database call exceeding threshold. It is
// intentionally cheap so it can be sprinkled on hot read paths to warn before
// data growth pushes a request over the timeout ceiling again.
func logSlowQuery(endpoint string, start time.Time, docs int) {
	if elapsed := time.Since(start); elapsed > 2*time.Second {
		log.Printf("⚠️ %s SLOW: %v (%d docs)", endpoint, elapsed, docs)
	}
}
