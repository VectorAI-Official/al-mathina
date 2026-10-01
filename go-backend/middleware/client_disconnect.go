package middleware

import (
	"context"
	"errors"
	"io"
	"net"
	"strings"
	"syscall"

	"github.com/gin-gonic/gin"
)

// ContextKeyClientDisconnect is set on the request context when the response
// write failed because the client went away.
const ContextKeyClientDisconnect = "client_disconnect"

// IsClientDisconnect reports whether err is a benign "the client hung up"
// error rather than a real server fault.
//
// When a browser aborts an in-flight request (navigation, tab close, a proxy
// closing an idle socket), the response write fails with EPIPE/ECONNRESET.
// gin's Context.Render pushes that error onto c.Errors (context.go), and the
// Logger middleware that gin.Default() installs prints it as the trailing
// "%#v" field of the access-log line. The result is an alarming log entry for
// something that is entirely normal, and it drowns real errors.
func IsClientDisconnect(err error) bool {
	if err == nil {
		return false
	}

	// Sentinel errors covering the raw syscall and net/http layers.
	if errors.Is(err, syscall.EPIPE) ||
		errors.Is(err, syscall.ECONNRESET) ||
		errors.Is(err, syscall.ESHUTDOWN) ||
		errors.Is(err, net.ErrClosed) ||
		errors.Is(err, io.ErrClosedPipe) ||
		errors.Is(err, io.EOF) {
		return true
	}

	// context.Canceled surfaces when a handler's own context is derived from
	// the request and the client disappears mid-query.
	if errors.Is(err, context.Canceled) {
		return true
	}

	// Fall back to matching the message: the mongo driver and net/http wrap
	// these errors in ways that break errors.Is in some Go versions.
	msg := strings.ToLower(err.Error())
	for _, needle := range []string{
		"broken pipe",
		"connection reset by peer",
		"connection reset",
		"client disconnected",
		"client closed",
		"use of closed network connection",
		"request canceled",
		"context canceled",
	} {
		if strings.Contains(msg, needle) {
			return true
		}
	}

	return false
}

// ClientDisconnect returns middleware that removes client-disconnect errors
// from c.Errors before gin's Logger formats the access-log line.
//
// Registration order matters: gin.Default() installs Logger as the outermost
// middleware, so this must be registered after it (router.Use after
// gin.Default) for the post-processing to run before the log line is built.
func ClientDisconnect() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		if len(c.Errors) == 0 {
			return
		}

		kept := make([]*gin.Error, 0, len(c.Errors))
		disconnected := false
		for _, e := range c.Errors {
			if IsClientDisconnect(e.Err) {
				disconnected = true
				continue
			}
			kept = append(kept, e)
		}

		if !disconnected {
			return
		}

		// Rebuild the slice so gin's Logger sees an empty ErrorMessage and
		// prints a clean access-log line. Non-disconnect errors are preserved
		// verbatim so genuine failures are never silenced.
		if len(kept) == 0 {
			c.Errors = nil
		} else {
			c.Errors = kept
		}
		c.Set(ContextKeyClientDisconnect, true)
	}
}
