# Proxmox-VE-Laptop-Hybrid-Setup

Proxmox VE Laptop Hybrid Optimizer
Turn your laptop into a high-performance Proxmox node with WiFi WAN, NAT, and Desktop Environment
This script is an all-in-one solution for users running Proxmox VE on a laptop (optimized for ASUS ROG series and similar hardware). It solves the most common "laptop-as-a-server" pain points: WiFi bridging, high RAM consumption, and power management.
🌟 Key Features

    WiFi as WAN: Proxmox doesn't natively support bridging over WiFi. This script uses NetworkManager and IPTables NAT to route internet from your WiFi card to your Virtual Machines.
    Automated VM Networking (vmbr1): Integrated dnsmasq server provides automatic DHCP IP addresses to any VM connected to the vmbr1 bridge. No manual IP configuration needed!
    Hybrid Desktop (Cinnamon): Installs a lightweight Cinnamon Desktop on the host, allowing you to use your server as a daily-driver laptop while VMs run in the background.
    GPU Power Saving (NVIDIA Blacklist): Automatically identifies and blacklists NVIDIA GPUs to save power and RAM, leaving the host to run cool on Intel Integrated Graphics (ready for GPU Passthrough later).
    Proxmox Repo Fix: Switches to the official "No-Subscription" repositories and removes the enterprise warnings.
    Power Optimization: Installs and configures TLP to manage battery life and CPU thermals effectively.

⚠️ Important Warnings (Disclaimer)

    Intended Use: Designed for Home-Lab/Development setups. Not recommended for production datacenter environments.
    Kernel/GRUB Changes: The script modifies GRUB parameters and refreshes initramfs. While safe for most modern Intel laptops, ensure you have a backup of your data.
    Web UI Access: After reboot, the Proxmox Web Interface (port 8006) will be accessible via the WiFi IP address. The vmbr0 bridge is left in manual mode without an IP.


    Installation & Usage

    Download the script onto a fresh Proxmox VE installation.
    Edit your config at the top of the file:
    bash

    SSID1="Your_WiFi_Name"
    PASS="Your_WiFi_Password"
    USER_NAME="your_username"

    Folosește codul cu precauție.

Run as ROOT:
bash

chmod +x proxmox_laptop_setup.sh
sudo ./proxmox_laptop_setup.sh

Folosește codul cu precauție.
Reboot: Your laptop will boot into the Cinnamon GUI automatically.

Recommended VM Configuration
To get the best performance out of this setup:

    Network: Use Bridge vmbr1 (Model: VirtIO). VMs will get internet instantly via DHCP.
    Display: Use SPICE (qxl) for the smoothest experience.
    Processor: Set Type to host to utilize all CPU instruction sets (AES, AVX, etc.).
    Disk: Use SCSI with VirtIO SCSI single controller and enable io_uring
