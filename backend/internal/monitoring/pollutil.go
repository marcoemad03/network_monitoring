package monitoring

import (
	"context"
	"net"
	"sync"
	"time"

	"github.com/google/uuid"
)

const (
	pollWorkers       = 10
	pollDeviceTimeout = 20 * time.Second
)

// forEachDevice polls devices concurrently. Every device gets its own deadline,
// so one slow or unreachable device cannot exhaust the time budget of the rest
// (a single shared deadline used to make every database write fail once it expired).
func forEachDevice(parent context.Context, ids []uuid.UUID, fn func(ctx context.Context, id uuid.UUID)) {
	sem := make(chan struct{}, pollWorkers)
	var wg sync.WaitGroup
	for _, id := range ids {
		if parent.Err() != nil {
			break
		}
		sem <- struct{}{}
		wg.Add(1)
		go func(id uuid.UUID) {
			defer wg.Done()
			defer func() { <-sem }()
			ctx, cancel := context.WithTimeout(parent, pollDeviceTimeout)
			defer cancel()
			fn(ctx, id)
		}(id)
	}
	wg.Wait()
}

// pollable reports whether an IP can be pinged (placeholder devices created from
// a MAC address carry 0.0.0.0).
func pollable(ip net.IP) bool {
	return ip != nil && !ip.IsUnspecified()
}
