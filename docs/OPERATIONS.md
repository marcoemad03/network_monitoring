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
