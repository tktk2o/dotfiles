package main

import (
	"os"
	"path/filepath"
	"strings"
)

// shellSources are the `#`-commented files whose definitions need a `##`
// annotation to appear in the cheatsheet.
var shellSources = []struct {
	glob     string
	category string
}{
	{"zsh/.zshrc", "shell"},
	{"zsh/plugins/*.zsh", "shell"},
	{"tmux/.tmux.conf", "tmux"},
}

// Collect walks the repo and returns every documented entry, plus the
// definitions that are missing their `##` annotation.
func Collect(root string) (entries []Entry, missing []Entry, err error) {
	for _, src := range shellSources {
		paths, err := filepath.Glob(filepath.Join(root, src.glob))
		if err != nil {
			return nil, nil, err
		}
		for _, abs := range paths {
			rel, err := filepath.Rel(root, abs)
			if err != nil {
				return nil, nil, err
			}
			s, err := readSource(root, rel)
			if err != nil {
				return nil, nil, err
			}
			found, miss := parseShell(s, src.category)
			entries = append(entries, found...)
			missing = append(missing, miss...)
		}
	}

	// Executables are announced by an annotated line in setup.sh rather than by
	// a definition, since they are built or symlinked, not declared.
	bins, err := collectBins(root)
	if err != nil {
		return nil, nil, err
	}
	entries = append(entries, bins...)

	luaPaths, err := filepath.Glob(filepath.Join(root, "nvim/lua/plugins/*.lua"))
	if err != nil {
		return nil, nil, err
	}
	for _, abs := range luaPaths {
		rel, err := filepath.Rel(root, abs)
		if err != nil {
			return nil, nil, err
		}
		s, err := readSource(root, rel)
		if err != nil {
			return nil, nil, err
		}
		entries = append(entries, parseLua(s)...)
	}

	if s, err := readSource(root, "gh/config.yml"); err == nil {
		entries = append(entries, parseGhAliases(s)...)
	}
	if s, err := readSource(root, "gh-dash/config.yml.example"); err == nil {
		found, miss := parseGhDash(s)
		entries = append(entries, found...)
		missing = append(missing, miss...)
	}

	entries = append(entries, parseSkills(root)...)
	entries = append(entries, parseKarabiner(root)...)

	sortEntries(entries)
	sortEntries(missing)
	return entries, missing, nil
}

// collectBins reads the annotated `~/.local/bin` lines out of setup.sh, so the
// list of executables cannot drift from what setup actually installs.
func collectBins(root string) ([]Entry, error) {
	s, err := readSource(root, "setup.sh")
	if err != nil {
		return nil, err
	}

	var out []Entry
	for i, line := range s.lines {
		if !strings.Contains(line, "$HOME/.local/bin/") {
			continue
		}
		desc, ok := s.annotationAt(i)
		if !ok {
			continue
		}
		name := binName(line)
		if name == "" {
			continue
		}
		out = append(out, Entry{
			Category: "shell", Key: name, Desc: desc, File: s.path, Line: i + 1,
		})
	}
	return out, nil
}

func binName(line string) string {
	_, rest, ok := strings.Cut(line, "$HOME/.local/bin/")
	if !ok {
		return ""
	}
	// The path is followed by a quote, a space or a closing paren depending on
	// whether it is a symlink target or a build output.
	return strings.TrimRight(rest, "\"' .)")
}

func repoRoot() string {
	if dir := os.Getenv("DOTFILES_DIR"); dir != "" {
		return dir
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "."
	}
	return filepath.Join(home, "src", "github.com", "tktk2o", "dotfiles")
}
