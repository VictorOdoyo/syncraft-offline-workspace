package store

import (
	"context"
	"errors"
	"fmt"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
	"sync"
	"testing"
)

func uid(i int) string { return fmt.Sprintf("00000000-0000-4000-8000-%012d", i) }
func contract(t *testing.T, s Store) {
	t.Helper()
	ctx := context.Background()
	w := "test-" + uid(1)
	d := domain.Device{ID: uid(1), Actor: "author", Name: "Tablet"}
	if err := s.Register(ctx, w, d); err != nil {
		t.Fatal(err)
	}
	a := domain.Operation{ID: uid(2), Record: uid(10), Field: "title", Value: "Pump"}
	if _, err := s.Push(ctx, w, d.ID, d.Actor, []domain.Operation{a}); err != nil {
		t.Fatal(err)
	}
	if _, err := s.Push(ctx, w, d.ID, d.Actor, []domain.Operation{a}); err != nil {
		t.Fatal(err)
	}
	p, err := s.Pull(ctx, w, 0, 1)
	if err != nil || len(p.Entries) != 1 || p.Cursor != 1 {
		t.Fatalf("%+v %v", p, err)
	}
	bad := a
	bad.ID = uid(3)
	bad.Parents = []string{uid(999)}
	b := a
	b.ID = uid(4)
	if _, err = s.Push(ctx, w, d.ID, d.Actor, []domain.Operation{b, bad}); err == nil {
		t.Fatal("accepted missing parent")
	}
	p, _ = s.Pull(ctx, w, 0, 200)
	if len(p.Entries) != 1 {
		t.Fatal("partial batch persisted")
	}
	p, _ = s.Pull(ctx, "other", 0, 200)
	if len(p.Entries) != 0 {
		t.Fatal("workspace leak")
	}
	if err = s.Revoke(ctx, w, d.ID, "admin"); err != nil {
		t.Fatal(err)
	}
	if _, err = s.Push(ctx, w, d.ID, d.Actor, []domain.Operation{b}); !errors.Is(err, domain.ErrForbidden) {
		t.Fatal(err)
	}
}
func TestMemoryContract(t *testing.T) { contract(t, NewMemory()) }
func TestConcurrentSequence(t *testing.T) {
	s := NewMemory()
	ctx := context.Background()
	_ = s.Register(ctx, "w", domain.Device{ID: uid(1), Actor: "a"})
	var wg sync.WaitGroup
	for i := 2; i < 52; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := s.Push(ctx, "w", uid(1), "a", []domain.Operation{{ID: uid(i), Record: uid(100), Field: "notes", Value: "field"}})
			if err != nil {
				t.Error(err)
			}
		}()
	}
	wg.Wait()
	page, err := s.Pull(ctx, "w", 0, 200)
	if err != nil || len(page.Entries) != 50 {
		t.Fatal(page, err)
	}
	for i, e := range page.Entries {
		if e.Sequence != int64(i+1) {
			t.Fatal("gap")
		}
	}
}
