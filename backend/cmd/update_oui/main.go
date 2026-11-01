// Command update_oui rebuilds the embedded MAC vendor table from a copy of the
// IEEE registry in Wireshark's "manuf" format.
//
//	go run ./cmd/update_oui <path-to-manuf> [output.tsv.gz]
//
// The default output is the file the backend embeds,
// internal/services/oui_manuf.tsv.gz. The registry only changes weekly, so
// refreshing it once in a while is enough.
package main

import (
	"bufio"
	"compress/gzip"
	"fmt"
	"os"
	"sort"
	"strings"
)

const defaultOutput = "internal/services/oui_manuf.tsv.gz"

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: update_oui <manuf-file> [output.tsv.gz]")
		os.Exit(2)
	}
	out := defaultOutput
	if len(os.Args) > 2 {
		out = os.Args[2]
	}

	in, err := os.Open(os.Args[1])
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer in.Close()

	entries := map[string]string{}
	scanner := bufio.NewScanner(in)
	scanner.Buffer(make([]byte, 1<<20), 1<<20)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "#") || strings.TrimSpace(line) == "" {
			continue
		}
		cols := strings.Split(line, "\t")
		if len(cols) < 2 {
			continue
		}
		key, ok := prefixKey(strings.TrimSpace(cols[0]))
		if !ok {
			continue
		}
		name := strings.TrimSpace(cols[1])
		if len(cols) > 2 && strings.TrimSpace(cols[2]) != "" {
			name = strings.TrimSpace(cols[2])
		}
		entries[key] = strings.ReplaceAll(name, "\t", " ")
	}
	if err := scanner.Err(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	keys := make([]string, 0, len(entries))
	for k := range entries {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	f, err := os.Create(out)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	gz, _ := gzip.NewWriterLevel(f, gzip.BestCompression)
	w := bufio.NewWriter(gz)
	for _, k := range keys {
		fmt.Fprintf(w, "%s\t%s\n", k, entries[k])
	}
	w.Flush()
	gz.Close()
	f.Close()
	info, _ := os.Stat(out)
	fmt.Printf("%d vendor blocks written to %s (%d KB)\n", len(keys), out, info.Size()/1024)
}

// prefixKey turns "AA:BB:CC" (24 bits), "AA:BB:CC:D0:00:00/28" or ".../36" into
// the hex digits that identify the block: 6, 7 or 9 characters.
func prefixKey(col string) (string, bool) {
	digits := 6
	if i := strings.Index(col, "/"); i >= 0 {
		switch col[i+1:] {
		case "28":
			digits = 7
		case "36":
			digits = 9
		default:
			return "", false
		}
		col = col[:i]
	}
	hex := strings.ToUpper(strings.ReplaceAll(strings.ReplaceAll(col, ":", ""), "-", ""))
	if len(hex) < digits {
		return "", false
	}
	for _, c := range hex[:digits] {
		if !(c >= '0' && c <= '9' || c >= 'A' && c <= 'F') {
			return "", false
		}
	}
	return hex[:digits], true
}
