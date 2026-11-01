package monitoring

import "sync/atomic"

var simulateData atomic.Bool

// SetSimulation turns the random demo metrics on or off (MONITOR_SIMULATE_METRICS).
// Off by default: only measured values (ping) are stored, so nothing the UI shows
// is made up.
func SetSimulation(on bool) { simulateData.Store(on) }

func simulating() bool { return simulateData.Load() }
