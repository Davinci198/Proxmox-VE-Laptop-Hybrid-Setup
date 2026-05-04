# 💻 Proxmox VE Laptop Hybrid Optimizer (v1.7.1 - Trixie Edition)

[Romanian version below]

Transform your laptop into a virtualization beast with **Proxmox 9**, optimized for extreme **WiFi performance**, low latency, and a hybrid workflow.

> **Update v1.7.1:** Optimized for Debian Trixie (Debian 13). Validated performance: **160 Mbps** download within VMs and stable latency of **~10ms**.

## 🌟 Key Features (v1.7.1 Turbo)

- **WiFi Hardened Networking:** Uses `NetworkManager` with strict stability policies. Includes a **WiFi Watchdog** (systemd service) that monitors connectivity and automatically resets the WiFi interface if pings to Google DNS fail.
- **Top Speed (160 Mbps):** Optimized configuration for USB Passthrough and disabled Power Management on the WiFi card to achieve maximum throughput.
- **Proxmox 9 Ready:** Integrated patch to remove the "No Subscription" nag and automated setup for **Debian Trixie (Testing)** repositories.
- **Thorium Turbo Mode:** Automatically installs the Thorium browser (AVX optimized) and moves the cache folder to a **RAM disk (/tmp)** to protect the SSD and provide near-instant browsing.
- **CPU Pinning (Core Isolation):** Dedicates cores 4-7 exclusively to Virtual Machines via `taskset`, leaving cores 0-3 free for a lag-free Host interface (Cinnamon) and background processes.
- **ZRAM & SSD Protection:** Implements ZRAM with the `zstd` algorithm and `swappiness=100`. Includes automated `fstrim` to maintain long-term SSD health.
- **Automated NAT Bridge (vmbr1):** Integrated `dnsmasq` server on a private bridge (`10.10.10.1`), providing instant internet and DHCP IPs to any connected VM.

---

# 💻 Proxmox VE Laptop Hybrid Optimizer (v1.7.1 - Română)

Transformă-ți laptopul într-o bestie de virtualizare cu **Proxmox 9**, optimizat pentru performanță extremă pe **WiFi**, latență minimă și workflow hibrid.

## 🚀 Instalare / Installation

1. Install a fresh Proxmox VE on your laptop.
2. Clone the repo and edit `setup.sh` with your credentials:
   ```bash
   SSID1="CASA CECILIA 5G"
   WIFI_PASS="CASACECILIA"
   USER_NAME="dani"
   ```
3. Run as **ROOT**:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
4. **Reboot:** Your system will automatically boot into the Cinnamon GUI.

---
*Maintained and Optimized by: [Davinci198](https://github.com/Davinci198)*
