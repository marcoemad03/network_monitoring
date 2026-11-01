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
