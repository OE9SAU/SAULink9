#!/bin/bash
set -euo pipefail

# eSM CPU-Temperaturgraph + FanControl GPIO18
# Raspberry Pi OS / Debian
# Installation: sudo bash install-tempgraph.sh
# v2.1 by OE9SAU 10/2026
# 

ESM_DIR="${ESM_DIR:-/var/www/html/esm}"
INDEX="$ESM_DIR/index.php"
DATA_DIR=/var/log/esm
LOGGER=/usr/local/bin/esm-temp-logger.py

if (( EUID != 0 )); then echo 'Bitte mit sudo ausführen.' >&2; exit 1; fi
if [[ ! -f "$INDEX" ]]; then echo "FEHLER: $INDEX nicht gefunden." >&2; exit 1; fi

# apt-get update
# apt-get install -y curl python3

mkdir -p "$ESM_DIR/js" "$DATA_DIR"
chmod 755 "$DATA_DIR"
if [[ ! -s "$ESM_DIR/js/chart.umd.min.js" ]]; then
  curl -fLsS --retry 3 'https://cdn.jsdelivr.net/npm/chart.js@4.4.8/dist/chart.umd.min.js' -o "$ESM_DIR/js/chart.umd.min.js.tmp"
  mv "$ESM_DIR/js/chart.umd.min.js.tmp" "$ESM_DIR/js/chart.umd.min.js"
fi
chmod 644 "$ESM_DIR/js/chart.umd.min.js"

cat > "$LOGGER" <<'PYLOGGER'
#!/usr/bin/env python3
import csv
import os
import time

path = '/var/log/esm/temp_history.csv'
with open('/sys/class/thermal/thermal_zone0/temp', encoding='utf-8') as f:
    temperature = int(f.read().strip()) / 1000
now = int(time.time())
rows = []
if os.path.isfile(path):
    with open(path, newline='', encoding='utf-8') as f:
        for row in csv.reader(f):
            try:
                ts, value = int(row[0]), float(row[1])
                if now - 3600 <= ts <= now:
                    rows.append((ts, value))
            except (IndexError, ValueError):
                pass
rows.append((now, round(temperature, 1)))
tmp = path + '.tmp'
with open(tmp, 'w', newline='', encoding='utf-8') as f:
    csv.writer(f).writerows(rows)
os.chmod(tmp, 0o644)
os.replace(tmp, path)
PYLOGGER
chmod 755 "$LOGGER"

cat > "$ESM_DIR/temp_history.php" <<'PHP'
<?php
header('Content-Type: text/plain; charset=utf-8');
header('Cache-Control: no-store');
$file = '/var/log/esm/temp_history.csv';
if (is_readable($file)) {
    readfile($file);
}
PHP

cat > "$ESM_DIR/fan_status.php" <<'PHP'
<?php
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
$state = null;
$path = '/sys/class/gpio/gpio18/value';
if (is_readable($path)) {
    $raw = trim(file_get_contents($path));
    if ($raw === '0' || $raw === '1') $state = (int)$raw;
}
if ($state === null) {
    $cmd = null;
    foreach (['/usr/bin/pinctrl', '/usr/local/bin/pinctrl'] as $candidate) {
        if (is_executable($candidate)) { $cmd = $candidate; break; }
    }
    if ($cmd !== null && function_exists('exec')) {
        $output = [];
        $code = 1;
        exec(escapeshellarg($cmd) . ' get 18 2>/dev/null', $output, $code);
        if ($code === 0) {
            $line = implode(' ', $output);
            if (preg_match('/\b(hi|lo)\b/i', $line, $m)) {
                $state = strtolower($m[1]) === 'hi' ? 1 : 0;
            }
        }
    }
}
echo json_encode(['gpio' => 18, 'state' => $state,
                  'status' => $state === null ? 'UNKNOWN' : ($state ? 'ON' : 'OFF')]);
PHP
chmod 644 "$ESM_DIR/temp_history.php" "$ESM_DIR/fan_status.php"

# Modify existing eSM markup only after validating anchor points.
python3 - "$INDEX" <<'PYINDEX'
from pathlib import Path
from datetime import datetime
import re
import sys

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
start = '<!-- OE9SAU_TEMPGRAPH_JS_START -->'
end = '<!-- OE9SAU_TEMPGRAPH_JS_END -->'
# Remove prior version of this installer (bottom-of-body widget).
old_start = '<!-- ESM TEMPGRAPH START -->'
old_end = '<!-- ESM TEMPGRAPH END -->'
if old_start in s and old_end in s:
    s = re.sub(re.escape(old_start) + r'.*?' + re.escape(old_end), '', s, flags=re.S)
# Remove any previous marker-delimited JS section.
if start in s and end in s:
    s = re.sub(re.escape(start) + r'.*?' + re.escape(end), '', s, flags=re.S)
# Remove a previous OE9SAU graph table row, including the requested marker.
s = re.sub(r'<!-- OE9SAU_TEMPGRAPH -->\s*<tr>\s*<td colspan="2">\s*<div[^>]*>\s*<canvas id="cpuTempChart"></canvas>\s*</div>\s*</td>\s*</tr>', '', s, flags=re.S)
# Remove the graph row created by the earlier move-to-CPU patch.
s = re.sub(r'<tr class="esm-tempgraph-row">\s*<td colspan="2">\s*<div id="esm-tempgraph-panel">.*?</div>\s*</td>\s*</tr>', '', s, flags=re.S)
# Remove previously installed fan rows by ID, leaving unrelated rows alone.
s = re.sub(r'<tr>\s*<td>Fan GPIO18</td>\s*<td id="cpu-gpio18"[^>]*>.*?</td>\s*</tr>', '', s, flags=re.S)
# Avoid duplicate Chart.js includes (only exact local include).
s = re.sub(r'<script\s+src=["\']js/chart\.umd\.min\.js["\']\s*></script>\s*', '', s)
# If older unmarked JS from a manual install exists, abort rather than duplicate handlers.
if 'OE9SAU_TEMPGRAPH_JS' in s or 'function loadCpuTempChart()' in s or 'function colorFanStatus()' in s:
    raise SystemExit('FEHLER: Bereits vorhandenes, nicht eindeutig markiertes Temperaturgraph-JavaScript gefunden. Bitte index.php prüfen.')

anchor = re.search(r'(<tr>\s*<td>Temperature</td>\s*<td id="cpu-temp"></td>\s*</tr>)', s)
if not anchor or '</body>' not in s:
    raise SystemExit('FEHLER: CPU-Temperature-Zeile oder </body> fehlt; index.php unverändert.')

rows = '''
                    <tr>
                        <td>Fan GPIO18</td>
                        <td id="cpu-gpio18">UNKNOWN</td>
                    </tr>
                    <!-- OE9SAU_TEMPGRAPH -->
                    <tr>
                        <td colspan="2">
                            <div style="height:140px; width:100%; margin-top:10px;">
                                <canvas id="cpuTempChart"></canvas>
                            </div>
                        </td>
                    </tr>'''
s = s[:anchor.end()] + rows + s[anchor.end():]

js = r'''<!-- OE9SAU_TEMPGRAPH_JS_START -->
<script src="js/chart.umd.min.js"></script>
<script>
/* OE9SAU_TEMPGRAPH_JS */
let cpuTempChart = null;
function loadCpuTempChart() {
    fetch('temp_history.php?t=' + Date.now())
        .then(response => { if (!response.ok) throw new Error('HTTP ' + response.status); return response.text(); })
        .then(text => {
            const labels = [];
            const temps = [];
            const cutoff = Date.now() - 3600000;
            text.trim().split('\n').forEach(line => {
                const parts = line.trim().split(',');
                if (parts.length !== 2) return;
                const timestamp = parseInt(parts[0], 10);
                const temp = parseFloat(parts[1]);
                if (!Number.isFinite(timestamp) || !Number.isFinite(temp) || timestamp * 1000 < cutoff) return;
                const d = new Date(timestamp * 1000);
                labels.push(d.getHours().toString().padStart(2, '0') + ':' + d.getMinutes().toString().padStart(2, '0'));
                temps.push(temp);
            });
            if (cpuTempChart) {
                cpuTempChart.data.labels = labels;
                cpuTempChart.data.datasets[0].data = temps;
                cpuTempChart.update();
                return;
            }
            const ctx = document.getElementById('cpuTempChart');
            if (!ctx || typeof Chart === 'undefined') return;
            cpuTempChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: labels,
                    datasets: [{ label: 'CPU °C', data: temps, borderWidth: 2, pointRadius: 1, tension: 0.25, fill: false }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    animation: false,
                    scales: {
                        y: {
                            min: 40, max: 80,
                            ticks: { stepSize: 5, autoSkip: false },
                            title: { display: true, text: '°C' }
                        },
                        x: {
                            ticks: {
                                autoSkip: false, maxRotation: 0, minRotation: 0,
                                callback: function(value) {
                                    const label = this.getLabelForValue(value);
                                    return /:(00|15|30|45)$/.test(label) ? label : '';
                                }
                            },
                            grid: {
                                color: function(context) {
                                    const index = context.index;
                                    if (index === undefined || !labels[index]) return 'transparent';
                                    return /:(00|15|30|45)$/.test(labels[index]) ? 'rgba(100,100,100,0.2)' : 'transparent';
                                }
                            }
                        }
                    },
                    plugins: { legend: { display: false } }
                }
            });
        })
        .catch(error => console.error('CPU Temperaturgraph:', error));
}
loadCpuTempChart();
setInterval(loadCpuTempChart, 60000);

/* GPIO18: ON rot, OFF gruen */
function colorFanStatus() {
    const fan = document.getElementById('cpu-gpio18');
    if (!fan) return;
    const status = fan.textContent.trim().toUpperCase();
    fan.style.display = 'inline-block';
    fan.style.padding = '2px 8px';
    fan.style.borderRadius = '0';
    fan.style.fontWeight = 'normal';
    fan.style.color = '#444';
    fan.style.minWidth = '30px';
    fan.style.textAlign = 'center';
    fan.style.backgroundColor = status === 'ON' ? '#e57373' : status === 'OFF' ? '#7ed36d' : 'transparent';
}
async function loadFanStatus() {
    try {
        const response = await fetch('fan_status.php?t=' + Date.now());
        if (!response.ok) throw new Error('HTTP ' + response.status);
        const data = await response.json();
        const fan = document.getElementById('cpu-gpio18');
        if (fan) fan.textContent = data.status || 'UNKNOWN';
    } catch (error) {
        const fan = document.getElementById('cpu-gpio18');
        if (fan) fan.textContent = 'UNKNOWN';
    }
    colorFanStatus();
}
loadFanStatus();
setInterval(loadFanStatus, 1000);
</script>
<!-- OE9SAU_TEMPGRAPH_JS_END -->'''
s = s.replace('</body>', js + '\n</body>', 1)
if s != p.read_text(encoding='utf-8'):
    backup = p.with_name('index.php.bak.' + datetime.now().strftime('%Y%m%d-%H%M%S'))
    backup.write_text(p.read_text(encoding='utf-8'), encoding='utf-8')
    p.write_text(s, encoding='utf-8')
    print('Dashboard aktualisiert. Sicherung:', backup)
PYINDEX

cat > /etc/systemd/system/esm-temp-logger.service <<'SERVICE'
[Unit]
Description=eSM CPU temperature logger

[Service]
Type=oneshot
ExecStart=/usr/local/bin/esm-temp-logger.py
SERVICE
cat > /etc/systemd/system/esm-temp-logger.timer <<'TIMER'
[Unit]
Description=eSM CPU temperature logging every minute

[Timer]
OnBootSec=10s
OnUnitActiveSec=60s
AccuracySec=1s
Unit=esm-temp-logger.service

[Install]
WantedBy=timers.target
TIMER
systemctl daemon-reload
systemctl enable --now esm-temp-logger.timer
systemctl start esm-temp-logger.service

echo 'Installation abgeschlossen.'
echo "Dashboard: http://$(hostname -I | awk '{print $1}')/esm/"
echo 'CPU-Graph: 140px, 40-80 °C, 5 °C Raster, 60 Minuten'
echo 'GPIO18: ON=rot, OFF=gruen'
