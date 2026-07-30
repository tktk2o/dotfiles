package main

import (
	"io/fs"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
)

// Scan returns every human prompt across all session logs, newest first,
// re-parsing only the logs that changed since the last run.
//
// The cache always holds the unfiltered result, so narrowing to one project
// cannot poison it for the next cross-project search.
func Scan(projectsDir, onlyCwd string) ([]Record, error) {
	stamps, err := collectStamps(projectsDir)
	if err != nil {
		return nil, err
	}

	dir := cacheDir()
	cache := LoadCache(dir)

	records := make(map[string][]Record, len(stamps))
	var stale []string
	for path, s := range stamps {
		if hit, ok := cache.Hit(path, s); ok {
			records[path] = hit
		} else {
			stale = append(stale, path)
		}
	}

	for path, rs := range parseAll(stale) {
		records[path] = rs
	}

	if len(stale) > 0 {
		// A cache we failed to write only costs speed, never correctness.
		_ = Save(dir, stamps, records)
	}

	return flattenRecords(records, onlyCwd), nil
}

func collectStamps(projectsDir string) (map[string]stamp, error) {
	stamps := map[string]stamp{}

	err := filepath.WalkDir(projectsDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			// Unreadable corners of the log dir should not sink the search.
			return nil //nolint:nilerr
		}
		if d.IsDir() || !strings.HasSuffix(path, ".jsonl") {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return nil
		}
		stamps[path] = stamp{ModNano: info.ModTime().UnixNano(), Size: info.Size()}
		return nil
	})

	return stamps, err
}

func parseAll(paths []string) map[string][]Record {
	out := map[string][]Record{}
	if len(paths) == 0 {
		return out
	}

	workers := runtime.NumCPU()
	if workers > len(paths) {
		workers = len(paths)
	}

	jobs := make(chan string)
	var mu sync.Mutex
	var wg sync.WaitGroup

	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for path := range jobs {
				sid := strings.TrimSuffix(filepath.Base(path), ".jsonl")
				rs, err := RecordsFromFile(path, sid)
				if err != nil {
					continue
				}
				mu.Lock()
				out[path] = rs
				mu.Unlock()
			}
		}()
	}

	for _, p := range paths {
		jobs <- p
	}
	close(jobs)
	wg.Wait()

	return out
}

func flattenRecords(records map[string][]Record, onlyCwd string) []Record {
	var out []Record
	for _, rs := range records {
		for _, r := range rs {
			if onlyCwd != "" && r.Cwd != onlyCwd {
				continue
			}
			out = append(out, r)
		}
	}

	// Timestamps are RFC3339 UTC, so a string sort is chronological.
	sort.Slice(out, func(i, j int) bool { return out[i].Ts > out[j].Ts })
	return out
}
