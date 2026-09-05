package api

import (
	"crypto/sha256"
	"encoding/hex"
	"github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
	"io"
	"mime"
	"net/http"
	"net/url"
	"strings"
)

func (s *Server) upload(w http.ResponseWriter, r *http.Request) {
	c, ok := s.identity(w, r, true, true)
	if !ok {
		return
	}
	id, record := r.PathValue("id"), r.Header.Get("X-Record-ID")
	name, err := url.QueryUnescape(r.Header.Get("X-Filename"))
	if err != nil || !domain.ValidID(id) || !domain.ValidID(record) || len(name) == 0 || len(name) > 200 || strings.ContainsAny(name, "/\\\r\n\x00") {
		problem(w, domain.ErrInvalid)
		return
	}
	media, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil || (media != "image/jpeg" && media != "image/png" && media != "application/pdf" && media != "text/plain") {
		problem(w, domain.ErrInvalid)
		return
	}
	data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 5<<20))
	if err != nil || len(data) == 0 {
		write(w, 413, map[string]string{"error": "attachment must contain 1 byte to 5 MiB"})
		return
	}
	sum := sha256.Sum256(data)
	a := domain.Attachment{ID: id, Record: record, Name: name, Type: media, SHA256: hex.EncodeToString(sum[:]), Size: len(data), Data: data}
	if err = s.Store.PutAttachment(r.Context(), c.Workspace, c.Subject, a); err != nil {
		problem(w, err)
		return
	}
	s.Hub.Notify(c.Workspace)
	write(w, 201, a)
}
func (s *Server) download(w http.ResponseWriter, r *http.Request) {
	c, ok := s.identity(w, r, false, true)
	if !ok {
		return
	}
	if !domain.ValidID(r.PathValue("id")) {
		problem(w, domain.ErrInvalid)
		return
	}
	a, err := s.Store.GetAttachment(r.Context(), c.Workspace, r.PathValue("id"))
	if err != nil {
		problem(w, err)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Header().Set("Content-Disposition", mime.FormatMediaType("attachment", map[string]string{"filename": a.Name}))
	w.Header().Set("X-Content-SHA256", a.SHA256)
	w.WriteHeader(200)
	_, _ = w.Write(a.Data)
}
func (s *Server) attachments(w http.ResponseWriter, r *http.Request) {
	c, ok := s.identity(w, r, false, true)
	if !ok {
		return
	}
	record := r.URL.Query().Get("record")
	if !domain.ValidID(record) {
		problem(w, domain.ErrInvalid)
		return
	}
	rows, err := s.Store.Attachments(r.Context(), c.Workspace, record)
	if err != nil {
		problem(w, err)
		return
	}
	write(w, 200, rows)
}
