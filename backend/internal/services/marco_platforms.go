package services

import "github.com/hospital/nms-backend/internal/models"

// youtubeIPRanges lists address space owned by Google itself. Shared cloud
// ranges (Google Cloud customer blocks such as 35.x, 104.196.0.0/14 or
// 130.211.0.0/16) are deliberately excluded: they host thousands of unrelated
// sites and would break hospital systems for the blocked devices.
var youtubeIPRanges = []string{
	"64.233.160.0/19", "66.249.64.0/19", "72.14.192.0/18", "74.125.0.0/16",
	"108.177.0.0/17", "142.250.0.0/15", "172.217.0.0/16", "172.253.0.0/16",
	"173.194.0.0/16", "209.85.128.0/17", "216.58.192.0/19", "216.239.32.0/19",
}

// MarcoPlatforms is the full catalog of blockable websites exposed to the UI.
//
// Enforcement uses per-group firewall rules keyed on address-lists (IP ranges),
// so each Marco group is blocked independently of the others. Platforms with an
// empty IPRanges list (AI assistants, whose addresses sit on shared CDNs) can
// only be enforced through layer7 matching, which is off unless
// ROUTER_ENABLE_LAYER7=true; the sync reports them as warnings otherwise.
// Ranges that belong to shared CDNs/clouds (Cloudflare, Fastly, AWS, GCP) are
// not listed on purpose.
var MarcoPlatforms = []models.PlatformDefinition{
	{
		Key:   "youtube",
		Label: "YouTube",
		Domains: []string{"youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be",
			"googlevideo.com", "ytimg.com", "youtubei.googleapis.com", "youtube-nocookie.com",
			"youtube.googleapis.com", "yt3.ggpht.com"},
		// No IPRanges on purpose: YouTube shares Google frontends with Gmail and
		// Search, so an address list of Google ranges blocks them too. tls-host
		// matching was tried and does not match modern browsers on RouterOS 6.
		// It is blocked by name in DNS instead, see dnsBlockedPlatforms.
	},
	{
		Key:      "facebook",
		Label:    "Facebook",
		Domains:  []string{"facebook.com", "fbcdn.net", "fb.com", "fb.gg", "messenger.com", "facebook.net", "fbwat.ch", "facebookwatch.com"},
		IPRanges: []string{"31.13.24.0/21", "31.13.64.0/18", "157.240.0.0/16", "69.171.224.0/19", "66.220.144.0/20", "179.60.192.0/22", "204.15.20.0/22", "173.252.64.0/18", "185.60.216.0/22", "45.64.40.0/22", "199.201.64.0/22", "69.63.176.0/20", "69.171.192.0/18"},
	},
	{
		Key:      "instagram",
		Label:    "Instagram",
		Domains:  []string{"instagram.com", "cdninstagram.com", "instagr.am", "instagramstatic.com"},
		IPRanges: []string{"31.13.24.0/21", "31.13.64.0/18", "157.240.0.0/16", "69.171.224.0/19", "179.60.192.0/22", "173.252.64.0/18", "185.60.216.0/22", "45.64.40.0/22"},
	},
	{
		Key:      "tiktok",
		Label:    "TikTok",
		Domains:  []string{"tiktok.com", "tiktokcdn.com", "tiktokv.com", "musical.ly", "tiktokcdn-us.com", "tiktok-i18n.com", "byteoversea.com", "ibytedtos.com"},
		IPRanges: []string{"161.117.0.0/16", "170.33.0.0/16", "68.64.0.0/16", "89.31.192.0/18", "99.181.64.0/18", "144.178.0.0/16"},
	},
	{
		Key:      "netflix",
		Label:    "Netflix",
		Domains:  []string{"netflix.com", "nflxext.com", "nflximg.com", "nflxvideo.net", "nflxso.net", "nflxsearch.net", "netflixdnstest.com", "nflxviplz.com", "nflxvideo.com", "netflix.net"},
		IPRanges: []string{"69.53.224.0/19", "104.99.128.0/17", "192.173.64.0/18", "198.38.96.0/19", "198.45.48.0/20", "208.25.64.0/18", "209.136.144.0/20", "23.246.0.0/18", "37.77.184.0/21", "45.57.20.0/22", "64.120.128.0/17", "66.117.192.0/20", "76.223.128.0/17", "8.41.4.0/24"},
	},
	{
		Key:      "twitter",
		Label:    "Twitter / X",
		Domains:  []string{"twitter.com", "x.com", "twimg.com", "twttr.com", "t.co", "twitterinc.com", "twitterstream.com"},
		IPRanges: []string{"104.244.42.0/24", "199.59.148.0/22", "199.16.156.0/22", "199.96.56.0/21", "209.128.208.0/20", "202.160.128.0/19", "69.195.160.0/19", "104.244.0.0/18"},
	},
	{
		Key:      "reddit",
		Label:    "Reddit",
		Domains:  []string{"reddit.com", "redd.it", "redditmedia.com", "redditstatic.com", "redditinc.com", "redditmail.com"},
		IPRanges: []string{},
	},
	{
		Key:      "steam",
		Label:    "Steam",
		Domains:  []string{"steampowered.com", "steamgames.com", "steamstatic.com", "steamcommunity.com", "steamusercontent.com", "steamcontent.com", "steammobile.com", "steam-chat.com", "steamcdn-a.akamaihd.net"},
		IPRanges: []string{"208.64.200.0/22", "208.78.164.0/22", "209.197.28.0/22", "146.66.152.0/21", "185.25.180.0/22", "103.10.124.0/22", "185.169.96.0/22"},
	},
	{
		Key:      "epicgames",
		Label:    "Epic Games",
		Domains:  []string{"epicgames.com", "epicgames.dev", "unrealengine.com", "fortnite.com", "fn.gg", "eac-cdn.com", "epicgamescdn.com", "epicgames.net", "launchercontent.epicgames.com"},
		IPRanges: []string{"162.248.16.0/22"},
	},
	{
		Key:      "discord",
		Label:    "Discord",
		Domains:  []string{"discord.com", "discord.gg", "discordapp.com", "discordapp.net", "discord.media", "discordcdn.com", "discord.co", "discordstatus.com", "dis.gd"},
		IPRanges: []string{},
	},
	{
		Key:      "telegram",
		Label:    "Telegram",
		Domains:  []string{"telegram.org", "t.me", "telegram.me", "telegram.dog", "web.telegram.org", "telesco.pe", "telegram-cdn.com", "telegram-cdn.org"},
		IPRanges: []string{"91.108.4.0/22", "91.108.8.0/22", "91.108.16.0/22", "91.108.56.0/22", "149.154.160.0/20", "149.154.164.0/22", "149.154.168.0/22", "149.154.172.0/22", "149.154.176.0/20", "149.154.192.0/22", "149.154.196.0/22", "149.154.200.0/21", "149.154.208.0/20"},
	},
	{
		Key:      "whatsappweb",
		Label:    "WhatsApp Web",
		Domains:  []string{"whatsapp.com", "web.whatsapp.com", "wa.me", "whatsapp.net", "whatsapp-cdn.com", "whatsappmedia.com", "whatsappdns.com"},
		IPRanges: []string{"157.240.0.0/16", "185.60.216.0/22", "31.13.24.0/21", "45.64.40.0/22", "66.220.144.0/20", "69.171.224.0/19"},
	},
	{
		Key:      "chatgpt",
		Label:    "ChatGPT",
		Domains:  []string{"chatgpt.com", "openai.com", "chat.openai.com", "oaistatic.com", "oaiusercontent.com", "chatgptcdn.com", "openaiusercontent.com", "openai.org", "cdn.openai.com", "auth.openai.com", "api.openai.com", "sora.com", "sora.chatgpt.com"},
		IPRanges: []string{},
	},
	{
		Key:      "gemini",
		Label:    "Gemini",
		Domains:  []string{"gemini.google.com", "bard.google.com", "deepmind.google", "aistudio.google.com", "ai.google.dev", "makersuite.google.com", "gemini.google.dev"},
		IPRanges: []string{},
	},
	{
		Key:      "claude",
		Label:    "Claude",
		Domains:  []string{"claude.ai", "anthropic.com", "claudeusercontent.com", "anthropic.net", "claude.app", "console.anthropic.com"},
		IPRanges: []string{},
	},
	{
		Key:      "copilot",
		Label:    "Microsoft Copilot",
		Domains:  []string{"copilot.microsoft.com", "githubcopilot.com", "microsoftcopilot.com", "copilot.com"},
		IPRanges: []string{},
	},
}

// dnsBlockedPlatforms are blocked by dropping the group's DNS questions that contain
// these words, in the raw table so it happens before the hotspot redirects DNS. A
// phone that cannot look up a name cannot open the site or the app, whatever it uses
// to connect, and names like mail.google.com are not asked about. It reads only small
// DNS packets from the group's devices, unlike layer7, which reads web traffic.
var dnsBlockedPlatforms = map[string][]string{
	"youtube": {"youtu", "googlevideo", "ytimg"},
	// Meta's address ranges also carry WhatsApp, so these two must not be blocked by address.
	"facebook":  {"facebook", "fbcdn", "fbsbx"},
	"instagram": {"instagram"},
	"tiktok":    {"tiktok", "byteoversea", "ibytedtos", "ibyteimg"},
}

// Public resolvers that answer over HTTPS or TLS, where DNS questions cannot be read.
// The group's devices are kept off these ports so they ask in the open. Phones and
// browsers fall back on their own, unless a phone is set to one private DNS server.
var encryptedDNSServers = []string{
	"8.8.8.8", "8.8.4.4", "1.1.1.1", "1.0.0.1", "9.9.9.9", "149.112.112.112",
	"208.67.222.222", "208.67.220.220", "94.140.14.14", "94.140.15.15",
}

var marcoPlatformByKey = func() map[string]models.PlatformDefinition {
	m := make(map[string]models.PlatformDefinition, len(MarcoPlatforms))
	for _, p := range MarcoPlatforms {
		m[p.Key] = p
	}
	return m
}()
