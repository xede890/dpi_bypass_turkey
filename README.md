# DPI Bypass for Turkey / Türkiye için DPI Bypass

A single-script installer that sets up [Zapret](https://github.com/bol-van/zapret) (nfqws) + encrypted DNS (dnscrypt-proxy) + a system tray indicator to bypass DPI-based internet censorship in Turkey.

Tek bir script ile [Zapret](https://github.com/bol-van/zapret) (nfqws) + şifrelenmiş DNS (dnscrypt-proxy) + sistem tepsisi göstergesi kurulumu yaparak Türkiye'deki DPI tabanlı internet sansürünü aşmanızı sağlar.

---

## Table of Contents / İçindekiler

- [English](#english)
  - [Supported Platforms](#supported-platforms)
  - [Dependencies](#dependencies)
  - [Usage](#usage)
  - [How It Works](#how-it-works)
- [Türkçe](#türkçe)
  - [Desteklenen Platformlar](#desteklenen-platformlar)
  - [Bağımlılıklar](#bağımlılıklar)
  - [Kullanım](#kullanım)
  - [Nasıl Çalışır](#nasıl-çalışır)

---

## English

### Supported Platforms

| Distro | Status |
|--------|--------|
| Ubuntu (20.04+) | Supported |
| Pop!_OS (22.04+) | Supported |
| Debian (11+) | Supported |
| Linux Mint | Should work (untested) |
| elementary OS | Should work (untested) |
| Zorin OS | Should work (untested) |
| Other Debian/Ubuntu derivatives | Should work (untested) |

**Requirements:**
- `apt` package manager
- `systemd` (with `systemd-resolved`)
- `iptables`
- GTK 3 desktop environment (for the tray indicator)

> **Note:** Fedora, Arch, openSUSE, and other non-Debian-based distros are **not supported**.

### Dependencies

The script automatically installs the following packages via `apt`:

| Package | Purpose |
|---------|---------|
| `git` | Clone the Zapret repository |
| `build-essential` | Compile nfqws from source |
| `libnetfilter-queue-dev` | Netfilter queue library (build) |
| `libcap-dev` | POSIX capabilities library (build) |
| `zlib1g-dev` | Compression library (build) |
| `libmnl-dev` | Minimalistic netlink library (build) |
| `iptables` | Redirect packets to nfqws |
| `dnscrypt-proxy` | Encrypted DNS resolution |
| `gir1.2-appindicator3-0.1` | System tray indicator |
| `python3` | Tray application runtime |
| `python3-gi` | GTK bindings for the tray app |

### Usage

| Action | Command |
|--------|---------|
| Install | `sudo bash dpi_bypass_turkey.sh` |
| Install (explicit) | `sudo bash dpi_bypass_turkey.sh install` |
| Remove | `sudo bash dpi_bypass_turkey.sh remove` |
| Check status | `sudo bash dpi_bypass_turkey.sh status` |
| Help | `bash dpi_bypass_turkey.sh help` |

After installation, a system tray icon appears allowing you to start, stop, or restart the service without the terminal.

### How It Works

1. **Zapret (nfqws)** — Intercepts outgoing TCP (ports 80, 443) and UDP (port 443) traffic via `iptables` NFQUEUE and applies DPI desynchronization techniques (fake packets, TTL manipulation, split segments).
2. **dnscrypt-proxy** — Resolves DNS queries over encrypted channels (DNSCrypt / DoH) using Cloudflare, Google, and Quad9 servers, preventing DNS-level blocking.
3. **systemd-resolved** — Configured to forward all DNS queries to dnscrypt-proxy at `127.0.2.1:53`.
4. **System tray indicator** — A lightweight Python/GTK app that shows the current bypass status and lets you toggle the service via polkit authentication.

---

## Türkçe

### Desteklenen Platformlar

| Dağıtım | Durum |
|----------|-------|
| Ubuntu (20.04+) | Destekleniyor |
| Pop!_OS (22.04+) | Destekleniyor |
| Debian (11+) | Destekleniyor |
| Linux Mint | Çalışmalı (test edilmedi) |
| elementary OS | Çalışmalı (test edilmedi) |
| Zorin OS | Çalışmalı (test edilmedi) |
| Diğer Debian/Ubuntu türevleri | Çalışmalı (test edilmedi) |

**Gereksinimler:**
- `apt` paket yöneticisi
- `systemd` (`systemd-resolved` ile birlikte)
- `iptables`
- GTK 3 masaüstü ortamı (tepsi göstergesi için)

> **Not:** Fedora, Arch, openSUSE ve diğer Debian tabanlı olmayan dağıtımlar **desteklenmemektedir**.

### Bağımlılıklar

Script aşağıdaki paketleri `apt` ile otomatik olarak yükler:

| Paket | Amaç |
|-------|------|
| `git` | Zapret deposunu klonlamak |
| `build-essential` | nfqws'yi kaynaktan derlemek |
| `libnetfilter-queue-dev` | Netfilter kuyruk kütüphanesi (derleme) |
| `libcap-dev` | POSIX yetenek kütüphanesi (derleme) |
| `zlib1g-dev` | Sıkıştırma kütüphanesi (derleme) |
| `libmnl-dev` | Minimalist netlink kütüphanesi (derleme) |
| `iptables` | Paketleri nfqws'ye yönlendirmek |
| `dnscrypt-proxy` | Şifrelenmiş DNS çözümlemesi |
| `gir1.2-appindicator3-0.1` | Sistem tepsisi göstergesi |
| `python3` | Tepsi uygulaması çalışma ortamı |
| `python3-gi` | Tepsi uygulaması için GTK bağlantıları |

### Kullanım

| İşlem | Komut |
|-------|-------|
| Kurulum | `sudo bash dpi_bypass_turkey.sh` |
| Kurulum (açık) | `sudo bash dpi_bypass_turkey.sh install` |
| Kaldırma | `sudo bash dpi_bypass_turkey.sh remove` |
| Durum kontrolü | `sudo bash dpi_bypass_turkey.sh status` |
| Yardım | `bash dpi_bypass_turkey.sh help` |

Kurulumdan sonra sistem tepsisinde bir simge belirir. Bu simge ile terminale gerek kalmadan servisi başlatabilir, durdurabilir veya yeniden başlatabilirsiniz.

### Nasıl Çalışır

1. **Zapret (nfqws)** — Giden TCP (80, 443 portları) ve UDP (443 portu) trafiğini `iptables` NFQUEUE ile yakalar ve DPI desenkronizasyon teknikleri (sahte paketler, TTL manipülasyonu, bölünmüş segmentler) uygular.
2. **dnscrypt-proxy** — DNS sorgularını Cloudflare, Google ve Quad9 sunucuları üzerinden şifrelenmiş kanallarla (DNSCrypt / DoH) çözümleyerek DNS seviyesindeki engellemeleri önler.
3. **systemd-resolved** — Tüm DNS sorgularını `127.0.2.1:53` adresindeki dnscrypt-proxy'ye yönlendirecek şekilde yapılandırılır.
4. **Sistem tepsisi göstergesi** — Bypass durumunu gösteren ve polkit kimlik doğrulaması ile servisi açıp kapatmanızı sağlayan hafif bir Python/GTK uygulaması.

---

## License / Lisans

This script is provided as-is for educational and personal use. Zapret is maintained by [bol-van](https://github.com/bol-van/zapret) under its own license.

Bu script eğitim ve kişisel kullanım için olduğu gibi sunulmaktadır. Zapret, [bol-van](https://github.com/bol-van/zapret) tarafından kendi lisansı altında geliştirilmektedir.
