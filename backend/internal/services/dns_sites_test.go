package services

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"image"
	"image/color"
	"image/png"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRegistrableDomain(t *testing.T) {
	cases := map[string]string{
		"www.google.com":                   "google.com",
		"r3---sn-abc.googlevideo.com.":     "googlevideo.com",
		"portal.misr-insurance.com.eg":     "misr-insurance.com.eg",
		"a.b.c.example.co.uk":              "example.co.uk",
		"WWW.YouTube.COM":                  "youtube.com",
		"edge-chat.instagram.com":          "instagram.com",
		"someone.github.io":                "github.io", // private suffixes are not boundaries: tenants of one host group together
		"d1234.cloudfront.net":             "cloudfront.net",
		"mail.hospital.gov.eg":             "hospital.gov.eg",
		"xn--mgbaam7a8h.xn--mgberp4a5d4ar": "xn--mgbaam7a8h.xn--mgberp4a5d4ar",
	}
	for in, want := range cases {
		got, ok := registrableDomain(in)
		if !ok || got != want {
			t.Errorf("registrableDomain(%q) = %q, %v; want %q", in, got, ok, want)
		}
	}
	for _, in := range []string{"", "localhost", "printer.local", "nas.lan", "172.16.0.5", "1.0.0.172.in-addr.arpa", "_dmarc.example.com", "com", "co.uk", "a b.com", "host.home.arpa", "::1"} {
		if got, ok := registrableDomain(in); ok {
			t.Errorf("registrableDomain(%q) = %q, want it ignored", in, got)
		}
	}
}

func TestCleanSiteDomain(t *testing.T) {
	good := map[string]string{
		"https://www.Example.com.eg/login?x=1": "example.com.eg",
		"portal.insurer.com.eg":                "insurer.com.eg",
		"  insurer.com.eg:8443/path ":          "insurer.com.eg",
		"www.bupa.com":                         "bupa.com",
	}
	for in, want := range good {
		got, err := CleanSiteDomain(in)
		if err != nil || got != want {
			t.Errorf("CleanSiteDomain(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
	for _, in := range []string{"", "   ", "nothing", "ex ample.com", "http://", "192.168.1.1", "شركة.com", "a/b"} {
		if got, err := CleanSiteDomain(in); err == nil {
			t.Errorf("CleanSiteDomain(%q) = %q, want an error", in, got)
		}
	}
}

func TestBuiltInSitesAreConsistent(t *testing.T) {
	seen := map[string]string{}
	for _, def := range builtInSites {
		if !validCategory(def.Category) {
			t.Errorf("%s has unknown category %q", def.Name, def.Category)
		}
		for _, d := range def.Domains {
			if got, ok := registrableDomain(d); !ok || got != d {
				t.Errorf("%s lists %q, which is not a registrable domain (%q)", def.Name, d, got)
			}
			if other, dup := seen[d]; dup {
				t.Errorf("%q is listed under both %s and %s", d, other, def.Name)
			}
			seen[d] = def.Name
		}
	}
}

func TestParseDNSLogLine(t *testing.T) {
	cases := []struct {
		line string
		want DNSEvent
		ok   bool
	}{
		{"<30>Nov  1 10:00:01 pihole dnsmasq[812]: query[A] www.google.com from 172.16.0.5", DNSEvent{ClientIP: "172.16.0.5", Name: "www.google.com", QType: "A"}, true},
		{"dnsmasq[812]: query[AAAA] graph.facebook.com from 172.16.0.9", DNSEvent{ClientIP: "172.16.0.9", Name: "graph.facebook.com", QType: "AAAA"}, true},
		{"<14>dns,packet: query from 172.16.0.77: #4711 www.youtube.com. A", DNSEvent{ClientIP: "172.16.0.77", Name: "www.youtube.com.", QType: "A"}, true},
		{"dnsmasq[812]: reply www.google.com is 142.250.1.1", DNSEvent{}, false},
		{"dnsmasq[812]: cached www.google.com is 142.250.1.1", DNSEvent{}, false},
		{"system,info: something else", DNSEvent{}, false},
	}
	for _, c := range cases {
		got, ok := parseDNSLogLine(c.line)
		if ok != c.ok || got != c.want {
			t.Errorf("parseDNSLogLine(%q) = %+v, %v; want %+v, %v", c.line, got, ok, c.want, c.ok)
		}
	}
}

func TestSyslogSourceAllowList(t *testing.T) {
	allow := parseAllowList([]string{"203.0.113.7", "198.51.100.0/24", "garbage"})
	for ip, want := range map[string]bool{
		"172.16.0.1": true, "10.1.2.3": true, "127.0.0.1": true, "203.0.113.7": true, "198.51.100.200": true,
		"8.8.8.8": false, "203.0.113.8": false,
	} {
		if got := allowedSyslogSource(net.ParseIP(ip), allow); got != want {
			t.Errorf("allowedSyslogSource(%s) = %v, want %v", ip, got, want)
		}
	}
}

func TestCollectorCountsPerHourDeviceAndSite(t *testing.T) {
	c := NewDNSCollector(nil, nil, 30)
	c.RegisterSource("test", true)
	noon := time.Date(2026, 11, 1, 12, 20, 0, 0, time.UTC)
	for _, ev := range []DNSEvent{
		{Time: noon, ClientIP: "172.16.0.5", Name: "www.google.com", QType: "A"},
		{Time: noon.Add(10 * time.Minute), ClientIP: "172.16.0.5", Name: "mail.google.com.", QType: "A"},
		{Time: noon, ClientIP: "172.16.0.5", Name: "www.google.com", QType: "AAAA"},  // not counted: same visit
		{Time: noon, ClientIP: "172.16.0.5", Name: "www.google.com", QType: "HTTPS"}, // not counted
		{Time: noon, ClientIP: "172.16.0.5", Name: "ads.tracker.net", QType: "A", Blocked: true},
		{Time: noon.Add(time.Hour), ClientIP: "172.16.0.5", Name: "www.google.com", QType: "A"},
		{Time: noon, ClientIP: "172.16.0.6", Name: "www.google.com", QType: ""},
		{Time: noon, ClientIP: "127.0.0.1", Name: "www.google.com", QType: "A"}, // the resolver itself
		{Time: noon, ClientIP: "172.16.0.5", Name: "printer.local", QType: "A"}, // not a site
		{Time: noon, ClientIP: "not-an-ip", Name: "www.google.com", QType: "A"},
	} {
		c.Add("test", ev)
	}
	get := func(hour time.Time, ip, site string) dnsCount {
		if n := c.pending[dnsKey{bucket: hour, ip: ip, site: site}]; n != nil {
			return *n
		}
		return dnsCount{}
	}
	h12, h13 := noon.Truncate(time.Hour), noon.Truncate(time.Hour).Add(time.Hour)
	if got := get(h12, "172.16.0.5", "google.com"); got.queries != 2 {
		t.Errorf("google.com for .5 at 12h = %+v, want 2 queries", got)
	}
	if got := get(h13, "172.16.0.5", "google.com"); got.queries != 1 {
		t.Errorf("google.com for .5 at 13h = %+v, want 1 query", got)
	}
	if got := get(h12, "172.16.0.6", "google.com"); got.queries != 1 {
		t.Errorf("google.com for .6 = %+v, want 1 query", got)
	}
	if got := get(h12, "172.16.0.5", "tracker.net"); got.queries != 1 || got.blocked != 1 {
		t.Errorf("tracker.net = %+v, want 1 query, 1 blocked", got)
	}
	if len(c.pending) != 4 {
		t.Errorf("pending has %d counters, want 4: %v", len(c.pending), c.pending)
	}
	src := c.Sources()
	if len(src) != 1 || src[0].Events != 5 || src[0].LastSeen == nil {
		t.Errorf("source status = %+v, want 5 events", src)
	}
}

func TestCollectorBoundsMemory(t *testing.T) {
	c := NewDNSCollector(nil, nil, 30)
	for i := 0; i < dnsMaxPending+500; i++ {
		c.Add("x", DNSEvent{ClientIP: "172.16.0.5", Name: "h" + strings.Repeat("a", i%50) + string(rune('a'+i%26)) + ".site" + itoa(i) + ".com", QType: "A"})
	}
	if len(c.pending) > dnsMaxPending {
		t.Errorf("pending grew to %d, limit %d", len(c.pending), dnsMaxPending)
	}
	if c.dropped == 0 {
		t.Error("lookups over the limit should be counted as dropped")
	}
}

func itoa(i int) string {
	b, _ := json.Marshal(i)
	return string(b)
}

// ---------------------------------------------------------------------------
// Pi-hole

func TestPiholeV6(t *testing.T) {
	signedIn := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/auth":
			var in map[string]string
			_ = json.NewDecoder(r.Body).Decode(&in)
			if in["password"] != "secret" {
				_, _ = w.Write([]byte(`{"session":{"valid":false,"sid":null}}`))
				return
			}
			signedIn = true
			_, _ = w.Write([]byte(`{"session":{"valid":true,"sid":"abc123","validity":1800}}`))
		case "/api/queries":
			if r.Header.Get("X-FTL-SID") != "abc123" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}
			if r.URL.Query().Get("from") == "" || r.URL.Query().Get("until") == "" {
				t.Error("from and until must be sent")
			}
			_, _ = w.Write([]byte(`{"queries":[
				{"time":1762000000.5,"type":"A","domain":"www.youtube.com","status":"FORWARDED","client":{"ip":"172.16.0.5","name":"x"}},
				{"time":1762000001.1,"type":"A","domain":"ads.doubleclick.net","status":"GRAVITY","client":{"ip":"172.16.0.6","name":null}}
			]}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()

	p := NewPiholeReader(srv.URL, "secret", "", false)
	events, err := p.Queries(context.Background(), time.Unix(1761999000, 0), time.Unix(1762001000, 0))
	if err != nil || !signedIn {
		t.Fatalf("Queries: %v (signed in: %v)", err, signedIn)
	}
	if len(events) != 2 || events[0].ClientIP != "172.16.0.5" || events[0].Name != "www.youtube.com" || events[0].Blocked || !events[1].Blocked {
		t.Fatalf("events = %+v", events)
	}

	wrong := NewPiholeReader(srv.URL, "nope", "", false)
	if _, err := wrong.Queries(context.Background(), time.Now().Add(-time.Minute), time.Now()); err == nil || !strings.Contains(err.Error(), "password") {
		t.Errorf("wrong password error = %v", err)
	}
}

func TestPiholeV6SignsInAgainWhenSessionExpires(t *testing.T) {
	logins := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/auth":
			logins++
			_, _ = w.Write([]byte(`{"session":{"valid":true,"sid":"sid` + itoa(logins) + `"}}`))
		case "/api/queries":
			if r.Header.Get("X-FTL-SID") != "sid2" {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}
			_, _ = w.Write([]byte(`{"queries":[]}`))
		}
	}))
	defer srv.Close()
	p := NewPiholeReader(srv.URL, "secret", "", false)
	if _, err := p.Queries(context.Background(), time.Now().Add(-time.Minute), time.Now()); err != nil || logins != 2 {
		t.Errorf("err = %v, logins = %d, want a second sign-in to fix the session", err, logins)
	}
}

func TestPiholeV5(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/admin/api.php" || r.URL.Query().Get("auth") != "tok" {
			_, _ = w.Write([]byte(`[]`)) // what Pi-hole v5 answers to a wrong token
			return
		}
		_, _ = w.Write([]byte(`{"data":[
			["1762000000","A","www.facebook.com","172.16.0.8","2","N/A","3","10","N/A","-1","8.8.8.8#53","N/A"],
			["1762000002","A","ads.example.com","172.16.0.8","1","N/A","3","10","N/A","-1","N/A","N/A"],
			["short"]
		]}`))
	}))
	defer srv.Close()

	events, err := NewPiholeReader(srv.URL, "", "tok", false).Queries(context.Background(), time.Unix(1761999000, 0), time.Unix(1762001000, 0))
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 2 || events[0].Name != "www.facebook.com" || events[0].Blocked || !events[1].Blocked {
		t.Fatalf("events = %+v", events)
	}
	if _, err := NewPiholeReader(srv.URL, "", "bad", false).Queries(context.Background(), time.Now().Add(-time.Minute), time.Now()); err == nil {
		t.Error("a wrong token should be reported, not read as an empty log")
	}
}

func TestPiholeErrorsDoNotLeakTheToken(t *testing.T) {
	_, err := NewPiholeReader("http://127.0.0.1:1", "", "supersecrettoken", false).Queries(context.Background(), time.Now().Add(-time.Minute), time.Now())
	if err == nil || strings.Contains(err.Error(), "supersecrettoken") {
		t.Errorf("error = %v, must exist and not contain the token", err)
	}
}

// ---------------------------------------------------------------------------
// Logos

func pngBytes(t *testing.T) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 8, 8))
	for x := 0; x < 8; x++ {
		img.Set(x, x, color.RGBA{R: 200, A: 255})
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func icoBytes() []byte {
	// ICONDIR with one 1x1 entry pointing at a tiny BMP payload.
	var b bytes.Buffer
	_ = binary.Write(&b, binary.LittleEndian, []uint16{0, 1, 1})
	b.Write([]byte{1, 1, 0, 0})
	_ = binary.Write(&b, binary.LittleEndian, []uint16{1, 32})
	_ = binary.Write(&b, binary.LittleEndian, []uint32{40, 22})
	b.Write(make([]byte, 40))
	return b.Bytes()
}

func TestSniffLogo(t *testing.T) {
	if ct, err := SniffLogo(pngBytes(t)); err != nil || ct != "image/png" {
		t.Errorf("png: %q, %v", ct, err)
	}
	if ct, err := SniffLogo(icoBytes()); err != nil || !strings.Contains(ct, "icon") {
		t.Errorf("ico: %q, %v", ct, err)
	}
	for name, data := range map[string][]byte{
		"svg":   []byte(`<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>`),
		"html":  []byte(`<html><body>not an image</body></html>`),
		"empty": nil,
		"huge":  append(pngBytes(t), make([]byte, maxLogoBytes)...),
		"text":  []byte("hello"),
	} {
		if _, err := SniffLogo(data); err == nil {
			t.Errorf("%s was accepted as a logo", name)
		}
	}
}

func TestPublicAddress(t *testing.T) {
	for ip, want := range map[string]bool{
		"8.8.8.8": true, "142.250.1.1": true, "2606:4700::1111": true,
		"127.0.0.1": false, "172.16.0.1": false, "10.0.0.5": false, "192.168.1.1": false, "169.254.1.1": false,
		"100.64.0.1": false, "0.0.0.0": false, "::1": false, "fe80::1": false, "224.0.0.1": false,
	} {
		if got := publicAddress(net.ParseIP(ip)); got != want {
			t.Errorf("publicAddress(%s) = %v, want %v", ip, got, want)
		}
	}
}

func TestLogoClientRefusesTheLocalNetwork(t *testing.T) {
	hit := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { hit = true }))
	defer srv.Close()
	client := logoHTTPClient()
	if _, _, err := fetchBytes(context.Background(), client, srv.URL, 1024); err == nil || hit {
		t.Errorf("the logo client reached a loopback server (err = %v, hit = %v)", err, hit)
	}
	// A redirect from a public name to an internal address is refused the same way.
	if _, _, err := fetchBytes(context.Background(), client, "http://169.254.169.254/latest/meta-data", 1024); err == nil {
		t.Error("the cloud metadata address was reachable")
	}
}

func TestIconCandidatesPreferTouchIcons(t *testing.T) {
	page := []byte(`<html><head>
	  <link rel="icon" href="/favicon-16.png" sizes="16x16">
	  <link rel="shortcut icon" href="/old.ico">
	  <link rel="apple-touch-icon" href="/touch.png" sizes="180x180">
	  <link rel="icon" href="/vector.svg">
	  <link rel="stylesheet" href="/style.css">
	  <link rel="icon" href="javascript:alert(1)">
	  </head><body><link rel="icon" href="/late.png"></body></html>`)
	base, _ := http.NewRequest("GET", "https://www.insurer.com.eg/home", nil)
	got := iconCandidates(page, base.URL)
	want := []string{"https://www.insurer.com.eg/touch.png", "https://www.insurer.com.eg/favicon-16.png", "https://www.insurer.com.eg/old.ico", "https://www.insurer.com.eg/favicon.ico"}
	if strings.Join(got, " ") != strings.Join(want, " ") {
		t.Errorf("candidates = %v\nwant       %v", got, want)
	}
}

func TestFetchSiteLogoFollowsThePageAndRejectsNonImages(t *testing.T) {
	logo := pngBytes(t)
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`<html><head><link rel="apple-touch-icon" href="/fake.png"><link rel="icon" href="/real.png"></head></html>`))
	})
	mux.HandleFunc("/fake.png", func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("<html>login required</html>")) })
	mux.HandleFunc("/real.png", func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write(logo) })
	srv := httptest.NewTLSServer(mux)
	defer srv.Close()

	// Point the host name at the test server; the production client also refuses
	// loopback, so this test uses a plain client that trusts the test certificate.
	client := srv.Client()
	client.Transport.(*http.Transport).DialContext = func(ctx context.Context, network, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, network, srv.Listener.Addr().String())
	}
	data, ct, source, err := fetchSiteLogo(context.Background(), client, "example.com")
	if err != nil {
		t.Fatal(err)
	}
	if ct != "image/png" || !bytes.Equal(data, logo) || !strings.HasSuffix(source, "/real.png") {
		t.Errorf("got %s from %s (%d bytes)", ct, source, len(data))
	}
}

func TestFetchSiteLogoReportsAPageWithoutIcon(t *testing.T) {
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/" {
			_, _ = w.Write([]byte(`<html><head></head></html>`))
			return
		}
		http.NotFound(w, r)
	}))
	defer srv.Close()
	client := srv.Client()
	client.Transport.(*http.Transport).DialContext = func(ctx context.Context, network, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, network, srv.Listener.Addr().String())
	}
	if _, _, _, err := fetchSiteLogo(context.Background(), client, "example.com"); err == nil || !strings.Contains(err.Error(), "icon") {
		t.Errorf("err = %v, want a message about the missing icon", err)
	}
}

func TestFetchLogoImageFromAnAddress(t *testing.T) {
	logo := pngBytes(t)
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/logo.png":
			_, _ = w.Write(logo)
		case "/page":
			_, _ = w.Write([]byte("<html>not an image</html>"))
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	client := srv.Client()

	data, ct, err := fetchLogoImage(context.Background(), client, srv.URL+"/logo.png")
	if err != nil || ct != "image/png" || !bytes.Equal(data, logo) {
		t.Fatalf("logo: %d bytes, %q, %v", len(data), ct, err)
	}
	for name, addr := range map[string]string{
		"a page":        srv.URL + "/page",
		"a missing one": srv.URL + "/nope.png",
		"a file path":   "file:///etc/passwd",
		"no scheme":     "example.com/logo.png",
		"credentials":   "https://user:pass@example.com/logo.png",
		"empty":         "  ",
	} {
		if _, _, err := fetchLogoImage(context.Background(), client, addr); err == nil {
			t.Errorf("%s was accepted", name)
		}
	}
	// The real client never reaches the local network, whatever address is pasted.
	if _, _, err := FetchLogoImage(context.Background(), "http://172.16.0.1/logo.png"); err == nil {
		t.Error("an address inside the hospital was fetched")
	}
}
