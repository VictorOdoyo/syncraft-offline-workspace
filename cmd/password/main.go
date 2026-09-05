package main

import (
	"fmt"
	"golang.org/x/crypto/bcrypt"
	"io"
	"os"
	"strings"
)

func main() {
	raw, err := io.ReadAll(io.LimitReader(os.Stdin, 257))
	password := strings.TrimRight(string(raw), "\r\n")
	if err != nil || len(password) < 12 || len(password) > 72 {
		fmt.Fprintln(os.Stderr, "provide a 12-72 byte password on stdin")
		os.Exit(1)
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(hash))
}
