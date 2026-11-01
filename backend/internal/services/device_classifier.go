package services

import (
	"regexp"
	"strings"
)

// Device kinds the inventory can tell apart.
const (
	KindPhone    = "phone"
	KindTablet   = "tablet"
	KindComputer = "computer"
	KindPrinter  = "printer"
	KindCamera   = "camera"
	KindTV       = "tv"
	KindNetwork  = "network"
	KindServer   = "server"
	KindIoT      = "iot"
	KindMedical  = "medical"
	KindUnknown  = "unknown"
)

// Confidence of a classification.
const (
	ConfidenceHigh   = "high"
	ConfidenceMedium = "medium"
	ConfidenceLow    = "low"
	ConfidenceNone   = "none"
)

// DeviceGuess is what could be inferred about a device from what the router
// knows about it. Reason says which evidence the guess rests on, so the UI can
// show it and the user can correct a wrong guess.
type DeviceGuess struct {
	Kind  string `json:"kind"`
	Brand string `json:"brand,omitempty"`
	// Vendor is the company the MAC address block is registered to.
	Vendor     string `json:"vendor,omitempty"`
	Confidence string `json:"confidence"`
	Reason     string `json:"reason"`
}

type classRule struct {
	kind  string
	brand string
	// match is tested against the lower-cased host name.
	match *regexp.Regexp
	conf  string
}

func rule(kind, brand, pattern, conf string) classRule {
	return classRule{kind: kind, brand: brand, match: regexp.MustCompile(pattern), conf: conf}
}

// Rules are tried in order; the first match wins, so specific rules come first
// (a "galaxy-tab" is a tablet before "galaxy" makes it a phone).
var classRules = []classRule{
	// Medical equipment first: a hospital's own names must not be mistaken for PCs.
	rule(KindMedical, "", `\b(ecg|ekg|mri|xray|x-ray|ultrasound|ventilator|infusion|defib|spo2|incubator|dialysis|patient[-_ ]?monitor)\b|^(ecg|ekg|mri|us)[-_]`, ConfidenceMedium),

	rule(KindPrinter, "HP", `^npi[0-9a-f]{6}|hp.?(laserjet|officejet|deskjet|envy|photosmart|color|mfp)|^hp[0-9a-f]{6}$`, ConfidenceHigh),
	rule(KindPrinter, "Brother", `^brn[0-9a-f]{6,}|^brw[0-9a-f]{6,}|brother`, ConfidenceHigh),
	rule(KindPrinter, "Epson", `epson|^epson[0-9a-f]+`, ConfidenceHigh),
	rule(KindPrinter, "Canon", `canon|^cnpz|^canon[0-9a-f]+`, ConfidenceHigh),
	rule(KindPrinter, "Ricoh", `ricoh|^sp[ -]?c?\d{3}`, ConfidenceHigh),
	rule(KindPrinter, "Xerox", `xerox`, ConfidenceHigh),
	rule(KindPrinter, "Kyocera", `kyocera|ecosys`, ConfidenceHigh),
	rule(KindPrinter, "Lexmark", `lexmark`, ConfidenceHigh),
	rule(KindPrinter, "", `printer|scanner|laserjet|plotter|^prn[-_]`, ConfidenceHigh),

	rule(KindCamera, "Hikvision", `hikvision|^ds-2cd|^ds-7`, ConfidenceHigh),
	rule(KindCamera, "Dahua", `dahua|^ipc-hdw|^dh-`, ConfidenceHigh),
	rule(KindCamera, "", `\b(ip)?cam(era)?\b|^cam[-_]?\d|^ipc\b|^nvr|^dvr`, ConfidenceMedium),

	rule(KindTV, "Samsung", `\[tv\]|^samsung.*(tv|smart)|tizen`, ConfidenceHigh),
	rule(KindTV, "LG", `^lg.*(tv|webos)|webos`, ConfidenceHigh),
	rule(KindTV, "Sony", `bravia`, ConfidenceHigh),
	rule(KindTV, "", `smart.?tv|androidtv|android-tv|chromecast|roku|firetv|fire-tv|apple-?tv|nvidia-?shield|\btv\b`, ConfidenceMedium),

	rule(KindNetwork, "MikroTik", `mikrotik`, ConfidenceHigh),
	rule(KindNetwork, "TP-Link", `tp-?link|^archer|^deco`, ConfidenceHigh),
	rule(KindNetwork, "Ubiquiti", `ubnt|unifi|ubiquiti`, ConfidenceHigh),
	rule(KindNetwork, "Cisco", `cisco|^sw-|^cat\d{4}`, ConfidenceMedium),
	rule(KindNetwork, "", `\b(ap|access.?point|switch|router|gateway|repeater|extender)\b|^ap[-_]\d|^sw[-_]\d`, ConfidenceMedium),

	rule(KindServer, "Synology", `synology|diskstation`, ConfidenceHigh),
	rule(KindServer, "QNAP", `qnap`, ConfidenceHigh),
	rule(KindServer, "", `\bserver\b|^srv[-_]?\d|\bnas\b|esxi|vmware|proxmox|^dc\d|^sql`, ConfidenceMedium),

	rule(KindIoT, "Espressif", `^esp[-_]?(32|8266)?[-_0-9a-f]*$|espressif`, ConfidenceHigh),
	rule(KindIoT, "", `tuya|sonoff|shelly|alexa|echo-|google-home|nest-|ring-|smartplug|^iot`, ConfidenceMedium),

	// Tablets before phones: their names overlap ("galaxy-tab", "sm-t...").
	rule(KindTablet, "Apple", `ipad`, ConfidenceHigh),
	rule(KindTablet, "Samsung", `galaxy-?tab|^sm-?[tx]\d`, ConfidenceHigh),
	rule(KindTablet, "Huawei", `mediapad|matepad`, ConfidenceHigh),
	rule(KindTablet, "Amazon", `kindle|^fire-?tablet|^amazon-?fire`, ConfidenceHigh),
	rule(KindTablet, "", `tablet|\btab\b|^tab-?[a-z0-9]`, ConfidenceMedium),

	rule(KindPhone, "Apple", `iphone`, ConfidenceHigh),
	rule(KindPhone, "Samsung", `galaxy|^sm-?[agmnsfj]\d|samsung`, ConfidenceHigh),
	rule(KindPhone, "OPPO", `oppo|^cph\d{4}|reno\d`, ConfidenceHigh),
	rule(KindPhone, "Xiaomi", `redmi|xiaomi|^poco|^mi[-_ ]?\d|^mi-|^m\d{4}[a-z]\d`, ConfidenceHigh),
	rule(KindPhone, "realme", `realme|^rmx\d{4}`, ConfidenceHigh),
	rule(KindPhone, "vivo", `\bvivo\b|^v\d{4}[a-z]?$|^vivo-|^y\d{2}[a-z]?$`, ConfidenceHigh),
	rule(KindPhone, "Huawei", `huawei|^honor|^hw-|nova-?\d|^y\d{1}[a-z]?-`, ConfidenceHigh),
	rule(KindPhone, "Tecno", `tecno|^tecno-`, ConfidenceHigh),
	rule(KindPhone, "Infinix", `infinix`, ConfidenceHigh),
	rule(KindPhone, "itel", `^itel`, ConfidenceHigh),
	rule(KindPhone, "OnePlus", `oneplus|^one[-_]?plus`, ConfidenceHigh),
	rule(KindPhone, "Google", `pixel`, ConfidenceHigh),
	rule(KindPhone, "Nokia", `nokia`, ConfidenceHigh),
	rule(KindPhone, "Motorola", `^moto[-_ ]|motorola`, ConfidenceHigh),
	// Android's stock DHCP name is "android-" plus 16 hex digits.
	rule(KindPhone, "Android", `^android-?[0-9a-f]{8,}$`, ConfidenceMedium),
	rule(KindPhone, "", `\bphone\b|\bmobile\b`, ConfidenceMedium),

	rule(KindComputer, "Apple", `macbook|imac|mac-?mini|^mbp|-mbp|mac-?pro|^mac[-_]`, ConfidenceHigh),
	rule(KindComputer, "Microsoft", `^desktop-[a-z0-9]{5,}|^laptop-[a-z0-9]{5,}|^win-[a-z0-9]{5,}|^surface`, ConfidenceHigh),
	rule(KindComputer, "Dell", `^dell|latitude|optiplex|inspiron|precision`, ConfidenceHigh),
	rule(KindComputer, "Lenovo", `thinkpad|thinkcentre|ideapad|^lenovo`, ConfidenceHigh),
	rule(KindComputer, "HP", `elitebook|probook|pavilion|^hp-?(pc|laptop|desktop)|^hp[-_ ]?\w*(g\d)$`, ConfidenceHigh),
	rule(KindComputer, "Asus", `^asus|vivobook|zenbook|^rog-`, ConfidenceHigh),
	rule(KindComputer, "Acer", `^acer|aspire|^swift-`, ConfidenceHigh),
	rule(KindComputer, "", `^pc[-_]?\d|\bpc\b|^comp[-_]?\d|computer|workstation|laptop|desktop|notebook|ubuntu|debian|linux|^win\d|^ws[-_]?\d|^reception|^pharmacy|^lab[-_]`, ConfidenceMedium),
}

var privateMACReason = "uses a private (randomized) Wi-Fi address, which modern phones, tablets and laptops do"

// Samsung's A/S-series names ("A30s-alkhas-b-Amany", "Tona-s-A17", "S23-Ultra").
var samsungSeries = regexp.MustCompile(`(^|-)(a\d{2}s?|s(1\d|2\d)(e|\+|-ultra|-plus|-fe)?)($|-)`)

// Names that hospital IT gives workstations: after a department or a room.
var departmentName = regexp.MustCompile(`emergency|\bemr\b|^emr[-_]|\bhr\b|physio|maintenance|clinic|clinc|pharm|\bacc\b|^acc[-_]|accounting|in-?patient|\bped\b|^ped[-_]|^rec\d*$|reception|\blab\b|radiolog|dental|surgery|\bicu\b|nurs|kitchen|^store|admin|\bward\b|\bopd\b|cashier|billing|insurance|^dr[-_]`)

// commentRules read the comment someone wrote on the router (often Arabic).
// It is deliberate human evidence, so it counts as medium confidence.
var commentRules = []classRule{
	rule(KindMedical, "", "اشعة|أشعة|اشعه|سونار|منظار|رسم قلب|اكسجين|أكسجين|ecg|x-?ray|mri|ultrasound", ConfidenceMedium),
	rule(KindPrinter, "", "طابع|برنتر|برينتر|printer", ConfidenceMedium),
	rule(KindCamera, "", "كاميرا|كاميره|camera", ConfidenceMedium),
	rule(KindTablet, "", "تابلت|ايباد|tablet|ipad", ConfidenceMedium),
	rule(KindPhone, "", "موبايل|تليفون|هاتف|mobile|phone", ConfidenceMedium),
	rule(KindTV, "", "شاشة عرض|تلفزيون|\btv\b", ConfidenceMedium),
	rule(KindNetwork, "", "راوتر|اكسس|اكسيس|سويتش|router|switch|access ?point", ConfidenceMedium),
	rule(KindServer, "", "سيرفر|server", ConfidenceMedium),
	rule(KindComputer, "", "كمبيوتر|كمبيوتر|كومبيوتر|لابتوب|لاب توب|\bpc\b|computer|laptop|desktop", ConfidenceMedium),
}

// cleanHostname drops names that were damaged on the way (an Arabic name typed
// on a device and flattened to "?" or replacement characters tells nothing).
func cleanHostname(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return ""
	}
	bad, total := 0, 0
	for _, r := range name {
		total++
		if r == '?' || r == '�' {
			bad++
		}
	}
	if bad*3 >= total {
		return ""
	}
	return name
}

// ClassifyDevice guesses what a device is from its DHCP host name, the comment
// on the router, the company behind its MAC address, and whether that address
// is randomized. It never invents certainty: a device with no usable evidence
// stays "unknown" instead of being labelled as a likely PC.
func ClassifyDevice(hostname, mac, comment string) DeviceGuess {
	guess := classifyEvidence(hostname, mac, comment)
	guess.Vendor = LookupVendor(mac)
	if guess.Brand == "" && guess.Vendor != "" {
		guess.Brand = ShortVendor(guess.Vendor)
	}
	return guess
}

func classifyEvidence(hostname, mac, comment string) DeviceGuess {
	hostname = cleanHostname(hostname)
	name := strings.ToLower(hostname)
	private := IsPrivateMAC(mac)

	if name != "" {
		for _, r := range classRules {
			if r.match.MatchString(name) {
				return DeviceGuess{Kind: r.kind, Brand: r.brand, Confidence: r.conf, Reason: "host name \"" + hostname + "\""}
			}
		}
		if samsungSeries.MatchString(name) {
			return DeviceGuess{Kind: KindPhone, Brand: "Samsung", Confidence: ConfidenceMedium, Reason: "host name \"" + hostname + "\" looks like a Samsung Galaxy A/S model"}
		}
	}
	if text := strings.ToLower(strings.TrimSpace(comment)); text != "" {
		for _, r := range commentRules {
			if r.match.MatchString(text) {
				return DeviceGuess{Kind: r.kind, Confidence: r.conf, Reason: "the comment on the router says so"}
			}
		}
	}
	if g, ok := guessFromVendor(LookupVendor(mac)); ok {
		return g
	}
	if name != "" && departmentName.MatchString(name) {
		return DeviceGuess{Kind: KindComputer, Confidence: ConfidenceLow, Reason: "named after a department or room, as workstations usually are"}
	}
	if private {
		return DeviceGuess{Kind: KindPhone, Confidence: ConfidenceLow, Reason: privateMACReason}
	}
	if name == "" {
		return DeviceGuess{Kind: KindUnknown, Confidence: ConfidenceNone, Reason: "the device does not announce a name"}
	}
	return DeviceGuess{Kind: KindUnknown, Confidence: ConfidenceNone, Reason: "host name \"" + hostname + "\" does not match a known device"}
}

// IsPrivateMAC reports whether the address is locally administered (second-least
// significant bit of the first octet), i.e. randomized rather than assigned by
// a manufacturer.
func IsPrivateMAC(mac string) bool {
	mac = strings.TrimSpace(mac)
	if len(mac) < 2 {
		return false
	}
	var first byte
	for i := 0; i < 2; i++ {
		c := mac[i]
		var v byte
		switch {
		case c >= '0' && c <= '9':
			v = c - '0'
		case c >= 'a' && c <= 'f':
			v = c - 'a' + 10
		case c >= 'A' && c <= 'F':
			v = c - 'A' + 10
		default:
			return false
		}
		first = first<<4 | v
	}
	return first&0x02 != 0
}
