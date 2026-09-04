package domain

import "time"

type Operation struct {
	ID      string   `json:"id"`
	Record  string   `json:"record"`
	Field   string   `json:"field"`
	Value   string   `json:"value"`
	Parents []string `json:"parents"`
}
type Entry struct {
	Sequence  int64     `json:"sequence"`
	Device    string    `json:"device"`
	Actor     string    `json:"actor"`
	Created   time.Time `json:"created"`
	Operation Operation `json:"operation"`
}
type Device struct {
	ID      string    `json:"id"`
	Name    string    `json:"name"`
	Actor   string    `json:"actor"`
	Revoked bool      `json:"revoked"`
	Created time.Time `json:"created"`
}
type Audit struct {
	Sequence int64     `json:"sequence"`
	Actor    string    `json:"actor"`
	Action   string    `json:"action"`
	Target   string    `json:"target"`
	Created  time.Time `json:"created"`
}
type Attachment struct {
	ID     string `json:"id"`
	Record string `json:"record"`
	Name   string `json:"name"`
	Type   string `json:"type"`
	SHA256 string `json:"sha256"`
	Size   int    `json:"size"`
	Data   []byte `json:"-"`
}
type Page struct {
	Entries []Entry `json:"entries"`
	Cursor  int64   `json:"cursor"`
	More    bool    `json:"more"`
}
