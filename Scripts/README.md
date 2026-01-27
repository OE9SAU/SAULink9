<p align="center">
  <img width="500" height="500" src="update.png">
</p>

# Update der Status LEDs im Frontpanel

Script dient der Anpassung der Statusanzeige von SVXLink-Dienst und NEU Reflektor-Verbindungen über die beiden roten GPIO-LEDs im Frontpanel.

### Statusanzeige – SVXLink (STAT LED 1 bestehend)

|SVXLink               | LED-Verhalten        |
|----------------------|----------------------|
| Dienst läuft nicht   | AUS                  |
| Dienst läuft         | Blinkend (0,5 s)     |

### Statusanzeige – Reflektor (STAT LED 2 Neu)

|Reflektor          | LED-Verhalten        |
|-------------------|----------------------|
| DOWN              | AUS                  |
| UP                | Blinkend (0,5 s)     |
| CONNECTING        | Langsam blinkend     |
| ERROR             | Dauer-AN             |

## Installation
### Script von GitHub laden
```
sudo curl -fsSL https://raw.githubusercontent.com/OE9SAU/SAULink9/refs/heads/main/Scripts/svxlink_service_led.py \
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
# Rpi System-Update

Script führt ein normales Systemupdate (apt update + apt upgrade) durch und stellt anschließend sicher, 

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

