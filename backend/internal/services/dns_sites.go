package services

import (
	"errors"
	"net"
	"net/url"
	"strings"

	"golang.org/x/net/publicsuffix"
)

// Site categories. "background" holds services devices call by themselves
// (updates, telemetry, content delivery); they are hidden unless asked for, since
// a single page view or an idle phone makes dozens of them.
const (
	CategoryInsurance  = "insurance"
	CategoryHealth     = "health"
	CategoryGovernment = "government"
	CategoryBanking    = "banking"
	CategorySocial     = "social"
	CategoryVideo      = "video"
	CategoryMessaging  = "messaging"
	CategorySearch     = "search"
	CategoryEmail      = "email"
	CategoryWork       = "work"
	CategoryCloud      = "cloud"
	CategoryShopping   = "shopping"
	CategoryNews       = "news"
	CategoryAI         = "ai"
	CategoryGames      = "games"
	CategoryBackground = "background"
	CategoryOther      = "other"
)

var siteCategories = []string{
	CategoryInsurance, CategoryHealth, CategoryGovernment, CategoryBanking, CategorySocial, CategoryVideo, CategoryMessaging,
	CategorySearch, CategoryEmail, CategoryWork, CategoryCloud, CategoryShopping, CategoryNews, CategoryAI, CategoryGames,
	CategoryBackground, CategoryOther,
}

// SiteCategories lists the categories a site can be given.
func SiteCategories() []string { return append([]string(nil), siteCategories...) }

func validCategory(c string) bool {
	for _, s := range siteCategories {
		if s == c {
			return true
		}
	}
	return false
}

// SiteDef names a site and the registrable domains that belong to it.
type SiteDef struct {
	Name     string
	Category string
	Domains  []string
}

// builtInSites are well known services, so common names show without any setup.
// Sites that matter to the hospital itself (insurers, ministries, suppliers) are
// not guessed here: they are added by the hospital, with their own logo.
var builtInSites = []SiteDef{
	{"Google", CategorySearch, []string{"google.com", "google.com.eg"}},
	{"Bing", CategorySearch, []string{"bing.com"}},
	{"DuckDuckGo", CategorySearch, []string{"duckduckgo.com"}},
	{"YouTube", CategoryVideo, []string{"youtube.com", "youtu.be", "ytimg.com", "googlevideo.com"}},
	{"Netflix", CategoryVideo, []string{"netflix.com", "nflxvideo.net"}},
	{"Shahid", CategoryVideo, []string{"shahid.net", "mbc.net"}},
	{"Twitch", CategoryVideo, []string{"twitch.tv", "ttvnw.net"}},
	{"Facebook", CategorySocial, []string{"facebook.com", "fbcdn.net", "fb.com", "fbsbx.com"}},
	{"Instagram", CategorySocial, []string{"instagram.com", "cdninstagram.com"}},
	{"TikTok", CategorySocial, []string{"tiktok.com", "tiktokv.com", "tiktokcdn.com", "byteoversea.com", "musical.ly"}},
	{"X (Twitter)", CategorySocial, []string{"twitter.com", "x.com", "twimg.com"}},
	{"Snapchat", CategorySocial, []string{"snapchat.com", "sc-cdn.net"}},
	{"LinkedIn", CategorySocial, []string{"linkedin.com", "licdn.com"}},
	{"Reddit", CategorySocial, []string{"reddit.com", "redd.it", "redditstatic.com", "redditmedia.com"}},
	{"Pinterest", CategorySocial, []string{"pinterest.com", "pinimg.com"}},
	{"WhatsApp", CategoryMessaging, []string{"whatsapp.com", "whatsapp.net", "wa.me"}},
	{"Telegram", CategoryMessaging, []string{"telegram.org", "t.me", "telegram.me"}},
	{"Messenger", CategoryMessaging, []string{"messenger.com"}},
	{"Signal", CategoryMessaging, []string{"signal.org"}},
	{"Discord", CategoryMessaging, []string{"discord.com", "discordapp.com", "discord.gg"}},
	{"Zoom", CategoryWork, []string{"zoom.us", "zoom.com"}},
	{"Gmail", CategoryEmail, []string{"gmail.com"}},
	{"Outlook", CategoryEmail, []string{"outlook.com", "hotmail.com", "live.com"}},
	{"Yahoo", CategoryEmail, []string{"yahoo.com", "ymail.com"}},
	{"Microsoft 365", CategoryWork, []string{"office.com", "office365.com", "microsoftonline.com", "sharepoint.com", "onedrive.com"}},
	{"Google user content", CategoryCloud, []string{"googleusercontent.com"}},
	{"Dropbox", CategoryCloud, []string{"dropbox.com", "dropboxapi.com"}},
	{"iCloud", CategoryCloud, []string{"icloud.com", "icloud-content.com"}},
	{"GitHub", CategoryWork, []string{"github.com", "githubusercontent.com", "githubassets.com"}},
	{"Amazon", CategoryShopping, []string{"amazon.com", "amazon.eg", "media-amazon.com", "ssl-images-amazon.com"}},
	{"AliExpress", CategoryShopping, []string{"aliexpress.com", "alicdn.com", "alibaba.com"}},
	{"Jumia", CategoryShopping, []string{"jumia.com.eg"}},
	{"Noon", CategoryShopping, []string{"noon.com"}},
	{"OLX", CategoryShopping, []string{"olx.com.eg"}},
	{"Wikipedia", CategoryNews, []string{"wikipedia.org", "wikimedia.org"}},
	{"BBC", CategoryNews, []string{"bbc.com", "bbc.co.uk"}},
	{"Al Jazeera", CategoryNews, []string{"aljazeera.net", "aljazeera.com"}},
	{"Youm7", CategoryNews, []string{"youm7.com"}},
	{"ChatGPT", CategoryAI, []string{"openai.com", "chatgpt.com"}},
	{"Claude", CategoryAI, []string{"claude.ai", "anthropic.com"}},
	{"Steam", CategoryGames, []string{"steampowered.com", "steamcommunity.com", "steamstatic.com"}},
	{"Roblox", CategoryGames, []string{"roblox.com", "rbxcdn.com"}},
	{"Epic Games", CategoryGames, []string{"epicgames.com", "unrealengine.com"}},
	{"Google services", CategoryBackground, []string{"googleapis.com", "gstatic.com", "googleadservices.com", "doubleclick.net", "googlesyndication.com", "google-analytics.com", "googletagmanager.com", "gvt1.com", "gvt2.com", "ggpht.com", "app-measurement.com", "firebaseio.com", "crashlytics.com"}},
	{"Microsoft services", CategoryBackground, []string{"microsoft.com", "windows.com", "windowsupdate.com", "msftconnecttest.com", "msftncsi.com", "bing.net", "msn.com", "live.net", "skype.com", "azure.com", "azureedge.net", "trafficmanager.net", "msedge.net", "microsoftonline-p.com", "office.net", "visualstudio.com"}},
	{"Apple services", CategoryBackground, []string{"apple.com", "mzstatic.com", "apple-dns.net", "cdn-apple.com", "icloud.com.cn", "aaplimg.com"}},
	{"Content delivery", CategoryBackground, []string{"akamaiedge.net", "akamai.net", "akadns.net", "akamaihd.net", "cloudfront.net", "cloudflare.com", "cloudflare.net", "fastly.net", "fastlylb.net", "edgekey.net", "edgesuite.net", "llnwd.net", "cdn77.org", "jsdelivr.net", "unpkg.com", "cdnjs.com", "b-cdn.net"}},
	{"Amazon services", CategoryBackground, []string{"amazonaws.com", "amazontrust.com", "awsdns-00.com"}},
	{"Advertising and tracking", CategoryBackground, []string{"adnxs.com", "criteo.com", "taboola.com", "outbrain.com", "scorecardresearch.com", "adsrvr.org", "casalemedia.com", "pubmatic.com", "rubiconproject.com", "moatads.com", "hotjar.com", "mixpanel.com", "segment.io", "branch.io", "appsflyer.com", "adjust.com"}},
	{"Certificates and time", CategoryBackground, []string{"digicert.com", "letsencrypt.org", "sectigo.com", "globalsign.com", "verisign.com", "ntp.org", "usertrust.com", "entrust.net"}},
}

// ignoredSuffixes are names that never leave the network or are not sites.
var ignoredSuffixes = []string{
	".local", ".lan", ".home", ".internal", ".localdomain", ".localhost", ".arpa", ".home.arpa", ".invalid", ".test", ".intranet", ".corp",
}

// registrableDomain reduces a name from a DNS query to the domain a person would
// recognise as the site: "r3---sn-x.googlevideo.com." becomes "googlevideo.com".
// ok is false for names that are not sites: addresses, one-label names and names
// that only exist inside a network.
func registrableDomain(name string) (string, bool) {
	name = strings.ToLower(strings.TrimSuffix(strings.TrimSpace(name), "."))
	if name == "" || len(name) > 253 || !strings.Contains(name, ".") || strings.ContainsAny(name, " /\\:@_") || net.ParseIP(name) != nil {
		return "", false
	}
	for _, s := range ignoredSuffixes {
		if strings.HasSuffix(name, s) || name == strings.TrimPrefix(s, ".") {
			return "", false
		}
	}
	return icannRegistrable(name)
}

// icannRegistrable is the name one label below the public suffix. Only suffixes
// run by registries count (com, co.uk, com.eg): hosting platforms the list also
// holds (cloudfront.net, github.io) do not, so all of a platform's tenants group
// under the platform and its entry in the catalog can name it. A name under a
// top-level domain the list does not know is not treated as a site.
func icannRegistrable(name string) (string, bool) {
	if suffix, icann := publicsuffix.PublicSuffix(name); icann && suffix == name {
		return "", false // a bare suffix such as co.uk
	}
	labels := strings.Split(name, ".")
	for i := 1; i < len(labels); i++ {
		candidate := strings.Join(labels[i:], ".")
		if suffix, icann := publicsuffix.PublicSuffix(candidate); icann && suffix == candidate {
			return labels[i-1] + "." + candidate, true
		}
	}
	return "", false
}

// CleanSiteDomain turns what a person typed (a site name, an address or a pasted
// link) into the registrable domain the recording uses.
func CleanSiteDomain(input string) (string, error) {
	s := strings.TrimSpace(input)
	if s == "" {
		return "", errors.New("empty domain")
	}
	if strings.Contains(s, "://") {
		u, err := url.Parse(s)
		if err != nil || u.Hostname() == "" {
			return "", errors.New("not a valid address: " + input)
		}
		s = u.Hostname()
	}
	if i := strings.IndexAny(s, "/?#"); i >= 0 {
		s = s[:i]
	}
	if host, _, err := net.SplitHostPort(s); err == nil {
		s = host
	}
	s = strings.TrimPrefix(strings.ToLower(s), "www.")
	for _, r := range s {
		if !(r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r == '-' || r == '.') {
			return "", errors.New("use the plain domain, like example.com.eg (letters, digits and dashes): " + input)
		}
	}
	site, ok := registrableDomain(s)
	if !ok {
		return "", errors.New("not a website domain: " + input)
	}
	return site, nil
}
