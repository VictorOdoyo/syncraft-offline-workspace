package api

import (
	"fmt"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
	"net/http"
	"sync/atomic"
)

type Metrics struct {
	Requests atomic.Uint64
	Pushes   atomic.Uint64
	Pulls    atomic.Uint64
}

func (s *Server) metrics(w http.ResponseWriter, r *http.Request) {
	c, ok := s.identity(w, r, false, true)
	if !ok {
		return
	}
	if c.Role != "admin" {
		problem(w, domain.ErrForbidden)
		return
	}
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")
	_, _ = fmt.Fprintf(w, "# TYPE syncraft_requests_total counter\nsyncraft_requests_total %d\n# TYPE syncraft_push_batches_total counter\nsyncraft_push_batches_total %d\n# TYPE syncraft_pull_pages_total counter\nsyncraft_pull_pages_total %d\n", s.Metrics.Requests.Load(), s.Metrics.Pushes.Load(), s.Metrics.Pulls.Load())
}
