package services

import (
	"bufio"
	"context"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/hospital/nms-backend/pkg/logger"
)

const logCleanupEvery = 6 * time.Hour

// logLineDate finds the date a log entry was written: "│ 2026-11-03 11:40:34" from
// the app, {"level":"info","timestamp":"2026-11-03T10:59:34 from the server. A date
// further along a line is data, not when the line was written.
var logLineDate = regexp.MustCompile(`^(?:[^0-9A-Za-z{"]*|\{"level":"[a-z]+","timestamp":")(20\d\d-\d\d-\d\d)[ T]\d\d:\d\d`)

// StartLogCleanup removes log entries older than days from the files the patterns
// match, now and every few hours.
func StartLogCleanup(ctx context.Context, patterns []string, days int) {
	if len(patterns) == 0 || days <= 0 {
		return
	}
	go func() {
		ticker := time.NewTicker(logCleanupEvery)
		defer ticker.Stop()
		for {
			cleanLogs(patterns, time.Now().AddDate(0, 0, -days))
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
		}
	}()
}

func cleanLogs(patterns []string, cutoff time.Time) {
	for _, pattern := range patterns {
		files, err := filepath.Glob(pattern)
		if err != nil {
			logger.Warn("Log cleanup: bad file pattern", "pattern", pattern, "error", err)
			continue
		}
		for _, file := range files {
			if !strings.HasSuffix(strings.ToLower(file), ".log") {
				continue // never delete anything that is not a log
			}
			freed, err := cleanLogFile(file, cutoff)
			if err != nil {
				logger.Warn("Log cleanup failed", "file", file, "error", err)
			} else if freed > 0 {
				logger.Info("Log cleanup", "file", file, "freed_bytes", freed)
			}
		}
	}
}

// cleanLogFile deletes a log nothing has written to since the cutoff, and otherwise
// removes the entries older than the cutoff from the start of it. It returns the
// bytes freed. A file with no dates it can read is left alone.
func cleanLogFile(file string, cutoff time.Time) (int64, error) {
	info, err := os.Stat(file)
	if err != nil {
		return 0, err
	}
	if info.ModTime().Before(cutoff) {
		return info.Size(), os.Remove(file)
	}
	f, err := os.OpenFile(file, os.O_RDWR, 0)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	keepFrom, err := firstEntryFrom(f, cutoff.Format("2006-01-02"))
	if err != nil || keepFrom == 0 {
		return 0, err
	}
	return shiftToStart(f, keepFrom)
}

// firstEntryFrom returns where the first entry dated day or later starts, and the
// file's size when every entry is older. It returns 0 when nothing dated is older
// than day: lines with no date before the first entry say nothing about their age.
func firstEntryFrom(f *os.File, day string) (int64, error) {
	if _, err := f.Seek(0, io.SeekStart); err != nil {
		return 0, err
	}
	r := bufio.NewReaderSize(f, 1<<20)
	var offset int64
	atLineStart, sawOld := true, false
	for {
		chunk, err := r.ReadSlice('\n')
		if atLineStart && len(chunk) > 0 {
			head := chunk
			if len(head) > 120 {
				head = head[:120]
			}
			if m := logLineDate.FindSubmatch(head); m != nil {
				if string(m[1]) >= day {
					if !sawOld {
						return 0, nil
					}
					return offset, nil
				}
				sawOld = true
			}
		}
		offset += int64(len(chunk))
		atLineStart = err != bufio.ErrBufferFull
		switch err {
		case nil, bufio.ErrBufferFull:
		case io.EOF:
			if !sawOld {
				return 0, nil
			}
			return offset, nil
		default:
			return 0, err
		}
	}
}

// shiftToStart moves everything from keepFrom to the start of the file and cuts the
// rest. The file stays the same file, because the program writing to it holds it
// open and keeps adding to its end.
func shiftToStart(f *os.File, keepFrom int64) (int64, error) {
	buf := make([]byte, 1<<20)
	read, written := keepFrom, int64(0)
	for {
		n, err := f.ReadAt(buf, read)
		if n > 0 {
			if _, werr := f.WriteAt(buf[:n], written); werr != nil {
				return 0, werr
			}
			read += int64(n)
			written += int64(n)
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return 0, err
		}
	}
	return read - written, f.Truncate(written)
}
