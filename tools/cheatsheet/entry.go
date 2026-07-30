package main

import (
	"fmt"
	"sort"
)

// Entry is one thing this dotfiles repo lets you type: an alias, a function, a
// key binding, an executable, a skill.
type Entry struct {
	Category string
	Key      string // what you type
	Desc     string
	File     string // repo-relative
	Line     int
}

func (e Entry) Source() string {
	if e.Line == 0 {
		return e.File
	}
	return fmt.Sprintf("%s:%d", e.File, e.Line)
}

// categoryOrder groups the cheatsheet by where you are when you reach for the
// command, rather than alphabetically.
var categoryOrder = []string{
	"shell",
	"tmux",
	"nvim",
	"gh",
	"gh-dash",
	"claude",
	"macOS",
}

func categoryRank(name string) int {
	for i, c := range categoryOrder {
		if c == name {
			return i
		}
	}
	return len(categoryOrder)
}

func sortEntries(entries []Entry) {
	sort.SliceStable(entries, func(i, j int) bool {
		a, b := entries[i], entries[j]
		if ra, rb := categoryRank(a.Category), categoryRank(b.Category); ra != rb {
			return ra < rb
		}
		if a.Category != b.Category {
			return a.Category < b.Category
		}
		if a.File != b.File {
			return a.File < b.File
		}
		return a.Line < b.Line
	})
}
