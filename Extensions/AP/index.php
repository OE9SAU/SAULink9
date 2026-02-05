<?php
$config = require __DIR__.'/includes/config.php';
require __DIR__.'/includes/hostapd.php';

$cfg = readHostapd($config['hostapd_conf']);
$status = hostapdStatus();
$clients = connectedClients($config['iface']);
$title = $config['title'].' '.$config['version'];
?>
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title><?= htmlspecialchars($title) ?></title>
<link rel="icon" href="assets/favicon.ico">
<link rel="stylesheet" href="assets/style.css">
</head>
<body>

<header class="topbar">
  <h1><?= htmlspecialchars($title) ?></h1>
</header>

<section class="status <?= $status ?>">
hostapd: <strong><?= strtoupper($status) ?></strong><br>
Primary access via LAN (eth0)
</section>

<h2>👥 Clients</h2>
<table>
<tr><th>MAC</th><th>RSSI</th><th>TX Rate</th></tr>
<?php if (count($clients) === 0): ?>
<tr><td colspan="3">no clients connected</td></tr>
<?php endif; ?>
<?php foreach ($clients as $mac => $data): ?>
<tr>
<td><?= htmlspecialchars($mac) ?></td>
<td><?= htmlspecialchars($data['rssi']) ?></td>
<td><?= htmlspecialchars($data['tx']) ?></td>
</tr>
<?php endforeach; ?>
</table>

<form method="post" action="action.php">
<label>SSID <input name="ssid" value="<?= htmlspecialchars($cfg['ssid']) ?>"></label>
<label>Channel <input name="channel" type="number" min="1" max="13" value="<?= htmlspecialchars($cfg['channel']) ?>"></label>
<label>WPA2 Key <input name="wpa" type="password" value="<?= htmlspecialchars($cfg['wpa']) ?>"></label>

<label>
Apply mode:
<select name="mode">
  <option value="reload">Reload (soft)</option>
  <option value="restart">Restart (hard)</option>
</select>
</label>

<button name="action" value="apply">Apply</button>
</form>

<footer>
<?= htmlspecialchars($config['title']) ?> <?= htmlspecialchars($config['version']) ?>
</footer>

</body>
</html>
