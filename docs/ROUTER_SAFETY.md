# Router safety

The policy engines (Marco groups and the legacy asset policies) can change the
hospital MikroTik. These rules keep a bad policy from taking the network down.

## Dry-run by default
`ROUTER_POLICY_WRITES=false` (default): a sync reads the router, computes what it
would change and writes the plan to `marco_policy_logs` (status `dry_run`) and the
sync log. No add/set/remove command is ever sent. Enforced in one place
(`routerSession` in `internal/services/router_session.go`), so no code path can bypass it.

Enable writes only after reviewing the plan:
1. Run a sync (`POST /api/v1/marco/sync`) and read `planned_changes` and `warnings`.
2. Set `ROUTER_POLICY_WRITES=true` in `backend/.env` and restart the backend.

## Guards (always on)
* One router session at a time (policy sync, quota loop and legacy sync share a gate).
* A drop/reject rule without a source scope is refused (`validateFirewallScope`).
* The router's own address and `ROUTER_PROTECTED_IPS` never receive rules.
* A plan larger than `ROUTER_MAX_MANAGED_ENTRIES` is refused.
* Only entries commented `nms-marco-` (Marco) or `nms-policy-` (legacy) are touched.
  RouterOS `?comment=x` is an exact match, so the tables are printed and filtered by prefix.
* Duplicates left by older syncs are removed; failures undo exactly what the run changed.
* New drop rules are placed at the top of the forward chain, scoped to their group.
* Rules that read packet contents (`layer7-protocol`, `tls-host`, `content`) and layer7 protocols can never be written (`refusedRouterWrite`). See the incident below. `ROUTER_ENABLE_LAYER7=true` only makes syncs fail with that error.
* Any change runs under a safety timer on the router itself (`marco_watchdog.go`): the job `nms-marco-deadman` removes all `nms-marco-` rules and queues after 5 minutes. The sync cancels it after watching the router for 30 seconds. If the router stops answering or its CPU stays full, the sync rolls back and pauses router changes until someone presses Update the router now; if the router cannot be reached, the timer cleans up on its own. A sync that changes nothing sets no timer.

## Incident: 2026-11-03, the whole hospital lost internet
A layer7 rule (with a drop of udp 443) for two devices was synced at 10:51:39. The last normal reading of the line was at 10:51:42; the router then stopped answering, sat at 100% CPU and stayed that way after a reboot at about 11:07. Internet came back after all `nms-marco-` entries were removed at 11:11:25, and the CPU fell to 40%. The same group's address-list rule had run for 10 minutes without trouble. Layer7 runs a regular expression on the packets it sees, which this RB2011 cannot afford even for two devices.

## Opt-in, off by default
* `ROUTER_ENABLE_DNS_BLOCK` - legacy router-wide static DNS entries; affects every device.

## Emergency: internet is down after an NMS change
Fastest: run `backend/marco-remove.exe` (keep it next to `.env`) on a PC on the hospital network and type YES. It stops the NMS server, sets `ROUTER_POLICY_WRITES=false` and deletes every `nms-marco-` entry, retrying for 5 minutes while the router struggles. `marco-remove.exe --check` only reports what is there. Rebuild it with `go build -o marco-remove.exe ./cmd/marco-remove` from `backend`.

By hand, if that cannot reach the router:
1. Stop the NMS server, so it cannot put the rules back.
2. Open WinBox. If the router's address does not answer, connect by its MAC address from the Neighbors tab (`B8:69:F4:B3:A8:FC`).
3. In New Terminal, run the commands below. They only remove entries named `nms-marco-`.
```
/ip firewall filter remove [find where comment~"^nms-marco-"]
/queue simple remove [find where comment~"^nms-marco-"]
/ip firewall address-list remove [find where comment~"^nms-marco-"]
/ip firewall layer7-protocol remove [find where name~"^nms-marco-"]
/system scheduler remove [find where name="nms-marco-deadman"]
```
4. Set `ROUTER_POLICY_WRITES=false` in `backend/.env` before starting the server again.

## Manual rollback on the router
Everything the NMS ever created, including the legacy engine:
```
/ip firewall filter remove [find where comment~"^nms-"]
/ip firewall layer7-protocol remove [find where name~"^nms-"]
/ip firewall address-list remove [find where comment~"^nms-"]
/queue simple remove [find where comment~"^nms-"]
/ip dns static remove [find where comment~"^nms-"]
```

## Write switches
* `ROUTER_POLICY_WRITES` - master switch. `false` records the plan only (dry-run).
* `ROUTER_PRUNE_STALE` - `true` (default): the Marco sync also removes the `nms-marco-` entries it no longer wants (a device taken out of a group, a site unblocked, a deleted group), so a removed block is really lifted. It never touches entries without the `nms-marco-` prefix. `false` makes the sync add and update only; old rules then stay on the router until you remove them by hand.
* `ROUTER_MAX_PRUNE` - a sync that would remove more than this many entries (default 60) is refused with an error, so a reset database cannot clear the router.
* `ROUTER_LEGACY_POLICY_WRITES` - the legacy policy engine writes only when this and `ROUTER_POLICY_WRITES` are both `true`.
* `ROUTER_PLATFORM_DST_LISTS` - `key=router address-list` pairs, separated by `;`. YouTube has no built-in ranges (its addresses are shared with Gmail), so it needs this, e.g. `youtube=collect all youtube ips`. The list must exist on the router and be kept up to date by you.

## Write account
Use a dedicated RouterOS user (policy `read,write,api`, restricted with `address=<server ip>/32`) for writes and a read-only one (`read,api`) while previewing.
