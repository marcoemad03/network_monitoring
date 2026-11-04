//go:build !portable

package main

// Without the portable tag there is nothing to unpack, so the rest of the module
// builds and tests without the large package file.
var payload []byte
