#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Bitte mit sudo ausführen."
    exit 1
fi

echo "Installiere pigpio..."
apt update
apt install -y pigpio

echo "Aktiviere pigpiod..."
systemctl enable pigpiod
systemctl start pigpiod

echo "Installiere Fan-Control..."
install -m755 fancontrol.sh /usr/local/bin/fancontrol.sh
install -m644 fancontrol.service /etc/systemd/system/fancontrol.service

systemctl daemon-reload
systemctl enable fancontrol.service
systemctl restart fancontrol.service

echo
echo "Installation abgeschlossen."
echo
systemctl --no-pager --full status fancontrol.service