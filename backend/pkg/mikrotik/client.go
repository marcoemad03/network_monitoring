package mikrotik

import (
	"fmt"
	"net"
	"net/url"
	"strconv"
	"strings"
	"time"
)

type DiscoveredDevice struct {
	IPAddress      string
	MACAddress     string
	Hostname       string
	Vendor         string
	InterfaceName  string
	ConnectionType string
	IsActive       bool
	Source         string
}

type Client struct {
	host     string
	port     int
	username string
	password string
	timeout  time.Duration
}

func NewClient(host, username, password string, timeout time.Duration) *Client {
	return NewClientWithPort(host, 8728, username, password, timeout)
}

func NewClientWithPort(host string, port int, username, password string, timeout time.Duration) *Client {
	return &Client{
		host:     host,
		port:     port,
		username: username,
		password: password,
		timeout:  timeout,
	}
}

func NewClientFromEndpoint(endpoint, username, password string, timeout time.Duration) (*Client, error) {
	host, port, err := ParseEndpoint(endpoint)
	if err != nil {
		return nil, err
	}
	return NewClientWithPort(host, port, username, password, timeout), nil
}

func ParseEndpoint(endpoint string) (string, int, error) {
	value := strings.TrimSpace(endpoint)
	if value == "" {
		return "", 0, fmt.Errorf("RouterOS API endpoint is empty")
	}
	if !strings.Contains(value, "://") {
		value = "routeros://" + value
	}
	u, err := url.Parse(value)
	if err != nil {
		return "", 0, fmt.Errorf("invalid RouterOS API endpoint: %w", err)
	}
	host := u.Hostname()
	if host == "" {
		return "", 0, fmt.Errorf("invalid RouterOS API host")
	}
	port := 8728
	if u.Port() != "" {
		port, err = strconv.Atoi(u.Port())
		if err != nil || port < 1 || port > 65535 {
			return "", 0, fmt.Errorf("invalid RouterOS API port")
		}
	}
	if net.ParseIP(host) == nil && strings.ContainsAny(host, "/?#") {
		return "", 0, fmt.Errorf("invalid RouterOS API host")
	}
	return host, port, nil
}

func (c *Client) Host() string {
	return c.host
}

func (c *Client) Port() int {
	return c.port
}

func (c *Client) Username() string {
	return c.username
}

func (c *Client) Password() string {
	return c.password
}

func (c *Client) connect() (*APIConnection, error) {
	conn := NewAPIConnection(c.host, c.port, c.username, c.password, c.timeout)
	if err := conn.Connect(); err != nil {
		return nil, fmt.Errorf("connect: %w", err)
	}
	if err := conn.Login(); err != nil {
		conn.Close()
		return nil, fmt.Errorf("login: %w", err)
	}
	return conn, nil
}

func (c *Client) query(cmd string) ([]DiscoveredDevice, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command(cmd)
	if err != nil {
		return nil, err
	}

	var devices []DiscoveredDevice
	for _, r := range results {
		d := parseRouterOSEntry(r)
		if d.MACAddress != "" || d.IPAddress != "" {
			devices = append(devices, d)
		}
	}
	return devices, nil
}

func parseRouterOSEntry(r map[string]string) DiscoveredDevice {
	d := DiscoveredDevice{
		MACAddress:     r["mac-address"],
		IPAddress:      r["address"],
		Hostname:       r["host-name"],
		InterfaceName:  r["interface"],
		ConnectionType: "LAN",
		IsActive:       true,
	}

	if comment, ok := r["comment"]; ok {
		d.Vendor = comment
	}
	if name, ok := r["name"]; ok && d.Hostname == "" {
		d.Hostname = name
	}

	return d
}

func (c *Client) GetDHCPLeases() ([]DiscoveredDevice, error) {
	return c.query("/ip/dhcp-server/lease/print")
}

func (c *Client) GetARP() ([]DiscoveredDevice, error) {
	return c.query("/ip/arp/print")
}

func (c *Client) GetWirelessRegistrationTable() ([]DiscoveredDevice, error) {
	return c.query("/interface/wireless/registration-table/print")
}

func (c *Client) GetHotspotHosts() ([]DiscoveredDevice, error) {
	return c.query("/ip/hotspot/host/print")
}

func (c *Client) GetBridgeHosts() ([]DiscoveredDevice, error) {
	return c.query("/interface/bridge/host/print")
}

func (c *Client) GetInterfaces() ([]DiscoveredDevice, error) {
	return c.query("/interface/print")
}

func (c *Client) TestConnection() error {
	conn, err := c.connect()
	if err != nil {
		return err
	}
	defer conn.Close()
	return nil
}

func (c *Client) GetAllDevices() ([]DiscoveredDevice, error) {
	seen := make(map[string]DiscoveredDevice)
	sources := []struct {
		name string
		fn   func() ([]DiscoveredDevice, error)
	}{
		{"dhcp", c.GetDHCPLeases},
		{"arp", c.GetARP},
		{"wireless", c.GetWirelessRegistrationTable},
		{"hotspot", c.GetHotspotHosts},
		{"bridge", c.GetBridgeHosts},
	}

	for _, src := range sources {
		devices, err := src.fn()
		if err != nil {
			continue
		}
		for _, d := range devices {
			mergeDevice(seen, d, src.name)
		}
	}

	result := make([]DiscoveredDevice, 0, len(seen))
	for _, d := range seen {
		result = append(result, d)
	}
	return result, nil
}

func mergeDevice(seen map[string]DiscoveredDevice, d DiscoveredDevice, source string) {
	d.Source = source
	key := d.MACAddress
	if key == "" {
		key = d.IPAddress
	}
	if key == "" {
		return
	}
	existing, ok := seen[key]
	if !ok {
		seen[key] = d
		return
	}
	if existing.IPAddress == "" && d.IPAddress != "" {
		existing.IPAddress = d.IPAddress
	}
	if existing.Hostname == "" && d.Hostname != "" {
		existing.Hostname = d.Hostname
	}
	if existing.InterfaceName == "" && d.InterfaceName != "" {
		existing.InterfaceName = d.InterfaceName
	}
	if d.Vendor != "" {
		existing.Vendor = d.Vendor
	}
	if d.IsActive {
		existing.IsActive = true
	}
	seen[key] = existing
}
