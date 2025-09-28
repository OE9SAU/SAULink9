# CM108 EEPROM Utility (93C46)

This tool is designed to **read, edit, and write** the **93C46 EEPROM** installed on the **SAULink9_ATPI** board.  
It allows you to configure settings for the **CM108 sound chip**, such as **Vendor/Product IDs**, **audio settings**, and more.  
When present, the CM108 reads the configuration data from the EEPROM at startup and stores it temporarily in its internal memory.

---

## ✨ Features

- **Read EEPROM product string**  
- **Write EEPROM product string**  
- **Erase EEPROM**  
- **Hex Dump** (complete content of the 93C46)  

---

## 💻 Hardware / Code

- Tested with **Arduino UNO**  
- Communicates directly with the 93C46 EEPROM via SPI/Microwire  
- Example code is included in this folder  

---

## ⚙️ Usage (Console)

1. Upload the code to the Arduino UNO using the **Arduino IDE**.  
2. Send commands via the serial interface, e.g.:  
   - **Arduino Serial Monitor**  
   - **CM108 EEPROM Utility GUI** 
