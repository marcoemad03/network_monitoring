package services

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	"golang.org/x/net/html"
)

const (
	maxLogoBytes = 256 << 10
	maxPageBytes = 512 << 10
)

// ErrNotAnImage is returned for an upload or download that is not a usable logo.
var ErrNotAnImage = errors.New("not a PNG, JPEG, GIF, WebP or ICO image of at most 256 KB")

// SniffLogo checks the bytes (not the name or the declared type) and returns the
// image type. SVG is refused: it can carry scripts and the app cannot draw it.
func SniffLogo(data []byte) (string, error) {
	if len(data) == 0 || len(data) > maxLogoBytes {
		return "", ErrNotAnImage
	}
	switch ct := http.DetectContentType(data); ct {
	case "image/png", "image/jpeg", "image/gif", "image/webp", "image/x-icon", "image/vnd.microsoft.icon":
		return ct, nil
	}
	return "", ErrNotAnImage
}

// publicAddress is false for anything inside the hospital or on the machine itself.
// A device can ask for any name, so the server must never be steered into its own
// network by a logo request.
func publicAddress(ip net.IP) bool {
	return ip != nil && !(ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() ||
		ip.IsMulticast() || ip.IsUnspecified() || ip.IsInterfaceLocalMulticast() || isCarrierGradeNAT(ip))
}

func isCarrierGradeNAT(ip net.IP) bool {
	v4 := ip.To4()
	return v4 != nil && v4[0] == 100 && v4[1]&0xC0 == 64
}

func logoHTTPClient() *http.Client {
	dialer := &net.Dialer{
		Timeout: 6 * time.Second,
		// Control runs on the address actually being connected to, after name
		// resolution, so a name that resolves to a private address is refused too.
		Control: func(network, address string, _ syscall.RawConn) error {
			host, _, err := net.SplitHostPort(address)
			if err != nil || !publicAddress(net.ParseIP(host)) {
				return fmt.Errorf("refusing to connect to %s", address)
			}
			return nil
		},
	}
	return &http.Client{
		Timeout: 12 * time.Second,
		Transport: &http.Transport{
			Proxy: nil, DialContext: dialer.DialContext, TLSHandshakeTimeout: 6 * time.Second,
			TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS12}, DisableKeepAlives: true,
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 4 {
				return errors.New("too many redirects")
			}
			if req.URL.Scheme != "https" && req.URL.Scheme != "http" {
				return errors.New("redirect to a non-web address")
			}
			return nil
		},
	}
}

type iconCandidate struct {
	href  string
	score int
}

// iconCandidates lists the icons a page declares, best first. A touch icon is
// larger and cleaner than a favicon, so it is preferred.
func iconCandidates(page []byte, base *url.URL) []string {
	var found []iconCandidate
	z := html.NewTokenizer(strings.NewReader(string(page)))
	for {
		tt := z.Next()
		if tt == html.ErrorToken {
			break
		}
		if tt != html.StartTagToken && tt != html.SelfClosingTagToken {
			continue
		}
		tok := z.Token()
		if tok.Data == "body" {
			break
		}
		if tok.Data != "link" {
			continue
		}
		var rel, href, sizes string
		for _, a := range tok.Attr {
			switch a.Key {
			case "rel":
				rel = strings.ToLower(a.Val)
			case "href":
				href = strings.TrimSpace(a.Val)
			case "sizes":
				sizes = strings.ToLower(a.Val)
			}
		}
		if href == "" || !strings.Contains(rel, "icon") {
			continue
		}
		ref, err := base.Parse(href)
		if err != nil || (ref.Scheme != "https" && ref.Scheme != "http") {
			continue
		}
		score := 10
		if strings.Contains(rel, "apple-touch-icon") {
			score += 200
		}
		if w, _, ok := strings.Cut(sizes, "x"); ok {
			if n, err := strconv.Atoi(w); err == nil && n <= 512 {
				score += n / 4
			}
		}
		if strings.HasSuffix(strings.ToLower(ref.Path), ".svg") {
			score = -1
		}
		if score > 0 {
			found = append(found, iconCandidate{href: ref.String(), score: score})
		}
	}
	sort.SliceStable(found, func(i, j int) bool { return found[i].score > found[j].score })
	out := make([]string, 0, len(found)+1)
	for _, f := range found {
		out = append(out, f.href)
	}
	return append(out, base.ResolveReference(&url.URL{Path: "/favicon.ico"}).String())
}

func fetchBytes(ctx context.Context, client *http.Client, u string, limit int64) ([]byte, *url.URL, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return nil, nil, err
	}
	req.Header.Set("User-Agent", "HospitalNMS-LogoFetcher/1.0")
	req.Header.Set("Accept", "text/html,image/*;q=0.8")
	resp, err := client.Do(req)
	if err != nil {
		return nil, nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	data, err := io.ReadAll(io.LimitReader(resp.Body, limit+1))
	if err != nil {
		return nil, nil, err
	}
	if int64(len(data)) > limit {
		return nil, nil, errors.New("too large")
	}
	return data, resp.Request.URL, nil
}

// FetchSiteLogo downloads a site's own icon from the site itself. Only the sites
// the hospital has added to its catalog are fetched, on request, and never through
// a third-party icon service, so nothing about who visits what leaves the hospital.
func FetchSiteLogo(ctx context.Context, domain string) (image []byte, contentType, source string, err error) {
	return fetchSiteLogo(ctx, logoHTTPClient(), domain)
}

func fetchSiteLogo(ctx context.Context, client *http.Client, domain string) ([]byte, string, string, error) {
	var lastErr error = errors.New("the site could not be reached")
	for _, host := range []string{domain, "www." + domain} {
		page, finalURL, err := fetchBytes(ctx, client, "https://"+host+"/", maxPageBytes)
		if err != nil {
			lastErr = err
			continue
		}
		for _, candidate := range iconCandidates(page, finalURL) {
			data, _, err := fetchBytes(ctx, client, candidate, maxLogoBytes)
			if err != nil {
				lastErr = err
				continue
			}
			if ct, err := SniffLogo(data); err == nil {
				return data, ct, candidate, nil
			}
		}
		lastErr = errors.New("the site does not publish a usable icon")
	}
	return nil, "", "", lastErr
}

// FetchLogoImage downloads an image from an address a person pasted, for sites
// whose own icon is missing or poor. The same limits apply: public addresses only,
// small images only, and the bytes are checked, not the name.
func FetchLogoImage(ctx context.Context, rawURL string) (image []byte, contentType string, err error) {
	return fetchLogoImage(ctx, logoHTTPClient(), rawURL)
}

func fetchLogoImage(ctx context.Context, client *http.Client, rawURL string) ([]byte, string, error) {
	u, err := url.Parse(strings.TrimSpace(rawURL))
	if err != nil || (u.Scheme != "https" && u.Scheme != "http") || u.Hostname() == "" || u.User != nil {
		return nil, "", errors.New("give the full address of the image, starting with https://")
	}
	data, _, err := fetchBytes(ctx, client, u.String(), maxLogoBytes)
	if err != nil {
		return nil, "", fmt.Errorf("could not download the image: %w", err)
	}
	ct, err := SniffLogo(data)
	return data, ct, err
}
