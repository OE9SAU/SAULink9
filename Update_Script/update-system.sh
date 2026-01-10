#!/usr/bin/env bash
#
# update-system.sh OE9SAU 01/2026 v1
#
# Zweck:
#   Führt ein normales Systemupdate (apt update + apt upgrade) durch und
#   stellt anschließend sicher, dass Apache mit PrivateTmp=false läuft.
#
# Funktionsweise:
#   1. Systemupdate ausführen
#   2. systemd-Override für apache2 prüfen/erstellen:
#        /etc/systemd/system/apache2.service.d/override.conf
#   3. systemd neu laden
#   4. Apache neu starten
#   5. Status von PrivateTmp als true/false anzeigen
#
# Wichtige Hinweise:
#   - Die Vendor-Datei /usr/lib/systemd/system/apache2.service
#     wird NICHT verändert.
#   - Das Script ist updatefest und beliebig oft ausführbar (idempotent).
#   - systemd zeigt intern yes/no, dieses Script übersetzt auf true/false.
#
# Verwendung:
#   sudo update-system.sh
#
# Voraussetzungen:
#   - Debian / Raspberry Pi OS
#   - apache2 installiert
#   - Ausführung mit root-Rechten
#
# Ablage:
#   /usr/local/sbin/update-system.sh
#

set -euo pipefail

UNIT="apache2"
DROPIN_DIR="/etc/systemd/system/${UNIT}.service.d"
DROPIN_FILE="${DROPIN_DIR}/override.conf"

echo "=== Systemupdate ==="
sudo apt-get update
sudo apt-get -y upgrade

echo "=== Apache PrivateTmp Fix ==="
sudo mkdir -p "$DROPIN_DIR"

DESIRED=$'[Service]\nPrivateTmp=false\n'

if [[ ! -f "$DROPIN_FILE" ]] || ! cmp -s <(printf '%s' "$DESIRED") "$DROPIN_FILE"; then
  echo "Setze/aktualisiere Override"
  printf '%s' "$DESIRED" | sudo tee "$DROPIN_FILE" >/dev/null
else
  echo "Override bereits korrekt"
fi

sudo systemctl daemon-reload
sudo systemctl restart "$UNIT"

# --- Anzeige mit Übersetzung yes/no -> true/false ---
VAL="$(systemctl show "$UNIT" -p PrivateTmp --value)"
case "$VAL" in
  no)  echo "PrivateTmp=false" ;;
  yes) echo "PrivateTmp=true" ;;
  *)   echo "UNBEKANNT: PrivateTmp=$VAL" >&2 ;;
esac

echo "FERTIG"
