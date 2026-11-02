package services

import (
	"context"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/pkg/logger"
)

const (
	followEvery   = 2 * time.Minute
	followRefresh = 30 * time.Minute // sites change address now and then
)

// StartFollower keeps the router in step with the network once groups exist: when
// a device in a group (or one that is blocked or limited) gets a new address from
// DHCP, the rules are moved to it, and the blocked websites are looked up again now
// and then because their addresses change. It does nothing while router writes
// are off.
func (s *MarcoGroupService) StartFollower(ctx context.Context, orgs func(context.Context) ([]uuid.UUID, error)) {
	go func() {
		ticker := time.NewTicker(followEvery)
		defer ticker.Stop()
		last := map[uuid.UUID]string{}
		refreshed := map[uuid.UUID]time.Time{}
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
			if !s.cfg.RouterPolicyWrites || s.inventory == nil {
				continue
			}
			ids, err := orgs(ctx)
			if err != nil {
				logger.Warn("Marco follower: list organizations failed", "error", err)
				continue
			}
			for _, id := range ids {
				print, hasSites, err := s.followState(ctx, id)
				if err != nil {
					continue
				}
				prev, known := last[id]
				last[id] = print
				switch {
				case !known:
					// First look after a start: nothing has changed yet.
					refreshed[id] = time.Now()
				case print != prev:
					s.scheduleSync(id, nil, nil)
					refreshed[id] = time.Now()
				case hasSites && time.Since(refreshed[id]) >= followRefresh:
					s.scheduleSync(id, nil, nil)
					refreshed[id] = time.Now()
				}
			}
		}
	}()
}

// followState summarises where the devices the rules point at are right now.
func (s *MarcoGroupService) followState(ctx context.Context, orgID uuid.UUID) (string, bool, error) {
	live := s.inventory.LiveIPs(orgID)
	if len(live) == 0 {
		return "", false, context.Canceled // the router has not been read yet
	}
	groups, err := s.marcoRepo.ListGroups(ctx, orgID)
	if err != nil {
		return "", false, err
	}
	members, err := s.marcoRepo.ListAllMembers(ctx, orgID)
	if err != nil {
		return "", false, err
	}
	overrides, err := s.marcoRepo.ListOverrides(ctx, orgID)
	if err != nil {
		return "", false, err
	}
	active := map[string]bool{}
	hasSites := false
	for _, g := range groups {
		if !isZeroPolicy(g.Policy) {
			active[g.ID.String()] = true
		}
		if len(g.Policy.BlockedPacks)+len(g.Policy.BlockedDomains) > 0 {
			hasSites = true
		}
	}
	var parts []string
	for _, m := range members {
		if active[m.GroupID.String()] {
			mac := strings.ToUpper(orEmpty(m.MACAddress))
			if ip := live[mac]; ip != "" {
				parts = append(parts, mac+"="+ip)
			}
		}
	}
	for _, o := range overrides {
		if ip := live[strings.ToUpper(o.MAC)]; ip != "" {
			parts = append(parts, "o:"+o.MAC+"="+ip)
		}
	}
	sort.Strings(parts)
	return strings.Join(parts, ","), hasSites, nil
}
