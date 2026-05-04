#!/bin/bash
set -e

# =====================
# CONFIG
# =====================
SSID1="Your_WiFi_Name"
SSID2="Your_WiFi2"
PASS="YourPassword"
USER_NAME="YourName"

echo "=== CHECK ROOT ==="
[ "$EUID" -ne 0 ] && echo "Run as root!" && exit 1

echo "=== PROXMOX SAFE ==="
apt-mark hold proxmox-ve proxmox-kernel-6.17 proxmox-default-kernel pve-firmware || true

cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOF

cat <<EOF > /etc/apt/sources.list.d/pve-no-sub.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF

rm -f /etc/apt/sources.list.d/pve-enterprise.list || true

apt update && apt full-upgrade -y

echo "=== INSTALL SYSTEM ==="
apt install -y \
intel-media-va-driver mesa-utils \
task-cinnamon-desktop lightdm \
network-manager iw wireless-tools dnsmasq \
iptables-persistent curl wget sudo \
alsa-utils pulseaudio pavucontrol \
tlp

systemctl set-default graphical.target

echo "=== USER SETUP ==="
id "$USER_NAME" &>/dev/null || adduser --disabled-password --gecos "" "$USER_NAME"
echo "$USER_NAME:parola123" | chpasswd
usermod -aG video,render,sudo "$USER_NAME"
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER_NAME

mkdir -p /etc/lightdm/lightdm.conf.d/
cat <<EOF > /etc/lightdm/lightdm.conf.d/12-autologin.conf
[Seat:*]
user-session=cinnamon
autologin-user=$USER_NAME
autologin-user-timeout=0
EOF

echo "=== GPU PASSTHROUGH ==="
PARAM="intel_iommu=on iommu=pt acpi_osi=Linux"

sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $PARAM\"/" /etc/default/grub
update-grub

if [ -f /etc/kernel/cmdline ]; then
    sed -i "s/$/ $PARAM/" /etc/kernel/cmdline
    proxmox-boot-tool refresh
fi

NVIDIA_ID=$(lspci -nn | grep -i nvidia | head -n1 | sed -n 's/.*\[\(.*\)\].*/\1/p')
[ -n "$NVIDIA_ID" ] && echo "options vfio-pci ids=$NVIDIA_ID" > /etc/modprobe.d/vfio.conf

cat <<EOF > /etc/modprobe.d/blacklist-gpu.conf
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
EOF

echo "=== NETWORKMANAGER CONFIG ==="

printf "\n[ifupdown]\nmanaged=true\n" >> /etc/NetworkManager/NetworkManager.conf

mkdir -p /etc/NetworkManager/conf.d
cat <<EOF > /etc/NetworkManager/conf.d/10-proxmox-ignore.conf
[keyfile]
unmanaged-devices=interface-name:vmbr*
EOF

systemctl enable NetworkManager
systemctl restart NetworkManager

sleep 5

echo "=== CONNECT WIFI ==="
nmcli radio wifi on
nmcli dev wifi connect "$SSID1" password "$PASS" || \
nmcli dev wifi connect "$SSID2" password "$PASS" || true

echo "=== AUTOCONNECT WIFI ==="
nmcli connection modify "$SSID1" connection.autoconnect yes 2>/dev/null || true
nmcli connection modify "$SSID2" connection.autoconnect yes 2>/dev/null || true

echo "=== PROXMOX NETWORK CLEAN ==="

cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

iface nic0 inet manual

auto vmbr0
iface vmbr0 inet manual
    bridge_ports nic0
    bridge_stp off
    bridge_fd 0

auto vmbr1
iface vmbr1 inet static
    address 10.10.10.1/24
    bridge_ports none
    bridge_stp off
    bridge_fd 0
EOF

echo "=== ENABLE IP FORWARD ==="
grep -q net.ipv4.ip_forward /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "=== DHCP VM NETWORK ==="
cat <<EOF > /etc/dnsmasq.d/vm.conf
interface=vmbr1
dhcp-range=10.10.10.50,10.10.10.200,12h
dhcp-option=3,10.10.10.1
dhcp-option=6,8.8.8.8,1.1.1.1
EOF

systemctl enable dnsmasq
systemctl restart dnsmasq

echo "=== NAT CONFIG ==="
WIFI_IF=$(iw dev | awk '$1=="Interface"{print $2}' | head -n1)

iptables -t nat -C POSTROUTING -o $WIFI_IF -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -o $WIFI_IF -j MASQUERADE

iptables -C FORWARD -i vmbr1 -o $WIFI_IF -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i vmbr1 -o $WIFI_IF -j ACCEPT

iptables -C FORWARD -i $WIFI_IF -o vmbr1 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i $WIFI_IF -o vmbr1 -m state --state RELATED,ESTABLISHED -j ACCEPT

netfilter-persistent save

echo "=== POWER OPTIMIZATION ==="
systemctl enable tlp
systemctl start tlp

update-initramfs -u -k all

echo "=== DONE ==="
echo "WiFi = WAN (internet)"
echo "vmbr0 = LAN bridge (no IP)"
echo "vmbr1 = NAT VM network"
echo "Access Proxmox via WiFi IP"
echo "REBOOT REQUIRED"
