package store

import (
	"context"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
)

type Store interface {
	Register(context.Context, string, domain.Device) error
	Devices(context.Context, string) ([]domain.Device, error)
	Device(context.Context, string, string) (domain.Device, error)
	Revoke(context.Context, string, string, string) error
	Push(context.Context, string, string, string, []domain.Operation) (int64, error)
	Pull(context.Context, string, int64, int) (domain.Page, error)
	Audit(context.Context, string, int64, int) ([]domain.Audit, error)
	PutAttachment(context.Context, string, string, string, domain.Attachment) error
	GetAttachment(context.Context, string, string) (domain.Attachment, error)
	Attachments(context.Context, string, string) ([]domain.Attachment, error)
	Ping(context.Context) error
	Close()
}
