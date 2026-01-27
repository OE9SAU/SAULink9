<p align="center">
  <img width="500" height="500" src="update.png">
</p>

# Script für Update der Status LEDs im Frontpanel

...dient der Anpassung der Statusanzeige von SVXLink-Dienst und Reflektor-Verbindungen über die beiden roten GPIO-LEDs im Frontpanel.

### Statusanzeige – SVXLink (STAT LED 1 bestehend)

| SVXLink-Zustand      | LED-Verhalten        |
|----------------------|----------------------|
| SVXLink läuft nicht  | AUS                  |
| SVXLink läuft        | Blinkend (0,5 s)     |

### Statusanzeige – Reflektor (STAT LED 2 Neu)

| Reflektor-Zustand | LED-Verhalten        |
|-------------------|----------------------|
| DOWN              | AUS                  |
| CONNECTING        | Langsam blinkend     |
| UP                | Schnell blinkend     |
| ERROR             | Dauer-AN             |

## Installation
### Script von GitHub laden
```
sudo curl -fsSL https://raw.githubusercontent.com/<DEIN_GITHUB_USER>/<DEIN_REPO>/main/svxlink-gpio-status.py \
  -o /usr/local/sbin/svxlink-gpio-status.py \
  && sudo chmod 755 /usr/local/sbin/svxlink-gpio-status.py
```
### Service aktivieren
```
sudo systemctl daemon-reload
sudo systemctl enable svxlink-gpio-status.service
sudo systemctl start svxlink-gpio-status.service
```




---
# Script für Rpi System-Update

Führt ein normales Systemupdate (apt update + apt upgrade) durch und stellt anschließend sicher, 

dass Apache wieder mit PrivateTmp=false läuft. Was für die Funktion von DTMF und Co benötigt wird!

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

