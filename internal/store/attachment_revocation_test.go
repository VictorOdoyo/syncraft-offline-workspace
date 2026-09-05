package store

import (
	"context"
	"errors"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
	"testing"
)

func TestAttachmentWriteRechecksRevocation(t *testing.T) {
	s := NewMemory()
	ctx := context.Background()
	_ = s.Register(ctx, "w", domain.Device{ID: uid(1), Actor: "a"})
	_ = s.Revoke(ctx, "w", uid(1), "a")
	err := s.PutAttachment(ctx, "w", uid(1), "a", domain.Attachment{ID: uid(2), Record: uid(3), Data: []byte("file")})
	if !errors.Is(err, domain.ErrForbidden) {
		t.Fatal(err)
	}
	if _, err = s.GetAttachment(ctx, "w", uid(2)); !errors.Is(err, domain.ErrNotFound) {
		t.Fatal("attachment persisted")
	}
}
