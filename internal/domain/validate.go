package domain

import (
	"errors"
	"regexp"
	"strings"
	"unicode/utf8"
)

var ErrConflict = errors.New("immutable ID conflict")
var ErrForbidden = errors.New("access denied")
var ErrNotFound = errors.New("not found")
var ErrInvalid = errors.New("invalid operation or request")
var uuidPattern = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)
var fields = map[string]int{"title": 200, "site": 200, "notes": 16000, "status": 20, "priority": 20, "archived": 5, "check.safety": 5, "check.equipment": 5, "check.access": 5}

func ValidID(s string) bool { return uuidPattern.MatchString(s) }
func Validate(op Operation) error {
	limit, ok := fields[op.Field]
	if !ValidID(op.ID) || !ValidID(op.Record) || !ok || !utf8.ValidString(op.Value) || len(op.Value) > limit || len(op.Parents) > 100 {
		return ErrInvalid
	}
	if (op.Field == "title" || op.Field == "site") && strings.TrimSpace(op.Value) == "" {
		return ErrInvalid
	}
	if op.Field == "status" && op.Value != "draft" && op.Value != "in_progress" && op.Value != "complete" {
		return ErrInvalid
	}
	if op.Field == "priority" && op.Value != "normal" && op.Value != "high" && op.Value != "critical" {
		return ErrInvalid
	}
	if (op.Field == "archived" || strings.HasPrefix(op.Field, "check.")) && op.Value != "true" && op.Value != "false" {
		return ErrInvalid
	}
	seen := map[string]bool{}
	for _, p := range op.Parents {
		if !ValidID(p) || p == op.ID || seen[p] {
			return ErrInvalid
		}
		seen[p] = true
	}
	return nil
}
