// nms-client is the program for other PCs: one exe holding the app, which it opens
// connected to the NMS server on the main PC. It holds no database and no server, and
// nothing runs on this PC after the app closes. Built by scripts/build_client.ps1,
// which sets the server's address and access key. The exe is the key to the server,
// so share it only with the PCs that should have access.
package main

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/hex"
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
)

// Set at build time.
var (
	serverHost = ""
	accessKey  = ""
)

const (
	mbOK          = 0x0
	mbRetryCancel = 0x5
	mbError       = 0x10
	mbWarning     = 0x30
	idRetry       = 4
)

func message(text string, flags uintptr) int {
	t, _ := syscall.UTF16PtrFromString(text)
	c, _ := syscall.UTF16PtrFromString("Harpur Network NMS")
	r, _, _ := syscall.NewLazyDLL("user32.dll").NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(t)), uintptr(unsafe.Pointer(c)), flags)
	return int(r)
}

func main() {
	if err := run(); err != nil {
		message("The program could not start:\n\n"+err.Error(), mbOK|mbError)
		os.Exit(1)
	}
}

func run() error {
	if len(payload) == 0 || serverHost == "" {
		return errors.New("this build is incomplete; use scripts/build_client.ps1")
	}
	base, err := os.UserCacheDir() // %LOCALAPPDATA%
	if err != nil {
		return err
	}
	root := filepath.Join(base, "HarpurNMS-Client")
	host := chooseHost(root)
	for {
		problem := serverProblem(host)
		if problem == "" {
			break
		}
		if message(problem+"\n\nThe main PC must be on, with Open Server running.\n(To use a different address, put it in "+filepath.Join(root, "server.txt")+")", mbRetryCancel|mbWarning) != idRetry {
			return nil
		}
		host = chooseHost(root)
	}
	sum := sha256.Sum256(payload)
	dir := filepath.Join(root, "v-"+hex.EncodeToString(sum[:6]))
	if _, err := os.Stat(filepath.Join(dir, ".unpacked")); err != nil {
		_ = os.RemoveAll(dir)
		if err := extractZip(payload, dir); err != nil {
			return fmt.Errorf("unpack: %w", err)
		}
		if err := os.WriteFile(filepath.Join(dir, ".unpacked"), []byte("ok"), 0o600); err != nil {
			return err
		}
	}
	app := exec.Command(filepath.Join(dir, "app", "network_monitorong.exe"))
	app.Dir = filepath.Dir(app.Path)
	app.Env = append(os.Environ(), "NMS_SERVER_HOST="+host, "NMS_SERVER_KEY="+accessKey)
	var exit *exec.ExitError
	if err := app.Run(); err != nil && !errors.As(err, &exit) {
		return err
	}
	return nil
}

// chooseHost prefers an address written in server.txt, in case the main PC moves.
func chooseHost(root string) string {
	if data, err := os.ReadFile(filepath.Join(root, "server.txt")); err == nil {
		if h := strings.TrimSpace(string(data)); h != "" {
			return h
		}
	}
	return serverHost
}

// serverProblem says what is wrong with the server, or nothing when it is ready.
func serverProblem(host string) string {
	client := http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get("http://" + host + ":8080/api/v1/health")
	if err != nil {
		return "The NMS server at " + host + " is not answering."
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if !strings.Contains(string(body), `"database":"connected"`) {
		return "The NMS server at " + host + " is on, but its database is not."
	}
	return ""
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
