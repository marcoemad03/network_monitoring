# Operations notes

## Remove the old demo readings

Until the simulator was switched off (`MONITOR_SIMULATE_METRICS=false`, the default now) the monitor stored
random CPU, memory, traffic and speed-test readings for every device. Those tables hold nothing but that
made-up data. Ping results, devices, alerts, groups and the router's own usage are kept elsewhere and are
not touched.

```
cd backend
go run ./cmd/purge_simulated            # dry run: shows how many rows it would delete
go run ./cmd/purge_simulated -confirm   # delete them
```

It refuses to run while `MONITOR_SIMULATE_METRICS` is on, because the monitor would refill the tables at once.
Run it on the machine whose `backend/.env` points at the database you want to clean.

## Refresh the MAC vendor table

`backend/internal/services/oui_manuf.tsv.gz` maps the first bytes of a MAC address to the company the IEEE
registered it to (MA-L, MA-M and MA-S blocks). It is built from Wireshark's `manuf` file, which mirrors the
IEEE registry and changes about once a week:

```
curl -o manuf https://www.wireshark.org/download/automated/data/manuf
cd backend && go run ./cmd/update_oui ../manuf
```

Randomized (private) Wi-Fi addresses belong to no company and never match.

## Websites by name

The Websites page (Security → Websites) lists the sites devices opened, by name and
logo, and which devices opened them. Nothing about this comes from the router: web
traffic is encrypted, so the router only sees addresses. The names come from the DNS
server devices ask for addresses. The NMS counts those lookups; it does not sit in the
path of any traffic, so it cannot slow the network down.

What is stored: the site's domain (`example.com.eg`, not the page), how many times each
device asked for it, per hour. Never page addresses, content or answers. Rows are
deleted after `DNS_RETENTION_DAYS` (30). Opening one device's list of sites, or one
site's list of devices, is written to the audit log.

A lookup is a device asking for a site's address. It shows a site was opened, not for
how long, and a few lookups can come from an app in the background. Only `A` lookups
are counted (a page view makes an `A` and an `AAAA`), and updates, push notifications,
content delivery and ad/tracking domains are put in a "background" category and hidden
unless the switch on the page is on.

### 1. Make the hospital DNS the one devices use

Devices only show up if they ask the hospital's DNS. That needs two things, both on the
network side and both outside the NMS:

- DHCP hands out the DNS server's address
  (`/ip dhcp-server network set [find] dns-server=<dns-server-ip>`). Today the network
  `172.16.0.0/24` gives out no DNS server, and the router's own DNS does not accept
  requests from devices (`allow-remote-requests=no`).
- Devices cannot go around it. DNS-over-TLS uses port 853, DNS-over-HTTPS uses port 443
  to known resolver addresses (dns.google, 1.1.1.1, 9.9.9.9...). Browsers can be told
  not to use it by policy (Chrome `DnsOverHttpsMode=off`, Firefox `network.trr.mode`),
  and the router can refuse the resolver addresses.

**Pi-hole (or another resolver machine) is the recommended resolver.** Making the
RB2011 the resolver for the whole hospital adds the lookups of every device to a
router that already runs at 50-75% CPU, and its DNS cache is already full.

These are router changes on a live network. The NMS does not make them. Try them with
one device or one DHCP lease first and keep a way back (WinBox safe mode).

### 2. Tell the NMS where the lookups come from

In `backend/.env`, then restart the NMS server. Either or both:

```
# Pi-hole: the NMS reads its query log over the API (read only).
PIHOLE_URL=http://<pihole-ip>
PIHOLE_PASSWORD=...          # Pi-hole v6 (web password, or an app password)
# PIHOLE_API_TOKEN=...       # Pi-hole v5 (Settings > API > Show API token) instead of the password
# PIHOLE_INSECURE_TLS=true   # only if PIHOLE_URL is https:// with Pi-hole's self-signed certificate
PIHOLE_POLL_INTERVAL=30s

# Any resolver or the router: it sends its query log to this server with syslog.
DNS_SYSLOG_LISTEN=:5514
# Senders on private addresses are accepted. Add others here (addresses or networks).
# DNS_SYSLOG_ALLOW=203.0.113.7
```

Lines understood on the syslog port:

```
dnsmasq[812]: query[A] www.example.com from 172.16.0.5        (dnsmasq, Pi-hole, OpenWrt)
query from 172.16.0.5: #4711 www.example.com. A                (RouterOS, topic "dns")
```

The page shows each source and the time of its last lookup, or why it fails (for
example "Pi-hole refused the password"). The Pi-hole reader follows the documented v5
and v6 API formats and has been tested against stand-ins of both, not yet against a
real Pi-hole: check the status on the page after the first minute.

If port 5514 on the NMS machine is blocked by Windows Firewall, allow UDP 5514 from the
resolver's address only.

### 3. Give sites names and logos

Open a site on the page and choose **Name this site**, or use **Add a site** at the top:
a name, a category (Insurance is the first in the list) and one or more domains. A pasted
link is cut down to its domain. Several domains can share one name, so an insurer with
`portal.`, `claims.` and a second company domain is one row.

The hospital's insurance companies are not guessed: add each one with its real domain.

Logos are fetched only for sites you add. The NMS server downloads the site's own icon
(touch icon first, then favicon) straight from the site, never through an outside icon
service, so nothing about who visits what leaves the hospital. If a site has no usable
icon, paste the address of an image with **Logo from an image address**. Only public
addresses are fetched (never anything inside the hospital), only PNG/JPEG/GIF/WebP/ICO
up to 256 KB, and the file's bytes are checked, not its name. SVG is refused.

Well known sites (Google, YouTube, Facebook, WhatsApp...) are recognised by name out of
the box; **Add to the catalog with its logo** gives one a logo with a single tap.

## Network map

The Network Map page lists every device the router sees, with its name, type, IP and MAC address, and draws it behind the router port it is connected to. Everything is read; the NMS never writes to the router for the map.

What the server reads, with `print` commands only, at most once a minute (the refresh button allows one read every 15 seconds): `/interface`, `/interface/bridge/port`, `/interface/bridge/host`, `/interface/wireless/registration-table`, `/caps-man/registration-table`, `/ip/neighbor` and `/system/identity`. Tables a router does not have are skipped and listed in the page's notice. The device list itself comes from the client inventory that is already polled (hotspot hosts, DHCP leases, ARP).

How a device gets a port: the bridge host table first, then the Wi-Fi registration table, then the ARP entry, then the port it was last seen on (kept so offline devices keep their place).

**A port is not a place.** When more than 10 devices are behind one port, the port leads to another switch (on the hospital router today, `ether5` carries the whole LAN). The map then keeps the port but does not use it as the device's place. To say where devices are:

- name a router port (tap it on the map), or
- open a device and set its place, or
- in List view, tick several devices and use "Set place".

Places and port names are stored in `client_device_notes.place` and `network_places` (migration `016_network_map.sql`). To get a real room per device automatically, the switch behind `ether5` would have to be read too (its MAC table over SNMP); that is not done yet.

## Reports & Analytics

The page is built from what the NMS already records, so building a report never touches the router: WAN counters (`wan_usage_samples`), per-device daily usage (`client_usage_daily`), `alerts`, `device_events` and the latest security scan.

- `GET /api/v1/reports/usage?from=YYYY-MM-DD&to=YYYY-MM-DD` returns the report (both days included, at most one year, server time zone).
- `GET /api/v1/reports/usage/export?from=&to=&view=devices|daily|hourly|kinds|places` returns a CSV file (UTF-8 with a byte order mark so Excel reads Arabic names; names that start with `=`, `+`, `-` or `@` get a leading `'` so they never run as formulas).
- Measuring only happens while the server runs. Days before measuring started are reported as "not measured", not as zero.
- Device usage is counted from hotspot counters, so it can add up to less than the WAN total; the page shows that share.
- Web, connection and download logs (`web_logs`, `connection_logs`, `download_logs`) have no writer yet, and alert rules (`alert_rules`) are saved but never evaluated. The Reporting hub says so on each card.

## Groups, blocked websites and device controls

A group is a set of devices (by MAC address) with shared rules: internet on/off, speed limit per device, hours, data limits and blocked websites. A device can be in one group. Devices can also be blocked or limited one by one (`marco_device_overrides`), with or without a group.

**How websites are blocked.** The router only sees addresses, so a block by name is a block of the addresses the name points to. Sites are blocked three ways: platforms (YouTube, Facebook... through address ranges or your own router list from `ROUTER_PLATFORM_DST_LISTS`), ready-made packs (games, social, video, music, chat, AI, torrents, VPN sites) and sites typed by hand. The server looks each domain up (every 20 minutes at most, and again about every 30 minutes while groups block sites) and keeps the addresses in a per-group list `nms-marco-site-<group>`. Phone apps and browsers are both covered, because both connect to the same addresses.

- A site hosted on Cloudflare, Fastly or Google frontends cannot be blocked by address without breaking thousands of other sites. The page says so and skips those addresses.
- **Always-allowed sites.** YouTube's API (`youtubei.googleapis.com`) shares addresses with Firebase, Translate and other Google APIs, so blocking those addresses broke them. Every group that blocks by address now gets an `accept` rule, placed above its blocks, for the addresses of the sites in the always-allowed list (built in, editable on the Websites tab). The result: videos stop playing, Gmail, Firebase and Translate keep working. The YouTube app may still open.
- Rule order on the router is kept as: hard blocks (internet off, schedule, blocked device, quota), then the always-allowed accepts, then blocks by destination. The sync moves only its own `nms-marco-` rules to restore this order.

**Removing rules.** `ROUTER_PRUNE_STALE` now defaults to `true`: taking a device out of a group, unblocking a site or deleting a group removes the matching `nms-marco-` entries from the router. Nothing else is touched. A sync that would remove more than `ROUTER_MAX_PRUNE` entries (default 60) is refused, so a reset database cannot clear the router. Set `ROUTER_PRUNE_STALE=false` to go back to add-only.

**Device addresses.** A device added by MAC takes its address from the router's own tables (ARP, DHCP, hotspot). Every 2 minutes the server checks whether a device in a group, or one blocked or limited, got a new address from DHCP and moves the rules to it. This only runs while `ROUTER_POLICY_WRITES=true`.

Limits: `ROUTER_MAX_MANAGED_ENTRIES` defaults to 1000 (blocked-site addresses count). One group blocks at most 150 site addresses and the always-allowed list keeps at most 120.
