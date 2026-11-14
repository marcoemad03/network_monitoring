package services

import (
	"testing"
	"time"
)

func TestBytesReadBeforeMidnightCanBeTakenForThatDay(t *testing.T) {
	st := &inventoryState{prev: map[string]counterReading{}, pendDown: map[string]int64{}, pendUp: map[string]int64{}}
	at := time.Date(2026, 11, 9, 23, 59, 0, 0, time.Local)
	st.apply([]LiveClient{{MAC: "AA", HasCounters: true, BytesDown: 100, BytesUp: 10}}, at)
	st.apply([]LiveClient{{MAC: "AA", HasCounters: true, BytesDown: 600, BytesUp: 60}}, at.Add(30*time.Second))

	macs, down, up := st.drainPending()
	if len(macs) != 1 || down[0] != 500 || up[0] != 50 {
		t.Fatalf("drained %v %v %v, want AA 500/50", macs, down, up)
	}
	if len(st.pendDown)+len(st.pendUp) != 0 {
		t.Fatal("bytes left pending would be counted twice")
	}
	st.apply([]LiveClient{{MAC: "AA", HasCounters: true, BytesDown: 700, BytesUp: 70}}, at.Add(90*time.Second))
	if st.pendDown["AA"] != 100 {
		t.Fatalf("after midnight pending = %d, want 100", st.pendDown["AA"])
	}
}
