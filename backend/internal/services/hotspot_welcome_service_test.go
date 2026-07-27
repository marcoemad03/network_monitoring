package services

import (
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestGenerateHotspotLoginHTMLRouterOSCompatibility(t *testing.T) {
	config := DefaultHotspotWelcomeConfig(uuid.New())
	config.HospitalName = `<script>alert("x")</script>`
	config.Announcements = []string{"Clinic closes at 5 PM"}

	content, err := GenerateHotspotLoginHTML(config)
	if err != nil {
		t.Fatal(err)
	}
	html := string(content)
	for _, expected := range []string{"$(link-login-only)", "$(username)", "$(date)", "$(chap-id)", "/md5.js", "Good morning", "Guest", "Clinic closes at 5 PM", "$(ip)", "$(mac-address)", "$(interface)", "$(session-time-left)"} {
		if !strings.Contains(html, expected) {
			t.Errorf("generated login.html is missing %q", expected)
		}
	}
	if strings.Contains(html, `<script>alert("x")</script>`) {
		t.Error("configuration text was not HTML escaped")
	}
}

func TestGenerateHotspotLoginHTMLDisabled(t *testing.T) {
	config := DefaultHotspotWelcomeConfig(uuid.New())
	config.Enabled = false
	content, err := GenerateHotspotLoginHTML(config)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(content), `<form name="login"`) || !strings.Contains(string(content), "currently unavailable") {
		t.Error("disabled page must not render the login form")
	}
}
