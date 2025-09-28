# CM108 EEPROM Utility (93C46)

Dieses Tool dient zum Auslesen, Bearbeiten und Beschreiben des **93C46 EEPROM**, welcher auf dem SAULink9_ATPI verbaut werden kann.
Damit lassen sich versch. Konfigurationen (z. B. Vendor-/Product-IDs, Audio-Einstellungen) anpassen.

---

## Hintergrund

- **CM108** ist ein weit verbreiteter USB-Audio-Controller.  
- Seine Konfiguration (USB-Kennung, Sound-Optionen, Tastenbelegung usw.) wird in einem externen **93C46 EEPROM** gespeichert.  
- Mit diesem Utility können diese Daten **gelesen, gesichert, geändert und zurückgeschrieben** werden.

---

## Funktionen

- **EEPROM auslesen** → Sicherung der aktuellen Konfiguration  
- **EEPROM beschreiben** → Ändern von Parametern oder Wiederherstellen eines Backups  
- **Dump/Restore von Binärdateien**  
- Debugging und Analyse des 93C46-Inhalts  

---

## Voraussetzungen

- Ein Rechner mit Linux (andere Plattformen evtl. auch möglich)  
- Entwicklungsumgebung (`gcc`, `make`)  
- Abhängigkeiten:
  - `libusb` (für USB-Kommunikation)  
- Schreibrechte auf das USB-Gerät (ggf. `udev`-Regel hinzufügen oder mit `sudo` starten)  

---

## Kompilieren

Im Ordner des Projekts:

```bash
make
