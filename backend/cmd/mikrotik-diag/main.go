package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/hospital/nms-backend/pkg/mikrotik"
)

func logFn(prefix string) func(string, ...interface{}) {
	return func(format string, args ...interface{}) {
		msg := fmt.Sprintf(format, args...)
		fmt.Printf("[%s] %s\n", prefix, msg)
	}
}

func main() {
	host := getEnv("MT_HOST", "192.168.88.1")
	username := getEnv("MT_USER", "admin")
	password := getEnv("MT_PASS", "")
	timeoutSec := getEnvInt("MT_TIMEOUT", 10)

	timeout := time.Duration(timeoutSec) * time.Second

	fmt.Println(strings.Repeat("=", 70))
	fmt.Println("  MIKROTIK ROUTEROS DIAGNOSTIC TOOL")
	fmt.Println(strings.Repeat("=", 70))
	fmt.Printf("  Host:     %s\n", host)
	fmt.Printf("  Username: %s\n", username)
	fmt.Printf("  Password: %s\n", maskStr(password))
	fmt.Printf("  Timeout:  %v\n", timeout)
	fmt.Println(strings.Repeat("=", 70))

	fmt.Println()
	fmt.Println(">>> PHASE 1: TCP CONNECTIVITY CHECK <<<")
	fmt.Println()

	testTCPPort(host, 8728, timeout)
	testTCPPort(host, 8729, timeout)
	testTCPPort(host, 80, timeout)
	testTCPPort(host, 443, timeout)
	testTCPPort(host, 22, timeout)

	fmt.Println()
	fmt.Println(">>> PHASE 2: NATIVE API (port 8728) <<<")
	fmt.Println()

	tryNativeAPI(host, 8728, username, password, timeout)

	fmt.Println()
	fmt.Println(">>> PHASE 3: NATIVE API TLS (port 8729) <<<")
	fmt.Println()

	tryNativeAPI(host, 8729, username, password, timeout)

	fmt.Println()
	fmt.Println(">>> PHASE 4: REST API (port 80) <<<")
	fmt.Println()

	tryRESTAPI(host, 80, false, username, password, timeout)

	fmt.Println()
	fmt.Println(">>> PHASE 5: REST API TLS (port 443) <<<")
	fmt.Println()

	tryRESTAPI(host, 443, true, username, password, timeout)

	fmt.Println()
	fmt.Println(strings.Repeat("=", 70))
	fmt.Println("  DIAGNOSTIC COMPLETE")
	fmt.Println(strings.Repeat("=", 70))
}

func tryNativeAPI(host string, port int, username, password string, timeout time.Duration) {
	log := logFn(fmt.Sprintf("API:%d", port))

	conn := mikrotik.NewAPIConnection(host, port, username, password, timeout)
	conn.Debug = true
	conn.LogFn = log

	log("Connecting...")
	if err := conn.Connect(); err != nil {
		log("CONNECTION FAILED: %v", err)
		return
	}
	defer conn.Close()
	log("CONNECTION OK")

	log("")
	log("------- LOGIN -------")
	if err := conn.Login(); err != nil {
		log("LOGIN FAILED: %v", err)
		return
	}
	log("LOGIN OK")

	log("")
	log("------- SYSTEM IDENTITY -------")
	results, err := conn.Command("/system/identity/print")
	if err != nil {
		log("FAILED: %v", err)
	} else {
		for _, r := range results {
			log("Router identity: %s", r["name"])
		}
	}

	log("")
	log("------- SYSTEM RESOURCE -------")
	results, err = conn.Command("/system/resource/print")
	if err != nil {
		log("FAILED: %v", err)
	} else {
		for _, r := range results {
			log("Version: %-20s Board: %-20s Uptime: %-10s CPU: %s",
				r["version"], r["board-name"], r["uptime"], r["cpu"])
		}
		if len(results) > 0 {
			ver := results[0]["version"]
			log("RouterOS version: %s", ver)
			if strings.Contains(ver, "7.") {
				log("RouterOS v7 detected — REST API should be available")
			} else if strings.Contains(ver, "6.") {
				log("RouterOS v6 detected — REST API NOT available, native API only")
			}
		}
	}

	log("")
	log("------- DHCP LEASES -------")
	results, err = conn.Command("/ip/dhcp-server/lease/print")
	if err != nil {
		log("FAILED: %v", err)
	} else {
		log("Found %d DHCP leases", len(results))
		for _, r := range results {
			log("  MAC: %-18s IP: %-16s Hostname: %-20s Status: %s",
				r["mac-address"], r["address"], r["host-name"], r["status"])
		}
	}

	log("")
	log("------- ARP TABLE -------")
	results, err = conn.Command("/ip/arp/print")
	if err != nil {
		log("FAILED: %v", err)
	} else {
		log("Found %d ARP entries", len(results))
		for _, r := range results {
			log("  IP: %-16s MAC: %-18s Interface: %-12s Status: %s",
				r["address"], r["mac-address"], r["interface"], r["status"])
		}
	}

	log("")
	log("------- INTERFACES -------")
	results, err = conn.Command("/interface/print")
	if err != nil {
		log("FAILED: %v", err)
	} else {
		log("Found %d interfaces", len(results))
		for _, r := range results {
			run := "down"
			if r["running"] == "true" {
				run = "UP"
			}
			log("  %-20s Type: %-10s MAC: %-18s %s", r["name"], r["type"], r["mac-address"], run)
		}
	}

	log("")
	log("------- WIRELESS REGISTRATION TABLE -------")
	results, err = conn.Command("/interface/wireless/registration-table/print")
	if err != nil {
		log("FAILED: %v (wireless not enabled or v7)", err)
	} else {
		log("Found %d wireless clients", len(results))
		for _, r := range results {
			log("  MAC: %-18s Interface: %-12s Signal: %s", r["mac-address"], r["interface"], r["signal-strength"])
		}
	}

	log("")
	log("------- BRIDGE HOSTS -------")
	results, err = conn.Command("/interface/bridge/host/print")
	if err != nil {
		log("FAILED: %v (no bridge configured?)", err)
	} else {
		log("Found %d bridge hosts", len(results))
		for _, r := range results {
			local := ""
			if r["local"] == "true" {
				local = " (local)"
			}
			log("  MAC: %-18s Bridge: %-12s%s", r["mac-address"], r["bridge"], local)
		}
	}

	log("")
	log("------- HOTSPOT HOSTS -------")
	results, err = conn.Command("/ip/hotspot/host/print")
	if err != nil {
		log("FAILED: %v (hotspot not configured)", err)
	} else {
		log("Found %d hotspot hosts", len(results))
		for _, r := range results {
			log("  MAC: %-18s IP: %-16s User: %s", r["mac-address"], r["address"], r["user"])
		}
	}

	log("")
	log("*** NATIVE API (port %d) COMPLETE ***", port)
}

func tryRESTAPI(host string, port int, useTLS bool, username, password string, timeout time.Duration) {
	log := logFn(fmt.Sprintf("REST:%d", port))

	scheme := "http"
	if useTLS {
		scheme = "https"
	}

	baseURL := fmt.Sprintf("%s://%s:%d", scheme, host, port)
	log("Base URL: %s", baseURL)

	client := &http.Client{Timeout: timeout}

	endpoints := []string{
		"/rest/system/identity",
		"/rest/system/resource",
		"/rest/ip/dhcp-server/lease",
		"/rest/ip/arp",
		"/rest/interface",
	}

	for _, ep := range endpoints {
		log("")
		log(">>> GET %s <<<", ep)
		url := fmt.Sprintf("%s%s", baseURL, ep)

		req, err := http.NewRequest("GET", url, nil)
		if err != nil {
			log("REQUEST BUILD ERROR: %v", err)
			continue
		}
		req.SetBasicAuth(username, password)

		log("Request: GET %s", url)
		log("Authorization: Basic %s", maskStr(fmt.Sprintf("%s:%s", username, password)))

		resp, err := client.Do(req)
		if err != nil {
			log("HTTP ERROR: %v", err)
			continue
		}

		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		log("Response: HTTP %d", resp.StatusCode)

		if resp.StatusCode >= 200 && resp.StatusCode < 300 {
			var prettyBuf bytes.Buffer
			if err := json.Indent(&prettyBuf, body, "    ", "  "); err != nil {
				log("Raw: %s", string(body))
			} else {
				log("Body:")
				for _, line := range strings.Split(prettyBuf.String(), "\n") {
					log("  %s", line)
				}
			}
		} else {
			log("Error response: %s", string(body))
		}
	}

	log("")
	log("*** REST API (port %d) COMPLETE ***", port)
}

func testTCPPort(host string, port int, timeout time.Duration) {
	addr := fmt.Sprintf("%s:%d", host, port)
	fmt.Printf("  %-22s ... ", addr)
	conn, err := net.DialTimeout("tcp", addr, timeout)
	if err != nil {
		fmt.Printf("CLOSED (%v)\n", err)
		return
	}
	conn.Close()
	fmt.Println("OPEN")
}

func maskStr(s string) string {
	if len(s) <= 4 {
		return strings.Repeat("*", len(s))
	}
	return s[:2] + strings.Repeat("*", len(s)-4) + s[len(s)-2:]
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		var i int
		fmt.Sscanf(v, "%d", &i)
		return i
	}
	return fallback
}
