package store

import (
	"context"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
	"sort"
	"sync"
	"time"
)

type space struct {
	devices     map[string]domain.Device
	entries     []domain.Entry
	audit       []domain.Audit
	attachments map[string]domain.Attachment
}
type Memory struct {
	mu     sync.Mutex
	spaces map[string]*space
}

func NewMemory() *Memory { return &Memory{spaces: map[string]*space{}} }
func (m *Memory) space(w string) *space {
	s := m.spaces[w]
	if s == nil {
		s = &space{devices: map[string]domain.Device{}, entries: []domain.Entry{}, audit: []domain.Audit{}, attachments: map[string]domain.Attachment{}}
		m.spaces[w] = s
	}
	return s
}
func (s *space) log(actor, action, target string) {
	s.audit = append(s.audit, domain.Audit{Sequence: int64(len(s.audit) + 1), Actor: actor, Action: action, Target: target, Created: time.Now().UTC()})
}
func (m *Memory) Register(_ context.Context, w string, d domain.Device) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.space(w)
	if old, ok := s.devices[d.ID]; ok {
		if old.Actor != d.Actor || old.Revoked {
			return domain.ErrForbidden
		}
		return nil
	}
	d.Created = time.Now().UTC()
	s.devices[d.ID] = d
	s.log(d.Actor, "device.registered", d.ID)
	return nil
}
func (m *Memory) Devices(_ context.Context, w string) ([]domain.Device, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []domain.Device{}
	for _, d := range m.space(w).devices {
		out = append(out, d)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}
func (m *Memory) Device(_ context.Context, w, id string) (domain.Device, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	d, ok := m.space(w).devices[id]
	if !ok {
		return d, domain.ErrNotFound
	}
	return d, nil
}
func (m *Memory) Revoke(_ context.Context, w, id, actor string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.space(w)
	d, ok := s.devices[id]
	if !ok {
		return domain.ErrNotFound
	}
	if !d.Revoked {
		d.Revoked = true
		s.devices[id] = d
		s.log(actor, "device.revoked", id)
	}
	return nil
}
func (m *Memory) Push(_ context.Context, w, device, actor string, batch []domain.Operation) (int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.space(w)
	d, ok := s.devices[device]
	if !ok || d.Revoked || d.Actor != actor {
		return 0, domain.ErrForbidden
	}
	known := map[string]domain.Operation{}
	for _, e := range s.entries {
		known[e.Operation.ID] = e.Operation
	}
	if err := domain.ValidateBatch(known, batch); err != nil {
		return 0, err
	}
	for _, o := range batch {
		if _, ok := known[o.ID]; ok {
			continue
		}
		o.Parents = append([]string{}, o.Parents...)
		s.entries = append(s.entries, domain.Entry{Sequence: int64(len(s.entries) + 1), Device: device, Actor: actor, Created: time.Now().UTC(), Operation: o})
		known[o.ID] = o
		s.log(actor, "operation.accepted", o.ID)
	}
	return int64(len(s.entries)), nil
}
func (m *Memory) Pull(_ context.Context, w string, after int64, limit int) (domain.Page, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.space(w)
	if after < 0 || after > int64(len(s.entries)) || limit < 1 || limit > 200 {
		return domain.Page{}, domain.ErrInvalid
	}
	end := min(int(after)+limit, len(s.entries))
	entries := append([]domain.Entry{}, s.entries[int(after):end]...)
	return domain.Page{Entries: entries, Cursor: int64(end), More: end < len(s.entries)}, nil
}
func (m *Memory) Audit(_ context.Context, w string, after int64, limit int) ([]domain.Audit, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.space(w)
	if after < 0 || limit < 1 || limit > 200 {
		return nil, domain.ErrInvalid
	}
	start := min(int64(len(s.audit)), after)
	end := min(int(start)+limit, len(s.audit))
	return append([]domain.Audit{}, s.audit[start:end]...), nil
}
func (m *Memory) PutAttachment(_ context.Context, w, actor string, a domain.Attachment) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	s := m.space(w)
	if old, ok := s.attachments[a.ID]; ok {
		if old.SHA256 != a.SHA256 || old.Record != a.Record || old.Name != a.Name || old.Type != a.Type {
			return domain.ErrConflict
		}
		return nil
	}
	a.Data = append([]byte{}, a.Data...)
	s.attachments[a.ID] = a
	s.log(actor, "attachment.stored", a.ID)
	return nil
}
func (m *Memory) GetAttachment(_ context.Context, w, id string) (domain.Attachment, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	a, ok := m.space(w).attachments[id]
	if !ok {
		return a, domain.ErrNotFound
	}
	a.Data = append([]byte{}, a.Data...)
	return a, nil
}
func (m *Memory) Attachments(_ context.Context, w, record string) ([]domain.Attachment, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := []domain.Attachment{}
	for _, a := range m.space(w).attachments {
		if a.Record == record {
			a.Data = nil
			out = append(out, a)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}
func (m *Memory) Ping(context.Context) error { return nil }
func (m *Memory) Close()                     {}
