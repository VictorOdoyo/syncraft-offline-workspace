package store

import (
	"context"
	"fmt"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
	"os"
	"sync"
	"testing"
	"time"
)

func TestPostgresConcurrentCursorReplay(t *testing.T) {
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("requires PostgreSQL")
	}
	ctx := context.Background()
	p, err := OpenPostgres(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer p.Close()
	workspace := fmt.Sprintf("concurrent-%d", time.Now().UnixNano())
	d := domain.Device{ID: uid(1), Actor: "author", Name: "Device"}
	if err = p.Register(ctx, workspace, d); err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	for i := 2; i < 22; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := p.Push(ctx, workspace, d.ID, d.Actor, []domain.Operation{{ID: uid(i), Record: uid(100), Field: "notes", Value: fmt.Sprint(i)}})
			if err != nil {
				t.Error(err)
			}
		}()
	}
	wg.Wait()
	var cursor int64
	seen := map[string]bool{}
	for {
		page, err := p.Pull(ctx, workspace, cursor, 3)
		if err != nil {
			t.Fatal(err)
		}
		for _, entry := range page.Entries {
			if entry.Sequence != cursor+1 {
				t.Fatal("cursor gap")
			}
			cursor = entry.Sequence
			seen[entry.Operation.ID] = true
		}
		if !page.More {
			break
		}
	}
	if len(seen) != 20 || cursor != 20 {
		t.Fatal(len(seen), cursor)
	}
}
