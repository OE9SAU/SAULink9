#!/bin/bash
set -euo pipefail

# eSM CPU-Temperaturgraph + FanControl GPIO18
# Raspberry Pi OS / Debian
# Installation: sudo bash install-tempgraph.sh
# v2.0 by OE9SAU 10/2026
# 

ESM="/var/www/html/esm"
DATA="/var/log/esm"
JS="$ESM/js"
INDEX="$ESM/index.php"

if [[ $EUID -ne 0 ]]; then
    echo "Bitte mit sudo ausführen."
    exit 1
fi

if [[ ! -f "$INDEX" ]]; then
    echo "FEHLER: $INDEX nicht gefunden."
    exit 1
fi

echo "Installiere eSM Temperaturgraph ..."

apt-get update
apt-get install -y curl python3

mkdir -p "$JS" "$DATA"
chmod 755 "$DATA"

# Lokale Chart.js Installation
curl -fLsS \
  https://cdn.jsdelivr.net/npm/chart.js@4.4.8/dist/chart.umd.min.js \
  -o "$JS/chart.umd.min.js"

# Vorhandene Installation sichern
cp -a "$INDEX" "$INDEX.bak.$(date +%Y%m%d-%H%M%S)"

# Python-basierte Temperaturaufzeichnung
cat > /usr/local/bin/esm-temp-logger.py <<'PY'
#!/usr/bin/env python3
import os
import time
import csv

path = "/var/log/esm/temp_history.csv"
sensor = "/sys/class/thermal/thermal_zone0/temp"

with open(sensor) as f:
    temp = int(f.read().strip()) / 1000.0

now = int(time.time())
rows = []

if os.path.exists(path):
    with open(path, newline="") as f:
        for row in csv.reader(f):
            try:
                ts = int(row[0])
                value = float(row[1])
                if ts >= now - 3600:
                    rows.append((ts, value))
            except (ValueError, IndexError):
                pass

rows.append((now, round(temp, 1)))

tmp = path + ".tmp"
with open(tmp, "w", newline="") as f:
    csv.writer(f).writerows(rows)

os.replace(tmp, path)
PY

chmod 755 /usr/local/bin/esm-temp-logger.py

# Temperatur-API
cat > "$ESM/temp_history.php" <<'PHP'
<?php
header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-store');

$file = '/var/log/esm/temp_history.csv';

if (is_readable($file)) {
    readfile($file);
}
PHP

# GPIO18-API (BCM-Nummerierung)
cat > "$ESM/fan_status.php" <<'PHP'
<?php
header('Content-Type: application/json');
header('Cache-Control: no-store');

$path = '/sys/class/gpio/gpio18/value';
$value = null;

if (is_readable($path)) {
    $raw = trim(file_get_contents($path));
    if ($raw === '0' || $raw === '1') {
        $value = (int)$raw;
    }
}

if ($value === null) {
    $output = [];
    $code = 1;
    exec('/usr/bin/pinctrl get 18 2>/dev/null', $output, $code);

    if ($code === 0) {
        $line = implode(' ', $output);
        if (preg_match('/\b(hi|lo)\b/i', $line, $m)) {
            $value = strtolower($m[1]) === 'hi' ? 1 : 0;
        }
    }
}

echo json_encode([
    'gpio' => 18,
    'state' => $value,
    'status' => $value === null ? 'UNKNOWN' :
        ($value === 1 ? 'ON' : 'OFF')
]);
PHP

# Dashboard-Integration
python3 - "$INDEX" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
html = path.read_text()

start = "<!-- ESM TEMPGRAPH START -->"
end = "<!-- ESM TEMPGRAPH END -->"

if start in html and end in html:
    a = html.index(start)
    b = html.index(end, a) + len(end)
    html = html[:a] + html[b:]

block = """
<!-- ESM TEMPGRAPH START -->
<style>
#esm-tempgraph-panel {
    margin: 15px 0;
    padding: 12px;
}
#esm-tempgraph-panel canvas {
    width: 100% !important;
    height: 230px !important;
}
#cpu-gpio18 {
    padding: 5px 14px;
    border-radius: 4px;
    font-weight: bold;
    text-align: center;
}
</style>

<div id="esm-tempgraph-panel">
    <h3>CPU Temperature - Last 60 Minutes</h3>
    <canvas id="cpuTempChart"></canvas>
    <table style="width:100%;margin-top:12px">
        <tr>
            <td>Fan GPIO18</td>
            <td id="cpu-gpio18">UNKNOWN</td>
        </tr>
    </table>
</div>

<script src="js/chart.umd.min.js"></script>
<script>
(function() {
    let chart = null;

    async function loadCpuTempChart() {
        try {
            const response = await fetch(
                'temp_history.php?t=' + Date.now()
            );
            if (!response.ok) return;

            const csv = await response.text();
            const now = Date.now();
            const points = [];

            csv.trim().split(/\\r?\\n/).forEach(line => {
                const parts = line.split(',');
                if (parts.length < 2) return;

                const ts = Number(parts[0]) * 1000;
                const temp = Number(parts[1]);

                if (
                    Number.isFinite(ts) &&
                    Number.isFinite(temp) &&
                    ts >= now - 3600000
                ) {
                    points.push({x: ts, y: temp});
                }
            });

            points.sort((a,b) => a.x - b.x);

            const labels = points.map(p =>
                new Date(p.x).toLocaleTimeString(
                    'de-AT',
                    {hour:'2-digit',minute:'2-digit'}
                )
            );

            const values = points.map(p => p.y);
            const ctx = document.getElementById('cpuTempChart');
            if (!ctx || typeof Chart === 'undefined') return;

            if (!chart) {
                chart = new Chart(ctx, {
                    type: 'line',
                    data: {
                        labels,
                        datasets: [{
                            label: 'CPU °C',
                            data: values,
                            borderColor: '#e67e22',
                            borderWidth: 2,
                            pointRadius: 0,
                            tension: 0.2,
                            fill: false
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        animation: false,
                        scales: {
                            x: {
                                ticks: {
                                    autoSkip: false,
                                    maxRotation: 0,
                                    callback: function(value) {
                                        const label =
                                            this.getLabelForValue(value);
                                        const parts = label.split(':');
                                        const minute = Number(parts[1]);
                                        return minute % 15 === 0
                                            ? label : '';
                                    }
                                },
                                grid: {
                                    color: function(context) {
                                        const label =
                                            context.tick?.label || '';
                                        const minute =
                                            Number(label.split(':')[1]);
                                        return minute % 15 === 0
                                            ? '#cccccc'
                                            : 'transparent';
                                    }
                                }
                            },
                            y: {
                                min: 40,
								max: 80,
								title: {
                                display: true,
                                text: 'Temperature °C'
                                },
                                ticks: {
                                    stepSize: 5
                                }
                            }
                        }
                    }
                });
            } else {
                chart.data.labels = labels;
                chart.data.datasets[0].data = values;
                chart.update('none');
            }
        } catch(e) {
            console.error('Temperature graph:', e);
        }
    }

    async function loadFanStatus() {
        const cell = document.getElementById('cpu-gpio18');
        if (!cell) return;

        try {
            const response = await fetch(
                'fan_status.php?t=' + Date.now()
            );
            const data = await response.json();

            cell.textContent = data.status;

            if (data.state === 1) {
                cell.style.backgroundColor = '#b8edb8';
                cell.style.color = '#145214';
            } else if (data.state === 0) {
                cell.style.backgroundColor = '#f5b5b5';
                cell.style.color = '#751818';
            } else {
                cell.style.backgroundColor = '#dddddd';
                cell.style.color = '#333333';
            }
        } catch(e) {
            cell.textContent = 'UNKNOWN';
        }
    }

    loadCpuTempChart();
    loadFanStatus();

    setInterval(loadCpuTempChart, 30000);
    setInterval(loadFanStatus, 5000);
})();
</script>
<!-- ESM TEMPGRAPH END -->
"""

if "</body>" not in html:
    raise SystemExit("FEHLER: </body> nicht gefunden")

html = html.replace("</body>", block + "\n</body>", 1)
path.write_text(html)
PY

# Systemd-Service und Timer
cat > /etc/systemd/system/esm-temp-logger.service <<'EOF'
[Unit]
Description=eSM CPU temperature logger

[Service]
Type=oneshot
ExecStart=/usr/local/bin/esm-temp-logger.py
EOF

cat > /etc/systemd/system/esm-temp-logger.timer <<'EOF'
[Unit]
Description=eSM temperature logging every minute

[Timer]
OnBootSec=10s
OnUnitActiveSec=60s
AccuracySec=1s
Unit=esm-temp-logger.service

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now esm-temp-logger.timer
systemctl start esm-temp-logger.service

chmod 644 "$ESM/temp_history.php" "$ESM/fan_status.php"

echo
echo "Installation abgeschlossen."
echo "Dashboard: http://$(hostname -I | awk '{print $1}')/esm/"
echo "Temperaturdaten: $DATA/temp_history.csv"
echo "Fan GPIO18: ON=rot, OFF=gruen"
