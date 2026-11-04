// nms-portable is one exe that runs the whole NMS on any 64-bit Windows PC. The first
// run unpacks the app, the server and PostgreSQL to the user's AppData and makes an
// empty database. It carries no router login and no hospital data: the router is
// connected from the app's own screen, and router writes start off, because two
// servers writing to one router would remove each other's rules.
//
// Build it with scripts/build_portable.ps1.
package main

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"github.com/jackc/pgx/v5"
)

const (
	dbPort = "55432"
	dbUser = "nms_admin"
	dbName = "hospital_nms"
	// createNoWindow keeps the helper programs from opening console windows.
	createNoWindow = 0x08000000
)

var (
	kernel32 = syscall.NewLazyDLL("kernel32.dll")
	user32   = syscall.NewLazyDLL("user32.dll")
)

func main() {
	if err := run(); err != nil {
		logLine("ERROR: " + err.Error())
		messageBox("Harpur Network NMS could not start:\n\n" + err.Error())
		os.Exit(1)
	}
}

var logPath string

func logLine(s string) {
	fmt.Println(s)
	if logPath == "" {
		return
	}
	if f, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600); err == nil {
		fmt.Fprintf(f, "%s %s\n", time.Now().Format("2006-01-02 15:04:05"), s)
		f.Close()
	}
}

func messageBox(text string) {
	t, _ := syscall.UTF16PtrFromString(text)
	c, _ := syscall.UTF16PtrFromString("Harpur Network NMS")
	user32.NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(t)), uintptr(unsafe.Pointer(c)), 0x10)
}

func run() error {
	if len(payload) == 0 {
		return fmt.Errorf("this build has no payload; use scripts/build_portable.ps1")
	}
	root := os.Getenv("NMS_PORTABLE_ROOT")
	if root == "" {
		base, err := os.UserCacheDir() // %LOCALAPPDATA%
		if err != nil {
			return err
		}
		root = filepath.Join(base, "HarpurNMS")
	}
	if err := os.MkdirAll(filepath.Join(root, "logs"), 0o700); err != nil {
		return err
	}
	logPath = filepath.Join(root, "logs", "launcher.log")
	serverPort := os.Getenv("NMS_SERVER_PORT")
	if serverPort == "" {
		serverPort = "8080"
	}
	testRun := os.Getenv("NMS_PORTABLE_TEST") == "1"

	sum := sha256.Sum256(payload)
	dir := filepath.Join(root, "v-"+hex.EncodeToString(sum[:6]))
	if err := unpack(dir); err != nil {
		return fmt.Errorf("unpack: %w", err)
	}
	appExe := filepath.Join(dir, "app", "network_monitorong.exe")

	// A server is already answering here (the NMS PC itself): only the app is needed.
	if !testRun && healthy(serverPort) {
		if !databaseUp(serverPort) {
			return fmt.Errorf("the NMS server already running on this PC has lost its database, so the app would only show errors.\n\nStart that database and try again")
		}
		logLine("A server is already running; opening the app.")
		hideConsole()
		return runHidden(exec.Command(appExe))
	}
	if !singleInstance() {
		return nil
	}

	cfg, err := loadOrCreateEnv(root, serverPort)
	if err != nil {
		return fmt.Errorf("settings: %w", err)
	}
	pgData := filepath.Join(root, "pgdata")
	pgBin := filepath.Join(dir, "pg", "bin")
	if err := initDatabase(pgBin, pgData, cfg["DB_PASSWORD"]); err != nil {
		return fmt.Errorf("database setup: %w", err)
	}
	logLine("Starting the database...")
	pgLog := filepath.Join(root, "logs", "postgres.log")
	pgCtl := filepath.Join(pgBin, "pg_ctl.exe")
	if err := hidden(exec.Command(pgCtl, "-D", pgData, "-w", "-t", "60", "-l", pgLog, "-o", "-p "+dbPort+" -c listen_addresses=127.0.0.1", "start")).Run(); err != nil {
		if hidden(exec.Command(pgCtl, "-D", pgData, "status")).Run() != nil {
			return fmt.Errorf("the database did not start (see %s): %w", pgLog, err)
		}
	}
	defer func() {
		_ = hidden(exec.Command(pgCtl, "-D", pgData, "-m", "fast", "-w", "stop")).Run()
	}()
	if err := createDatabase(cfg["DB_PASSWORD"]); err != nil {
		return fmt.Errorf("create the database: %w", err)
	}

	logLine("Starting the server...")
	serverDir := filepath.Join(dir, "server")
	if err := writeEnv(filepath.Join(serverDir, ".env"), cfg); err != nil {
		return err
	}
	serverLog, err := os.OpenFile(filepath.Join(root, "logs", "server.log"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	defer serverLog.Close()
	server := hidden(exec.Command(filepath.Join(serverDir, "server.exe")))
	server.Dir, server.Stdout, server.Stderr = serverDir, serverLog, serverLog
	if err := server.Start(); err != nil {
		return fmt.Errorf("start the server: %w", err)
	}
	defer func() {
		_ = server.Process.Kill()
		_ = server.Wait()
	}()
	if !waitHealthy(serverPort, 90*time.Second) {
		return fmt.Errorf("the server did not answer; see %s", serverLog.Name())
	}
	if testRun {
		logLine("TEST OK: server answering on " + serverPort)
		return nil
	}
	logLine("Opening the app...")
	hideConsole()
	return runHidden(exec.Command(appExe))
}

func hidden(cmd *exec.Cmd) *exec.Cmd {
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow}
	return cmd
}

func runHidden(cmd *exec.Cmd) error {
	cmd.Dir = filepath.Dir(cmd.Path)
	err := cmd.Run()
	// However the app closed, there is nothing to tell the person: it is gone.
	var exit *exec.ExitError
	if errors.As(err, &exit) {
		logLine("The app closed with: " + exit.Error())
		return nil
	}
	return err
}

func hideConsole() {
	kernel32.NewProc("FreeConsole").Call()
}

// singleInstance stops a second click from setting up over the first.
func singleInstance() bool {
	name, _ := syscall.UTF16PtrFromString(`Local\HarpurNMSPortable`)
	_, _, err := kernel32.NewProc("CreateMutexW").Call(0, 0, uintptr(unsafe.Pointer(name)))
	return err != syscall.ERROR_ALREADY_EXISTS
}

func healthy(port string) bool {
	client := http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + "/api/v1/health")
	if err != nil {
		return false
	}
	resp.Body.Close()
	return resp.StatusCode < 500
}

// databaseUp asks a running server whether it can reach its database.
func databaseUp(port string) bool {
	client := http.Client{Timeout: 4 * time.Second}
	resp, err := client.Get("http://127.0.0.1:" + port + "/api/v1/health")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	return healthSaysDatabaseUp(body)
}

func healthSaysDatabaseUp(body []byte) bool {
	var h struct {
		Database string `json:"database"`
	}
	return json.Unmarshal(body, &h) == nil && h.Database != "disconnected"
}

func waitHealthy(port string, limit time.Duration) bool {
	for end := time.Now().Add(limit); time.Now().Before(end); time.Sleep(time.Second) {
		if healthy(port) {
			return true
		}
	}
	return false
}

// unpack extracts the payload once per version.
func unpack(dir string) error {
	done := filepath.Join(dir, ".unpacked")
	if _, err := os.Stat(done); err == nil {
		return nil
	}
	logLine("First run: unpacking, this takes a minute...")
	_ = os.RemoveAll(dir)
	if err := extractZip(payload, dir); err != nil {
		return err
	}
	return os.WriteFile(done, []byte("ok"), 0o600)
}

func extractZip(data []byte, dir string) error {
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return err
	}
	base := filepath.Clean(dir) + string(os.PathSeparator)
	for _, f := range zr.File {
		name := strings.ReplaceAll(f.Name, `\`, "/")
		target := filepath.Join(dir, filepath.FromSlash(name))
		if !strings.HasPrefix(target, base) {
			return fmt.Errorf("bad path in package: %s", f.Name)
		}
		if strings.HasSuffix(name, "/") {
			if err := os.MkdirAll(target, 0o700); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
			return err
		}
		src, err := f.Open()
		if err != nil {
			return err
		}
		dst, err := os.Create(target)
		if err != nil {
			src.Close()
			return err
		}
		_, err = io.Copy(dst, src)
		src.Close()
		if cerr := dst.Close(); err == nil {
			err = cerr
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func randomHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// loadOrCreateEnv keeps this PC's random secrets between runs and versions.
func loadOrCreateEnv(root, serverPort string) (map[string]string, error) {
	file := filepath.Join(root, "config.env")
	cfg := map[string]string{}
	if data, err := os.ReadFile(file); err == nil {
		for _, line := range strings.Split(string(data), "\n") {
			if k, v, ok := strings.Cut(strings.TrimSpace(line), "="); ok {
				cfg[k] = v
			}
		}
	}
	for _, key := range []string{"DB_PASSWORD", "JWT_ACCESS_SECRET", "JWT_REFRESH_SECRET", "ENCRYPTION_KEY"} {
		if cfg[key] == "" {
			v, err := randomHex(16)
			if err != nil {
				return nil, err
			}
			cfg[key] = v
		}
	}
	// Only this PC can reach the server: in this mode the API asks for no login.
	for k, v := range map[string]string{
		"SERVER_HOST": "127.0.0.1", "SERVER_PORT": serverPort, "ENVIRONMENT": "development",
		"DB_HOST": "127.0.0.1", "DB_PORT": dbPort, "DB_USER": dbUser, "DB_NAME": dbName, "DB_SSLMODE": "disable",
		"SEED_DEMO_DATA": "false", "LOG_LEVEL": "info", "LOG_FORMAT": "json", "LOG_KEEP_DAYS": "10",
		"LOG_CLEANUP_FILES": filepath.ToSlash(filepath.Join(root, "logs")) + "/server.log",
	} {
		cfg[k] = v
	}
	if cfg["ROUTER_POLICY_WRITES"] == "" {
		cfg["ROUTER_POLICY_WRITES"] = "false"
	}
	return cfg, writeEnv(file, cfg)
}

func writeEnv(file string, cfg map[string]string) error {
	var b strings.Builder
	for k, v := range cfg {
		b.WriteString(k + "=" + v + "\n")
	}
	return os.WriteFile(file, []byte(b.String()), 0o600)
}

func initDatabase(pgBin, pgData, password string) error {
	if _, err := os.Stat(filepath.Join(pgData, "PG_VERSION")); err == nil {
		return nil
	}
	logLine("Making the database...")
	_ = os.RemoveAll(pgData)
	pwFile := pgData + ".pw"
	if err := os.WriteFile(pwFile, []byte(password), 0o600); err != nil {
		return err
	}
	defer os.Remove(pwFile)
	out, err := hidden(exec.Command(filepath.Join(pgBin, "initdb.exe"), "-D", pgData, "-U", dbUser, "--pwfile="+pwFile, "-A", "scram-sha-256", "-E", "UTF8", "--locale=C")).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%w: %s", err, tail(string(out)))
	}
	return nil
}

func tail(s string) string {
	if len(s) > 400 {
		return s[len(s)-400:]
	}
	return s
}

func createDatabase(password string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	conn, err := pgx.Connect(ctx, fmt.Sprintf("postgres://%s:%s@127.0.0.1:%s/postgres?sslmode=disable", dbUser, password, dbPort))
	if err != nil {
		return err
	}
	defer conn.Close(ctx)
	var exists bool
	if err := conn.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM pg_database WHERE datname = $1)`, dbName).Scan(&exists); err != nil {
		return err
	}
	if exists {
		return nil
	}
	_, err = conn.Exec(ctx, `CREATE DATABASE `+dbName)
	return err
}
