#!/bin/bash
# v1.0 by OE9SAU 08/2026
#	
# install-tempgraph.sh
#
# Installiert CPU-Temperaturgraph fuer eZ Server Monitor
#
# Funktionen:
# - Temperaturmessung jede Minute
# - letzte 60 Messwerte
# - Daten unter /var/log/esm (geeignet fuer Log2RAM)
# - PHP-Schnittstelle fuer den Browser
# - Chart.js
# - Temperaturgraph 40-80 °C / 5 °C Raster
# - Zeitraster alle 15 Minuten
# - Fan GPIO18: OFF gruen / ON rot
#
# ------------------------------------------------------------

set -e

ESM_DIR="/var/www/html/esm"
INDEX="$ESM_DIR/index.php"

LOGGER="/usr/local/bin/cpu-temp-log.sh"
LOGDIR="/var/log/esm"
LOGFILE="$LOGDIR/temp_history.csv"
PHPFILE="$ESM_DIR/temp_history.php"

MARKER="OE9SAU_TEMPGRAPH"

echo "=========================================="
echo " eSM CPU Temperaturgraph Installation"
echo "=========================================="
echo

# ------------------------------------------------------------
# Root pruefen
# ------------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    echo "[FEHLER] Bitte mit sudo starten:"
    echo
    echo "sudo ./install-tempgraph.sh"
    exit 1
fi

# ------------------------------------------------------------
# eSM pruefen
# ------------------------------------------------------------

if [ ! -f "$INDEX" ]; then
    echo "[FEHLER] $INDEX nicht gefunden."
    exit 1
fi

echo "[OK] eSM gefunden: $ESM_DIR"

# ------------------------------------------------------------
# Pruefen ob bereits installiert
# ------------------------------------------------------------

if grep -q "$MARKER" "$INDEX"; then
    echo "[FEHLER] Temperaturgraph ist bereits installiert."
    exit 1
fi

# ------------------------------------------------------------
# Voraussetzungen in index.php pruefen
# ------------------------------------------------------------

if ! grep -q 'id="cpu-gpio18"' "$INDEX"; then
    echo "[FEHLER] cpu-gpio18 wurde in index.php nicht gefunden."
    echo
    echo "Erwartet wird:"
    echo '<td id="cpu-gpio18"></td>'
    exit 1
fi

if ! grep -q '</body>' "$INDEX"; then
    echo "[FEHLER] </body> wurde in index.php nicht gefunden."
    exit 1
fi

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

BACKUP="${INDEX}.backup-tempgraph-$(date +%Y%m%d-%H%M%S)"

cp -a "$INDEX" "$BACKUP"

echo "[OK] Backup:"
echo "     $BACKUP"

# ------------------------------------------------------------
# Log-Verzeichnis
# ------------------------------------------------------------

mkdir -p "$LOGDIR"
touch "$LOGFILE"

chmod 755 "$LOGDIR"
chmod 644 "$LOGFILE"

echo "[OK] $LOGDIR angelegt"

# ------------------------------------------------------------
# Temperatur Logger
# ------------------------------------------------------------

cat > "$LOGGER" <<'EOF'
#!/bin/bash

FILE="/var/log/esm/temp_history.csv"

mkdir -p "$(dirname "$FILE")"

TEMP=$(vcgencmd measure_temp | sed "s/temp=//;s/'C//")
TIME=$(date +%s)

# Nur gueltige Temperatur speichern
if [[ "$TEMP" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "$TIME,$TEMP" >> "$FILE"

    # Nur die letzten 60 Messwerte behalten
    tail -n 60 "$FILE" > "${FILE}.tmp"
    mv "${FILE}.tmp" "$FILE"

    chmod 644 "$FILE"
fi
EOF

chmod 755 "$LOGGER"

echo "[OK] Temperatur-Logger installiert"

# ------------------------------------------------------------
# Logger testen
# ------------------------------------------------------------

"$LOGGER"

if [ ! -s "$LOGFILE" ]; then
    echo "[FEHLER] Temperaturmessung fehlgeschlagen."
    echo "Bitte vcgencmd pruefen:"
    echo
    echo "vcgencmd measure_temp"
    exit 1
fi

echo "[OK] Temperaturmessung funktioniert:"
tail -n 1 "$LOGFILE"

# ------------------------------------------------------------
# Cronjob
# ------------------------------------------------------------

CRONLINE="* * * * * $LOGGER"

(
    crontab -l 2>/dev/null | grep -Fv "$LOGGER" || true
    echo "$CRONLINE"
) | crontab -

echo "[OK] Cronjob eingerichtet (jede Minute)"

# ------------------------------------------------------------
# PHP Schnittstelle
# ------------------------------------------------------------

cat > "$PHPFILE" <<'EOF'
<?php

$file = '/var/log/esm/temp_history.csv';

header('Content-Type: text/plain');
header('Cache-Control: no-store, no-cache, must-revalidate');

if (is_readable($file)) {
    readfile($file);
}
EOF

chmod 644 "$PHPFILE"

echo "[OK] temp_history.php installiert"

# ------------------------------------------------------------
# Chart.js lokal installieren
# ------------------------------------------------------------

CHARTJS="$ESM_DIR/js/chart.umd.min.js"

if [ ! -f "$CHARTJS" ]; then
    echo "[INFO] Lade Chart.js herunter..."

    wget -q \
        -O "$CHARTJS" \
        "https://cdn.jsdelivr.net/npm/chart.js@4.5.1/dist/chart.umd.min.js"

    if [ ! -s "$CHARTJS" ]; then
        echo "[FEHLER] Chart.js Download fehlgeschlagen."
        rm -f "$CHARTJS"
        exit 1
    fi

    chmod 644 "$CHARTJS"

    echo "[OK] Chart.js lokal installiert"
else
    echo "[OK] Chart.js bereits lokal vorhanden"
fi


# ------------------------------------------------------------
# Chart.js in index.php einbinden
# ------------------------------------------------------------

if ! grep -q 'js/chart.umd.min.js' "$INDEX"; then

    # eventuell vorhandene CDN-Version entfernen
    sed -i \
        '/cdn\.jsdelivr\.net\/npm\/chart\.js/d' \
        "$INDEX"

    sed -i \
        '/<script src="js\/esm.js" type="text\/javascript"><\/script>/a\
    <script src="js/chart.umd.min.js"></script>' \
        "$INDEX"

    echo "[OK] Lokales Chart.js in index.php eingebunden"

else
    echo "[OK] Lokales Chart.js bereits eingebunden"
fi

# ------------------------------------------------------------
# Graph unter GPIO18 einbauen
#
# Wir suchen:
# <td id="cpu-gpio18"></td>
# </tr>
#
# und setzen danach den Graphen.
# ------------------------------------------------------------

python3 - "$INDEX" <<'PY'
import sys
import re

filename = sys.argv[1]

with open(filename, "r", encoding="utf-8") as f:
    data = f.read()

pattern = r'(<td\s+id=["\']cpu-gpio18["\']\s*>\s*</td>\s*</tr>)'

graph = r'''\1

<!-- OE9SAU_TEMPGRAPH -->
<tr>
    <td colspan="2">
        <div style="height:140px; width:100%; margin-top:10px;">
            <canvas id="cpuTempChart"></canvas>
        </div>
    </td>
</tr>
'''

newdata, count = re.subn(
    pattern,
    graph,
    data,
    count=1,
    flags=re.IGNORECASE
)

if count != 1:
    print("[FEHLER] Position fuer Temperaturgraph nicht gefunden.")
    sys.exit(1)

with open(filename, "w", encoding="utf-8") as f:
    f.write(newdata)
PY

echo "[OK] Temperaturgraph in CPU-Box eingebunden"

# ------------------------------------------------------------
# JavaScript vor </body> einfuegen
# ------------------------------------------------------------

JSFILE=$(mktemp)

cat > "$JSFILE" <<'EOF'
<script>
/* OE9SAU_TEMPGRAPH_JS */

let cpuTempChart = null;

function loadCpuTempChart() {

    fetch('temp_history.php?t=' + Date.now())
        .then(response => response.text())
        .then(text => {

            const labels = [];
            const temps = [];

            text.trim().split('\n').forEach(line => {

                const parts = line.split(',');

                if (parts.length === 2) {

                    const timestamp = parseInt(parts[0]);
                    const temp = parseFloat(parts[1]);

                    if (isNaN(timestamp) || isNaN(temp)) {
                        return;
                    }

                    const d = new Date(timestamp * 1000);

                    labels.push(
                        d.getHours().toString().padStart(2, '0') +
                        ':' +
                        d.getMinutes().toString().padStart(2, '0')
                    );

                    temps.push(temp);
                }
            });

            if (cpuTempChart) {

                cpuTempChart.data.labels = labels;
                cpuTempChart.data.datasets[0].data = temps;

                cpuTempChart.update();

                return;
            }

            const ctx = document.getElementById('cpuTempChart');

            if (!ctx) {
                return;
            }

            cpuTempChart = new Chart(ctx, {

                type: 'line',

                data: {

                    labels: labels,

                    datasets: [{
                        label: 'CPU °C',
                        data: temps,
                        borderWidth: 2,
                        pointRadius: 1,
                        tension: 0.25,
                        fill: false
                    }]
                },

                options: {

                    responsive: true,
                    maintainAspectRatio: false,
                    animation: false,

                    scales: {

                        y: {
                            min: 40,
                            max: 80,

                            ticks: {
                                stepSize: 5,
                                autoSkip: false
                            },

                            title: {
                                display: true,
                                text: '°C'
                            }
                        },

                        x: {

                            ticks: {

                                autoSkip: false,
                                maxRotation: 0,
                                minRotation: 0,

                                callback: function(value) {

                                    const label =
                                        this.getLabelForValue(value);

                                    if (
                                        label.endsWith(':00') ||
                                        label.endsWith(':15') ||
                                        label.endsWith(':30') ||
                                        label.endsWith(':45')
                                    ) {
                                        return label;
                                    }

                                    return '';
                                }
                            },

                            grid: {

                                color: function(context) {

                                    const index = context.index;

                                    if (
                                        index === undefined ||
                                        !labels[index]
                                    ) {
                                        return 'transparent';
                                    }

                                    const label = labels[index];

                                    if (
                                        label.endsWith(':00') ||
                                        label.endsWith(':15') ||
                                        label.endsWith(':30') ||
                                        label.endsWith(':45')
                                    ) {
                                        return 'rgba(0,0,0,0.1)';
                                    }

                                    return 'transparent';
                                }
                            }
                        }
                    },

                    plugins: {

                        legend: {
                            display: false
                        }
                    }
                }
            });
        })
        .catch(error => {
            console.error(
                'CPU Temperaturgraph:',
                error
            );
        });
}


/* Graph beim Laden starten */

loadCpuTempChart();


/* Graph jede Minute aktualisieren */

setInterval(
    loadCpuTempChart,
    60000
);


/* ---------------------------------------------------------
   Fan GPIO18 Statusfarbe

   OFF = gruen
   ON  = rot
--------------------------------------------------------- */

function colorFanStatus() {

    const fan =
        document.getElementById('cpu-gpio18');

    if (!fan) {
        return;
    }

    const status =
        fan.textContent.trim().toUpperCase();

    fan.style.display = 'inline-block';
    fan.style.padding = '2px 8px';
    fan.style.borderRadius = '0';
    fan.style.fontWeight = 'normal';
    fan.style.color = '#444';
    fan.style.minWidth = '30px';
    fan.style.textAlign = 'center';

    if (status === 'ON') {

        fan.style.backgroundColor =
            '#e57373';

    } else if (status === 'OFF') {

        fan.style.backgroundColor =
            '#7ed36d';

    } else {

        fan.style.backgroundColor =
            'transparent';
    }
}

setInterval(
    colorFanStatus,
    1000
);

</script>
EOF


python3 - "$INDEX" "$JSFILE" <<'PY'
import sys

filename = sys.argv[1]
jsfile = sys.argv[2]

with open(filename, "r", encoding="utf-8") as f:
    data = f.read()

with open(jsfile, "r", encoding="utf-8") as f:
    javascript = f.read()

if "</body>" not in data:
    print("[FEHLER] </body> nicht gefunden.")
    sys.exit(1)

data = data.replace(
    "</body>",
    javascript + "\n\n</body>",
    1
)

with open(filename, "w", encoding="utf-8") as f:
    f.write(data)
PY

rm -f "$JSFILE"

echo "[OK] Graph-JavaScript installiert"
echo "[OK] Fan-Statusfarben installiert"

# ------------------------------------------------------------
# PHP Syntax pruefen
# ------------------------------------------------------------

if command -v php >/dev/null 2>&1; then

    if ! php -l "$INDEX" >/dev/null; then

        echo
        echo "[FEHLER] PHP Syntaxfehler!"
        echo
        echo "Backup wird wiederhergestellt."

        cp -a "$BACKUP" "$INDEX"

        exit 1
    fi

    echo "[OK] PHP Syntax geprueft"
fi

# ------------------------------------------------------------
# PHP Schnittstelle testen
# ------------------------------------------------------------

echo
echo "Aktueller Messwert:"
cat "$LOGFILE"
echo

echo "=========================================="
echo " Installation abgeschlossen"
echo "=========================================="
echo
echo "Logger:"
echo "  $LOGGER"
echo
echo "Messwerte:"
echo "  $LOGFILE"
echo
echo "PHP Schnittstelle:"
echo "  $PHPFILE"
echo
echo "Backup:"
echo "  $BACKUP"
echo
echo "Cronjob:"
echo "  $CRONLINE"
echo
echo "Browser danach mit Strg+F5 neu laden."
echo
