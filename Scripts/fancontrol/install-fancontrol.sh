#!/bin/bash

set -e

REPO="https://raw.githubusercontent.com/OE9SAU/SAULink9/main/Scripts/fancontrol"

echo "======================================="
echo " SAULink9 - Lüftersteuerung mit pigpio "
echo "======================================="

# Root prüfen
if [ "$EUID" -ne 0 ]; then
    echo "Bitte mit sudo ausführen!"
    exit 1
fi

# pigpio installieren
echo "Installiere pigpio..."
apt update
apt install -y pigpio

# Dateien herunterladen
echo "Lade Dateien herunter..."
wget -q -O /usr/local/bin/fancontrol.sh "$REPO/fancontrol.sh"
wget -q -O /etc/systemd/system/fancontrol.service "$REPO/fancontrol.service"

# Rechte setzen
chmod 755 /usr/local/bin/fancontrol.sh
chmod 644 /etc/systemd/system/fancontrol.service

# pigpiod aktivieren
systemctl enable pigpiod
systemctl start pigpiod

# Fan-Control aktivieren
systemctl daemon-reload
systemctl enable fancontrol.service
systemctl restart fancontrol.service

echo
echo "======================================="
echo " Installation erfolgreich abgeschlossen"
echo "======================================="
echo

systemctl --no-pager --full status fancontrol.service