#!/bin/bash
set -e

# =====================
# 1. CONFIGURARE
# =====================
SSID1="CASA CECILIA 5G"
PASS="CASACECILIA"
USER_NAME="dani"

echo "=== 1. REPO & SYSTEM UPDATE (TRIXIE) ==="
# Ștergem orice conflict de repo-uri vechi
rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources

# Configurăm formatul nou .sources pentru Proxmox 9 pe Trixie
cat <<EOF > /etc/apt/sources.list.d/proxmox.sources
Types: deb
URIs: http://proxmox.com
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

# Surse Debian standard (Bookworm base for Trixie compatibility)
cat <<EOF > /etc/apt/sources.list
deb http://debian.org bookworm main contrib non-free non-free-firmware
deb http://debian.org bookworm-updates main contrib non-free non-free-firmware
deb http://debian.org bookworm-security main contrib non-free non-free-firmware
EOF

apt update && apt full-upgrade -y

echo "=== 2. INSTALARE DRIVERE VIDEO (NON-FREE) ==="
# Instalăm driverele înainte de HOLD pentru a evita erorile de dependențe
apt install -y intel-media-va-driver-non-free mesa-va-drivers mesa-utils intel-gpu-tools

echo "=== 3. FREEZE STABILITY (HOLD) ==="
# Înghețăm kernel-ul și pachetele de bază Proxmox pentru stabilitate pe Trixie
apt-mark hold proxmox-ve proxmox-kernel-$(uname -r) proxmox-default-kernel pve-firmware || true

echo "=== 4. GPU PASSTHROUGH & BLACKLIST NVIDIA MOARTA ==="
# Parametrii IOMMU pentru Intel Haswell
PARAM="intel_iommu=on iommu=pt acpi_osi=Linux"
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $PARAM\"/" /etc/default/grub

# Dezactivăm NVIDIA complet (hardware-ul defect)
cat <<EOF > /etc/modprobe.d/blacklist-gpu.conf
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
EOF

echo "=== 5. NETWORK (WIFI WAN + VM NAT ROUTER) ==="
# Activăm IP Forwarding
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configurare Bridge Intern (vmbr1) pentru VM-uri
if ! grep -q "vmbr1" /etc/network/interfaces; then
cat <<EOF >> /etc/network/interfaces

auto vmbr1
iface vmbr1 inet static
    address 10.10.10.1/24
    bridge_ports none
    bridge_stp off
    bridge_fd 0
EOF
fi

# DHCP VM Network (dnsmasq)
apt install -y dnsmasq
cat <<EOF > /etc/dnsmasq.d/vm.conf
interface=vmbr1
dhcp-range=10.10.10.50,10.10.10.200,12h
dhcp-option=3,10.10.10.1
dhcp-option=6,8.8.8.8,1.1.1.1
EOF
systemctl restart dnsmasq

# NAT WiFi (Detectăm interfața activă)
WIFI_IF=$(iw dev | awk '$1=="Interface"{print $2}' | head -n1)
apt install -y iptables-persistent
iptables -t nat -A POSTROUTING -o $WIFI_IF -j MASQUERADE
iptables -A FORWARD -i vmbr1 -o $WIFI_IF -j ACCEPT
iptables -A FORWARD -i $WIFI_IF -o vmbr1 -m state --state RELATED,ESTABLISHED -j ACCEPT
netfilter-persistent save

echo "=== 6. BOOT & EFI STABILITY (FIX PENTRU ASUS) ==="
apt install -y grub-efi-amd64
# Detectăm partitia EFI și o fixăm în fstab
EFI_DEV=$(lsblk -o NAME,FSTYPE | grep vfat | awk '{print $1}' | head -n1)
if [ -n "$EFI_DEV" ]; then
    mkdir -p /boot/efi
    mount /dev/$EFI_DEV /boot/efi || true
    grep -q "/boot/efi" /etc/fstab || echo "/dev/$EFI_DEV /boot/efi vfat defaults 0 1" >> /etc/fstab
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --recheck
fi
update-grub

echo "=== 7. PERFORMANCE (ZRAM & CPU PINNING) ==="
# Setup ZRAM cu algoritm ZSTD (protecție SSD)
apt install -y zramswap-enabler
echo -e "ALGO=zstd\nPERCENT=25\nPRIORITY=100" > /etc/default/zramswap
# Setăm Swappiness la 100 pentru a folosi ZRAM eficient
grep -q "vm.swappiness=100" /etc/sysctl.conf || echo "vm.swappiness=100" >> /etc/sysctl.conf
systemctl restart zramswap
sysctl -p

# Hookscript pentru CPU Pinning (Nuclee 4-7 pentru VM, 0-3 pentru Host)
mkdir -p /var/lib/vz/snippets
cat <<'EOF' > /var/lib/vz/snippets/cpu-pinning.sh
#!/bin/bash
vmid=$1
phase=$2
if [ "$phase" == "post-start" ]; then
    sleep 7
    pid=$(cat /var/run/qemu-server/${vmid}.pid)
    [ -n "$pid" ] && taskset -pa -cp 4-7 $pid > /dev/null 2>&1
fi
EOF
chmod +x /var/lib/vz/snippets/cpu-pinning.sh

# Aplicăm hookscript-ul tuturor VM-urilor existente
for vmid in $(qm list | awk '{if(NR>1) print $1}'); do
    qm set $vmid --hookscript local:snippets/cpu-pinning.sh
done

echo "=== 8. USER & CINNAMON AUTO-LOGIN ==="
id "$USER_NAME" &>/dev/null || adduser --disabled-password --gecos "" "$USER_NAME"
usermod -aG video,render,sudo "$USER_NAME"
apt install -y task-cinnamon-desktop lightdm
mkdir -p /etc/lightdm/lightdm.conf.d/
cat <<EOF > /etc/lightdm/lightdm.conf.d/12-autologin.conf
[Seat:*]
user-session=cinnamon
autologin-user=$USER_NAME
autologin-user-timeout=0
EOF

echo "=== DONE! REBOOT TO APPLY TUNING ==="

