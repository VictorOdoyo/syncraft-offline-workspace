package main

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/api"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/auth"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/store"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
)

func main() {
	if err := run(); err != nil {
		slog.Error("server stopped", "error", err)
		os.Exit(1)
	}
}
func run() error {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()
	demo := os.Getenv("SYNCRAFT_DEMO") == "true"
	address := os.Getenv("LISTEN_ADDR")
	if address == "" {
		address = "127.0.0.1:8091"
	}
	secret := os.Getenv("JWT_SECRET")
	users := map[string]auth.User{}
	if demo {
		secret = "loopback-demo-secret-not-for-production"
		users = auth.DemoUsers()
	} else {
		if len(secret) < 32 {
			return errors.New("JWT_SECRET must contain at least 32 bytes")
		}
		if err := json.Unmarshal([]byte(os.Getenv("USERS_JSON")), &users); err != nil || len(users) == 0 {
			return errors.New("USERS_JSON must configure bcrypt workspace identities")
		}
	}
	for name, u := range users {
		if len(name) == 0 || len(name) > 100 || len(u.Workspace) == 0 || len(u.Workspace) > 100 || (u.Role != "editor" && u.Role != "viewer" && u.Role != "admin") || !strings.HasPrefix(u.PasswordHash, "$2") {
			return errors.New("invalid user configuration")
		}
	}
	var db store.Store
	if url := os.Getenv("DATABASE_URL"); url != "" {
		openCtx, stop := context.WithTimeout(ctx, 30*time.Second)
		defer stop()
		p, err := store.OpenPostgres(openCtx, url)
		if err != nil {
			return err
		}
		db = p
	} else if demo {
		db = store.NewMemory()
	} else {
		return errors.New("DATABASE_URL is required outside demo mode")
	}
	defer db.Close()
	origins := strings.Split(os.Getenv("ALLOWED_ORIGINS"), ",")
	if origins[0] == "" {
		origins = []string{"http://127.0.0.1:5176", "http://localhost:5176"}
	}
	app := &api.Server{Store: db, Auth: &auth.Service{Secret: []byte(secret), Users: users}, Origins: origins, Hub: api.NewHub()}
	server := &http.Server{Addr: address, Handler: app.Handler(), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 20 * time.Second, WriteTimeout: 30 * time.Second, IdleTimeout: 60 * time.Second, MaxHeaderBytes: 16 << 10}
	done := make(chan error, 1)
	go func() {
		slog.Info("Syncraft API listening", "address", address, "demo", demo)
		done <- server.ListenAndServe()
	}()
	select {
	case err := <-done:
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}
		return err
	case <-ctx.Done():
		shutdown, stop := context.WithTimeout(context.Background(), 10*time.Second)
		defer stop()
		return server.Shutdown(shutdown)
	}
}
