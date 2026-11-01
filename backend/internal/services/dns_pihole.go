package services

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/hospital/nms-backend/pkg/logger"
)

// SourcePihole is the name of the Pi-hole reader in the source status.
const SourcePihole = "pihole"

const piholeMaxRows = 20000

// PiholeReader reads the query log of a Pi-hole over its API. It only reads. The
// password or token comes from the environment and is never logged or returned.
type PiholeReader struct {
	base     string
	password string // v6
	token    string // v5
	client   *http.Client
	sid      string
}

func NewPiholeReader(base, password, token string, insecureTLS bool) *PiholeReader {
	tr := &http.Transport{Proxy: nil}
	if insecureTLS {
		tr.TLSClientConfig = &tls.Config{InsecureSkipVerify: true} // opt-in: Pi-hole ships a self-signed certificate
	}
	return &PiholeReader{
		base: strings.TrimRight(base, "/"), password: password, token: token,
		client: &http.Client{Timeout: 20 * time.Second, Transport: tr},
	}
}

func (p *PiholeReader) v6() bool { return p.token == "" }

// Queries returns the lookups between from and until.
func (p *PiholeReader) Queries(ctx context.Context, from, until time.Time) ([]DNSEvent, error) {
	if p.v6() {
		return p.queriesV6(ctx, from, until)
	}
	return p.queriesV5(ctx, from, until)
}

// blockedV6 are the status names Pi-hole v6 uses for answers it refused.
func blockedV6(status string) bool {
	s := strings.ToUpper(status)
	return strings.HasPrefix(s, "GRAVITY") || strings.HasPrefix(s, "REGEX") || strings.HasPrefix(s, "DENYLIST") || strings.HasPrefix(s, "EXTERNAL_BLOCKED")
}

// blockedV5 are the numeric statuses of Pi-hole v5 for blocked answers.
func blockedV5(status int) bool {
	switch status {
	case 1, 4, 5, 6, 7, 8, 9, 10, 11:
		return true
	}
	return false
}

func (p *PiholeReader) login(ctx context.Context) error {
	body, _ := json.Marshal(map[string]string{"password": p.password})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.base+"/api/auth", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := p.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var out struct {
		Session struct {
			Valid bool   `json:"valid"`
			SID   string `json:"sid"`
		} `json:"session"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&out); err != nil {
		return fmt.Errorf("Pi-hole sign-in gave an unreadable answer (HTTP %d)", resp.StatusCode)
	}
	if !out.Session.Valid || out.Session.SID == "" {
		return errors.New("Pi-hole refused the password")
	}
	p.sid = out.Session.SID
	return nil
}

func (p *PiholeReader) queriesV6(ctx context.Context, from, until time.Time) ([]DNSEvent, error) {
	if p.sid == "" {
		if err := p.login(ctx); err != nil {
			return nil, err
		}
	}
	for attempt := 0; attempt < 2; attempt++ {
		q := url.Values{}
		q.Set("from", strconv.FormatInt(from.Unix(), 10))
		q.Set("until", strconv.FormatInt(until.Unix(), 10))
		q.Set("length", strconv.Itoa(piholeMaxRows))
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, p.base+"/api/queries?"+q.Encode(), nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set("X-FTL-SID", p.sid)
		resp, err := p.client.Do(req)
		if err != nil {
			return nil, err
		}
		if resp.StatusCode == http.StatusUnauthorized && attempt == 0 {
			resp.Body.Close()
			p.sid = ""
			if err := p.login(ctx); err != nil {
				return nil, err
			}
			continue
		}
		var out struct {
			Queries []struct {
				Time   float64 `json:"time"`
				Type   string  `json:"type"`
				Domain string  `json:"domain"`
				Status string  `json:"status"`
				Client struct {
					IP string `json:"ip"`
				} `json:"client"`
			} `json:"queries"`
		}
		err = json.NewDecoder(io.LimitReader(resp.Body, 64<<20)).Decode(&out)
		code := resp.StatusCode
		resp.Body.Close()
		if code != http.StatusOK {
			return nil, fmt.Errorf("Pi-hole answered HTTP %d", code)
		}
		if err != nil {
			return nil, fmt.Errorf("Pi-hole query log is unreadable: %w", err)
		}
		events := make([]DNSEvent, 0, len(out.Queries))
		for _, r := range out.Queries {
			events = append(events, DNSEvent{
				Time: time.Unix(int64(r.Time), 0), ClientIP: r.Client.IP, Name: r.Domain, QType: r.Type, Blocked: blockedV6(r.Status),
			})
		}
		return events, nil
	}
	return nil, errors.New("Pi-hole refused the session")
}

func (p *PiholeReader) queriesV5(ctx context.Context, from, until time.Time) ([]DNSEvent, error) {
	q := url.Values{}
	q.Set("getAllQueries", strconv.Itoa(piholeMaxRows))
	q.Set("from", strconv.FormatInt(from.Unix(), 10))
	q.Set("until", strconv.FormatInt(until.Unix(), 10))
	q.Set("auth", p.token)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, p.base+"/admin/api.php?"+q.Encode(), nil)
	if err != nil {
		return nil, err
	}
	resp, err := p.client.Do(req)
	if err != nil {
		return nil, redactURLError(err, p.token)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Pi-hole answered HTTP %d", resp.StatusCode)
	}
	// Rows are [time, type, domain, client, status, ...]; a wrong token returns [].
	var out struct {
		Data [][]json.RawMessage `json:"data"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 64<<20)).Decode(&out); err != nil {
		return nil, errors.New("Pi-hole query log is unreadable (is the API token right?)")
	}
	events := make([]DNSEvent, 0, len(out.Data))
	for _, row := range out.Data {
		if len(row) < 5 {
			continue
		}
		var qtype, domain, client string
		ts, tsOK := jsonInt(row[0])
		status, _ := jsonInt(row[4])
		if !tsOK || json.Unmarshal(row[1], &qtype) != nil || json.Unmarshal(row[2], &domain) != nil || json.Unmarshal(row[3], &client) != nil {
			continue
		}
		events = append(events, DNSEvent{Time: time.Unix(ts, 0), ClientIP: client, Name: domain, QType: qtype, Blocked: blockedV5(int(status))})
	}
	return events, nil
}

// jsonInt reads a number that Pi-hole v5 sends either as a number or as text.
func jsonInt(raw json.RawMessage) (int64, bool) {
	var n int64
	if json.Unmarshal(raw, &n) == nil {
		return n, true
	}
	var s string
	if json.Unmarshal(raw, &s) == nil {
		n, err := strconv.ParseInt(strings.TrimSpace(s), 10, 64)
		return n, err == nil
	}
	return 0, false
}

// redactURLError removes the secret from errors that quote the request address.
func redactURLError(err error, secret string) error {
	if secret == "" {
		return err
	}
	return errors.New(strings.ReplaceAll(err.Error(), secret, "***"))
}

// StartPihole reads the Pi-hole's query log regularly and counts it.
func (c *DNSCollector) StartPihole(ctx context.Context, reader *PiholeReader, every time.Duration) {
	c.RegisterSource(SourcePihole, true)
	if every < 10*time.Second {
		every = 30 * time.Second
	}
	go func() {
		// First read goes back a short while so a restart does not leave a gap, but
		// not so far that lookups already stored are counted twice.
		from := time.Now().Add(-every)
		tick := time.NewTicker(every)
		defer tick.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-tick.C:
			}
			until := time.Now().Add(-3 * time.Second) // let Pi-hole finish writing the latest rows
			if !until.After(from) {
				continue
			}
			events, err := reader.Queries(ctx, from, until)
			if err != nil {
				c.SourceError(SourcePihole, err.Error())
				logger.Warn("Pi-hole query log not read", "error", err)
				continue
			}
			c.SourceError(SourcePihole, "")
			for _, ev := range events {
				c.Add(SourcePihole, ev)
			}
			from = until
		}
	}()
}
