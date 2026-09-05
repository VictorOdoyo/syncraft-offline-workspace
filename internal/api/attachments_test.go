package api

import (
	"bytes"
	"net/http/httptest"
	"testing"
)

func TestAttachmentRoundTripAndCollision(t *testing.T) {
	_, h, token := fixture(t)
	path := "/api/v1/attachments/00000000-0000-4000-8000-000000000009"
	upload := func(data, name string) int {
		r := httptest.NewRequest("POST", path, bytes.NewBufferString(data))
		r.Header.Set("Authorization", "Bearer "+token)
		r.Header.Set("X-Device-ID", deviceID)
		r.Header.Set("X-Record-ID", recordID)
		r.Header.Set("X-Filename", name)
		r.Header.Set("Content-Type", "text/plain")
		w := httptest.NewRecorder()
		h.ServeHTTP(w, r)
		return w.Code
	}
	if code := upload("Field observation", "notes.txt"); code != 201 {
		t.Fatal(code)
	}
	if code := upload("Field observation", "notes.txt"); code != 201 {
		t.Fatal(code)
	}
	if code := upload("changed", "notes.txt"); code != 409 {
		t.Fatal(code)
	}
	if code := upload("x", "../secrets"); code != 400 {
		t.Fatal(code)
	}
	r := request(h, "GET", path, token, "")
	if r.Code != 200 || r.Body.String() != "Field observation" || r.Header().Get("Content-Disposition") == "" {
		t.Fatal(r.Code, r.Body, r.Header())
	}
}
