#!/bin/bash

set -e

# OE9SAU v1
# Backup + Update von lh.php und lh_small.php
# Verbesserte aktualisierung der SVXReflector Activity Tabelle mit LastHeard, Callsign und TG-Daten

DIR="/var/www/html/include"

cd "$DIR" || exit

# Backup erstellen
cp lh.php lh.php_back
cp lh_small.php lh_small.php_back

# Dateien löschen
rm -f lh.php
rm -f lh_small.php

echo "Backup erstellt."

# Neue Dateien laden
wget -q -O lh.php \
https://raw.githubusercontent.com/OE9SAU/SAULink9/3d10a2b1882fa016141af158421157c2e75bfdbe/Scripts/files/lh.php

wget -q -O lh_small.php \
https://raw.githubusercontent.com/OE9SAU/SAULink9/3d10a2b1882fa016141af158421157c2e75bfdbe/Scripts/files/lh_small.php

echo "Dateien ersetzt. 73."
