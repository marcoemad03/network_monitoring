// open-server starts the NMS database and server on the main PC with one click, and
// offers to stop them when they are already running. They keep running after this
// program closes. Built as "open server.exe" by scripts/build_client.ps1.
package main

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

// Set at build time.
var (
	backendDir = `C:\Users\marco\Desktop\network_monitorong\backend`
	pgRoot     = `C:\pgsql16-dev`
)

const (
	createNoWindow         = 0x08000000
	createBreakawayFromJob = 0x01000000

	mbOK       = 0x0
	mbYesNo    = 0x4
	mbError    = 0x10
	mbQuestion = 0x20
	mbInfo     = 0x40
	mbDefault2 = 0x100
	idYes      = 6
)

func message(text string, flags uintptr) int {
	t, _ := syscall.UTF16PtrFromString(text)
	c, _ := syscall.UTF16PtrFromString("Open Server")
	r, _, _ := syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(t)), uintptr(unsafe.Pointer(c)), flags)
	return int(r)
}

func main() {
	if err := run(); err != nil {
		message(err.Error(), mbOK|mbError)
		os.Exit(1)
	}
}

func run() error {
	if serverAnswers() && databaseUp() {
		if message("The server is already running.\n\n"+whereToConnect()+"\n\nStop it? Monitoring stops for every PC. The rules already on the router stay.", mbYesNo|mbQuestion|mbDefault2) != idYes {
			return nil
		}
		return stop()
	}
	if !portOpen("5432") {
		if err := start(filepath.Join(pgRoot, "bin", "postgres.exe"), pgRoot, filepath.Join(pgRoot, "dl", "pg.log"), "-D", filepath.Join(pgRoot, "data")); err != nil {
			return fmt.Errorf("the database did not start: %w", err)
		}
		if !waitFor(90*time.Second, func() bool { return portOpen("5432") }) {
			return fmt.Errorf("the database did not start. See %s", filepath.Join(pgRoot, "dl", "pg.log"))
		}
	}
	log := filepath.Join(pgRoot, "dl", "server-run.log")
	if !serverAnswers() {
		if err := start(filepath.Join(backendDir, "cmd", "server", "server.exe"), backendDir, log); err != nil {
			return fmt.Errorf("the server did not start: %w", err)
		}
	}
	if !waitFor(120*time.Second, func() bool { return serverAnswers() && databaseUp() }) {
		return fmt.Errorf("the server did not become ready. See %s", log)
	}
	message("The server is running. You can open the program now.\n\n"+whereToConnect(), mbOK|mbInfo)
	return nil
}

// start runs a program on its own, so it outlives this one and any console.
func start(program, dir, logFile string, args ...string) error {
	f, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	defer f.Close()
	cmd := exec.Command(program, args...)
	cmd.Dir, cmd.Stdout, cmd.Stderr = dir, f, f
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow | createBreakawayFromJob}
	if err := cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}

func stop() error {
	server := filepath.Join(backendDir, "cmd", "server", "server.exe")
	script := fmt.Sprintf(`Get-Process server -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq '%s' } | Stop-Process -Force`, strings.ReplaceAll(server, "'", "''"))
	stopServer := exec.Command("powershell", "-NoProfile", "-NonInteractive", "-Command", script)
	stopServer.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow}
	if err := stopServer.Run(); err != nil {
		return fmt.Errorf("could not stop the server: %w", err)
	}
	stopDB := exec.Command(filepath.Join(pgRoot, "bin", "pg_ctl.exe"), "-D", filepath.Join(pgRoot, "data"), "-m", "fast", "-w", "stop")
	stopDB.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow}
	if err := stopDB.Run(); err != nil {
		return fmt.Errorf("the server stopped, but the database did not: %w", err)
	}
	message("The server and the database are stopped.", mbOK|mbInfo)
	return nil
}

func whereToConnect() string {
	addrs, _ := net.InterfaceAddrs()
	var ips []string
	for _, a := range addrs {
		if n, ok := a.(*net.IPNet); ok && n.IP.To4() != nil && n.IP.IsPrivate() {
			ips = append(ips, n.IP.String())
		}
	}
	return "Other PCs connect to: " + strings.Join(ips, " or ") + " (port 8080)"
}

func portOpen(port string) bool {
	conn, err := net.DialTimeout("tcp", net.JoinHostPort("127.0.0.1", port), time.Second)
	if err != nil {
		return false
	}
	conn.Close()
	return true
}

func serverAnswers() bool { return portOpen("8080") }

func databaseUp() bool {
	client := http.Client{Timeout: 4 * time.Second}
	resp, err := client.Get("http://127.0.0.1:8080/api/v1/health")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	return strings.Contains(string(body), `"database":"connected"`)
}

func waitFor(limit time.Duration, ready func() bool) bool {
	for end := time.Now().Add(limit); time.Now().Before(end); time.Sleep(time.Second) {
		if ready() {
			return true
		}
	}
	return false
}
