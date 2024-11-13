#!/usr/bin/env bats

setup() {
  chmod +x ./cloudflared-doh-install.sh
  sudo ./cloudflared-doh-install.sh
}

@test "Uninstall cloudflared" {
  run sudo ./cloudflared-doh-install.sh --uninstall
  [ "$status" -eq 0 ]
  
  run command -v cloudflared
  [ "$status" -ne 0 ]
  
  run test -f /etc/systemd/system/cloudflared.service
  [ "$status" -ne 0 ]
  
  run test -d /opt/cloudflared
  [ "$status" -ne 0 ]
  
  run test -f /usr/local/bin/cloudflared
  [ "$status" -ne 0 ]
  
  run test -f /etc/cron.d/cloudflared-update
  [ "$status" -ne 0 ]
}

@test "Verify cloudflared service is stopped" {
  run sudo systemctl status cloudflared
  [ "$status" -ne 0 ]
}
