package middleware

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"syscall"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestIsClientDisconnect(t *testing.T) {
	gin.SetMode(gin.TestMode)

	tests := []struct {
		name string
		err  error
		want bool
	}{
		{"nil", nil, false},
		{"epipe", syscall.EPIPE, true},
		{"econnreset", syscall.ECONNRESET, true},
		{"net closed", net.ErrClosed, true},
		{"io closed pipe", io.ErrClosedPipe, true},
		{"io eof", io.EOF, true},
		{"context canceled", context.Canceled, true},
		{"wrapped epipe", fmt.Errorf("write response: %w", syscall.EPIPE), true},
		{"opaque broken pipe msg", errors.New("write tcp 10.0.0.1:80: write: broken pipe"), true},
		{"opaque reset msg", errors.New("read tcp: connection reset by peer"), true},
		{"application error", errors.New("failed to fetch products"), false},
		{"mongo timeout", errors.New("server selection timeout exceeded context deadline exceeded"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsClientDisconnect(tt.err); got != tt.want {
				t.Errorf("IsClientDisconnect(%v) = %v, want %v", tt.err, got, tt.want)
			}
		})
	}
}

func TestClientDisconnectMiddlewareStripsDisconnectErrors(t *testing.T) {
	gin.SetMode(gin.TestMode)

	var accessLogError string

	router := gin.New()
	// The logger must be registered first (mirrors gin.Default()) so the
	// middleware below can scrub c.Errors before the log line is formatted.
	router.Use(func(c *gin.Context) {
		c.Next()
		accessLogError = c.Errors.ByType(gin.ErrorTypePrivate).String()
	})
	router.Use(ClientDisconnect())
	router.GET("/boom", func(c *gin.Context) {
		_ = c.Error(fmt.Errorf("write: %w", syscall.EPIPE))
		c.Status(http.StatusOK)
	})
	// Mirror gin.Context.Render, which records the write error and aborts.
	router.GET("/render", func(c *gin.Context) {
		c.Render(http.StatusOK, renderErr{Err: fmt.Errorf("write: %w", syscall.EPIPE)})
	})

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/boom", nil)
	router.ServeHTTP(rec, req)

	if accessLogError != "" {
		t.Errorf("expected access log to be free of disconnect noise, got %q", accessLogError)
	}

	rec = httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodGet, "/render", nil)
	router.ServeHTTP(rec, req)

	if accessLogError != "" {
		t.Errorf("expected render path access log to be clean, got %q", accessLogError)
	}
}

// renderErr reproduces gin.Context.Render's behaviour: a failed body write is
// pushed onto c.Errors.
type renderErr struct {
	Err error
}

func (r renderErr) Render(w http.ResponseWriter) error     { return r.Err }
func (r renderErr) WriteContentType(w http.ResponseWriter) {}

func TestClientDisconnectMiddlewareSetsContextFlag(t *testing.T) {
	gin.SetMode(gin.TestMode)

	var flag any
	var hasFlag bool

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Next()
		flag, hasFlag = c.Get(ContextKeyClientDisconnect)
	})
	router.Use(ClientDisconnect())
	router.GET("/boom", func(c *gin.Context) {
		_ = c.Error(syscall.EPIPE)
	})

	req := httptest.NewRequest(http.MethodGet, "/boom", nil)
	router.ServeHTTP(httptest.NewRecorder(), req)

	if !hasFlag || flag != true {
		t.Errorf("expected %s to be set, got %v (present=%v)", ContextKeyClientDisconnect, flag, hasFlag)
	}
}

func TestClientDisconnectMiddlewarePreservesRealErrors(t *testing.T) {
	gin.SetMode(gin.TestMode)

	var accessLogError string

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Next()
		accessLogError = c.Errors.ByType(gin.ErrorTypePrivate).String()
	})
	router.Use(ClientDisconnect())
	router.GET("/real", func(c *gin.Context) {
		_ = c.Error(errors.New("failed to fetch products"))
	})

	req := httptest.NewRequest(http.MethodGet, "/real", nil)
	router.ServeHTTP(httptest.NewRecorder(), req)

	if !strings.Contains(accessLogError, "failed to fetch products") {
		t.Errorf("expected genuine error to survive, got %q", accessLogError)
	}
}

func TestClientDisconnectMiddlewareKeepsMixedErrors(t *testing.T) {
	gin.SetMode(gin.TestMode)

	var accessLogError string

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Next()
		accessLogError = c.Errors.ByType(gin.ErrorTypePrivate).String()
	})
	router.Use(ClientDisconnect())
	router.GET("/mixed", func(c *gin.Context) {
		_ = c.Error(fmt.Errorf("%w", syscall.EPIPE))
		_ = c.Error(errors.New("decode failed"))
	})

	req := httptest.NewRequest(http.MethodGet, "/mixed", nil)
	router.ServeHTTP(httptest.NewRecorder(), req)

	if !strings.Contains(accessLogError, "decode failed") {
		t.Errorf("expected only the real error to remain, got %q", accessLogError)
	}
}
