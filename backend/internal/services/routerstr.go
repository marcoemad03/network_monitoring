package services

import (
	"unicode/utf8"

	"golang.org/x/text/encoding/charmap"
)

// decodeRouterText returns text read from RouterOS as valid UTF-8.
//
// RouterOS stores comments and names as raw bytes. WinBox on an Arabic Windows
// writes them in Windows-1256, which is not valid UTF-8 and would otherwise show
// as replacement characters. Text that is already valid UTF-8 is left alone.
func decodeRouterText(s string) string {
	if s == "" || utf8.ValidString(s) {
		return s
	}
	decoded, err := charmap.Windows1256.NewDecoder().String(s)
	if err != nil {
		return s
	}
	return decoded
}
