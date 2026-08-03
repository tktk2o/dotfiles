// keys is the inventory of everything this dotfiles repo lets you type.
//
// The configs are the source of truth: aliases, functions, key bindings,
// executables and skills are read straight out of them, with descriptions taken
// from `##` annotations placed next to each definition. docs/cheatsheet.md is
// generated from the same walk, so it cannot quietly go stale.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const usage = `keys - what this dotfiles repo lets you type

Usage:
  keys [query]     browse the inventory in fzf (query pre-fills the filter)
  keys --doc       read docs/cheatsheet.md in a pager (tmux: prefix + g)
  keys --list      print it as plain text
  keys --generate  write docs/cheatsheet.md
  keys --check     fail if the doc is stale or a definition lacks a #: annotation
  keys --help      show this help

Env:
  DOTFILES_DIR     repo location (default: ~/src/github.com/tktk2o/dotfiles)
`

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "keys:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	var query string
	mode := "browse"

	for _, arg := range args {
		switch arg {
		case "--help", "-h":
			fmt.Print(usage)
			return nil
		case "--doc":
			mode = "doc"
		case "--list":
			mode = "list"
		case "--generate":
			mode = "generate"
		case "--check":
			mode = "check"
		default:
			if strings.HasPrefix(arg, "-") {
				return fmt.Errorf("unknown option: %s", arg)
			}
			query = arg
		}
	}

	root := repoRoot()
	entries, missing, err := Collect(root)
	if err != nil {
		return err
	}
	if len(entries) == 0 {
		return fmt.Errorf("no commands found under %s", root)
	}

	switch mode {
	case "doc":
		// Regenerate first: reading a stale document is the one thing this
		// command must not do, and it costs a few milliseconds.
		if err := os.WriteFile(filepath.Join(root, cheatsheetPath), []byte(Render(entries)), 0o644); err != nil {
			return err
		}
		return readDoc(filepath.Join(root, cheatsheetPath))
	case "list":
		for _, line := range pickerLines(entries) {
			fmt.Println(line)
		}
		return nil
	case "generate":
		return generate(root, entries, missing)
	case "check":
		return check(root, entries, missing)
	default:
		return browse(entries, query)
	}
}

func generate(root string, entries, missing []Entry) error {
	path := filepath.Join(root, cheatsheetPath)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(path, []byte(Render(entries)), 0o644); err != nil {
		return err
	}

	fmt.Printf("wrote %s (%d entries)\n", cheatsheetPath, len(entries))
	reportMissing(missing)
	return nil
}

// check is for a pre-commit hook or a quick sanity run: it reports both kinds of
// drift, a stale document and an undocumented definition.
func check(root string, entries, missing []Entry) error {
	want := Render(entries)
	got, err := os.ReadFile(filepath.Join(root, cheatsheetPath))
	stale := err != nil || string(got) != want

	reportMissing(missing)

	if stale {
		return fmt.Errorf("%s is out of date - run 'keys --generate'", cheatsheetPath)
	}
	if len(missing) > 0 {
		return fmt.Errorf("%d definition(s) without a ## annotation", len(missing))
	}
	fmt.Printf("%s is up to date (%d entries), every definition annotated\n",
		cheatsheetPath, len(entries))
	return nil
}

func reportMissing(missing []Entry) {
	if len(missing) == 0 {
		return
	}
	fmt.Fprintf(os.Stderr, "\nmissing a ## annotation (not in the cheatsheet):\n")
	for _, e := range missing {
		fmt.Fprintf(os.Stderr, "  %-9s %-16s %s\n", e.Category, e.Key, e.Source())
	}
}

// readDoc pages the generated document. glow renders the Markdown tables, which
// is the whole point of having a document rather than a flat list; less is the
// fallback so a machine without glow still gets something readable.
func readDoc(path string) error {
	pagers := [][]string{
		{"glow", "--pager", path},
		{"less", "-R", path},
		{"cat", path},
	}

	for _, argv := range pagers {
		bin, err := exec.LookPath(argv[0])
		if err != nil {
			continue
		}
		cmd := exec.Command(bin, argv[1:]...)
		cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
		return cmd.Run()
	}
	return fmt.Errorf("no pager available (tried glow, less, cat)")
}

// browse hands the inventory to fzf. Selecting an entry prints it, so you can
// see where it is defined and jump there; nothing is executed on your behalf.
func browse(entries []Entry, query string) error {
	cmd := exec.Command("fzf",
		"--query="+query,
		"--prompt=keys > ",
		"--header=enter: print the entry (nothing is executed)",
	)
	cmd.Stdin = strings.NewReader(strings.Join(pickerLines(entries), "\n"))
	cmd.Stderr = os.Stderr

	out, err := cmd.Output()
	if err != nil {
		// Cancelling fzf is an ordinary outcome.
		if _, ok := err.(*exec.ExitError); ok {
			return nil
		}
		return fmt.Errorf("fzf: %w", err)
	}

	fmt.Print(string(out))
	return nil
}
