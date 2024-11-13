#!/usr/bin/env bats

setup() {
  chmod +x ./cloudflared-doh-install.sh
}

@test "Install with custom port" {
  run sudo ./cloudflared-doh-install.sh --port 5353
  [ "$status" -eq 0 ]
  run dig @localhost -p 5353 txt debug.opendns.com
  [ "$status" -eq 0 ]
  sudo ./cloudflared-doh-install.sh --uninstall
  [ "$status" -eq 0 ]
}

@test "Invalid parameter shows usage and exits with error code 1" {
  run ./cloudflared-doh-install.sh --invalid-param
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}