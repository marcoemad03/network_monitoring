package main

import (
	"archive/zip"
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func zipOf(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	for name, content := range files {
		f, err := w.Create(name)
		if err != nil {
			t.Fatal(err)
		}
		f.Write([]byte(content))
	}
	w.Close()
	return buf.Bytes()
}

func TestHealthSaysDatabaseUp(t *testing.T) {
	if healthSaysDatabaseUp([]byte(`{"status":"degraded","database":"disconnected"}`)) {
		t.Error("a server without its database must not count as ready")
	}
	if !healthSaysDatabaseUp([]byte(`{"status":"healthy","database":"connected"}`)) {
		t.Error("a healthy server must count")
	}
	if healthSaysDatabaseUp([]byte(`not json`)) {
		t.Error("an answer that cannot be read must not count")
	}
}

func TestExtractZip(t *testing.T) {
	dir := t.TempDir()
	// PowerShell's Compress-Archive writes backslashes.
	if err := extractZip(zipOf(t, map[string]string{`app\a.txt`: "one", "pg/bin/b.txt": "two"}), dir); err != nil {
		t.Fatal(err)
	}
	for file, want := range map[string]string{"app/a.txt": "one", "pg/bin/b.txt": "two"} {
		got, err := os.ReadFile(filepath.Join(dir, file))
		if err != nil || string(got) != want {
			t.Errorf("%s: %q %v", file, got, err)
		}
	}
}

func TestExtractZipRefusesPathsOutsideItsFolder(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "x")
	if err := extractZip(zipOf(t, map[string]string{"../evil.txt": "no"}), dir); err == nil {
		t.Fatal("a path leaving the folder must be refused")
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(dir), "evil.txt")); err == nil {
		t.Fatal("the file was written")
	}
}

func TestEnvStartsSafeAndKeepsItsSecrets(t *testing.T) {
	root := t.TempDir()
	first, err := loadOrCreateEnv(root, "8080")
	if err != nil {
		t.Fatal(err)
	}
	if first["ROUTER_POLICY_WRITES"] != "false" || first["SERVER_HOST"] != "127.0.0.1" || first["SEED_DEMO_DATA"] != "false" {
		t.Errorf("unsafe start: %v", first)
	}
	for _, k := range []string{"DB_PASSWORD", "JWT_ACCESS_SECRET", "JWT_REFRESH_SECRET", "ENCRYPTION_KEY"} {
		if len(first[k]) != 32 {
			t.Errorf("%s = %q", k, first[k])
		}
	}
	if first["JWT_ACCESS_SECRET"] == first["JWT_REFRESH_SECRET"] {
		t.Error("secrets must differ")
	}
	second, err := loadOrCreateEnv(root, "8080")
	if err != nil {
		t.Fatal(err)
	}
	if second["DB_PASSWORD"] != first["DB_PASSWORD"] {
		t.Error("the database password must survive a restart")
	}

	// A person who turned writes on keeps that choice, but the server stays local.
	data, _ := os.ReadFile(filepath.Join(root, "config.env"))
	edited := strings.ReplaceAll(strings.ReplaceAll(string(data), "ROUTER_POLICY_WRITES=false", "ROUTER_POLICY_WRITES=true"), "SERVER_HOST=127.0.0.1", "SERVER_HOST=0.0.0.0")
	os.WriteFile(filepath.Join(root, "config.env"), []byte(edited), 0o600)
	third, _ := loadOrCreateEnv(root, "8080")
	if third["ROUTER_POLICY_WRITES"] != "true" || third["SERVER_HOST"] != "127.0.0.1" {
		t.Errorf("%v", third)
	}
}
