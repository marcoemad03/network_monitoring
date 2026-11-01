package services

import (
	"bufio"
	"bytes"
	"compress/gzip"
	_ "embed"
	"regexp"
	"strings"
	"sync"
)

// oui_manuf.tsv.gz is the IEEE MAC address registry (MA-L, MA-M and MA-S blocks),
// one "HEXPREFIX<TAB>vendor name" line per block. Rebuild it with
// `go run ./cmd/update_oui <manuf file>`.
//
//go:embed oui_manuf.tsv.gz
var ouiData []byte

var (
	ouiOnce  sync.Once
	ouiTable map[string]string
)

func loadOUI() {
	ouiTable = make(map[string]string, 60000)
	gz, err := gzip.NewReader(bytes.NewReader(ouiData))
	if err != nil {
		return
	}
	defer gz.Close()
	scanner := bufio.NewScanner(gz)
	scanner.Buffer(make([]byte, 1<<16), 1<<20)
	for scanner.Scan() {
		key, name, ok := strings.Cut(scanner.Text(), "\t")
		if ok {
			ouiTable[key] = name
		}
	}
}

// LookupVendor returns the company the IEEE registered the address block to, or
// "" when it is unknown. Randomized (private) addresses belong to no company, so
// they never match. The most specific block wins: 36, then 28, then 24 bits.
func LookupVendor(mac string) string {
	hex := strings.ToUpper(strings.NewReplacer(":", "", "-", "", ".", "").Replace(strings.TrimSpace(mac)))
	if len(hex) < 6 || IsPrivateMAC(mac) {
		return ""
	}
	ouiOnce.Do(loadOUI)
	for _, n := range []int{9, 7, 6} {
		if len(hex) >= n {
			if name, ok := ouiTable[hex[:n]]; ok {
				return name
			}
		}
	}
	return ""
}

var vendorSuffix = regexp.MustCompile(`(?i)[,.\s]+(co\.?,?\s*ltd\.?|corporation|corp\.?|incorporated|inc\.?|limited|ltd\.?|gmbh|llc|s\.?a\.?|b\.?v\.?|ag|plc|pte\.?|company|co\.?)\s*$`)

// ShortVendor trims legal suffixes so a name fits a table cell:
// "Apple, Inc." becomes "Apple", "Hon Hai Precision Ind. Co.,Ltd." becomes "Hon Hai Precision Ind.".
func ShortVendor(name string) string {
	name = strings.TrimSpace(name)
	for i := 0; i < 3; i++ {
		trimmed := strings.TrimSpace(vendorSuffix.ReplaceAllString(name, ""))
		if trimmed == name || trimmed == "" {
			break
		}
		name = trimmed
	}
	return strings.TrimRight(name, " ,")
}

type vendorRule struct {
	kind  string
	conf  string
	match *regexp.Regexp
	// note explains the guess when the vendor makes more than one kind of device.
	note string
}

func vrule(kind, conf, pattern, note string) vendorRule {
	return vendorRule{kind: kind, conf: conf, match: regexp.MustCompile(pattern), note: note}
}

// vendorRules guess a kind from who made the network card. Vendors that make
// many kinds of device are marked low confidence and say so.
var vendorRules = []vendorRule{
	vrule(KindPrinter, ConfidenceMedium, `canon|epson|brother industries|ricoh|xerox|kyocera|lexmark|konica minolta|oki data|toshiba tec|zebra tech`, "makes printers"),
	vrule(KindCamera, ConfidenceMedium, `hikvision|dahua|axis communications|vivotek|reolink|uniview|hanwha|geovision`, "makes cameras"),
	vrule(KindNetwork, ConfidenceMedium, `cisco|tp-?link|ubiquiti|routerboard|mikrotik|netgear|d-link|zyxel|aruba|ruckus|juniper|fortinet|mercusys|tenda|linksys|edimax|engenius|extreme networks|meraki`, "makes network equipment"),
	vrule(KindServer, ConfidenceMedium, `vmware|xensource|qemu|red hat|synology|qnap|super ?micro`, "a virtual machine or server maker"),
	vrule(KindIoT, ConfidenceMedium, `espressif|tuya|allterco|shelly|itead|sonoff|raspberry pi`, "makes smart or embedded devices"),
	vrule(KindPhone, ConfidenceMedium, `oppo|vivo mobile|\bvivo\b|oneplus|realme|transsion|infinix|tecno|itel mobile|motorola mobility`, "makes phones"),
	vrule(KindPhone, ConfidenceLow, `samsung|xiaomi`, "makes phones, tablets and other devices; most likely a phone"),
	vrule(KindComputer, ConfidenceMedium, `intel corporate|dell|lenovo|acer|micro-star|giga-?byte|lcfc|compal|quanta|pegatron|wistron|azurewave|liteon|lite-on`, "makes computers and their network cards"),
	vrule(KindComputer, ConfidenceLow, `hewlett packard|hp inc|asustek|realtek|toshiba|fujitsu`, "makes computers, but also other devices; most likely a computer"),
}

// guessFromVendor reads the vendor behind a MAC address.
func guessFromVendor(vendor string) (DeviceGuess, bool) {
	name := strings.ToLower(vendor)
	for _, r := range vendorRules {
		if r.match.MatchString(name) {
			short := ShortVendor(vendor)
			return DeviceGuess{Kind: r.kind, Confidence: r.conf, Reason: "its MAC address belongs to " + short + ", which " + r.note}, true
		}
	}
	return DeviceGuess{}, false
}
