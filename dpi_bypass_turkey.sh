#!/bin/bash
# Turkiye icin DPI bypass kurulumu (Pop!_OS / Ubuntu / Debian)
# Zapret (nfqws) + dnscrypt-proxy (sifrelenmis DNS) + sistem tepsisi
#
# Kullanim: sudo bash dpi_bypass_turkey.sh [install|remove|status|help]

set -e

ZAPRET_DIR="/opt/zapret"
SERVICE_NAME="zapret-turkey"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
DNSCRYPT_CONF="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
RESOLVED_OVERRIDE="/etc/systemd/resolved.conf.d/dnscrypt.conf"
CTL_SCRIPT="/usr/local/bin/dpi-bypass-ctl"
POLKIT_POLICY="/usr/share/polkit-1/actions/com.dpi.bypass.policy"
TRAY_SCRIPT="/usr/local/bin/dpi-bypass-tray"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")
AUTOSTART_DIR="$REAL_HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/dpi-bypass-tray.desktop"

if [ "$EUID" -ne 0 ]; then
    echo "Bu scripti root olarak calistirin: sudo bash $0"
    exit 1
fi

remove_service() {
    echo "Tamamen kaldiriliyor..."

    # Stop and remove zapret
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SERVICE_FILE"

    # Remove iptables rules
    iptables -t mangle -D POSTROUTING -p tcp -m multiport --dports 80,443 -j NFQUEUE --queue-num 200 2>/dev/null || true
    iptables -t mangle -D POSTROUTING -p udp --dport 443 -j NFQUEUE --queue-num 201 2>/dev/null || true

    # Restore DNS
    rm -f "$RESOLVED_OVERRIDE"
    systemctl restart systemd-resolved 2>/dev/null || true
    systemctl stop dnscrypt-proxy 2>/dev/null || true
    systemctl disable dnscrypt-proxy 2>/dev/null || true

    # Remove tray components
    rm -f "$CTL_SCRIPT" "$POLKIT_POLICY" "$TRAY_SCRIPT" "$AUTOSTART_FILE"

    # Kill running tray
    pkill -f "dpi-bypass-tray" 2>/dev/null || true

    systemctl daemon-reload
    echo "Kaldirma tamamlandi."
}

show_status() {
    echo "=== Zapret DPI Bypass ==="
    systemctl status "$SERVICE_NAME" --no-pager 2>/dev/null || echo "Hizmet yuklu degil."
    echo ""
    echo "=== DNSCrypt Proxy ==="
    systemctl status dnscrypt-proxy --no-pager 2>/dev/null || echo "DNSCrypt yuklu degil."
    echo ""
    echo "=== Tray Indicator ==="
    if pgrep -f "dpi-bypass-tray" > /dev/null 2>&1; then
        echo "Tray calisiyor."
    else
        echo "Tray calismiyor."
    fi
}

install_service() {
    echo "================================================="
    echo " Turkiye DPI Bypass Kurulumu"
    echo " Zapret + Sifrelenmis DNS + Sistem Tepsisi"
    echo "================================================="
    echo ""

    # ---- 1. Dependencies ----
    echo "[1/8] Bagimliliklar yukleniyor..."
    apt-get update -qq
    apt-get install -y -qq git build-essential libnetfilter-queue-dev libcap-dev \
        zlib1g-dev libmnl-dev iptables dnscrypt-proxy gir1.2-appindicator3-0.1 \
        python3 python3-gi > /dev/null

    # ---- 2. Zapret ----
    echo "[2/8] Zapret indiriliyor..."
    if [ -d "$ZAPRET_DIR" ]; then
        cd "$ZAPRET_DIR" && git pull -q
    else
        git clone --depth 1 https://github.com/bol-van/zapret.git "$ZAPRET_DIR"
    fi

    # ---- 3. Build nfqws ----
    echo "[3/8] nfqws derleniyor..."
    cd "$ZAPRET_DIR/nfq"
    make clean > /dev/null 2>&1 || true
    make
    if [ ! -f "$ZAPRET_DIR/nfq/nfqws" ]; then
        echo "HATA: nfqws derlenemedi!"
        exit 1
    fi

    # ---- 4. DNSCrypt ----
    echo "[4/8] Sifrelenmis DNS ayarlaniyor..."
    systemctl stop dnscrypt-proxy.socket 2>/dev/null || true
    systemctl disable dnscrypt-proxy.socket 2>/dev/null || true

    cat > "$DNSCRYPT_CONF" <<'DNSEOF'
listen_addresses = ['127.0.2.1:53']
server_names = ['cloudflare', 'google', 'quad9-dnscrypt-ip4-filter-pri']
ipv4_servers = true
ipv6_servers = false
dnscrypt_servers = true
doh_servers = true
require_dnssec = false
require_nolog = true
require_nofilter = true
force_tcp = false
timeout = 5000
keepalive = 30
fallback_resolvers = ['1.1.1.1:53', '8.8.8.8:53']
ignore_system_dns = true

[query_log]
  file = '/var/log/dnscrypt-proxy/query.log'

[nx_log]
  file = '/var/log/dnscrypt-proxy/nx.log'

[sources]
  [sources.'public-resolvers']
  url = 'https://download.dnscrypt.info/resolvers-list/v2/public-resolvers.md'
  cache_file = '/var/cache/dnscrypt-proxy/public-resolvers.md'
  minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
  refresh_delay = 72
  prefix = ''
DNSEOF

    systemctl restart dnscrypt-proxy.service
    systemctl enable dnscrypt-proxy.service

    # ---- 5. System DNS ----
    echo "[5/8] Sistem DNS ayarlari guncelleniyor..."
    mkdir -p /etc/systemd/resolved.conf.d
    cat > "$RESOLVED_OVERRIDE" <<'RESEOF'
[Resolve]
DNS=127.0.2.1
DNSStubListener=yes
Domains=~.
RESEOF
    systemctl restart systemd-resolved

    # ---- 6. Zapret Service ----
    echo "[6/8] DPI bypass hizmeti olusturuluyor..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Turkiye icin DPI bypass (Zapret nfqws)
After=network.target dnscrypt-proxy.service

[Service]
Type=simple
ExecStartPre=/sbin/iptables -t mangle -A POSTROUTING -p tcp -m multiport --dports 80,443 -j NFQUEUE --queue-num 200
ExecStartPre=/sbin/iptables -t mangle -A POSTROUTING -p udp --dport 443 -j NFQUEUE --queue-num 201
ExecStart=${ZAPRET_DIR}/nfq/nfqws --qnum=200 --dpi-desync=fake,split2 --dpi-desync-ttl=5 --dpi-desync-autottl=2 --dpi-desync-fooling=md5sig --dpi-desync-split-pos=1
ExecStopPost=/sbin/iptables -t mangle -D POSTROUTING -p tcp -m multiport --dports 80,443 -j NFQUEUE --queue-num 200
ExecStopPost=/sbin/iptables -t mangle -D POSTROUTING -p udp --dport 443 -j NFQUEUE --queue-num 201
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"

    # ---- 7. Tray Control Helper + Polkit ----
    echo "[7/8] Sistem tepsisi kuruluyor..."

    cat > "$CTL_SCRIPT" <<'CTLEOF'
#!/bin/bash
case "$1" in
    stop)
        systemctl stop zapret-turkey
        systemctl stop dnscrypt-proxy
        ;;
    start)
        systemctl start dnscrypt-proxy
        systemctl start zapret-turkey
        ;;
    restart)
        systemctl restart dnscrypt-proxy
        systemctl restart zapret-turkey
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac
CTLEOF
    chmod 755 "$CTL_SCRIPT"

    cat > "$POLKIT_POLICY" <<'POLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="com.dpi.bypass.control">
    <description>DPI Bypass Kontrol</description>
    <message>DPI Bypass servisini yonetmek icin yetki gerekiyor</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/dpi-bypass-ctl</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>
POLEOF

    # ---- 8. Tray Python App + Autostart ----
    echo "[8/8] Tray uygulamasi olusturuluyor..."

    cat > "$TRAY_SCRIPT" <<'TRAYEOF'
#!/usr/bin/env python3
"""System tray indicator for Turkiye DPI Bypass"""

import gi
import subprocess

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, AppIndicator3, GLib

SERVICE_ZAPRET = "zapret-turkey"
SERVICE_DNS = "dnscrypt-proxy"
APP_ID = "dpi-bypass-turkey"

class DPIBypassIndicator:
    def __init__(self):
        self.indicator = AppIndicator3.Indicator.new(
            APP_ID, "network-vpn",
            AppIndicator3.IndicatorCategory.SYSTEM_SERVICES
        )
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.build_menu()
        self.update_status()
        GLib.timeout_add_seconds(5, self.update_status)

    def is_active(self, service):
        try:
            r = subprocess.run(["systemctl", "is-active", service],
                               capture_output=True, text=True, timeout=3)
            return r.stdout.strip() == "active"
        except Exception:
            return False

    def build_menu(self):
        self.menu = Gtk.Menu()
        self.status_item = Gtk.MenuItem(label="Durum: kontrol ediliyor...")
        self.status_item.set_sensitive(False)
        self.menu.append(self.status_item)
        self.menu.append(Gtk.SeparatorMenuItem())
        self.toggle_item = Gtk.MenuItem(label="Baslat / Durdur")
        self.toggle_item.connect("activate", self.toggle_service)
        self.menu.append(self.toggle_item)
        self.restart_item = Gtk.MenuItem(label="Yeniden Baslat")
        self.restart_item.connect("activate", self.restart_service)
        self.menu.append(self.restart_item)
        self.menu.append(Gtk.SeparatorMenuItem())
        quit_item = Gtk.MenuItem(label="Kapat")
        quit_item.connect("activate", self.quit)
        self.menu.append(quit_item)
        self.menu.show_all()
        self.indicator.set_menu(self.menu)

    def update_status(self):
        zapret_on = self.is_active(SERVICE_ZAPRET)
        dns_on = self.is_active(SERVICE_DNS)
        if zapret_on and dns_on:
            self.status_item.set_label("\u2713 DPI Bypass: Aktif")
            self.indicator.set_icon_full("network-vpn", "DPI Bypass Aktif")
            self.toggle_item.set_label("Durdur")
        elif zapret_on or dns_on:
            self.status_item.set_label("\u26a0 DPI Bypass: Kismi")
            self.indicator.set_icon_full("network-vpn-acquiring", "DPI Bypass Kismi")
            self.toggle_item.set_label("Durdur")
        else:
            self.status_item.set_label("\u2717 DPI Bypass: Kapali")
            self.indicator.set_icon_full("network-vpn-disabled", "DPI Bypass Kapali")
            self.toggle_item.set_label("Baslat")
        return True

    def run_ctl(self, action):
        try:
            subprocess.Popen(["pkexec", "/usr/local/bin/dpi-bypass-ctl", action],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            GLib.timeout_add_seconds(3, self.update_status)
        except Exception as e:
            d = Gtk.MessageDialog(message_type=Gtk.MessageType.ERROR,
                                  buttons=Gtk.ButtonsType.OK, text=f"Hata: {e}")
            d.run()
            d.destroy()

    def toggle_service(self, _):
        self.run_ctl("stop" if self.is_active(SERVICE_ZAPRET) else "start")

    def restart_service(self, _):
        self.run_ctl("restart")

    def quit(self, _):
        Gtk.main_quit()

if __name__ == "__main__":
    DPIBypassIndicator()
    Gtk.main()
TRAYEOF
    chmod 755 "$TRAY_SCRIPT"

    # Autostart desktop entry
    mkdir -p "$AUTOSTART_DIR"
    cat > "$AUTOSTART_FILE" <<'DESKEOF'
[Desktop Entry]
Type=Application
Name=DPI Bypass Tray
Comment=Turkiye DPI Bypass kontrol paneli
Exec=/usr/local/bin/dpi-bypass-tray
Icon=network-vpn
Terminal=false
Categories=Network;
X-GNOME-Autostart-enabled=true
DESKEOF
    chown "$REAL_USER":"$REAL_USER" "$AUTOSTART_FILE"

    # Launch tray for current user
    pkill -f "dpi-bypass-tray" 2>/dev/null || true
    su - "$REAL_USER" -c "nohup /usr/local/bin/dpi-bypass-tray > /dev/null 2>&1 &" || true

    echo ""
    echo "================================================="
    echo " Kurulum tamamlandi!"
    echo "================================================="
    echo ""
    echo "=== Zapret DPI Bypass ==="
    systemctl status "$SERVICE_NAME" --no-pager
    echo ""
    echo "=== DNSCrypt Proxy ==="
    systemctl status dnscrypt-proxy --no-pager
    echo ""
    echo "============================================="
    echo " Tek dosya ile baska bilgisayara kurulum:"
    echo "   sudo bash install_dpi_bypass_turkey.sh"
    echo ""
    echo " Tamamen kaldirmak icin:"
    echo "   sudo bash install_dpi_bypass_turkey.sh remove"
    echo ""
    echo " Durum kontrolu:"
    echo "   sudo bash install_dpi_bypass_turkey.sh status"
    echo "============================================="
}

show_help() {
    echo "============================================="
    echo " Turkiye DPI Bypass - Yardim"
    echo "============================================="
    echo ""
    echo "  Kur:            sudo bash $0 install"
    echo "  Kaldir:         sudo bash $0 remove"
    echo "  Durum:          sudo bash $0 status"
    echo "  Yardim:         bash $0 help"
    echo ""
    echo " Kurulum sonrasi sistem tepsisinden"
    echo " baslat/durdur yapabilirsiniz."
    echo "============================================="
}

case "${1:-install}" in
    install)  install_service ;;
    remove)   remove_service ;;
    status)   show_status ;;
    help)     show_help ;;
    *)
        echo "Kullanim: sudo bash $0 [install|remove|status|help]"
        exit 1
        ;;
esac
