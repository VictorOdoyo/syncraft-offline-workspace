package domain

import (
	"errors"
	"fmt"
	"math/rand"
	"reflect"
	"testing"
)

func id(n int) string { return fmt.Sprintf("00000000-0000-4000-8000-%012d", n) }
func op(n int, value string, parents ...string) Operation {
	return Operation{ID: id(n), Record: id(100), Field: "notes", Value: value, Parents: parents}
}
func TestConcurrentResolution(t *testing.T) {
	a, b := op(1, "north"), op(2, "south")
	if got := Frontier([]Operation{a, b}, a.Record, a.Field); len(got) != 2 {
		t.Fatal(got)
	}
	c := op(3, "both", a.ID, b.ID)
	d := op(4, "unseen", a.ID)
	if got := Frontier([]Operation{a, b, c, d}, a.Record, a.Field); len(got) != 2 {
		t.Fatal(got)
	}
}
func TestBatchAtomicValidation(t *testing.T) {
	a := op(1, "first")
	b := op(2, "second", a.ID)
	if err := ValidateBatch(nil, []Operation{a, b}); err != nil {
		t.Fatal(err)
	}
	if err := ValidateBatch(nil, []Operation{b, a}); !errors.Is(err, ErrInvalid) {
		t.Fatal(err)
	}
	if err := ValidateBatch(map[string]Operation{a.ID: a}, []Operation{op(1, "changed")}); !errors.Is(err, ErrConflict) {
		t.Fatal(err)
	}
	if err := ValidateBatch(map[string]Operation{a.ID: a}, []Operation{a}); err != nil {
		t.Fatal(err)
	}
}
func TestFrontierPermutationConvergence(t *testing.T) {
	ops := []Operation{op(1, "a"), op(2, "b"), op(3, "c", id(1)), op(4, "d", id(2))}
	expected := Frontier(ops, id(100), "notes")
	r := rand.New(rand.NewSource(42))
	for range 500 {
		r.Shuffle(len(ops), func(i, j int) { ops[i], ops[j] = ops[j], ops[i] })
		if !reflect.DeepEqual(expected, Frontier(ops, id(100), "notes")) {
			t.Fatal("order changed result")
		}
	}
}
func TestValidationRejectsInvalidFields(t *testing.T) {
	cases := []Operation{op(1, "ok", id(1)), op(1, "ok", id(2), id(2)), {ID: id(1), Record: id(100), Field: "password", Value: "secret"}, {ID: id(1), Record: id(100), Field: "status", Value: "approved"}}
	for _, o := range cases {
		if Validate(o) == nil {
			t.Fatalf("accepted %+v", o)
		}
	}
}
