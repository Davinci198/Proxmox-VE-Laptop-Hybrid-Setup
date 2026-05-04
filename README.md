# 💻 Proxmox VE Laptop Hybrid Optimizer (v1.7.1 - Trixie Edition)

Transformă-ți laptopul într-o bestie de virtualizare cu **Proxmox 9**, optimizat pentru performanță extremă pe **WiFi**, latență minimă și workflow hibrid.

> **Update v1.7.1:** Optimizat pentru Debian Trixie (Debian 13), performanțe validate de **160 Mbps** download în VM și latență stabilă de **~10ms**.

## 🌟 Caracteristici Cheie (v1.7.1 Turbo)

- **WiFi Hardened Networking:** Utilizează `NetworkManager` cu politici stricte de stabilitate. Include un **WiFi Watchdog** (serviciu systemd) care monitorizează conexiunea și o resetează automat dacă ping-ul către Google DNS eșuează.
- **Viteză de Top (160 Mbps):** Configurație optimizată pentru USB Passthrough și dezactivarea managementului de energie (Power Management Off) pe placa WiFi pentru a atinge viteze maxime.
- **Proxmox 9 Ready:** Patch integrat pentru eliminarea mesajului "No Subscription" și configurare automată pentru repository-urile **Debian Trixie (Testing)**.
- **Thorium Turbo Mode:** Instalează automat browserul Thorium (AVX optimized) și îi mută folderul de cache în **RAM disk (/tmp)** pentru a proteja SSD-ul și a oferi navigare instantanee.
- **CPU Pinning (Core Isolation):** Dedică nucleele 4-7 exclusiv mașinilor virtuale prin `taskset`, lăsând nucleele 0-3 libere pentru fluiditatea interfeței Cinnamon și a proceselor Host.
- **ZRAM & SSD Protection:** Implementare ZRAM cu algoritm `zstd` și `swappiness=100`. Include activarea automată `fstrim` pentru menținerea performanței SSD-ului pe termen lung.
- **NAT Bridge Automat (vmbr1):** Server `dnsmasq` integrat pe bridge-ul privat (`10.10.10.1`), oferind internet și IP-uri DHCP instantaneu oricărui VM conectat.

## ⚠️ Schimbări Majore de Stabilitate

- **Kernel Lock:** Scriptul aplică `apt-mark hold` pe pachetele de kernel Proxmox pentru a preveni stricarea driverelor WiFi la update-uri nesupravegheate.
- **DNS Imutabil:** Fișierul `/etc/resolv.conf` este configurat cu Google și Cloudflare DNS și blocat cu atributul `+i` (immutable) pentru a preveni suprascrierea lui de către ISP.
- **GPU Optimization:** Blacklist automat pentru driverele NVIDIA pentru a forța rularea eficientă pe grafica integrată Intel.

## 🚀 Instalare și Utilizare

1. Instalează Proxmox VE "curat" pe laptop.
2. Clonează repo-ul și editează fișierul `setup.sh` cu datele tale:
   ```bash
   SSID1="CASA CECILIA 5G"
   WIFI_PASS="CASACECILIA"
   USER_NAME="dani"
   ```
3. Rulează ca **ROOT**:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
4. **Reboot:** Sistemul va porni automat în mediul grafic Cinnamon.

## 💻 Configurație Recomandată VM (v1.7.1)

- **Network:** Bridge `vmbr1` (Model: **VirtIO**).
- **Processor:** Type pe **host** și alocă **4 nuclee** (corectat pentru pinning pe 4-7).
- **Disk:** SCSI cu controller **VirtIO SCSI single**, activat **Discard** și **io_uring**.
- **Update Browser:** Rulează periodic `/usr/local/bin/update-thorium`.

---
*Mentenanță și Optimizare: [Davinci198](https://github.com/Davinci198)*
