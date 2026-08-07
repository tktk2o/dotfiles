package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// A line larger than maxLineBytes in the middle of a file used to make
// bufio.Scanner return bufio.ErrTooLong and stop scanning entirely, silently
// dropping every line after it. scanLines must instead skip the oversized
// line and keep reading.
func TestScanLinesSkipsOversizedLineAndContinues(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "session.jsonl")

	oversized := strings.Repeat("x", maxLineBytes+1024)
	content := "first\n" + oversized + "\nlast\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write fixture: %v", err)
	}

	var got []string
	if err := scanLines(path, func(line []byte) {
		got = append(got, string(line))
	}); err != nil {
		t.Fatalf("scanLines: %v", err)
	}

	want := []string{"first", "last"}
	if len(got) != len(want) {
		t.Fatalf("got %d lines %q, want %d lines %q", len(got), got, len(want), want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("line %d: got %q, want %q", i, got[i], want[i])
		}
	}
}

// A truncated final line (session still being written) must still be
// delivered, matching the previous bufio.Scanner behavior.
func TestScanLinesKeepsTruncatedFinalLine(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "session.jsonl")

	content := "first\nsecond-partial-no-newline"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write fixture: %v", err)
	}

	var got []string
	if err := scanLines(path, func(line []byte) {
		got = append(got, string(line))
	}); err != nil {
		t.Fatalf("scanLines: %v", err)
	}

	want := []string{"first", "second-partial-no-newline"}
	if len(got) != len(want) {
		t.Fatalf("got %d lines %q, want %d lines %q", len(got), got, len(want), want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("line %d: got %q, want %q", i, got[i], want[i])
		}
	}
}
