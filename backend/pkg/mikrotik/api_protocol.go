package mikrotik

import (
	"bytes"
	"crypto/md5"
	"crypto/sha1"
	"encoding/hex"
	"fmt"
	"io"
	"net"
	"strings"
	"time"
)

type APIConnection struct {
	host     string
	port     int
	username string
	password string
	timeout  time.Duration
	conn     net.Conn
	reader   io.Reader
	Debug    bool
	LogFn    func(format string, args ...interface{})
}

func NewAPIConnection(host string, port int, username, password string, timeout time.Duration) *APIConnection {
	return &APIConnection{
		host:     host,
		port:     port,
		username: username,
		password: password,
		timeout:  timeout,
		LogFn:    func(format string, args ...interface{}) {},
	}
}

func (c *APIConnection) log(format string, args ...interface{}) {
	c.LogFn(format, args...)
}

// RouterOS API uses length-prefixed binary framing:
// - Each word: [1-2 byte length][data]
// - Sentence terminator: empty word (length 0x00)
// - Length encoding: if MSB set, combine with next byte

func (c *APIConnection) Connect() error {
	addr := fmt.Sprintf("%s:%d", c.host, c.port)
	c.log("[API] Dialing %s (timeout=%v)...", addr, c.timeout)

	dialer := net.Dialer{Timeout: c.timeout}
	conn, err := dialer.Dial("tcp", addr)
	if err != nil {
		c.log("[API] Dial ERROR: %v", err)
		return fmt.Errorf("tcp dial %s: %w", addr, err)
	}
	c.conn = conn
	c.reader = conn
	c.log("[API] TCP connection ESTABLISHED to %s", addr)
	return nil
}

func (c *APIConnection) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

func (c *APIConnection) writeSentence(words ...string) error {
	var buf bytes.Buffer
	for _, word := range words {
		data := []byte(word)
		writeLength(&buf, len(data))
		buf.Write(data)
	}
	// Empty word = end of sentence
	buf.WriteByte(0)

	c.log("[API] >> SEND sentence (%d bytes):", buf.Len())
	c.log("[API] >>   Words: %s", strings.Join(words, " | "))
	for i, w := range words {
		c.log("[API] >>   [%d] length=%d content=%q", i, len(w), w)
	}
	c.log("[API] >>   Raw hex: % x", buf.Bytes())

	if _, err := c.conn.Write(buf.Bytes()); err != nil {
		c.log("[API] >> WRITE ERROR: %v", err)
		return fmt.Errorf("write sentence: %w", err)
	}
	return nil
}

func writeLength(buf *bytes.Buffer, length int) {
	if length < 0x80 {
		buf.WriteByte(byte(length))
	} else {
		buf.WriteByte(byte(length | 0x80))
		buf.WriteByte(byte(length >> 7))
	}
}

func (c *APIConnection) readLength() (int, error) {
	b := make([]byte, 1)
	if _, err := io.ReadFull(c.reader, b); err != nil {
		return 0, err
	}
	if b[0] < 0x80 {
		return int(b[0]), nil
	}
	b2 := make([]byte, 1)
	if _, err := io.ReadFull(c.reader, b2); err != nil {
		return 0, err
	}
	return int(b[0]&0x7f) | (int(b2[0]) << 7), nil
}

func (c *APIConnection) readSentence() (string, []string, error) {
	var words []string
	var rawBytes []byte

	for {
		length, err := c.readLength()
		if err != nil {
			c.log("[API] << READ LENGTH ERROR: %v", err)
			return "", nil, fmt.Errorf("read word length: %w", err)
		}
		if length == 0 {
			break
		}
		data := make([]byte, length)
		if _, err := io.ReadFull(c.reader, data); err != nil {
			c.log("[API] << READ WORD ERROR: %v", err)
			return "", nil, fmt.Errorf("read word data: %w", err)
		}
		rawBytes = append(rawBytes, data...)
		words = append(words, string(data))
	}

	c.log("[API] << RECV sentence (%d bytes):", len(rawBytes)+1)
	for i, w := range words {
		c.log("[API] <<   [%d] length=%d content=%q", i, len(w), w)
	}

	sentenceType := ""
	if len(words) > 0 {
		sentenceType = words[0]
	}

	return sentenceType, words, nil
}

func (c *APIConnection) Login() error {
	c.log("")
	c.log("=== ROUTEROS API LOGIN SEQUENCE ===")
	c.log("Target: %s:%d, User: %s", c.host, c.port, c.username)
	c.log("")

	c.log("[LOGIN] Step 1: Sending /login with plain credentials...")
	if err := c.writeSentence("/login", fmt.Sprintf("=name=%s", c.username), fmt.Sprintf("=password=%s", c.password)); err != nil {
		return fmt.Errorf("login send: %w", err)
	}

	sentenceType, words, err := c.readSentence()
	if err != nil {
		c.log("[LOGIN] ERROR reading login response: %v", err)
		c.log("[LOGIN] Step 2 (fallback): Trying challenge-response login...")
		return c.challengeLogin()
	}

	c.log("[LOGIN] Response type: %s", sentenceType)

	switch sentenceType {
	case "!done":
		c.log("[LOGIN] SUCCESS: Plain login accepted")
		return nil

	case "!trap":
		c.log("[LOGIN] Plain login REJECTED (%v)", words)
		if isChallengeResponse(words) {
			c.log("[LOGIN] Detected challenge-response required (RouterOS < v6.43)")
		}
		c.log("[LOGIN] Step 2: Trying challenge-response login...")
		return c.challengeLogin()

	case "!fatal":
		c.log("[LOGIN] FATAL error: %v", words)
		return fmt.Errorf("login fatal: %v", words)

	default:
		c.log("[LOGIN] Unexpected response: %s %v", sentenceType, words)
		c.log("[LOGIN] Step 2 (fallback): Trying challenge-response login...")
		return c.challengeLogin()
	}
}

func isChallengeResponse(words []string) bool {
	for _, w := range words {
		if strings.HasPrefix(w, "=ret=") {
			return true
		}
	}
	return false
}

func (c *APIConnection) challengeLogin() error {
	c.log("")
	c.log("[CHALLENGE] Sending /login probe...")
	if err := c.writeSentence("/login"); err != nil {
		return fmt.Errorf("challenge probe send: %w", err)
	}

	sentenceType, words, err := c.readSentence()
	if err != nil {
		return fmt.Errorf("challenge probe read: %w", err)
	}

	c.log("[CHALLENGE] Response: %s %v", sentenceType, words)

	if sentenceType == "!trap" {
		msg := extractMessage(words)
		c.log("[CHALLENGE] Server rejected probe: %s", msg)
		return fmt.Errorf("login rejected: %s", msg)
	}

	if sentenceType != "!done" {
		return fmt.Errorf("challenge probe expected !done, got %s", sentenceType)
	}

	var challenge string
	for _, w := range words {
		if strings.HasPrefix(w, "=ret=") {
			challenge = strings.TrimPrefix(w, "=ret=")
			break
		}
	}

	if challenge == "" {
		c.log("[CHALLENGE] No challenge found in response, trying MD5(password) hash...")

		hash := md5.Sum([]byte(c.password))
		response := hex.EncodeToString(hash[:])
		c.log("[CHALLENGE] MD5 hash: %s", response)

		if err := c.writeSentence("/login", fmt.Sprintf("=name=%s", c.username), fmt.Sprintf("=response=%s", response)); err != nil {
			return fmt.Errorf("response send: %w", err)
		}

		sentenceType, words, err = c.readSentence()
		if err != nil {
			return fmt.Errorf("response read: %w", err)
		}
		c.log("[CHALLENGE] Response: %s %v", sentenceType, words)

		if sentenceType == "!done" {
			c.log("[CHALLENGE] LOGIN SUCCESS via MD5 hash!")
			return nil
		}
		return fmt.Errorf("login failed: %s %v", sentenceType, words)
	}

	c.log("[CHALLENGE] Challenge received: %s", challenge)

	// SHA1 challenge-response: SHA1(challenge + "\x00" + password)
	hash := sha1.Sum([]byte(challenge + "\x00" + c.password))
	response := "00" + hex.EncodeToString(hash[:])
	c.log("[CHALLENGE] Computed response: %s", response)

	if err := c.writeSentence("/login", fmt.Sprintf("=name=%s", c.username), fmt.Sprintf("=response=%s", response)); err != nil {
		return fmt.Errorf("challenge response send: %w", err)
	}

	sentenceType, words, err = c.readSentence()
	if err != nil {
		return fmt.Errorf("challenge response read: %w", err)
	}
	c.log("[CHALLENGE] Response: %s %v", sentenceType, words)

	if sentenceType == "!done" {
		c.log("[CHALLENGE] LOGIN SUCCESS via SHA1 challenge-response!")
		return nil
	}

	msg := extractMessage(words)
	return fmt.Errorf("challenge login failed: %s", msg)
}

func extractMessage(words []string) string {
	for _, w := range words {
		if strings.HasPrefix(w, "=message=") {
			return strings.TrimPrefix(w, "=message=")
		}
	}
	return strings.Join(words, ", ")
}

func (c *APIConnection) Command(cmd string, attrs ...string) ([]map[string]string, error) {
	c.log("")
	c.log("[CMD] Executing: %s", cmd)

	words := []string{cmd}
	words = append(words, attrs...)
	if err := c.writeSentence(words...); err != nil {
		return nil, err
	}

	var results []map[string]string

	for {
		sentenceType, wordParts, err := c.readSentence()
		if err != nil {
			return results, fmt.Errorf("read response: %w", err)
		}

		switch sentenceType {
		case "!re":
			entry := make(map[string]string)
			for _, w := range wordParts {
				if strings.HasPrefix(w, "=") {
					parts := strings.SplitN(w[1:], "=", 2)
					if len(parts) == 2 {
						entry[parts[0]] = parts[1]
					}
				}
			}
			results = append(results, entry)

		case "!done":
			c.log("[CMD] %s completed (%d results)", cmd, len(results))
			return results, nil

		case "!trap":
			msg := extractMessage(wordParts)
			c.log("[CMD] TRAP: %s", msg)
			return results, fmt.Errorf("routeros error: %s", msg)

		case "!fatal":
			msg := extractMessage(wordParts)
			c.log("[CMD] FATAL: %s", msg)
			return results, fmt.Errorf("routeros fatal: %s", msg)

		default:
			c.log("[CMD] Unknown sentence: %s", sentenceType)
		}
	}
}
