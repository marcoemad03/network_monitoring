package services

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
)

// The terminal in the app runs RouterOS console lines such as
//
//	/ip firewall filter remove [find where comment~"^nms-marco-"]
//
// The router's API has no console, so a line is read here and carried out as API
// commands. Only print, remove, enable and disable exist: a typing slip can lift a
// rule but cannot add one that takes the network down, and nothing here can reboot
// or reset the router. A change must name what it changes with a find, and it runs
// only after the app has shown what matched and the person confirmed.

// TerminalLine is what one typed line did.
type TerminalLine struct {
	Command string              `json:"command"`
	Verb    string              `json:"verb"`
	Matched int                 `json:"matched"`
	Changed int                 `json:"changed"`
	Names   []string            `json:"names,omitempty"` // what a change matched
	Rows    []map[string]string `json:"rows,omitempty"`  // what a print returned
	More    int                 `json:"more,omitempty"`  // rows left out of a long print
	Error   string              `json:"error,omitempty"`
}

// TerminalResult is the answer to a run.
type TerminalResult struct {
	Lines        []TerminalLine `json:"lines"`
	NeedsConfirm bool           `json:"needs_confirm"`
	DryRun       bool           `json:"dry_run"`
}

const terminalMaxRows = 300

// Tables a change may touch. Printing is open except for tables holding passwords.
var terminalWritable = map[string]bool{
	"/ip/firewall/filter": true, "/ip/firewall/nat": true, "/ip/firewall/mangle": true, "/ip/firewall/raw": true,
	"/ip/firewall/address-list": true, "/ip/firewall/layer7-protocol": true,
	"/queue/simple": true, "/queue/tree": true, "/ip/dns/static": true,
	"/system/scheduler": true,
}

type terminalFilter struct {
	key   string
	value string
	re    *regexp.Regexp
}

func (f terminalFilter) matches(row map[string]string) bool {
	if f.re != nil {
		return f.re.MatchString(row[f.key])
	}
	return row[f.key] == f.value
}

type terminalCommand struct {
	text    string
	path    string
	verb    string
	filters []terminalFilter
}

func (c terminalCommand) selects(row map[string]string) bool {
	for _, f := range c.filters {
		if !f.matches(row) {
			return false
		}
	}
	return true
}

// terminalTokens splits a line on spaces, keeping quoted text together and dropping
// the quotes and the brackets around a find.
func terminalTokens(line string) ([]string, error) {
	var out []string
	var cur strings.Builder
	inQuote, has := false, false
	flush := func() {
		if has {
			out = append(out, cur.String())
			cur.Reset()
			has = false
		}
	}
	for i := 0; i < len(line); i++ {
		ch := line[i]
		switch {
		case inQuote && ch == '\\' && i+1 < len(line):
			i++
			if line[i] != '"' {
				cur.WriteByte('\\')
			}
			cur.WriteByte(line[i])
		case ch == '"':
			inQuote = !inQuote
			has = true
		case inQuote:
			cur.WriteByte(ch)
		case ch == ' ' || ch == '\t':
			flush()
		case ch == '[' || ch == ']':
			flush()
		default:
			cur.WriteByte(ch)
			has = true
		}
	}
	if inQuote {
		return nil, fmt.Errorf("a quote is not closed")
	}
	flush()
	return out, nil
}

var terminalFilterToken = regexp.MustCompile(`^([a-zA-Z0-9._-]+)(=|~)(.*)$`)

func parseTerminalLine(line string) (terminalCommand, error) {
	cmd := terminalCommand{text: strings.TrimSpace(line)}
	if !strings.HasPrefix(cmd.text, "/") {
		return cmd, fmt.Errorf("a command starts with /, for example /ip firewall filter print")
	}
	tokens, err := terminalTokens(cmd.text)
	if err != nil {
		return cmd, err
	}
	// The console also accepts /ip/firewall/filter/print.
	if len(tokens) > 0 && strings.Contains(tokens[0][1:], "/") {
		tokens = append(strings.Split(strings.Trim(tokens[0], "/"), "/"), tokens[1:]...)
	}
	at := -1
	for i, t := range tokens {
		if t == "print" || t == "remove" || t == "enable" || t == "disable" {
			at = i
			break
		}
	}
	if at < 1 {
		return cmd, fmt.Errorf("only print, remove, enable and disable can be used here")
	}
	cmd.verb = tokens[at]
	path := strings.Join(tokens[:at], "/")
	path = "/" + strings.Trim(strings.ReplaceAll(path, "//", "/"), "/")
	cmd.path = path

	rest := tokens[at+1:]
	if len(rest) > 0 && rest[0] == "find" {
		rest = rest[1:]
	}
	if len(rest) > 0 && rest[0] == "where" {
		rest = rest[1:]
	}
	for _, t := range rest {
		if t == "and" {
			continue
		}
		m := terminalFilterToken.FindStringSubmatch(t)
		if m == nil {
			return cmd, fmt.Errorf("cannot read %q; use name=value or name~\"pattern\"", t)
		}
		f := terminalFilter{key: m[1], value: m[3]}
		if m[2] == "~" {
			re, err := regexp.Compile(m[3])
			if err != nil {
				return cmd, fmt.Errorf("bad pattern %q", m[3])
			}
			f.re = re
		}
		cmd.filters = append(cmd.filters, f)
	}

	if cmd.verb == "print" {
		for _, word := range []string{"/user", "password", "secret", "/certificate"} {
			if strings.Contains(path, word) {
				return cmd, fmt.Errorf("%s cannot be read from here", path)
			}
		}
		return cmd, nil
	}
	if !terminalWritable[path] {
		return cmd, fmt.Errorf("%s cannot be changed from here", path)
	}
	if path == "/system/scheduler" && cmd.verb != "remove" {
		return cmd, fmt.Errorf("scheduler jobs can only be removed from here")
	}
	if len(cmd.filters) == 0 {
		return cmd, fmt.Errorf("say what to %s with [find where ...]; changing a whole table is not allowed", cmd.verb)
	}
	return cmd, nil
}

// runTerminal carries out the lines in order and stops at the first that fails.
// Without confirm, changes only report what they would touch.
func runTerminal(conn routerCommander, text string, confirm bool) TerminalResult {
	var res TerminalResult
	for _, raw := range strings.Split(text, "\n") {
		raw = strings.TrimSpace(raw)
		if raw == "" || strings.HasPrefix(raw, "#") {
			continue
		}
		cmd, err := parseTerminalLine(raw)
		line := TerminalLine{Command: raw, Verb: cmd.verb}
		if err != nil {
			line.Error = err.Error()
			res.Lines = append(res.Lines, line)
			return res
		}
		runTerminalLine(conn, cmd, confirm, &line)
		res.Lines = append(res.Lines, line)
		if line.Error != "" {
			return res
		}
		if cmd.verb != "print" && !confirm && line.Matched > 0 {
			res.NeedsConfirm = true
		}
	}
	return res
}

func runTerminalLine(conn routerCommander, cmd terminalCommand, confirm bool, line *TerminalLine) {
	rows, err := conn.Command(cmd.path + "/print")
	if err != nil {
		line.Error = err.Error()
		return
	}
	for _, r := range rows {
		if !cmd.selects(r) {
			continue
		}
		if cmd.verb == "print" {
			line.Matched++
			if len(line.Rows) < terminalMaxRows {
				line.Rows = append(line.Rows, r)
			} else {
				line.More++
			}
			continue
		}
		if r["dynamic"] == "true" {
			continue // the router made it and would refuse
		}
		line.Matched++
		line.Names = append(line.Names, terminalEntryName(r))
		if !confirm {
			continue
		}
		if _, err := conn.Command(cmd.path+"/"+cmd.verb, "=.id="+r[".id"]); err != nil {
			line.Error = err.Error()
			return
		}
		line.Changed++
	}
}

func terminalEntryName(r map[string]string) string {
	for _, k := range []string{"comment", "name", "address"} {
		if r[k] != "" {
			return r[k]
		}
	}
	return "entry " + r[".id"] + " " + r["chain"] + " " + r["action"]
}

// RunTerminal runs what was typed in the app's terminal on the router.
func (s *MarcoSyncService) RunTerminal(ctx context.Context, orgID uuid.UUID, text string, confirm bool) (*TerminalResult, error) {
	ctx, cancel := context.WithTimeout(ctx, 60*time.Second)
	defer cancel()
	vendor, err := s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("active MikroTik integration is not configured: %w", err)
	}
	sess, err := openRouterSession(ctx, vendor, s.cfg, s.dialRouter, true)
	if err != nil {
		return nil, fmt.Errorf("connect MikroTik: %w", err)
	}
	defer sess.Close()
	res := runTerminal(sess, text, confirm)
	res.DryRun = sess.DryRun()
	if confirm {
		for _, l := range res.Lines {
			if l.Verb == "print" {
				continue
			}
			status, why := "applied", ""
			if l.Error != "" {
				status, why = "failed", l.Error
			}
			entry := &models.MarcoPolicyLog{ID: uuid.New(), OrganizationID: orgID, Action: "terminal", Message: fmt.Sprintf("%s (%d changed)", l.Command, l.Changed), Status: status}
			if why != "" {
				entry.RouterError = &why
			}
			_ = s.marcoRepo.CreatePolicyLog(context.Background(), entry)
		}
	}
	return &res, nil
}
