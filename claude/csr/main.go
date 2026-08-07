// csr searches past Claude Code sessions by what you typed, then resumes one.
//
// `claude --resume` only lists the current project's sessions, so a session
// whose project you have forgotten is unreachable. csr searches every log under
// ~/.claude/projects, across projects, matching on your own prompts, and resumes
// the pick in a new tmux window at that session's cwd.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const usage = `csr - search past Claude Code sessions and resume one

Usage:
  csr [query]     open the picker (query pre-fills the filter)
  csr --here      only sessions of the current directory's project
  csr --list      print candidates as TSV and exit (no fzf / tmux needed)
  csr --help      show this help

Env:
  CLAUDE_PROJECTS_DIR   session log dir (default: ~/.claude/projects)
  CSR_CACHE_DIR         index cache dir (default: ~/.cache/csr)
`

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "csr:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	var query string
	var here, list bool

	for i := 0; i < len(args); i++ {
		switch arg := args[i]; arg {
		case "--help", "-h":
			fmt.Print(usage)
			return nil
		case "--here":
			here = true
		case "--list":
			list = true
		case "--preview":
			// Internal: run by fzf for the highlighted row.
			if i+2 >= len(args) {
				return fmt.Errorf("--preview needs a file and a timestamp")
			}
			return preview(args[i+1], args[i+2])
		default:
			if strings.HasPrefix(arg, "-") {
				return fmt.Errorf("unknown option: %s", arg)
			}
			query = arg
		}
	}

	onlyCwd := ""
	if here {
		cwd, err := os.Getwd()
		if err != nil {
			return err
		}
		onlyCwd = cwd
	}

	records, err := Scan(projectsDir(), onlyCwd)
	if err != nil {
		return err
	}

	if len(records) == 0 {
		if here {
			return fmt.Errorf("no sessions for this directory (drop --here to search all projects)")
		}
		return fmt.Errorf("no sessions found under %s", projectsDir())
	}

	if list {
		for _, r := range records {
			fmt.Println(row(r))
		}
		return nil
	}

	picked, err := pick(records, query)
	if err != nil || picked == nil {
		return err
	}
	return resume(picked.SessionID, picked.Cwd)
}

// shellQuote wraps s in single quotes so it can be safely interpolated into
// a shell command string (e.g. a tmux new-window command, or an fzf
// --preview command), even if it contains spaces or shell metacharacters.
func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

func projectsDir() string {
	if dir := os.Getenv("CLAUDE_PROJECTS_DIR"); dir != "" {
		return dir
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ".claude/projects"
	}
	return filepath.Join(home, ".claude", "projects")
}

// row is the picker's line format. Columns 1-4 are machinery hidden from the
// view; column 5 is what you read and search.
func row(r Record) string {
	return strings.Join([]string{
		r.File,
		r.SessionID,
		r.Cwd,
		r.Ts,
		fmt.Sprintf("%-24s %s  %s", filepath.Base(r.Cwd), r.When, r.Text),
	}, "\t")
}

func pick(records []Record, query string) (*Record, error) {
	self, err := os.Executable()
	if err != nil {
		self = "csr"
	}

	var input strings.Builder
	for _, r := range records {
		input.WriteString(row(r))
		input.WriteByte('\n')
	}

	cmd := exec.Command("fzf",
		"--delimiter=\t",
		"--with-nth=5",
		"--no-sort",
		"--query="+query,
		"--prompt=claude session > ",
		"--header=enter: resume in a new window",
		"--preview", shellQuote(self)+" --preview {1} {4}",
		"--preview-window=down,60%,wrap",
	)
	cmd.Stdin = strings.NewReader(input.String())
	cmd.Stderr = os.Stderr

	out, err := cmd.Output()
	if err != nil {
		// Cancelling fzf is an ordinary outcome, not a failure.
		if _, ok := err.(*exec.ExitError); ok {
			return nil, nil
		}
		return nil, fmt.Errorf("fzf: %w", err)
	}

	line := strings.TrimRight(string(out), "\n")
	if line == "" {
		return nil, nil
	}

	fields := strings.Split(line, "\t")
	if len(fields) < 5 {
		return nil, fmt.Errorf("unexpected selection: %q", line)
	}
	return &Record{SessionID: fields[1], Cwd: fields[2]}, nil
}

// preview shows the matched prompt with a few turns either side, so you can
// tell two similar-looking sessions apart before resuming.
func preview(file, ts string) error {
	turns, err := TurnsFromFile(file)
	if err != nil {
		return err
	}

	const radius = 3
	match := 0
	for i, t := range turns {
		if t.Ts == ts {
			match = i
			break
		}
	}

	lo := max(match-radius, 0)
	hi := min(match+radius+1, len(turns))

	for _, t := range turns[lo:hi] {
		marker := "  "
		if t.Ts == ts {
			marker = "▶ "
		}
		fmt.Printf("%s%s\n", marker, strings.ToUpper(t.Role))
		for _, line := range strings.Split(truncate(t.Text, previewLimit), "\n") {
			fmt.Printf("    %s\n", line)
		}
		fmt.Println()
	}
	return nil
}

// resume opens the session in its own window: the pick almost always belongs to
// a different project, and taking over the current pane would cost you the work
// you were doing when you went looking.
func resume(sessionID, cwd string) error {
	if _, err := os.Stat(cwd); err != nil {
		fmt.Fprintf(os.Stderr, "csr: %s no longer exists - resuming in home\n", cwd)
		home, err := os.UserHomeDir()
		if err != nil {
			return err
		}
		cwd = home
	}

	if os.Getenv("TMUX") != "" {
		return exec.Command("tmux", "new-window", "-c", cwd,
			"claude --resume "+shellQuote(sessionID)).Run()
	}

	claude, err := exec.LookPath("claude")
	if err != nil {
		return err
	}
	if err := os.Chdir(cwd); err != nil {
		return err
	}
	return syscallExec(claude, []string{"claude", "--resume", sessionID})
}
