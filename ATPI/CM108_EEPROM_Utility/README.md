# CM108 EEPROM Utility (93C46)

Dieses Tool dient zum **Auslesen, Bearbeiten und Beschreiben** des **93C46 EEPROM**, das auf dem **SAULink9_ATPI**-Board verbaut ist (oder nachgerüstet werden kann).  
Damit lassen sich Konfigurationen (z. B. **Vendor-/Product-IDs**, **Audio-Einstellungen** u. v. m.) für den **CM108-Soundchip** ändern.  
Der CM108 liest beim Start, wenn vorhanden, die Konfigurationsdaten aus dem EEPROM und speichert sie flüchtig intern ab.

---

## ✨ Funktionen

- **EEPROM-Produktstring auslesen**  
- **EEPROM-Produktstring schreiben**  
- **EEPROM löschen**  
- **Hex-Dump** (kompletter Inhalt des 93C46)  

---

## 💻 Hardware / Code

- Getestet mit **Arduino UNO**  
- Kommunikation direkt mit dem 93C46 EEPROM über SPI/Microwire  
- Beispielcode im Ordner enthalten  

---

## ⚙️ Verwendung (Konsole)

1. Code mit der Arduino IDE auf den Arduino UNO laden.  
2. Über die serielle Schnittstelle Befehle senden (z. B. via Arduino Serial Monitor oder `screen`/`minicom`).  
3. Beispiele:  

