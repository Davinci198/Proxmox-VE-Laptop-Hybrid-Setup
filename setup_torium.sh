#!/bin/bash

# --- CONFIGURARE ---
USER_NAME="dani"
PROFILE_DIR="/home/$USER_NAME/.config/thorium"
PROFILE_NAME="Default"
RAM_DIR="/dev/shm/thorium-profile"
BACKUP_DIR="$PROFILE_DIR/$PROFILE_NAME.backup"

echo "🚀 Pornire Integrare Thorium RAM-Engine v1.4 (Full Auto)..."

# 1. Închidere forțată Thorium
sudo pkill -f thorium || true
sleep 1

# 2. Salvare profil existent (dacă este director real)
if [ -d "$PROFILE_DIR/$PROFILE_NAME" ] && [ ! -L "$PROFILE_DIR/$PROFILE_NAME" ]; then
    echo "📦 Mutăm profilul de pe SSD în zona de Backup..."
    mv "$PROFILE_DIR/$PROFILE_NAME" "$BACKUP_DIR"
fi

# 3. Creare structură foldere
mkdir -p "$BACKUP_DIR"
mkdir -p "$RAM_DIR"
chown -R $USER_NAME:$USER_NAME "$BACKUP_DIR"
chown -R $USER_NAME:$USER_NAME "$RAM_DIR"
chmod 700 "$RAM_DIR"

# 4. Creare script SALVARE (RAM -> SSD)
sudo bash -c "cat <<EOF > /usr/local/bin/thorium-save.sh
#!/bin/bash
if [ -d \"$RAM_DIR\" ] && [ \"\$(ls -A $RAM_DIR)\" ]; then
    rsync -a --delete \"$RAM_DIR/\" \"$BACKUP_DIR/\"
    chown -R $USER_NAME:$USER_NAME \"$BACKUP_DIR\"
    echo \"✅ Salvare RAM pe SSD efectuată cu succes!\"
else
    echo \"⚠️ Eroare: RAM Drive gol. Salvare anulată pentru siguranță.\"
fi
EOF"

# 5. Creare script RESTAURARE (SSD -> RAM)
sudo bash -c "cat <<EOF > /usr/local/bin/thorium-restore.sh
#!/bin/bash
mkdir -p \"$RAM_DIR\"
if [ -d \"$BACKUP_DIR\" ] && [ \"\$(ls -A $BACKUP_DIR)\" ]; then
    rsync -a \"$BACKUP_DIR/\" \"$RAM_DIR/\"
fi
chown -R $USER_NAME:$USER_NAME \"$RAM_DIR\"
chmod 700 \"$RAM_DIR\"
ln -sf \"$RAM_DIR\" \"$PROFILE_DIR/$PROFILE_NAME\"
chown -h $USER_NAME:$USER_NAME \"$PROFILE_DIR/$PROFILE_NAME\"
echo \"✅ Restaurare SSD în RAM efectuată!\"
EOF"

sudo chmod +x /usr/local/bin/thorium-save.sh
sudo chmod +x /usr/local/bin/thorium-restore.sh

# 6. Configurare Servicii Systemd
sudo bash -c "cat <<EOF > /etc/systemd/system/thorium-restore.service
[Unit]
Description=Restore Thorium RAM profile
Before=graphical.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/thorium-restore.sh
User=root
[Install]
WantedBy=graphical.target
EOF"

sudo bash -c "cat <<EOF > /etc/systemd/system/thorium-save.service
[Unit]
Description=Save Thorium RAM profile back to disk
Before=shutdown.target reboot.target halt.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/thorium-save.sh
User=root
[Install]
WantedBy=shutdown.target reboot.target halt.target
EOF"

# 7. Activare automatizări
sudo systemctl daemon-reload
sudo systemctl enable thorium-restore.service
sudo systemctl enable thorium-save.service

# 8. Prima rulare manuală pentru a seta totul acum
sudo /usr/local/bin/thorium-restore.sh

# 9. Configurare Cron (Salvare la 30 min)
(crontab -l 2>/dev/null | grep -v "thorium-save.sh"; echo "*/30 * * * * /usr/local/bin/thorium-save.sh >/dev/null 2>&1") | crontab -

echo "--------------------------------------------------------"
echo "✅ TOTUL ESTE GATA!"
ls -ld $PROFILE_DIR/$PROFILE_NAME
echo "🚀 Thorium rulează acum 100% din RAM."
echo "⏰ Backup automat configurat (la 30 min și la Shutdown)."
echo "--------------------------------------------------------"
