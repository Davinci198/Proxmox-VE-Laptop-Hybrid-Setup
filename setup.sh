#!/bin/bash
set -e

# ========================================================
# 📋 PROXMOX HYBRID WORKSTATION v1.2 - UNIFIED FINAL
# ========================================================
USER_NAME="dani"
PASS="parola123"
SSID1="YourWI-FI"
WIFI_PASS="YOURPASSWORD"
THORIUM_URL="https://github.com"

echo "=== [1] REPO & SYSTEM UPDATE (TRIXIE) ==="
[ "$EUID" -ne 0 ] && echo "Run as root!" && exit 1

# Curățăm repo-urile vechi pentru a evita conflicte
#rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources

# Surse Debian Trixie (Modern)
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

# Surse Proxmox 9 (Trixie)
cat <<EOF > /etc/apt/sources.list.d/proxmox.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

apt update && apt full-upgrade -y

echo "=== [2] PROXMOX SAFE (HOLD) ==="
# Înghețăm kernel-ul și pachetele critice înainte de restul configurării
apt-mark hold proxmox-ve proxmox-kernel-6.17* proxmox-default-kernel pve-firmware || true

echo "=== [3] INSTALARE DRIVERE VIDEO SI SISTEM (FIX HASWELL) ==="
# Am adăugat i965-va-driver pentru a repara eroarea libva de pe i7-4700HQ
apt install -y intel-media-va-driver-non-free i965-va-driver mesa-va-drivers mesa-utils \
intel-gpu-tools task-cinnamon-desktop lightdm network-manager iw wireless-tools dnsmasq \
iptables-persistent curl wget sudo alsa-utils pulseaudio pavucontrol tlp

systemctl set-default graphical.target

echo "=== [4] USER SETUP & AUTO-LOGIN ==="
id "$USER_NAME" &>/dev/null || adduser --disabled-password --gecos "" "$USER_NAME"
echo "$USER_NAME:$PASS" | chpasswd
usermod -aG video,render,sudo "$USER_NAME"
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER_NAME

mkdir -p /etc/lightdm/lightdm.conf.d/
cat <<EOF > /etc/lightdm/lightdm.conf.d/12-autologin.conf
[Seat:*]
user-session=cinnamon
autologin-user=$USER_NAME
autologin-user-timeout=0
EOF

echo "=== [5] GPU PASSTHROUGH & BLACKLIST NVIDIA MOARTA ==="
PARAM="intel_iommu=on iommu=pt acpi_osi=Linux"
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $PARAM\"/" /etc/default/grub
update-grub

# Fix pentru sisteme cu boot-tool
[ -f /etc/kernel/cmdline ] && sed -i "s/$/ $PARAM/" /etc/kernel/cmdline && proxmox-boot-tool refresh || true

# Blacklist total NVIDIA (Hardware defect)
cat <<EOF > /etc/modprobe.d/blacklist-gpu.conf
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
EOF

echo "=== [6] NETWORK (WIFI WAN + vmbr1 NAT) ==="
# Configurare NetworkManager să ignore bridge-urile Proxmox (din scriptul vechi)
mkdir -p /etc/NetworkManager/conf.d
cat <<EOF > /etc/NetworkManager/conf.d/10-proxmox-ignore.conf
[keyfile]
unmanaged-devices=interface-name:vmbr*
EOF
systemctl restart NetworkManager

# Activăm Forwarding
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-forwarding.conf
sysctl -p /etc/sysctl.d/99-forwarding.conf

# Bridge Intern vmbr1
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

# DHCP dnsmasq
cat <<EOF > /etc/dnsmasq.d/vm.conf
interface=vmbr1
dhcp-range=10.10.10.50,10.10.10.200,12h
dhcp-option=3,10.10.10.1
dhcp-option=6,8.8.8.8,1.1.1.1
EOF
systemctl restart dnsmasq

# NAT WiFi
WIFI_IF=$(iw dev | awk '$1=="Interface"{print $2}' | head -n1)
iptables -t nat -A POSTROUTING -o $WIFI_IF -j MASQUERADE || true
netfilter-persistent save

echo "=== [7] BOOT & EFI STABILITY (FIX ASUS) ==="
EFI_DEV=$(lsblk -o NAME,FSTYPE | grep vfat | awk '{print $1}' | head -n1)
if [ -n "$EFI_DEV" ]; then
    mkdir -p /boot/efi
    mount /dev/$EFI_DEV /boot/efi || true
    grep -q "/boot/efi" /etc/fstab || echo "/dev/$EFI_DEV /boot/efi vfat defaults 0 1" >> /etc/fstab
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --recheck
fi

echo "=== [8] PERFORMANCE (ZRAM & CPU PINNING) ==="
apt install -y zramswap-enabler
echo -e "ALGO=zstd\nPERCENT=25\nPRIORITY=100" > /etc/default/zramswap
echo "vm.swappiness=100" > /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf
systemctl restart zramswap

# Hookscript CPU Pinning
mkdir -p /var/lib/vz/snippets
cat <<'EOF' > /var/lib/vz/snippets/cpu-pinning.sh
#!/bin/bash
vmid=$1; phase=$2
if [ "$phase" == "post-start" ]; then
    sleep 7
    pid=$(cat /var/run/qemu-server/${vmid}.pid)
    [ -n "$pid" ] && taskset -pa -cp 4-7 $pid > /dev/null 2>&1
fi
EOF
chmod +x /var/lib/vz/snippets/cpu-pinning.sh

echo "=== [9] PERSISTENTA RAM FOLDER ==="
(crontab -l 2>/dev/null | grep -v "thorium-cache"; echo "@reboot mkdir -p /tmp/thorium-cache && chmod 777 /tmp/thorium-cache") | crontab -

echo "=== [10] THORIUM INSTALL (FINAL STEP) ==="
set +e
wget -q --show-progress -O /tmp/thorium.deb $THORIUM_URL
if [ $? -eq 0 ]; then
    apt install /tmp/thorium.deb -y
    DESKTOP_FILE="/usr/share/applications/thorium-browser.desktop"
    sudo sed -i '/^Exec=/d' $DESKTOP_FILE
    sudo sed -i '/\[Desktop Entry\]/a Exec=env LIBVA_DRIVER_NAME=i965 /usr/bin/thorium-browser %U --disk-cache-dir="/tmp/thorium-cache" --disk-cache-size=524288000' $DESKTOP_FILE
    mkdir -p /home/$USER_NAME/Desktop
    cp $DESKTOP_FILE /home/$USER_NAME/Desktop/
    chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/Desktop/
    chmod +x /home/$USER_NAME/Desktop/*.desktop
fi
set -e

echo "=== ✅ SETUP COMPLET! REBOOT RECOMANDAT ==="
