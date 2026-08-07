package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"io"
	"os"
	"strings"
	"time"
)

const (
	displayLimit = 200
	previewLimit = 800
	// Session logs contain single lines far larger than bufio's default cap
	// (pasted files, big tool results), so raise the limit rather than
	// silently truncating them.
	maxLineBytes = 32 << 20
)

// userMarker lets us skip the JSON decode for the ~4/5 of lines that cannot
// possibly be a prompt.
var userMarker = []byte(`"type":"user"`)

// Blocks the harness injects into the user role. They are not things the user
// typed, and they would otherwise dominate the candidate list.
var injectedPrefixes = []string{
	"<system-reminder>",
	"<command-name>",
	"<command-message>",
	"<command-args>",
	"<local-command-stdout>",
	"<local-command-stderr>",
	"<user-prompt-submit-hook>",
	"<bash-input>",
	"<bash-stdout>",
	"<bash-stderr>",
}

// Record is one human prompt: enough to display it, preview it, and resume it.
type Record struct {
	File      string
	SessionID string
	Cwd       string
	Ts        string
	When      string
	Text      string
}

// Turn is a prompt or a reply, used to show a match in context.
type Turn struct {
	Role string
	Ts   string
	Text string
}

type entry struct {
	Type      string `json:"type"`
	IsMeta    bool   `json:"isMeta"`
	Cwd       string `json:"cwd"`
	Timestamp string `json:"timestamp"`
	Message   struct {
		Content json.RawMessage `json:"content"`
	} `json:"message"`
}

type contentBlock struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

// text flattens the two shapes .message.content takes: a bare string, or an
// array of blocks of which only the text ones matter here.
func (e *entry) text(sep string) string {
	raw := e.Message.Content
	if len(raw) == 0 {
		return ""
	}

	if raw[0] == '"' {
		var s string
		if json.Unmarshal(raw, &s) != nil {
			return ""
		}
		return s
	}

	var blocks []contentBlock
	if json.Unmarshal(raw, &blocks) != nil {
		return ""
	}

	var parts []string
	for _, b := range blocks {
		if b.Type == "text" && b.Text != "" {
			parts = append(parts, b.Text)
		}
	}
	return strings.Join(parts, sep)
}

func isInjected(s string) bool {
	for _, p := range injectedPrefixes {
		if strings.HasPrefix(s, p) {
			return true
		}
	}
	return false
}

// flatten collapses a prompt to one line so it can live in a TSV and in a
// single picker row.
func flatten(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

func truncate(s string, limit int) string {
	r := []rune(s)
	if len(r) <= limit {
		return s
	}
	return string(r[:limit]) + "…"
}

func localTime(ts string) string {
	t, err := time.Parse(time.RFC3339, ts)
	if err != nil {
		return ""
	}
	return t.Local().Format("2006-01-02 15:04")
}

func scanLines(path string, fn func(line []byte)) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	r := bufio.NewReaderSize(f, 64*1024)
	for {
		line, _, err := readLine(r)
		if len(line) > 0 {
			fn(line)
		}
		if err != nil {
			if err == io.EOF {
				return nil
			}
			return err
		}
	}
}

// readLine reads the next line from r, up to the next '\n' or EOF. Unlike
// bufio.Scanner, an oversized line (> maxLineBytes — pasted files, big tool
// results) does not abort the whole read: its bytes are still consumed but
// discarded, oversized is reported true, and the caller continues with the
// next line instead of silently losing every line after it.
//
// A truncated final line (session still being written) is returned as-is
// rather than treated as an error, matching the previous scanner behavior.
func readLine(r *bufio.Reader) (line []byte, oversized bool, err error) {
	var buf []byte
	total := 0
	for {
		chunk, e := r.ReadSlice('\n')
		total += len(chunk)
		if !oversized {
			if total <= maxLineBytes {
				buf = append(buf, chunk...)
			} else {
				oversized = true
				buf = nil
			}
		}
		switch e {
		case bufio.ErrBufferFull:
			continue
		case nil:
			if oversized {
				return nil, true, nil
			}
			return bytes.TrimRight(buf, "\r\n"), false, nil
		case io.EOF:
			if oversized || len(buf) == 0 {
				return nil, oversized, io.EOF
			}
			return buf, false, io.EOF
		default:
			return nil, false, e
		}
	}
}

// RecordsFromFile pulls every human prompt out of one session log. The session
// id is the file's base name, which is what `claude --resume` expects.
func RecordsFromFile(path, sessionID string) ([]Record, error) {
	var out []Record

	err := scanLines(path, func(line []byte) {
		if !bytes.Contains(line, userMarker) {
			return
		}

		var e entry
		if json.Unmarshal(line, &e) != nil || e.Type != "user" || e.IsMeta {
			return
		}

		text := flatten(e.text(" "))
		if text == "" || isInjected(text) {
			return
		}

		out = append(out, Record{
			File:      path,
			SessionID: sessionID,
			Cwd:       e.Cwd,
			Ts:        e.Timestamp,
			When:      localTime(e.Timestamp),
			Text:      truncate(text, displayLimit),
		})
	})

	return out, err
}

// TurnsFromFile reads a session as an ordered conversation, for the preview.
func TurnsFromFile(path string) ([]Turn, error) {
	var out []Turn

	err := scanLines(path, func(line []byte) {
		var e entry
		if json.Unmarshal(line, &e) != nil || e.IsMeta {
			return
		}
		if e.Type != "user" && e.Type != "assistant" {
			return
		}

		text := strings.TrimSpace(e.text("\n"))
		if text == "" || isInjected(text) {
			return
		}

		out = append(out, Turn{Role: e.Type, Ts: e.Timestamp, Text: text})
	})

	return out, err
}
