package api

import (
	"crypto/rand"
	"encoding/hex"
	"net"
	"net/http"
	"sync"
	"time"
)

type bucket struct {
	start time.Time
	count int
}

func (s *Server) middleware(next http.Handler) http.Handler {
	var mu sync.Mutex
	buckets := map[string]bucket{}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nonce := make([]byte, 12)
		_, _ = rand.Read(nonce)
		w.Header().Set("X-Request-ID", hex.EncodeToString(nonce))
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Cache-Control", "no-store")
		origin := r.Header.Get("Origin")
		allowed := origin == ""
		for _, o := range s.Origins {
			if origin == o {
				allowed = true
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Add("Vary", "Origin")
			}
		}
		if !allowed {
			write(w, 403, map[string]string{"error": "origin denied"})
			return
		}
		if r.Method == "OPTIONS" {
			w.Header().Set("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization,Content-Type,X-Device-ID,X-Record-ID,X-Filename")
			w.WriteHeader(204)
			return
		}
		if r.URL.Path != "/health/live" && r.URL.Path != "/health/ready" {
			host, _, _ := net.SplitHostPort(r.RemoteAddr)
			key := host
			limit := 600
			if r.URL.Path == "/api/v1/login" {
				key += "/login"
				limit = 20
			}
			now := time.Now()
			mu.Lock()
			for k, b := range buckets {
				if now.Sub(b.start) > time.Minute {
					delete(buckets, k)
				}
			}
			b, exists := buckets[key]
			if !exists {
				b = bucket{start: now}
			}
			blocked := b.count >= limit || (!exists && len(buckets) >= 5000)
			if !blocked {
				b.count++
				buckets[key] = b
			}
			mu.Unlock()
			if blocked {
				w.Header().Set("Retry-After", "60")
				write(w, 429, map[string]string{"error": "request rate exceeded"})
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}
