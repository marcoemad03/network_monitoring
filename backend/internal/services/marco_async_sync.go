package services

import (
	"context"
	"sync"

	"github.com/google/uuid"
)

// asyncSyncer runs router syncs in the background, one at a time per
// organization. A sync reads several large RouterOS tables and takes seconds on
// a loaded router, so API calls save their change and return; requests that
// arrive while a sync is running are folded into one follow-up run.
type asyncSyncer struct {
	mu   sync.Mutex
	orgs map[uuid.UUID]*asyncSyncState
}

type asyncSyncState struct {
	running   bool
	pending   bool
	groupID   *uuid.UUID
	callbacks []func()
}

// scheduleSync queues a router sync for the organization. groupID tags a
// failure in the policy log; onDone runs after the sync that covers this
// request succeeds.
func (s *MarcoGroupService) scheduleSync(orgID uuid.UUID, groupID *uuid.UUID, onDone func()) {
	a := &s.async
	a.mu.Lock()
	if a.orgs == nil {
		a.orgs = map[uuid.UUID]*asyncSyncState{}
	}
	st := a.orgs[orgID]
	if st == nil {
		st = &asyncSyncState{}
		a.orgs[orgID] = st
	}
	st.groupID = groupID
	if onDone != nil {
		st.callbacks = append(st.callbacks, onDone)
	}
	if st.running {
		st.pending = true
		a.mu.Unlock()
		return
	}
	st.running = true
	a.mu.Unlock()

	go s.runAsyncSync(orgID, st)
}

func (s *MarcoGroupService) runAsyncSync(orgID uuid.UUID, st *asyncSyncState) {
	a := &s.async
	for {
		a.mu.Lock()
		callbacks := st.callbacks
		st.callbacks = nil
		groupID := st.groupID
		st.pending = false
		a.mu.Unlock()

		ctx := context.Background()
		if _, err := s.sync.SyncAll(ctx, orgID); err != nil {
			s.log(ctx, orgID, groupID, nil, "sync_failed", err.Error(), "failed", err.Error())
		} else {
			for _, fn := range callbacks {
				fn()
			}
		}

		a.mu.Lock()
		if !st.pending {
			st.running = false
			a.mu.Unlock()
			return
		}
		a.mu.Unlock()
	}
}
