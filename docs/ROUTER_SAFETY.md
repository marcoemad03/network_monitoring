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
