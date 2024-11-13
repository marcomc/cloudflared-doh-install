#!/usr/bin/env bats

setup() {
  chmod +x ./cloudflared-doh-install.sh
}

teardown() {
  sudo ./cloudflared-doh-install.sh --uninstall
}

@test "Install with custom port" {
  run sudo ./cloudflared-doh-install.sh --port 5353
  [ "$status" -eq 0 ]
  run dig @localhost -p 5353 txt debug.opendns.com
  [ "$status" -eq 0 ]
}