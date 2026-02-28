<?php
$config = require __DIR__.'/includes/config.php';
require __DIR__.'/includes/hostapd.php';

if ($_POST['action'] === 'apply') {
    writeHostapd($config['hostapd_conf'], $_POST);

    if ($_POST['mode'] === 'restart') {
        exec('sudo systemctl restart hostapd');
    } else {
        exec('sudo systemctl reload hostapd');
    }
}
header('Location: index.php');
