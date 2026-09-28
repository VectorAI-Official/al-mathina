package middleware

import (
	"compress/gzip"
	"path/filepath"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
)

// minCompressSize is the smallest body worth compressing. Bodies below this
// (small JSON acks, empty responses) are sent as-is to avoid overhead.
const minCompressSize = 1024

var gzipPool = sync.Pool{
	New: func() interface{} {
		// BestSpeed: JS/JSON compresses ~70-85% with negligible CPU.
		w, _ := gzip.NewWriterLevel(nil, gzip.BestSpeed)
		return w
	},
}

// binaryExtensions are already-compressed or binary payloads that must never be
// gzipped (double compression wastes CPU and can corrupt some formats).
var binaryExtensions = map[string]bool{
	".png": true, ".jpg": true, ".jpeg": true, ".gif": true, ".webp": true,
	".ico": true, ".svgz": true, ".woff": true, ".woff2": true, ".ttf": true,
	".eot": true, ".otf": true, ".pdf": true, ".zip": true, ".gz": true,
	".mp4": true, ".webm": true, ".apk": true, ".jar": true,
}

// compressibleContentType reports whether a response Content-Type benefits from
// gzip. Empty type is treated as compressible (Gin defaults JSON/text handlers
// set it, but being permissive avoids missing dynamic HTML).
func compressibleContentType(contentType string) bool {
	ct := strings.ToLower(strings.TrimSpace(contentType))
	if ct == "" {
		return true
	}
	if i := strings.IndexByte(ct, ';'); i >= 0 {
		ct = strings.TrimSpace(ct[:i])
	}
	switch {
	case strings.HasPrefix(ct, "application/json"),
		strings.HasPrefix(ct, "application/javascript"),
		strings.HasPrefix(ct, "text/"),
		strings.HasPrefix(ct, "application/xml"),
		strings.HasPrefix(ct, "image/svg+xml"),
		strings.HasPrefix(ct, "application/xhtml+xml"):
		return true
	}
	return false
}

// gzipResponseWriter delays the compression decision until the first Write, by
// which point Gin has set the Content-Type (Gin's WriteHeader only records the
// status; the real headers flush on first Write).
type gzipResponseWriter struct {
	gin.ResponseWriter
	gz        *gzip.Writer
	decided   bool
	compress  bool
	wroteBody bool
}

func (g *gzipResponseWriter) decide(first []byte) {
	g.decided = true

	ct := g.Header().Get("Content-Type")
	if !compressibleContentType(ct) {
		return
	}
	if len(first) < minCompressSize {
		return
	}

	g.compress = true
	g.gz.Reset(g.ResponseWriter)
	g.Header().Set("Content-Encoding", "gzip")
	g.Header().Add("Vary", "Accept-Encoding")
	// Length is unknown/incorrect once compressed; net/http handles chunking.
	g.Header().Del("Content-Length")
}

func (g *gzipResponseWriter) Write(b []byte) (int, error) {
	if !g.decided {
		g.decide(b)
	}
	g.wroteBody = true
	if g.compress {
		return g.gz.Write(b)
	}
	return g.ResponseWriter.Write(b)
}

func (g *gzipResponseWriter) WriteString(s string) (int, error) {
	if !g.decided {
		g.decide([]byte(s))
	}
	g.wroteBody = true
	if g.compress {
		return g.gz.Write([]byte(s))
	}
	return g.ResponseWriter.WriteString(s)
}

// Gzip compresses eligible responses when the client advertises gzip support.
// It must be registered after CORS and before routes. Content types outside the
// compressible allowlist (images, fonts, PDFs) and known binary static paths
// pass through untouched.
func Gzip() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !strings.Contains(c.Request.Header.Get("Accept-Encoding"), "gzip") {
			c.Next()
			return
		}

		if ext := strings.ToLower(filepath.Ext(c.Request.URL.Path)); binaryExtensions[ext] {
			c.Next()
			return
		}

		gz := gzipPool.Get().(*gzip.Writer)
		gzw := &gzipResponseWriter{ResponseWriter: c.Writer, gz: gz}
		c.Writer = gzw

		c.Next()

		if gzw.compress {
			gzw.gz.Close()
		}
		gzipPool.Put(gz)
	}
}
