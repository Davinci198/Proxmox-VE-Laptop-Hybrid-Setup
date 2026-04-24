#!/bin/bash
# =================================================================
# PROJECT: PROXMOX HYBRID WORKSTATION (v1.1 TURBO)
# COMPONENT: Thorium RAM-Engine v1.5 (Final Stable)
# AUTHOR: dani (via Proxmox Hybrid Project)
# =================================================================

USER_NAME="dani"
RAM_DIR="/dev/shm/thorium-profile"
CONFIG_DIR="/home/$USER_NAME/.config/thorium"
BACKUP_DIR="$CONFIG_DIR/Default.backup"
PROFILE_LINK="$CONFIG_DIR/Default"

echo "🚀 Pornire integrare Thorium RAM-Engine..."

# 1. Creare script SALVARE (Checksum Optimized)
sudo bash -c "cat <<EOF > /usr/local/bin/thorium-save.sh
#!/bin/bash
if [ -d \"$RAM_DIR\" ] && [ \"\$(ls -A $RAM_DIR)\" ]; then
    rsync -a -c --delete \"$RAM_DIR/\" \"$BACKUP_DIR/\"
    chown -R $USER_NAME:$USER_NAME \"$BACKUP_DIR\"
    echo \"✅ [\$(date)] Thorium RAM -> Disk salvat (Checksum OK).\"
else
    echo \"❌ [\$(date)] Eroare: RAM Drive gol. Salvare anulată!\"
fi
EOF"

# 2. Creare script RESTAURARE (Boot Logic)
sudo bash -c "cat <<EOF > /usr/local/bin/thorium-restore.sh
#!/bin/bash
mkdir -p \"$RAM_DIR\"
if [ -d \"$BACKUP_DIR\" ]; then
    rsync -a \"$BACKUP_DIR/\" \"$RAM_DIR/\"
fi
chown -R $USER_NAME:$USER_NAME \"$RAM_DIR\"
chmod 700 \"$RAM_DIR\"
ln -sf \"$RAM_DIR\" \"$PROFILE_LINK\"
chown -h $USER_NAME:$USER_NAME \"$PROFILE_LINK\"
echo \"🧠 [\$(date)] Profil Thorium încărcat în RAM.\"
EOF"

# 3. Permisiuni Execuție
sudo chmod +x /usr/local/bin/thorium-save.sh
sudo chmod +x /usr/local/bin/thorium-restore.sh

# 4. Configurare CRON (Auto-Save 30 min)
(crontab -l 2>/dev/null | grep -v "thorium-save.sh"; echo "*/30 * * * * /usr/local/bin/thorium-save.sh >/dev/null 2>&1") | crontab -

echo "--------------------------------------------------------"
echo "✅ CONFIGURARE FINALIZATĂ!"
echo "📍 Profil: $PROFILE_LINK -> $RAM_DIR"
echo "⏰ Auto-Save: Activat (30 min)"
echo "--------------------------------------------------------"
