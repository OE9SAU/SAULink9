<?php

function hostapdStatus(): string
{
    exec('systemctl is-active hostapd 2>/dev/null', $out);
    return $out[0] ?? 'unknown';
}

function readHostapd(string $file): array
{
    $cfg = ['ssid'=>'','channel'=>'','wpa'=>''];
    foreach (@file($file) ?: [] as $line) {
        if (str_starts_with($line, 'ssid=')) $cfg['ssid'] = trim(substr($line,5));
        if (str_starts_with($line, 'channel=')) $cfg['channel'] = trim(substr($line,8));
        if (str_starts_with($line, 'wpa_passphrase=')) $cfg['wpa'] = trim(substr($line,15));
    }
    return $cfg;
}

function writeHostapd(string $file, array $data): void
{
    $conf = <<<EOF
interface=wlan0
ssid={$data['ssid']}
hw_mode=g
channel={$data['channel']}
ieee80211n=1
wmm_enabled=0
auth_algs=1
wpa=2
wpa_passphrase={$data['wpa']}
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF;
    file_put_contents($file, $conf);
}

function connectedClients(string $iface): array
{
    exec("iw dev $iface station dump 2>/dev/null", $out);

    $clients = [];
    $current = null;

    foreach ($out as $line) {
        $line = trim($line);

        if (str_starts_with($line, 'Station')) {
            $parts = explode(' ', $line);
            $current = $parts[1] ?? null;
            if ($current) {
                $clients[$current] = ['rssi'=>'','tx'=>''];
            }
        }

        if ($current && str_starts_with($line, 'signal:')) {
            $clients[$current]['rssi'] = trim(str_replace('signal:', '', $line));
        }

        if ($current && str_starts_with($line, 'tx bitrate:')) {
            $clients[$current]['tx'] = trim(str_replace('tx bitrate:', '', $line));
        }
    }
    return $clients;
}
