package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Descriptions come from a `#:` annotation next to the definition, either
// trailing it or on the line above:
//
//	alias gs='git status' #: working tree の状態を見る
//	#: worktree を .worktrees/ に作って cd する
//	function wta() {
//
// The marker is `#:` rather than `##` because .tmux.conf already uses `##` for
// section labels and banner rules, and those would be swallowed as
// descriptions. A plain `#` stays an ordinary comment, so this convention never
// fights with the explanatory comments already in these files.
//
// Only annotated definitions reach the cheatsheet; `--check` reports the ones
// missing an annotation, which is what keeps a generated document honest.
const annotation = "#:"

var (
	reAlias     = regexp.MustCompile(`^\s*alias\s+([A-Za-z0-9_-]+)=`)
	reFunc      = regexp.MustCompile(`^\s*(?:function\s+([A-Za-z0-9_-]+)\s*\(\)|([A-Za-z0-9_-]+)\s*\(\)\s*\{)`)
	reLuaKeys   = regexp.MustCompile(`\{\s*"([^"]+)"\s*,.*desc\s*=\s*"([^"]+)"`)
	reLuaSet    = regexp.MustCompile(`vim\.keymap\.set\(\s*"[^"]*"\s*,\s*"([^"]+)"`)
	reLuaDesc   = regexp.MustCompile(`desc\s*=\s*"([^"]+)"`)
	reGhDashKey = regexp.MustCompile(`^\s*-\s*key:\s*(\S+)`)
	reYamlPair  = regexp.MustCompile(`^\s{2,}([A-Za-z0-9_-]+):\s*(.+?)\s*$`)
)

type sourceFile struct {
	path  string // repo-relative
	lines []string
}

func readSource(root, rel string) (*sourceFile, error) {
	data, err := os.ReadFile(filepath.Join(root, rel))
	if err != nil {
		return nil, err
	}
	return &sourceFile{path: rel, lines: strings.Split(string(data), "\n")}, nil
}

// annotationAt returns the description for the definition on line i, and
// whether one was found at all.
func (s *sourceFile) annotationAt(i int) (string, bool) {
	if _, after, ok := strings.Cut(s.lines[i], annotation); ok {
		return strings.TrimSpace(after), true
	}
	// Walk up past blank lines so a definition can be annotated above.
	for j := i - 1; j >= 0; j-- {
		line := strings.TrimSpace(s.lines[j])
		if line == "" {
			continue
		}
		if rest, ok := cutPrefix(line, annotation); ok {
			return strings.TrimSpace(rest), true
		}
		break
	}
	return "", false
}

func cutPrefix(s, prefix string) (string, bool) {
	if strings.HasPrefix(s, prefix) {
		return s[len(prefix):], true
	}
	return "", false
}

// parseShell picks up zsh aliases and functions, and tmux key bindings: all
// three are `#`-commented line-oriented formats, so one walker covers them.
func parseShell(s *sourceFile, category string) (found []Entry, missing []Entry) {
	for i, line := range s.lines {
		var key string
		switch {
		case reAlias.MatchString(line):
			key = reAlias.FindStringSubmatch(line)[1]
		case reFunc.MatchString(line):
			m := reFunc.FindStringSubmatch(line)
			key = m[1] + m[2]
			// `_name` is the shell convention for an internal helper, not
			// something you type.
			if strings.HasPrefix(key, "_") {
				continue
			}
		case category == "tmux":
			k, ok := parseBind(line)
			if !ok {
				continue
			}
			key = k
		default:
			continue
		}

		e := Entry{Category: category, Key: key, File: s.path, Line: i + 1}
		if desc, ok := s.annotationAt(i); ok {
			e.Desc = desc
			found = append(found, e)
		} else {
			missing = append(missing, e)
		}
	}
	return found, missing
}

// parseBind reads a tmux `bind` / `bind-key` line and returns how the binding
// is actually pressed. Options have to be walked rather than regexed away
// because `-T <table>` takes an argument, and the table decides whether the
// prefix is involved at all.
func parseBind(line string) (string, bool) {
	fields := strings.Fields(line)
	if len(fields) < 2 || (fields[0] != "bind" && fields[0] != "bind-key") {
		return "", false
	}

	table := "prefix"
	i := 1
	for i < len(fields) {
		switch {
		case fields[i] == "-T" && i+1 < len(fields):
			table = fields[i+1]
			i += 2
		case fields[i] == "-n":
			table = "root"
			i++
		// A lone "-" is the key for the horizontal split, not an option.
		case strings.HasPrefix(fields[i], "-") && len(fields[i]) > 1:
			i++
		default:
			goto done
		}
	}
done:
	if i >= len(fields) {
		return "", false
	}

	key := fields[i]
	switch table {
	case "prefix":
		return "prefix + " + key, true
	case "root":
		// Pressed on its own, no prefix.
		return key, true
	default:
		return table + ": " + key, true
	}
}

// parseLua reads Neovim keymaps. lazy.nvim `keys` entries and
// `vim.keymap.set` calls both already carry a `desc`, so no annotation is
// needed here.
func parseLua(s *sourceFile, category string) []Entry {
	var out []Entry
	pendingKey, pendingLine := "", 0

	for i, line := range s.lines {
		if m := reLuaKeys.FindStringSubmatch(line); m != nil {
			out = append(out, Entry{
				Category: category, Key: m[1], Desc: m[2],
				File: s.path, Line: i + 1,
			})
			pendingKey = ""
			continue
		}

		if m := reLuaSet.FindStringSubmatch(line); m != nil {
			pendingKey, pendingLine = m[1], i+1
			// desc may sit on the same line or a few lines down.
			if d := reLuaDesc.FindStringSubmatch(line); d != nil {
				out = append(out, Entry{
					Category: category, Key: pendingKey, Desc: d[1],
					File: s.path, Line: pendingLine,
				})
				pendingKey = ""
			}
			continue
		}

		if pendingKey != "" {
			if d := reLuaDesc.FindStringSubmatch(line); d != nil {
				out = append(out, Entry{
					Category: category, Key: pendingKey, Desc: d[1],
					File: s.path, Line: pendingLine,
				})
				pendingKey = ""
			}
		}
	}
	return out
}

// parseGhAliases reads the `aliases:` block of gh's config. The alias body is
// its own best description, so no annotation is required.
func parseGhAliases(s *sourceFile) []Entry {
	var out []Entry
	inBlock := false

	for i, line := range s.lines {
		if strings.HasPrefix(line, "aliases:") {
			inBlock = true
			continue
		}
		if inBlock {
			if line != "" && !strings.HasPrefix(line, " ") {
				break
			}
			if m := reYamlPair.FindStringSubmatch(line); m != nil {
				out = append(out, Entry{
					Category: "gh", Key: "gh " + m[1], Desc: "gh " + m[2],
					File: s.path, Line: i + 1,
				})
			}
		}
	}
	return out
}

// parseGhDash reads gh-dash's `keybindings:` from the tracked example, since
// the live config is untracked.
func parseGhDash(s *sourceFile) (found []Entry, missing []Entry) {
	for i, line := range s.lines {
		m := reGhDashKey.FindStringSubmatch(line)
		if m == nil {
			continue
		}
		e := Entry{Category: "gh-dash", Key: m[1], File: s.path, Line: i + 1}
		if desc, ok := s.annotationAt(i); ok {
			e.Desc = desc
			found = append(found, e)
		} else {
			missing = append(missing, e)
		}
	}
	return found, missing
}

// parseSkills reads each skill's frontmatter description, first sentence only.
func parseSkills(root string) []Entry {
	dir := filepath.Join(root, "claude", "skills")
	names, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}

	var out []Entry
	for _, n := range names {
		if !n.IsDir() {
			continue
		}
		rel := filepath.Join("claude", "skills", n.Name(), "SKILL.md")
		s, err := readSource(root, rel)
		if err != nil {
			continue
		}
		for i, line := range s.lines {
			rest, ok := cutPrefix(line, "description:")
			if !ok {
				continue
			}
			desc := foldedValue(s.lines, i, strings.TrimSpace(rest))
			if head, _, ok := strings.Cut(desc, "。"); ok {
				desc = head + "。"
			}
			out = append(out, Entry{
				Category: "claude", Key: "/" + n.Name(), Desc: desc,
				File: rel, Line: i + 1,
			})
			break
		}
	}
	return out
}

// foldedValue resolves a YAML scalar that may be folded onto the following
// indented lines (`description: >`), which is how the skills are written.
func foldedValue(lines []string, i int, value string) string {
	if value != ">" && value != "|" && value != ">-" && value != "|-" {
		return value
	}

	var parts []string
	for j := i + 1; j < len(lines); j++ {
		line := lines[j]
		if strings.TrimSpace(line) == "" || !strings.HasPrefix(line, " ") {
			break
		}
		parts = append(parts, strings.TrimSpace(line))
	}
	return strings.Join(parts, " ")
}

// parseKarabiner reads rule descriptions, which are already written for humans.
func parseKarabiner(root string) []Entry {
	rel := filepath.Join("karabiner", "karabiner.json")
	data, err := os.ReadFile(filepath.Join(root, rel))
	if err != nil {
		return nil
	}

	var cfg struct {
		Profiles []struct {
			Name                 string `json:"name"`
			ComplexModifications struct {
				Rules []struct {
					Description string `json:"description"`
				} `json:"rules"`
			} `json:"complex_modifications"`
		} `json:"profiles"`
	}
	if json.Unmarshal(data, &cfg) != nil {
		return nil
	}

	var out []Entry
	for _, p := range cfg.Profiles {
		for _, r := range p.ComplexModifications.Rules {
			if r.Description == "" {
				continue
			}
			// The description is "Map X to Y"; the key is the useful half.
			key, desc := r.Description, r.Description
			if _, rest, ok := strings.Cut(r.Description, "Map "); ok {
				if k, target, ok := strings.Cut(rest, " to "); ok {
					key, desc = k, "→ "+target
				}
			}
			out = append(out, Entry{
				Category: "macOS", Key: key, Desc: desc, File: rel,
			})
		}
		// Only the active profile matters; the rest are leftovers.
		break
	}
	return out
}
