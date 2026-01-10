# update-system.sh

Führt ein normales Systemupdate (apt update + apt upgrade) durch und stellt anschließend sicher, dass Apache wieder mit PrivateTmp=false läuft.

# Funktionsweise:
1. Systemupdate ausführen
2. systemd-Override für apache2 prüfen/erstellen:
/etc/systemd/system/apache2.service.d/override.conf
3. systemd neu laden
4. Apache neu starten
5. Status von PrivateTmp anzeigen

# Verwendung:
````
sudo update-system.sh
````
# Ablage:
/usr/local/sbin/update-system.sh

