package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/pkg/logger"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

func main() {
	// This tool ADDS and then removes test rules on the live router. Never run it
	// against the production router while the hospital is online.
	if os.Getenv("PROBE_ALLOW_ROUTER_WRITE") != "yes" {
		fmt.Println("refusing to run: this probe writes test rules to the router. Set PROBE_ALLOW_ROUTER_WRITE=yes on a lab router to continue.")
		return
	}
	cfg, err := config.Load(0)
	if err != nil {
		fmt.Println("config err:", err)
		return
	}
	logger.Init(cfg.LogLevel, cfg.LogFormat)
	db, err := database.NewPostgresDB(cfg)
	if err != nil {
		fmt.Println("db err:", err)
		return
	}
	defer db.Close()

	var pass, baseURL, username string
	err = db.QueryRow(context.Background(), `SELECT base_url, COALESCE(username,''), COALESCE(encrypted_password,'') FROM vendor_integrations WHERE id='a0000000-0000-0000-0000-000000000001'`).Scan(&baseURL, &username, &pass)
	if err != nil {
		fmt.Println("query err:", err)
		return
	}

	conn := mikrotik.NewAPIConnection("172.16.0.1", 8728, username, pass, 10*time.Second)
	if err := conn.Connect(); err != nil {
		fmt.Println("connect err:", err)
		return
	}
	defer conn.Close()
	if err := conn.Login(); err != nil {
		fmt.Println("login err:", err)
		return
	}

	// Add test entries
	_, _ = conn.Command("/ip/firewall/filter/add", "=chain=forward", "=action=drop", "=comment=nms-marco-test1")
	_, _ = conn.Command("/ip/firewall/filter/add", "=chain=forward", "=action=drop", "=comment=nms-marco-test2")
	_, _ = conn.Command("/ip/firewall/layer7-protocol/add", "=name=nms-marco-l7-test", "=regexp=.*(test\\.com).*", "=comment=nms-marco-l7-test")
	_, _ = conn.Command("/ip/firewall/address-list/add", "=list=nms-marco-plat-test", "=address=1.2.3.4/32", "=comment=nms-marco-plat-test-1.2.3.4-32")
	_, _ = conn.Command("/queue/simple/add", "=name=nms-marco-q-test", "=target=10.0.0.5/32", "=max-limit=1M/2M", "=comment=nms-marco-q-test")

	defer func() {
		// cleanup
		for _, p := range []string{"/ip/firewall/filter", "/ip/firewall/layer7-protocol", "/ip/firewall/address-list", "/queue/simple"} {
			ents, err := conn.Command(p+"/print", "?comment=nms-marco-")
			if err == nil {
				for _, e := range ents {
					_, _ = conn.Command(p+"/remove", "=.id="+e[".id"])
				}
			}
		}
		fmt.Println("cleanup done")
	}()

	fw, err := conn.Command("/ip/firewall/filter/print", "?comment=nms-marco-")
	fmt.Println("=== firewall ?comment=nms-marco- count:", len(fw), "err:", err)
	for _, e := range fw {
		fmt.Printf("  id=%s comment=%q chain=%s action=%s\n", e[".id"], e["comment"], e["chain"], e["action"])
	}

	l7, err := conn.Command("/ip/firewall/layer7-protocol/print", "?comment=nms-marco-")
	fmt.Println("=== layer7 ?comment=nms-marco- count:", len(l7), "err:", err)
	for _, e := range l7 {
		fmt.Printf("  id=%s name=%q comment=%q regexp=%q\n", e[".id"], e["name"], e["comment"], e["regexp"])
	}

	al, err := conn.Command("/ip/firewall/address-list/print", "?comment=nms-marco-")
	fmt.Println("=== address-list ?comment=nms-marco- count:", len(al), "err:", err)
	for _, e := range al {
		fmt.Printf("  id=%s list=%q address=%q comment=%q\n", e[".id"], e["list"], e["address"], e["comment"])
	}

	q, err := conn.Command("/queue/simple/print", "?comment=nms-marco-")
	fmt.Println("=== queue ?comment=nms-marco- count:", len(q), "err:", err)
	for _, e := range q {
		fmt.Printf("  id=%s name=%q target=%q max-limit=%q comment=%q\n", e[".id"], e["name"], e["target"], e["max-limit"], e["comment"])
	}
}
