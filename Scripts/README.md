<p align="center">
  <img width="500" height="500" src="update.png">
</p>

# FanControl
Temperaturgesteuerte Lüftersteuerung für den SAULink mit **pigpio**.

Für den Lüftereinbau muss der Gehäusedeckel modifiziert werden.

Verwendeter Lüfter: https://www.amazon.de/dp/B0DKJP347L?ref_=ppx_hzsearch_conn_dt_b_fed_asin_title_2

## Funktionen

- GPIO 18 schaltet einen Lüfter über den MosFet auf dem Rpi_Hat
- Lüfter EIN ab 65 °C
- Lüfter AUS unter 50 °C
- Hysterese verhindert Flattern
- Startet automatisch beim Booten über systemd

## Installation
```
wget -qO install.sh https://raw.githubusercontent.com/OE9SAU/SAULink9/main/Scripts/fancontrol/install.sh && chmod +x install.sh && sudo ./install.sh
```

## Standardwerte

| Parameter | Wert |
|-----------|------|
| GPIO | 18 |
| Einschalten | 65 °C |
| Ausschalten | 50 °C |
| Prüfintervall | 5 Sekunden |

## Dienst

Status anzeigen:

```
systemctl status fancontrol
```

Neustarten:

```
sudo systemctl restart fancontrol
```

Stoppen:

```
sudo systemctl stop fancontrol
```
---

# Update SvxLink Dashboard Ver 2.1
### Verbesserte aktualisierung der SVXReflector Activity Tabelle

-Sortierung verbessert

-Datum wird mitangezeigt

-Anzeige auf 23 Einträge erweitert


# Script herunterladen
```
wget -O /tmp/lh_update.sh \
https://raw.githubusercontent.com/OE9SAU/SAULink9/refs/heads/main/Scripts/lh_update.sh
```

# Rechte setzen
```
sudo chmod +x /tmp/lh_update.sh
```
# Script ausführen
```
sudo /tmp/lh_update.sh
```
---
# Update der Status LEDs im Frontpanel

v2.3: LINES_TO_READ = 200 auf 500, für besseres Erkennen der Zustände vom Reflektor

v2.2: GPIO_WATCHDOG = 21 / Neu: GIPO12

v2.1 GPIO21 auch als Trigger bei fehlender Reflektorverbindung für Watchdog-Anwendung hinzugefügt

v2.0 GPIO21 als Trigger für gestoppten SVXLink Dienst für Watchdog-Anwendung hinzugefügt, sowie Service/Reflektor Check nur 1x/Sekunde prüfen

Watchdog Schaltung unter SAULink9/Watchdog

Script dient der Anpassung der Statusanzeige von SVXLink-Dienst und der Reflektor-Verbindungen über die beiden roten GPIO-LEDs im Frontpanel.

### Statusanzeige – SVXLink (STAT LED 1 bestehend)

|SVXLink               | LED-Verhalten        |
|----------------------|----------------------|
| Dienst läuft nicht   | Dauer-AN             |
| Dienst läuft         | Blinkend (0,5 s)     |

### Statusanzeige – Reflektor (STAT LED 2 Neu)

| Reflektor Verbindung | LED-Verhalten        |
|-------------------|----------------------|
| UP                | Blinkend (0,5 s)     |
| CONNECTING        | Langsam blinkend     |
| DOWN / ERROR      | Dauer-AN             |

## Installation:
```
sudo systemctl stop svxlink_service_led.service
```
### Script von GitHub laden:
```
sudo cp -a /usr/local/bin/svxlink_service_led.py \
/usr/local/bin/svxlink_service_led.py.bak 2>/dev/null || true \
&& sudo curl -fsSL https://raw.githubusercontent.com/OE9SAU/SAULink9/refs/heads/main/Scripts/svxlink_service_led.py \
-o /usr/local/bin/svxlink_service_led.py \
&& sudo chmod 755 /usr/local/bin/svxlink_service_led.py
```
### Service aktivieren:
```
sudo systemctl daemon-reload && \
sudo systemctl enable svxlink_service_led.service && \
sudo systemctl start svxlink_service_led.service
```
### Service Status:
```
sudo systemctl status svxlink_service_led.service
```
---
# Rpi System-Update:

Script führt ein normales Systemupdate (apt update + apt upgrade) durch und stellt anschließend sicher, 

dass der Apache Webserver wieder mit PrivateTmp=false läuft. Was für die Funktion von DTMF und Co benötigt wird!

## Voraussetzung: 

SAULink9 mit Debian 12 "Bookworm"

OS und Release Version anzeigen
```
. /etc/os-release && echo "Debian $VERSION_ID.$(cut -d. -f2 /etc/debian_version) ($VERSION_CODENAME)"
````

# Funktionsweise:
1. Systemupdate ausführen
2. systemd-Override für apache2 prüfen/erstellen:
/etc/systemd/system/apache2.service.d/override.conf
3. systemd neu laden
4. Apache neu starten
5. Status von PrivateTmp anzeigen

# Verwendung:
Script von GitHub laden
````
sudo curl -fsSL https://raw.githubusercontent.com/OE9SAU/SAULink9/refs/heads/main/Scripts/update-system.sh \
  -o /usr/local/sbin/update-system.sh \
  && sudo chmod 755 /usr/local/sbin/update-system.sh
````
Script ausführen
````
sudo update-system.sh
````
# Ablage:
/usr/local/sbin/update-system.sh

