#!/usr/bin/env bats

setup() {
  chmod +x ./cloudflared-doh-install.sh
}

@test "Test install" {
  run sudo ./cloudflared-doh-install.sh
  [ "$status" -eq 0 ]
}

@test "Verify cloudflared service status" {
  run cloudflared -v
  [ "$status" -eq 0 ]
  run sudo systemctl status cloudflared
  [ "$status" -eq 0 ]
}

@test "Restart cloudflared service" {
    run sudo systemctl restart cloudflared
    [ "$status" -eq 0 ]
    run sudo systemctl status cloudflared
    [ "$status" -eq 0 ]
}

@test "Stop cloudflared service" {
    run sudo systemctl stop cloudflared
    [ "$status" -eq 0 ]
    run sudo systemctl status cloudflared
    [ "$status" -ne 0 ]
}

@test "Start cloudflared service" {
  run sudo systemctl start cloudflared
  [ "$status" -eq 0 ]
}

@test "Test DNS resolution" {
  run dig @localhost -p 5053 txt debug.opendns.com
  [ "$status" -eq 0 ]
}

@test "Test uninstall" {
  run sudo ./cloudflared-doh-install.sh --uninstall
  [ "$status" -eq 0 ]
}