package services

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/hospital/nms-backend/pkg/logger"
)

func writeLog(t *testing.T, name, content string) string {
	t.Helper()
	file := filepath.Join(t.TempDir(), name)
	if err := os.WriteFile(file, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return file
}

func TestCleanLogKeepsEntriesFromTheCutoffOn(t *testing.T) {
	cutoff := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	cases := []struct{ name, before, after string }{
		{
			"app log with its box lines and bodies",
			"│ 2026-10-20 10:00:00.000\n│ GET /old\n│ Data: old\n│ 2026-11-01 09:00:00.000\n│ GET /new\n",
			"│ 2026-11-01 09:00:00.000\n│ GET /new\n",
		},
		{
			"server log",
			`{"level":"info","timestamp":"2026-10-20T10:59:34.893+0200","msg":"old"}` + "\n" + `{"level":"info","timestamp":"2026-11-02T10:59:34.893+0200","msg":"new"}` + "\n",
			`{"level":"info","timestamp":"2026-11-02T10:59:34.893+0200","msg":"new"}` + "\n",
		},
		{
			"a recent date inside an old entry's data does not count",
			"│ 2026-10-20 10:00:00.000\n│ {day: 2026-11-03T00:00:00+02:00}\n│ 2026-11-02 09:00:00.000\n│ GET /new\n",
			"│ 2026-11-02 09:00:00.000\n│ GET /new\n",
		},
		{"nothing old", "│ 2026-11-02 09:00:00.000\nx\n", "│ 2026-11-02 09:00:00.000\nx\n"},
		{"everything old", "│ 2026-10-20 09:00:00.000\nx\n", ""},
		{"no dates at all is left alone", "started\nlistening\n", "started\nlistening\n"},
		{"lines with no date before recent entries stay", "Launching app\nBuilt\n│ 2026-11-02 09:00:00.000\nx\n", "Launching app\nBuilt\n│ 2026-11-02 09:00:00.000\nx\n"},
	}
	for _, c := range cases {
		file := writeLog(t, "a.log", c.before)
		if _, err := cleanLogFile(file, cutoff); err != nil {
			t.Fatalf("%s: %v", c.name, err)
		}
		got, _ := os.ReadFile(file)
		if string(got) != c.after {
			t.Errorf("%s: got %q, want %q", c.name, got, c.after)
		}
	}
}

func TestCleanLogHandlesLinesLongerThanItsBuffer(t *testing.T) {
	long := strings.Repeat("x", 3<<20)
	// A date that lands where the read buffer ends is still in the middle of a line.
	first := "│ 2026-10-20 10:00:00.000\n"
	tricky := long[:1<<20-len(first)] + "│ 2026-11-03 09:00:00.000" + long[:100]
	old := first + tricky + "\n│ 2026-11-02 09:00:00.000\n" + long + "\n"
	file := writeLog(t, "a.log", old)
	freed, err := cleanLogFile(file, time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(file)
	if !strings.HasPrefix(string(got), "│ 2026-11-02 09:00:00.000\n") || int64(len(old))-freed != int64(len(got)) {
		t.Errorf("kept %d bytes starting %q, freed %d", len(got), string(got[:30]), freed)
	}
}

func TestCleanLogWhileAnotherProgramKeepsWritingToIt(t *testing.T) {
	file := writeLog(t, "a.log", "│ 2026-10-20 10:00:00.000\nold\n│ 2026-11-02 09:00:00.000\nnew\n")
	writer, err := os.OpenFile(file, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	defer writer.Close()
	if _, err := cleanLogFile(file, time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)); err != nil {
		t.Fatal(err)
	}
	if _, err := writer.WriteString("later\n"); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(file)
	if string(got) != "│ 2026-11-02 09:00:00.000\nnew\nlater\n" {
		t.Errorf("got %q", got)
	}
}

func TestCleanLogsDeletesOnlyOldLogFiles(t *testing.T) {
	logger.Init("error", "json")
	dir := t.TempDir()
	now := time.Date(2026, 11, 20, 0, 0, 0, 0, time.UTC)
	cutoff := now.AddDate(0, 0, -10)
	mk := func(name string, modified time.Time) string {
		file := filepath.Join(dir, name)
		if err := os.WriteFile(file, []byte("no dates here\n"), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(file, modified, modified); err != nil {
			t.Fatal(err)
		}
		return file
	}
	oldLog := mk("server_err2.log", now.AddDate(0, 0, -30))
	newLog := mk("server.log", now.AddDate(0, 0, -2))
	notLog := mk("server.exe", now.AddDate(0, 0, -30))

	cleanLogs([]string{filepath.Join(dir, "*")}, cutoff)

	if _, err := os.Stat(oldLog); !os.IsNotExist(err) {
		t.Error("a log nothing wrote to for over the limit must go")
	}
	if _, err := os.Stat(newLog); err != nil {
		t.Error("a recent log must stay")
	}
	if _, err := os.Stat(notLog); err != nil {
		t.Error("only files named .log may ever be deleted")
	}
}
