package main

import (
	"bufio"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// The cache exists for one reason: a full parse of every session log cannot be
// made interactive (269MB is ~90ms just to read, before any JSON work). Keyed
// on size+mtime, a run re-parses only the sessions that actually changed, which
// in practice is the one you are sitting in.
//
// It is pure derived data: deleting the directory only costs one slow run.

const cacheFormat = "v1"

type stamp struct {
	ModNano int64
	Size    int64
}

// Cache is the previous run's extraction, grouped by session log.
type Cache struct {
	dir     string
	stamps  map[string]stamp
	records map[string][]Record
}

func cacheDir() string {
	if base := os.Getenv("CSR_CACHE_DIR"); base != "" {
		return base
	}
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return filepath.Join(os.TempDir(), "csr")
		}
		base = filepath.Join(home, ".cache")
	}
	return filepath.Join(base, "csr")
}

// LoadCache never fails hard: a missing or corrupt cache just means everything
// looks changed.
func LoadCache(dir string) *Cache {
	c := &Cache{
		dir:     dir,
		stamps:  map[string]stamp{},
		records: map[string][]Record{},
	}

	if !c.loadManifest() {
		return &Cache{dir: dir, stamps: map[string]stamp{}, records: map[string][]Record{}}
	}
	c.loadRecords()
	return c
}

func (c *Cache) loadManifest() bool {
	f, err := os.Open(filepath.Join(c.dir, "manifest.tsv"))
	if err != nil {
		return false
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	if !sc.Scan() || sc.Text() != cacheFormat {
		return false
	}

	for sc.Scan() {
		parts := strings.Split(sc.Text(), "\t")
		if len(parts) != 3 {
			continue
		}
		mod, err1 := strconv.ParseInt(parts[1], 10, 64)
		size, err2 := strconv.ParseInt(parts[2], 10, 64)
		if err1 != nil || err2 != nil {
			continue
		}
		c.stamps[parts[0]] = stamp{ModNano: mod, Size: size}
	}
	return sc.Err() == nil
}

func (c *Cache) loadRecords() {
	f, err := os.Open(filepath.Join(c.dir, "index.tsv"))
	if err != nil {
		c.stamps = map[string]stamp{}
		return
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 4<<20)
	for sc.Scan() {
		parts := strings.Split(sc.Text(), "\t")
		if len(parts) != 6 {
			continue
		}
		r := Record{
			File:      parts[0],
			SessionID: parts[1],
			Cwd:       parts[2],
			Ts:        parts[3],
			When:      parts[4],
			Text:      parts[5],
		}
		c.records[r.File] = append(c.records[r.File], r)
	}
}

// Hit reports the cached records for a log whose size and mtime are unchanged.
func (c *Cache) Hit(path string, s stamp) ([]Record, bool) {
	prev, ok := c.stamps[path]
	if !ok || prev != s {
		return nil, false
	}
	// A log with no prompts at all is a legitimate empty hit.
	return c.records[path], true
}

// Save replaces the cache with the current scan. Written to a temp file and
// renamed so a killed run cannot leave a half-written index behind.
func Save(dir string, stamps map[string]stamp, records map[string][]Record) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	var index strings.Builder
	for _, rs := range records {
		for _, r := range rs {
			index.WriteString(strings.Join(
				[]string{r.File, r.SessionID, r.Cwd, r.Ts, r.When, r.Text}, "\t"))
			index.WriteByte('\n')
		}
	}

	manifest := strings.Builder{}
	manifest.WriteString(cacheFormat + "\n")
	for path, s := range stamps {
		manifest.WriteString(path + "\t" +
			strconv.FormatInt(s.ModNano, 10) + "\t" +
			strconv.FormatInt(s.Size, 10) + "\n")
	}

	// index before manifest: a manifest without its records would claim hits
	// it cannot serve.
	if err := writeAtomic(filepath.Join(dir, "index.tsv"), index.String()); err != nil {
		return err
	}
	return writeAtomic(filepath.Join(dir, "manifest.tsv"), manifest.String())
}

func writeAtomic(path, content string) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), filepath.Base(path)+".*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())

	if _, err := tmp.WriteString(content); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), path)
}
