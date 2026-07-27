package mikrotik

import (
	"fmt"
	"net"
	"sort"
	"strings"
)

type EnhancedDevice struct {
	IPAddress      string
	MACAddress     string
	Hostname       string
	Vendor         string
	InterfaceName  string
	ConnectionType string
	IsActive       bool
	Source         string
	SSID           string
	BSSID          string
	SignalStrength int
	FrequencyMHz   int
	Channel        int
	TxRateMbps     float64
	RxRateMbps     float64
	RxBytes        int64
	TxBytes        int64
	RxPackets      int64
	TxPackets      int64
	DHCPStatus     string
	LeaseExpiry    string
	Comment        string
	Blocked        bool
	Disabled       bool
}

type QueueStats struct {
	Name        string
	Target      string
	MaxLimit    string
	BurstLimit  string
	BurstThresh string
	BurstTime   string
	RateLimit   string
	QueueType   string
	Parent      string
	BytesIn     int64
	BytesOut    int64
	PacketsIn   int64
	PacketsOut  int64
	QueuedBytes int64
	Disabled    bool
}

type FirewallRule struct {
	ID        string
	Chain     string
	Action    string
	Protocol  string
	SrcAddr   string
	DstAddr   string
	SrcPort   string
	DstPort   string
	InInterf  string
	OutInterf string
	Layer7    string
	Content   string
	Comment   string
	Disabled  bool
	Bytes     int64
	Packets   int64
}

type DNSStaticEntry struct {
	Name     string
	Address  string
	TTL      string
	MatchSub string
	Comment  string
	Disabled bool
}

type InterfaceDetail struct {
	Name       string
	Type       string
	MACAddress string
	MTU        int
	Speed      string
	Running    bool
	Enabled    bool
	Comment    string
	RxBytes    int64
	TxBytes    int64
	RxPackets  int64
	TxPackets  int64
	RxErrors   int64
	TxErrors   int64
	RxDrops    int64
	TxDrops    int64
}

type AddressList struct {
	List     string
	Address  string
	Timeout  string
	Comment  string
	Dynamic  bool
	Disabled bool
}

type RouterIdentity struct {
	Name    string
	Version string
	Board   string
	Uptime  string
}

const Subnet172 = "172.16.0.0/8"

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func IsInSubnet172(ip string) bool {
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return false
	}
	_, cidr, err := net.ParseCIDR(Subnet172)
	if err != nil {
		return false
	}
	return cidr.Contains(parsed)
}

func (c *Client) GetRouterIdentity() (*RouterIdentity, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command("/system/identity/print")
	if err != nil {
		return nil, err
	}

	res := &RouterIdentity{}
	if len(results) > 0 {
		res.Name = results[0]["name"]
	}

	results, err = conn.Command("/system/resource/print")
	if err == nil && len(results) > 0 {
		res.Version = results[0]["version"]
		res.Board = results[0]["board-name"]
		res.Uptime = results[0]["uptime"]
	}

	if strings.Contains(res.Version, "7.") {
		res.Version = "7" + res.Version[1:]
	}

	return res, nil
}

func (c *Client) GetWiFiRegistrationTable() ([]EnhancedDevice, error) {
	var devices []EnhancedDevice

	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command("/interface/wireless/registration-table/print")
	if err != nil {
		results, err = conn.Command("/interface/wifi/registration-table/print")
		if err != nil {
			return nil, err
		}
	}

	for _, r := range results {
		d := EnhancedDevice{
			MACAddress:     r["mac-address"],
			IPAddress:      r["address"],
			Hostname:       r["host-name"],
			InterfaceName:  r["interface"],
			ConnectionType: "WiFi",
			IsActive:       true,
			Source:         "wireless",
			SSID:           r["ssid"],
			BSSID:          r["bssid"],
			SignalStrength: parseInt(r["signal-strength"]),
			FrequencyMHz:   parseInt(r["frequency"]),
			Channel:        parseInt(r["channel"]),
			TxRateMbps:     parseFloat(r["tx-rate"]),
			RxRateMbps:     parseFloat(r["rx-rate"]),
			TxBytes:        parseInt64(r["tx-bytes"]),
			RxBytes:        parseInt64(r["rx-bytes"]),
			TxPackets:      parseInt64(r["tx-packets"]),
			RxPackets:      parseInt64(r["rx-packets"]),
		}
		if d.MACAddress != "" || d.IPAddress != "" {
			if strings.Contains(r["comment"], "block") {
				d.Blocked = true
			}
			devices = append(devices, d)
		}
	}
	return devices, nil
}

func (c *Client) GetDHCPLeasesEnhanced() ([]EnhancedDevice, error) {
	devices, err := c.queryEnhanced("/ip/dhcp-server/lease/print")
	if err != nil {
		return nil, err
	}
	for i, d := range devices {
		devices[i].Source = "dhcp"
		devices[i].DHCPStatus = "dynamic"
		if d.Comment != "" {
			devices[i].DHCPStatus = "static"
		}
	}
	return devices, nil
}

func (c *Client) GetARPEnhanced() ([]EnhancedDevice, error) {
	devices, err := c.queryEnhanced("/ip/arp/print")
	if err != nil {
		return nil, err
	}
	for i := range devices {
		devices[i].Source = "arp"
	}
	return devices, nil
}

func (c *Client) GetHotspotHostsEnhanced() ([]EnhancedDevice, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command("/ip/hotspot/host/print")
	if err != nil {
		return nil, err
	}
	devices := make([]EnhancedDevice, 0, len(results))
	for _, r := range results {
		d := EnhancedDevice{
			MACAddress:     r["mac-address"],
			IPAddress:      firstNonEmpty(r["address"], r["to-address"]),
			Hostname:       firstNonEmpty(r["host-name"], r["user"]),
			InterfaceName:  firstNonEmpty(r["interface"], r["server"]),
			ConnectionType: "WiFi",
			IsActive:       true,
			Source:         "hotspot",
			RxBytes:        parseInt64(firstNonEmpty(r["bytes-in"], r["rx-bytes"])),
			TxBytes:        parseInt64(firstNonEmpty(r["bytes-out"], r["tx-bytes"])),
			RxPackets:      parseInt64(firstNonEmpty(r["packets-in"], r["rx-packets"])),
			TxPackets:      parseInt64(firstNonEmpty(r["packets-out"], r["tx-packets"])),
		}
		if d.MACAddress != "" || d.IPAddress != "" {
			devices = append(devices, d)
		}
	}
	return devices, nil
}

func (c *Client) GetBridgeHostsEnhanced() ([]EnhancedDevice, error) {
	devices, err := c.queryEnhanced("/interface/bridge/host/print")
	if err != nil {
		return nil, err
	}
	for i := range devices {
		devices[i].Source = "bridge"
	}
	return devices, nil
}

func (c *Client) GetInterfacesDetail() ([]InterfaceDetail, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command("/interface/print")
	if err != nil {
		return nil, err
	}

	var ifaces []InterfaceDetail
	for _, r := range results {
		iface := InterfaceDetail{
			Name:       r["name"],
			Type:       r["type"],
			MACAddress: r["mac-address"],
			MTU:        parseInt(r["mtu"]),
			Speed:      r["speed"],
			Running:    r["running"] == "true",
			Enabled:    r["disabled"] != "true",
			Comment:    r["comment"],
			RxBytes:    parseInt64(r["rx-byte"]),
			TxBytes:    parseInt64(r["tx-byte"]),
			RxPackets:  parseInt64(r["rx-packet"]),
			TxPackets:  parseInt64(r["tx-packet"]),
			RxErrors:   parseInt64(r["rx-error"]),
			TxErrors:   parseInt64(r["tx-error"]),
			RxDrops:    parseInt64(r["rx-drop"]),
			TxDrops:    parseInt64(r["tx-drop"]),
		}
		ifaces = append(ifaces, iface)
	}
	return ifaces, nil
}

func (c *Client) GetSimpleQueues() ([]QueueStats, error) {
	return c.getQueues("/queue/simple/print")
}

func (c *Client) GetQueueTrees() ([]QueueStats, error) {
	return c.getQueues("/queue/tree/print")
}

func (c *Client) getQueues(cmd string) ([]QueueStats, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command(cmd)
	if err != nil {
		return nil, err
	}

	var queues []QueueStats
	for _, r := range results {
		q := QueueStats{
			Name:        r["name"],
			Target:      r["target"],
			MaxLimit:    r["max-limit"],
			BurstLimit:  r["burst-limit"],
			BurstThresh: r["burst-threshold"],
			BurstTime:   r["burst-time"],
			RateLimit:   r["rate-limit"],
			QueueType:   r["queue"],
			Parent:      r["parent"],
			BytesIn:     parseInt64(r["bytes"]),
			BytesOut:    parseInt64(r["bytes-out"]),
			PacketsIn:   parseInt64(r["packets"]),
			QueuedBytes: parseInt64(r["queued-bytes"]),
			Disabled:    r["disabled"] == "true",
		}
		queues = append(queues, q)
	}
	return queues, nil
}

func (c *Client) GetFirewallFilterRules() ([]FirewallRule, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command("/ip/firewall/filter/print")
	if err != nil {
		return nil, err
	}

	var rules []FirewallRule
	for _, r := range results {
		rule := FirewallRule{
			ID:        r[".id"],
			Chain:     r["chain"],
			Action:    r["action"],
			Protocol:  r["protocol"],
			SrcAddr:   r["src-address"],
			DstAddr:   r["dst-address"],
			SrcPort:   r["src-port"],
			DstPort:   r["dst-port"],
			InInterf:  r["in-interface"],
			OutInterf: r["out-interface"],
			Layer7:    r["layer7-protocol"],
			Content:   r["content"],
			Comment:   r["comment"],
			Disabled:  r["disabled"] == "true",
			Bytes:     parseInt64(r["bytes"]),
			Packets:   parseInt64(r["packets"]),
		}
		rules = append(rules, rule)
	}
	return rules, nil
}

func (c *Client) GetFirewallAddressLists() ([]AddressList, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command("/ip/firewall/address-list/print")
	if err != nil {
		return nil, err
	}

	var lists []AddressList
	for _, r := range results {
		al := AddressList{
			List:     r["list"],
			Address:  r["address"],
			Timeout:  r["timeout"],
			Comment:  r["comment"],
			Dynamic:  r["dynamic"] == "true",
			Disabled: r["disabled"] == "true",
		}
		lists = append(lists, al)
	}
	return lists, nil
}

func (c *Client) GetDNSStatic() ([]DNSStaticEntry, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command("/ip/dns/static/print")
	if err != nil {
		return nil, err
	}

	var entries []DNSStaticEntry
	for _, r := range results {
		e := DNSStaticEntry{
			Name:     r["name"],
			Address:  r["address"],
			TTL:      r["ttl"],
			MatchSub: r["match-subdomain"],
			Comment:  r["comment"],
			Disabled: r["disabled"] == "true",
		}
		entries = append(entries, e)
	}
	return entries, nil
}

func (c *Client) GetDHCPLeasesFull() ([]EnhancedDevice, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command("/ip/dhcp-server/lease/print")
	if err != nil {
		return nil, err
	}

	var devices []EnhancedDevice
	for _, r := range results {
		d := EnhancedDevice{
			MACAddress:     r["mac-address"],
			IPAddress:      r["address"],
			Hostname:       r["host-name"],
			InterfaceName:  r["interface"],
			ConnectionType: "LAN",
			IsActive:       r["status"] == "bound",
			Source:         "dhcp",
			DHCPStatus:     r["status"],
			LeaseExpiry:    r["expires-after"],
			Comment:        r["comment"],
			Blocked:        r["blocked"] == "true",
			Disabled:       r["disabled"] == "true",
			TxBytes:        parseInt64(r["tx-bytes"]),
			RxBytes:        parseInt64(r["rx-bytes"]),
			TxPackets:      parseInt64(r["tx-packets"]),
			RxPackets:      parseInt64(r["rx-packets"]),
		}
		if r["address-list"] != "" {
			d.DHCPStatus = "static"
		}
		if d.MACAddress != "" || d.IPAddress != "" {
			devices = append(devices, d)
		}
	}
	return devices, nil
}

func (c *Client) GetAllDevicesEnhanced() ([]EnhancedDevice, error) {
	seen := make(map[string]EnhancedDevice)
	sources := []struct {
		name string
		fn   func() ([]EnhancedDevice, error)
	}{
		{"dhcp", c.GetDHCPLeasesFull},
		{"hotspot", c.GetHotspotHostsEnhanced},
		{"arp", c.GetARPEnhanced},
		{"wireless", c.GetWiFiRegistrationTable},
		{"bridge", c.GetBridgeHostsEnhanced},
	}

	var sourceErrors []string
	successfulSources := 0
	for _, src := range sources {
		devices, err := src.fn()
		if err != nil {
			sourceErrors = append(sourceErrors, fmt.Sprintf("%s: %v", src.name, err))
			continue
		}
		successfulSources++
		for _, d := range devices {
			mergeEnhancedDevice(seen, d, src.name)
		}
	}
	if successfulSources == 0 {
		return nil, fmt.Errorf("all RouterOS device sources failed: %s", strings.Join(sourceErrors, "; "))
	}

	result := make([]EnhancedDevice, 0, len(seen))
	for _, d := range seen {
		result = append(result, d)
	}
	return result, nil
}

func mergeEnhancedDevice(seen map[string]EnhancedDevice, d EnhancedDevice, source string) {
	d.Source = source
	d.MACAddress = strings.ToUpper(strings.TrimSpace(d.MACAddress))
	key := d.MACAddress
	if key == "" {
		for existingKey, existing := range seen {
			if d.IPAddress != "" && existing.IPAddress == d.IPAddress {
				key = existingKey
				break
			}
		}
		if key == "" {
			key = d.IPAddress
		}
	} else if _, exists := seen[key]; !exists && d.IPAddress != "" {
		if existing, ok := seen[d.IPAddress]; ok && existing.MACAddress == "" {
			delete(seen, d.IPAddress)
			existing.MACAddress = d.MACAddress
			seen[key] = existing
		}
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
	if existing.MACAddress == "" && d.MACAddress != "" {
		existing.MACAddress = d.MACAddress
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
	if d.SSID != "" {
		existing.SSID = d.SSID
	}
	if d.BSSID != "" {
		existing.BSSID = d.BSSID
	}
	if d.SignalStrength != 0 {
		existing.SignalStrength = d.SignalStrength
	}
	if d.TxRateMbps > 0 {
		existing.TxRateMbps = d.TxRateMbps
	}
	if d.RxRateMbps > 0 {
		existing.RxRateMbps = d.RxRateMbps
	}
	if d.TxBytes > 0 {
		existing.TxBytes = d.TxBytes
	}
	if d.RxBytes > 0 {
		existing.RxBytes = d.RxBytes
	}
	if d.ConnectionType == "WiFi" {
		existing.ConnectionType = "WiFi"
		if d.InterfaceName != "" {
			existing.InterfaceName = d.InterfaceName
		}
	}
	if d.IsActive {
		existing.IsActive = true
	}
	seen[key] = existing
}

func (c *Client) RouterOSCommand(cmd string) ([]map[string]string, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	return conn.Command(cmd)
}

func (c *Client) ExecuteCommand(cmd string, args map[string]string) ([]map[string]string, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	attrs := make([]string, 0, len(args))
	for k, v := range args {
		attrs = append(attrs, fmt.Sprintf("=%s=%s", k, v))
	}
	sort.Strings(attrs)
	return conn.Command(cmd, attrs...)
}

func (c *Client) AddFirewallAddressList(listName, address, comment string) error {
	_, err := c.ExecuteCommand("/ip/firewall/address-list/add", map[string]string{
		"list":    listName,
		"address": address,
		"comment": comment,
	})
	return err
}

func (c *Client) RemoveFirewallAddressList(id string) error {
	_, err := c.ExecuteCommand("/ip/firewall/address-list/remove", map[string]string{
		".id": id,
	})
	return err
}

func (c *Client) AddSimpleQueue(name, target, maxLimit, comment string) error {
	_, err := c.ExecuteCommand("/queue/simple/add", map[string]string{
		"name":      name,
		"target":    target,
		"max-limit": maxLimit,
		"comment":   comment,
	})
	return err
}

func (c *Client) RemoveSimpleQueue(name string) error {
	_, err := c.ExecuteCommand("/queue/simple/remove", map[string]string{
		"name": name,
	})
	return err
}

func (c *Client) SetSimpleQueue(name, maxLimit string) error {
	_, err := c.ExecuteCommand("/queue/simple/set", map[string]string{
		"name":      name,
		"max-limit": maxLimit,
	})
	return err
}

func (c *Client) EnableInterface(name string) error {
	_, err := c.ExecuteCommand("/interface/enable", map[string]string{
		"numbers": name,
	})
	return err
}

func (c *Client) DisableInterface(name string) error {
	_, err := c.ExecuteCommand("/interface/disable", map[string]string{
		"numbers": name,
	})
	return err
}

func (c *Client) AddDHCPLease(macAddr, address, hostname, comment string) error {
	_, err := c.ExecuteCommand("/ip/dhcp-server/lease/add", map[string]string{
		"mac-address": macAddr,
		"address":     address,
		"host-name":   hostname,
		"comment":     comment,
	})
	return err
}

func (c *Client) RemoveDHCPLease(id string) error {
	_, err := c.ExecuteCommand("/ip/dhcp-server/lease/remove", map[string]string{
		".id": id,
	})
	return err
}

func (c *Client) queryEnhanced(cmd string) ([]EnhancedDevice, error) {
	conn, err := c.connect()
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	results, err := conn.Command(cmd)
	if err != nil {
		return nil, err
	}

	var devices []EnhancedDevice
	for _, r := range results {
		d := EnhancedDevice{
			MACAddress:     r["mac-address"],
			IPAddress:      r["address"],
			Hostname:       r["host-name"],
			InterfaceName:  firstNonEmpty(r["interface"], r["on-interface"]),
			ConnectionType: "LAN",
			IsActive:       true,
			TxBytes:        parseInt64(r["tx-bytes"]),
			RxBytes:        parseInt64(r["rx-bytes"]),
			TxPackets:      parseInt64(r["tx-packets"]),
			RxPackets:      parseInt64(r["rx-packets"]),
		}
		if comment, ok := r["comment"]; ok {
			d.Vendor = comment
			d.Comment = comment
		}
		if name, ok := r["name"]; ok && d.Hostname == "" {
			d.Hostname = name
		}
		if d.MACAddress != "" || d.IPAddress != "" {
			devices = append(devices, d)
		}
	}
	return devices, nil
}

func parseInt(s string) int {
	var v int
	fmt.Sscanf(s, "%d", &v)
	return v
}

func parseInt64(s string) int64 {
	var v int64
	fmt.Sscanf(s, "%d", &v)
	return v
}

func parseFloat(s string) float64 {
	var v float64
	fmt.Sscanf(s, "%f", &v)
	return v
}
