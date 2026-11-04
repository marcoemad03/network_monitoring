package services

import (
	"bytes"
	"context"
	"encoding/binary"
	"errors"
	"math/rand"
	"net"
	"strconv"
	"strings"
	"time"
)

// A small read-only SNMP v2c GET, enough to ask a printer or switch what it is.

func berLen(n int) []byte {
	if n < 128 {
		return []byte{byte(n)}
	}
	b := make([]byte, 4)
	binary.BigEndian.PutUint32(b, uint32(n))
	b = bytes.TrimLeft(b, "\x00")
	return append([]byte{0x80 | byte(len(b))}, b...)
}

func berTLV(tag byte, v []byte) []byte {
	return append(append([]byte{tag}, berLen(len(v))...), v...)
}

func berInt(n int) []byte {
	b := make([]byte, 4)
	binary.BigEndian.PutUint32(b, uint32(n))
	for len(b) > 1 && b[0] == 0 && b[1] < 0x80 {
		b = b[1:]
	}
	return berTLV(0x02, b)
}

func berOID(oid string) []byte {
	parts := strings.Split(oid, ".")
	nums := make([]int, len(parts))
	for i, p := range parts {
		nums[i], _ = strconv.Atoi(p)
	}
	out := []byte{byte(nums[0]*40 + nums[1])}
	for _, n := range nums[2:] {
		chunk := []byte{byte(n & 0x7f)}
		for n >>= 7; n > 0; n >>= 7 {
			chunk = append([]byte{byte(n&0x7f) | 0x80}, chunk...)
		}
		out = append(out, chunk...)
	}
	return berTLV(0x06, out)
}

func snmpGetRequest(community string, id int, oids []string) []byte {
	var binds []byte
	for _, oid := range oids {
		binds = append(binds, berTLV(0x30, append(berOID(oid), 0x05, 0x00))...)
	}
	pdu := append(append(append(berInt(id), berInt(0)...), berInt(0)...), berTLV(0x30, binds)...)
	msg := append(append(berInt(1), berTLV(0x04, []byte(community))...), berTLV(0xA0, pdu)...)
	return berTLV(0x30, msg)
}

// berRead returns the tag, the value and what follows it.
func berRead(b []byte) (byte, []byte, []byte, error) {
	if len(b) < 2 {
		return 0, nil, nil, errors.New("short")
	}
	tag, n, off := b[0], int(b[1]), 2
	if n >= 0x80 {
		size := n & 0x7f
		if size == 0 || size > 4 || len(b) < 2+size {
			return 0, nil, nil, errors.New("bad length")
		}
		n = 0
		for _, c := range b[2 : 2+size] {
			n = n<<8 | int(c)
		}
		off = 2 + size
	}
	if n < 0 || len(b) < off+n {
		return 0, nil, nil, errors.New("short value")
	}
	return tag, b[off : off+n], b[off+n:], nil
}

func berOIDString(v []byte) string {
	if len(v) == 0 {
		return ""
	}
	parts := []string{strconv.Itoa(int(v[0]) / 40), strconv.Itoa(int(v[0]) % 40)}
	n := 0
	for _, c := range v[1:] {
		n = n<<7 | int(c&0x7f)
		if c&0x80 == 0 {
			parts = append(parts, strconv.Itoa(n))
			n = 0
		}
	}
	return strings.Join(parts, ".")
}

// parseSNMPResponse returns the answered values by OID, as text. Objects the device
// does not have are left out.
func parseSNMPResponse(b []byte) (map[string]string, error) {
	_, msg, _, err := berRead(b)
	if err != nil {
		return nil, err
	}
	for i := 0; i < 2; i++ { // version, community
		if _, _, msg, err = berRead(msg); err != nil {
			return nil, err
		}
	}
	tag, pdu, _, err := berRead(msg)
	if err != nil {
		return nil, err
	}
	if tag != 0xA2 {
		return nil, errors.New("not a response")
	}
	for i := 0; i < 3; i++ { // id, error, index
		if _, _, pdu, err = berRead(pdu); err != nil {
			return nil, err
		}
	}
	_, binds, _, err := berRead(pdu)
	if err != nil {
		return nil, err
	}
	out := map[string]string{}
	for len(binds) > 0 {
		var bind []byte
		if _, bind, binds, err = berRead(binds); err != nil {
			return out, err
		}
		_, oid, rest, err := berRead(bind)
		if err != nil {
			return out, err
		}
		vtag, val, _, err := berRead(rest)
		if err != nil {
			return out, err
		}
		key := berOIDString(oid)
		switch vtag {
		case 0x04:
			out[key] = strings.TrimSpace(strings.Trim(string(val), "\x00"))
		case 0x02, 0x41, 0x42, 0x43:
			n := int64(0)
			if vtag == 0x02 && len(val) > 0 && val[0]&0x80 != 0 {
				n = -1
			}
			for _, c := range val {
				n = n<<8 | int64(c)
			}
			out[key] = strconv.FormatInt(n, 10)
		case 0x06:
			out[key] = berOIDString(val)
		}
	}
	return out, nil
}

// snmpGet asks one device with the public community. A device without SNMP simply
// does not answer.
func snmpGet(ctx context.Context, ip string, oids []string, timeout time.Duration) (map[string]string, error) {
	var d net.Dialer
	conn, err := d.DialContext(ctx, "udp", net.JoinHostPort(ip, "161"))
	if err != nil {
		return nil, err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(timeout))
	if _, err := conn.Write(snmpGetRequest("public", rand.Intn(1<<30), oids)); err != nil {
		return nil, err
	}
	buf := make([]byte, 4096)
	n, err := conn.Read(buf)
	if err != nil {
		return nil, err
	}
	return parseSNMPResponse(buf[:n])
}
