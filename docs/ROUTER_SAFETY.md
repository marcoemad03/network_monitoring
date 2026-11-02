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

## Opt-in, off by default
* `ROUTER_ENABLE_LAYER7` - layer7 matching (required to enforce AI sites, which have no fixed IP ranges).
* `ROUTER_ENABLE_DNS_BLOCK` - legacy router-wide static DNS entries; affects every device.

## Manual rollback on the router
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
