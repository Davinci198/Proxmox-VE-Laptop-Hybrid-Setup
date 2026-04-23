# 💻 Proxmox VE Laptop Hybrid Optimizer (v1.1)

Transformă-ți laptopul într-un nod Proxmox de înaltă performanță cu **WiFi WAN**, **NAT Routing** și **Desktop Environment** integrat.

Acest proiect reprezintă o soluție completă pentru utilizatorii care rulează Proxmox VE pe laptop (optimizat pentru seria **ASUS ROG** și hardware similar). Rezolvă punctele critice ale virtualizării pe laptop: bridge-ul WiFi, consumul ridicat de RAM și managementul termic.

## 🌟 Caracteristici Cheie (v1.1 Turbo)

- **WiFi as WAN (NAT Architecture):** Proxmox nu suportă nativ bridging pe WiFi. Acest script utilizează `NetworkManager` și `IPTables NAT` pentru a ruta internetul de la placa wireless către VM-uri.
- **Automated VM Networking (vmbr1):** Server `dnsmasq` integrat care oferă IP-uri automate (DHCP) oricărui VM conectat la bridge-ul `vmbr1`. Zero configurare manuală în Guest!
- **Hybrid Desktop (Cinnamon):** Instalează mediul grafic Cinnamon pe Host, permițându-ți să folosești laptopul ca "daily driver" în timp ce VM-urile rulează stabil în background.
- **CPU Pinning & Isolation:** Tehnologie de izolare a nucleelor (Pinning). Nucleele 4-7 sunt dedicate VM-urilor, lăsând nucleele 0-3 libere pentru fluiditatea sistemului Host (Cinnamon/Browser).
- **ZRAM & SSD Protection:** Implementare ZRAM cu algoritm `zstd` și `swappiness=100`. Reduce uzura SSD-ului și optimizează cei 16GB RAM pentru load mare.
- **GPU Power Optimization:** Identifică și blochează (blacklist) GPU-ul NVIDIA (ideal pentru unitățile defecte sau pentru economisirea energiei), forțând sistemul să ruleze eficient pe grafica integrată Intel.
- **EFI Stability Fix:** Rezolvă problema montării `/boot/efi` pe laptopurile ASUS, asigurând persistența bootloader-ului după update-uri de kernel.

## ⚠️ Atenționări Importante (Disclaimer)

- **Utilizare:** Proiectat pentru Home-Lab și medii de dezvoltare. Nu este recomandat pentru medii critice de tip Datacenter.
- **Modificări de Sistem:** Scriptul modifică parametrii GRUB, regulile IPTables și reîmprospătează `initramfs`. 
- **Acces Web UI:** După reboot, interfața web Proxmox (port 8006) va fi accesibilă prin **IP-ul primit de placa WiFi**. Bridge-ul `vmbr0` rămâne în mod manual (fără IP) pentru conexiuni LAN viitoare.

## 🚀 Instalare și Utilizare

1. Instalează Proxmox VE "curat" pe laptop.
2. Clonează repo-ul și editează fișierul `setup.sh` pentru a introduce datele tale:
   ```bash
   SSID1="Numele_WiFi"
   PASS="Parola_WiFi"
   USER_NAME="utilizatorul_tau"
   ```
3. Rulează ca **ROOT**:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
4. **Reboot:** Sistemul va porni automat în interfața grafică Cinnamon.

## 💻 Configurație Recomandată VM

Pentru a obține latență minimă și performanță maximă:
- **Network:** Folosește Bridge `vmbr1` (Model: **VirtIO**).
- **Display:** Folosește **SPICE (qxl)** pentru cea mai fluidă experiență video.
- **Processor:** Setează Type pe **host** (pentru a expune instrucțiunile AES/AVX către VM).
- **Disk:** Folosește **SCSI** cu controller **VirtIO SCSI single** și activează **io_uring**.

---
*Mentenanță și Optimizare: [Davinci198](https://github.com)*

# 💻 Proxmox VE Laptop Hybrid Optimizer (v1.1)

Turn your laptop into a high-performance Proxmox node featuring **WiFi WAN**, **NAT Routing**, and a built-in **Desktop Environment**.

This project is an all-in-one solution for users running Proxmox VE on a laptop (specifically optimized for **ASUS ROG** series and similar Haswell-era or newer hardware). It solves the most common "laptop-as-a-server" pain points: WiFi bridging, high RAM consumption, and thermal management.

## 🌟 Key Features (v1.1 Turbo)

- **WiFi as WAN (NAT Architecture):** Proxmox does not natively support bridging over WiFi. This script uses `NetworkManager` and `IPTables NAT` to route internet from your wireless card to your Virtual Machines.
- **Automated VM Networking (vmbr1):** Integrated `dnsmasq` server provides automatic DHCP IP addresses to any VM connected to the `vmbr1` bridge. Zero manual configuration in the Guest OS!
- **Hybrid Desktop (Cinnamon):** Installs the Cinnamon Desktop Environment on the Host, allowing you to use your server as a "daily driver" while VMs run stably in the background.
- **CPU Pinning & Isolation:** Advanced core isolation technology. Cores 4-7 are dedicated to VMs, leaving cores 0-3 free for a lag-free Host experience (Cinnamon/Browser).
- **ZRAM & SSD Protection:** Implements ZRAM with the `zstd` algorithm and `swappiness=100`. This reduces SSD wear and optimizes the 16GB RAM for heavy workloads.
- **GPU Power Optimization:** Automatically identifies and blacklists NVIDIA GPUs (ideal for defective units or power saving), forcing the system to run efficiently on Intel Integrated Graphics.
- **EFI Stability Fix:** Solves the `/boot/efi` mounting issue common on ASUS laptops, ensuring bootloader persistence after kernel updates.

## ⚠️ Important Warnings (Disclaimer)

- **Intended Use:** Designed for Home-Lab and development environments. Not recommended for critical Datacenter production.
- **System Changes:** The script modifies GRUB parameters, IPTables rules, and refreshes `initramfs`. 
- **Web UI Access:** After reboot, the Proxmox Web Interface (port 8006) will be accessible via the **WiFi IP address**. The `vmbr0` bridge is left in manual mode (no IP) for future physical LAN connections.

## 🚀 Installation & Usage

1. Install a fresh Proxmox VE on your laptop.
2. Clone this repo and edit the `setup.sh` file to include your credentials:
   ```bash
   SSID1="Your_WiFi_Name"
   PASS="Your_WiFi_Password"
   USER_NAME="your_username"
   ```
3. Run as **ROOT**:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
4. **Reboot:** Your laptop will automatically boot into the Cinnamon GUI.

## 💻 Recommended VM Configuration

To achieve the lowest latency and highest performance:
- **Network:** Use Bridge `vmbr1` (Model: **VirtIO**).
- **Display:** Use **SPICE (qxl)** for the smoothest video experience.
- **Processor:** Set Type to **host** (to expose AES/AVX instructions to the Guest).
- **Disk:** Use **SCSI** with the **VirtIO SCSI single** controller and enable **io_uring**.

---
*Maintained and Optimized by: [Davinci198](https://github.com)*
