#!/bin/bash
set -e

# ============================================================
# PROXMOX 9 WORKSTATION - WiFi ONLY (v1.7.1 UPDATED)
# ============================================================

USER_NAME="dani"
PASS="parola123"
SSID1="CASA CECILIA 5G"
SSID2="CASA CECILIA"
WIFI_PASS="CASACECILIA"

echo "=== CHECK ROOT ==="
[ "$EUID" -ne 0 ] && echo "Run as root!" && exit 1

# ============================================================
# 1. REPO & UPDATE + PROXMOX FIX
# ============================================================
echo "=== [1] REPO & UPDATE & PVE FIX ==="

cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

mkdir -p /etc/apt/sources.list.d
cat <<EOF > /etc/apt/sources.list.d/proxmox.sources
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF

wget -q -O /usr/share/keyrings/proxmox-archive-keyring.gpg \
https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg

rm -f /etc/apt/sources.list.d/pve-enterprise.list 2>/dev/null || true

apt update && apt full-upgrade -y

# Punctul 1: Scoate mesajul "No Subscription"
if [ -f /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ]; then
    sed -i.bak "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
fi

# ============================================================
# 2. PROTECT KERNEL
# ============================================================
echo "=== [2] PROTECT KERNEL ==="
apt-mark hold proxmox-ve proxmox-kernel-* proxmox-default-kernel pve-firmware || true

# ============================================================
# 3. PACKAGES + SSD OPTIMIZATION
# ============================================================
echo "=== [3] INSTALL PACKAGES & SSD TRIM ==="
apt install -y \
intel-media-va-driver-non-free i965-va-driver mesa-va-drivers mesa-utils \
intel-gpu-tools \
task-cinnamon-desktop lightdm \
network-manager iw wireless-tools dnsmasq \
iptables-persistent curl wget sudo \
alsa-utils pulseaudio pavucontrol \
tlp zram-tools curl jq

systemctl set-default graphical.target

# TRIM pentru SSD
systemctl enable fstrim.timer

# ============================================================
# 4. USER + AUTOLOGIN
# ============================================================
echo "=== [4] USER SETUP ==="
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

# ============================================================
# 5. GPU PARAMS + BLACKLIST NVIDIA
# ============================================================
echo "=== [5] GPU PARAMS ==="
PARAM="intel_iommu=on iommu=pt acpi_osi=Linux"

grep -q "intel_iommu" /etc/default/grub || \
sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $PARAM\"/" /etc/default/grub

update-grub

if [ -f /etc/kernel/cmdline ]; then
    grep -q "intel_iommu" /etc/kernel/cmdline || echo "$PARAM" >> /etc/kernel/cmdline
    proxmox-boot-tool refresh || true
fi

cat <<EOF > /etc/modprobe.d/blacklist-gpu.conf
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
EOF

# ============================================================
# 6. EFI / GRUB FIX
# ============================================================
echo "=== [6] EFI / GRUB UEFI FIX ==="
EFI_DEV=$(lsblk -o NAME,FSTYPE | awk '$2=="vfat"{print $1}' | head -n1)
if [ -n "$EFI_DEV" ]; then
    mkdir -p /boot/efi
    mountpoint -q /boot/efi || mount /dev/$EFI_DEV /boot/efi || true
    grep -q "/boot/efi" /etc/fstab || echo "/dev/$EFI_DEV /boot/efi vfat defaults 0 1" >> /etc/fstab
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --recheck || true
    proxmox-boot-tool refresh || true
fi
update-grub

# ============================================================
# 7. NETWORKMANAGER (HARDENED + IPv6 SAFE)
# ============================================================
echo "=== [7] NETWORKMANAGER (HARDENED) ==="

printf "\n[ifupdown]\nmanaged=true\n" >> /etc/NetworkManager/NetworkManager.conf
mkdir -p /etc/NetworkManager/conf.d

# DNS lockdown
cat <<EOF > /etc/NetworkManager/conf.d/90-dns-lockdown.conf
[main]
dns=none
rc-manager=unmanaged
EOF

# No systemd-resolved
cat <<EOF > /etc/NetworkManager/conf.d/91-no-resolv.conf
[main]
systemd-resolved=false
EOF

# Autoconnect behavior
cat <<EOF > /etc/NetworkManager/conf.d/93-no-auto-connect.conf
[connection]
autoconnect-retries=0
EOF

# Hostname protect
cat <<EOF > /etc/NetworkManager/conf.d/94-hostname-protect.conf
[main]
hostname-mode=none
EOF

# Ignore vmbr*
cat <<EOF > /etc/NetworkManager/conf.d/10-proxmox-ignore.conf
[keyfile]
unmanaged-devices=interface-name:vmbr*
EOF

systemctl enable NetworkManager
systemctl restart NetworkManager
sleep 5

# ============================================================
# 8. WIFI CONFIG (Verificare existenta interfata)
# ============================================================
echo "=== [8] WIFI CONFIG ==="
WIFI_IF=$(iw dev | awk '$1=="Interface"{print $2}' | head -n1 || true)

if [ -n "$WIFI_IF" ]; then
    iw dev "$WIFI_IF" set power_save off || true
    cat <<EOF > /etc/NetworkManager/conf.d/wifi-powersave.conf
[connection]
wifi.powersave = 2
EOF
    nmcli radio wifi on || true
    nmcli dev wifi connect "$SSID1" password "$WIFI_PASS" || \
    nmcli dev wifi connect "$SSID2" password "$WIFI_PASS" || true
    nmcli connection modify "$SSID1" connection.autoconnect yes 2>/dev/null || true
    nmcli connection modify "$SSID2" connection.autoconnect yes 2>/dev/null || true
else
    echo "⚠️ EROARE: Nu s-a detectat nicio interfata WiFi. Configurarile de retea ar putea esua!"
fi

# ============================================================
# 9. vmbr1
# ============================================================
echo "=== [9] CONFIG vmbr1 ==="
cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto vmbr1
iface vmbr1 inet static
    address 10.10.10.1/24
    bridge_ports none
    bridge_stp off
    bridge_fd 0
EOF

# ============================================================
# 10. DNSMASQ + NAT + IMMUTABLE DNS
# ============================================================
echo "=== [10] NAT + DHCP + DNS Protection ==="
systemctl disable --now systemd-resolved 2>/dev/null || true
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
chattr +i /etc/resolv.conf || true

echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-forwarding.conf
sysctl -p /etc/sysctl.d/99-forwarding.conf

cat <<EOF > /etc/dnsmasq.d/vm.conf
interface=vmbr1
dhcp-range=10.10.10.50,10.10.10.200,12h
dhcp-option=3,10.10.10.1
dhcp-option=6,8.8.8.8,1.1.1.1
EOF
systemctl enable dnsmasq
systemctl restart dnsmasq

if [ -n "$WIFI_IF" ]; then
    iptables -t nat -C POSTROUTING -o "$WIFI_IF" -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o "$WIFI_IF" -j MASQUERADE
    netfilter-persistent save || true
fi

# ============================================================
# 11. ZRAM
# ============================================================
echo "=== [11] ZRAM ==="
echo -e "ALGO=zstd\nPERCENT=25\nPRIORITY=100" > /etc/default/zramswap
echo "vm.swappiness=100" > /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf
systemctl restart zramswap || true

# ============================================================
# 12. CPU PINNING
# ============================================================
echo "=== [12] CPU PINNING ==="
mkdir -p /var/lib/vz/snippets
cat <<'EOF' > /var/lib/vz/snippets/cpu-pinning.sh
#!/bin/bash
vmid=$1; phase=$2
if [ "$phase" == "post-start" ]; then
    sleep 7
    pid=$(cat /var/run/qemu-server/${vmid}.pid 2>/dev/null)
    [ -n "$pid" ] && taskset -p -c 4-7 "$pid" >/dev/null 2>&1 || true
fi
EOF
chmod +x /var/lib/vz/snippets/cpu-pinning.sh

# ============================================================
# 13. WIFI WATCHDOG
# ============================================================
echo "=== [13] WIFI WATCHDOG ==="
cat <<EOF > /usr/local/bin/wifi-watchdog.sh
#!/bin/bash
LAST_RESET=0
while true; do
    CURRENT_TIME=\$(date +%s)
    ping -c 2 8.8.8.8 > /dev/null 2>&1
    if [ \$? -ne 0 ]; then
        if [ \$((CURRENT_TIME - LAST_RESET)) -gt 60 ]; then
            nmcli radio wifi off || true
            sleep 2
            nmcli radio wifi on || true
            LAST_RESET=\$CURRENT_TIME
            echo "\$(date): WiFi reset applied" >> /var/log/wifi-watchdog.log
        fi
    fi
    sleep 30
done
EOF
chmod +x /usr/local/bin/wifi-watchdog.sh

cat <<EOF > /etc/systemd/system/wifi-watchdog.service
[Unit]
Description=WiFi Watchdog
After=network.target

[Service]
ExecStart=/usr/local/bin/wifi-watchdog.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable wifi-watchdog
systemctl start wifi-watchdog

# ============================================================
# 14. POWER MANAGEMENT
# ============================================================
echo "=== [14] POWER ==="
systemctl enable tlp
systemctl start tlp

# ============================================================
# 15. THORIUM INSTALL & AUTO-UPDATE SCRIPT
# ============================================================
echo "=== [15] THORIUM INSTALL & AUTO-UPDATE SCRIPT ==="

cat <<EOF > /usr/local/bin/update-thorium
#!/bin/bash
TEMP_DEB="/tmp/thorium_latest.deb"
URL=\$(curl -s https://api.github.com/repos/Alex313031/thorium/releases/latest | grep "browser_download_url.*AVX.deb" | cut -d '\"' -f 4)
echo "Downloading latest Thorium..."
wget -q --show-progress -O \$TEMP_DEB "\$URL"
apt install -y \$TEMP_DEB
rm \$TEMP_DEB
EOF
chmod +x /usr/local/bin/update-thorium

/usr/local/bin/update-thorium

DESKTOP_FILE="/usr/share/applications/thorium-browser.desktop"
if [ -f "$DESKTOP_FILE" ]; then
    sed -i '/^Exec=/d' "$DESKTOP_FILE"
    sed -i '/

\[Desktop Entry\]

/a Exec=env LIBVA_DRIVER_NAME=i965 /usr/bin/thorium-browser %U --disk-cache-dir="/tmp/thorium-cache" --disk-cache-size=524288000' "$DESKTOP_FILE"
    mkdir -p /home/$USER_NAME/Desktop
    cp "$DESKTOP_FILE" /home/$USER_NAME/Desktop/
    chown -R $USER_NAME:$USER_NAME /home/$USER_NAME/Desktop/
    chmod +x /home/$USER_NAME/Desktop/*.desktop
fi

# ============================================================
# 16. FINAL CLEANUP
# ============================================================
echo "=== [16] FINAL CLEANUP ==="
update-initramfs -u -k all
apt autoremove -y

echo "=========================================="
echo "✅ PROXMOX 9 v1.7.1 COMPLETE"
echo "📍 No-subscription patch aplicat"
echo "📍 SSD fstrim activat"
echo "📍 Thorium auto-update: /usr/local/bin/update-thorium"
echo "📍 DNS blocat (immutable) pentru stabilitate"
echo "📍 WiFi check + watchdog active"
echo "=========================================="
