package services

import (
	"fmt"
	"sort"
	"strings"
)

// groupSiteAddresses lists the addresses to block for the sites a group blocks by
// address. Sites that cannot be blocked safely are reported as warnings, so the
// page can say why instead of silently doing nothing.
func groupSiteAddresses(groupName string, domains, literals []string, opts marcoBuildOptions, allow map[string]bool, d *marcoDesiredState) []string {
	seen := map[string]bool{}
	var out []string
	add := func(a string) {
		if !seen[a] {
			seen[a] = true
			out = append(out, a)
		}
	}
	for _, dom := range domains {
		res, ok := opts.siteIPs[dom]
		switch {
		case !ok:
			d.warnings = append(d.warnings, fmt.Sprintf("%s: %s has not been looked up yet, it will be blocked after the next sync", groupName, dom))
			continue
		case !res.Blockable():
			why := res.Error
			if why == "" {
				why = "no address to block"
			}
			d.warnings = append(d.warnings, fmt.Sprintf("%s: %s cannot be blocked: %s", groupName, dom, why))
			continue
		}
		if res.Many {
			d.warnings = append(d.warnings, fmt.Sprintf("%s: %s uses %d addresses, which looks like a content network; blocking them may also affect other sites", groupName, dom, len(res.IPs)))
		}
		for _, ip := range res.IPs {
			if allow[ip] {
				continue
			}
			add(ip)
		}
	}
	for _, lit := range literals {
		add(lit)
	}
	sort.Strings(out)
	if len(out) > maxSiteAddrsPerGroup {
		d.warnings = append(d.warnings, fmt.Sprintf("%s: the blocked sites point to %d addresses; only the first %d are blocked", groupName, len(out), maxSiteAddrsPerGroup))
		out = out[:maxSiteAddrsPerGroup]
	}
	return out
}

// groupBlocksByAddress reports whether any of the platforms is blocked through an
// address list, which is what the always-allowed addresses have to be let past.
func groupBlocksByAddress(platforms []string, opts marcoBuildOptions) bool {
	for _, key := range platforms {
		if opts.platformLists[key] != "" || len(marcoPlatformByKey[key].IPRanges) > 0 {
			return true
		}
	}
	return false
}

func macKey(mac string) string {
	return strings.ToLower(strings.ReplaceAll(mac, ":", ""))
}

// addDeviceOverrides adds the rules for devices blocked or limited one by one. They
// work for a device in any group, or in none.
func (d *marcoDesiredState) addDeviceOverrides(opts marcoBuildOptions) {
	overrides := append([]marcoOverrideTarget(nil), opts.overrides...)
	sort.Slice(overrides, func(i, j int) bool { return overrides[i].MAC < overrides[j].MAC })
	blockedAny := false
	for _, o := range overrides {
		if o.IP == nil || o.IP.IsUnspecified() {
			d.warnings = append(d.warnings, fmt.Sprintf("%s: the router has not seen this device, so its block or limit is not applied yet", o.MAC))
			continue
		}
		if isProtectedIP(o.IP, opts.protected) {
			d.warnings = append(d.warnings, fmt.Sprintf("%s: protected address %s, no rules created", o.MAC, o.IP))
			continue
		}
		key := macKey(o.MAC)
		if o.Blocked {
			d.addAddress(marcoBlockedPrefix+key, marcoBlockedList, hostCIDR(o.IP))
			blockedAny = true
			continue
		}
		dl, hasDL := mbpsToBps(o.DownMbps)
		ul, hasUL := mbpsToBps(o.UpMbps)
		if !hasDL && !hasUL {
			continue
		}
		name := marcoDeviceQueuePrefix + key
		d.queues[name] = desiredRouterEntry{path: "/queue/simple", attrs: map[string]string{
			"name": name, "target": hostCIDR(o.IP), "comment": name, "disabled": "no",
			"max-limit": queueRatePair(ul, hasUL, dl, hasDL),
		}}
	}
	if blockedAny {
		d.addFirewall(marcoManagedPrefix+"device-block", map[string]string{
			"chain": "forward", "action": "drop", "src-address-list": marcoBlockedList,
		}, true)
	}
}
