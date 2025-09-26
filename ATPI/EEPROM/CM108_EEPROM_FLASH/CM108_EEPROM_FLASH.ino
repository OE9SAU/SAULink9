#include <93C46.h>

// Pins für 93C46BT-I/OT
#define CS_PIN 10
#define DI_PIN 11
#define DO_PIN 12
#define SK_PIN 13
#define BUTTON_PIN 9   // Taster an Pin 9 gegen GND

eeprom_93C46 eeprom(CS_PIN, SK_PIN, DI_PIN, DO_PIN);

// --- Helper-Funktionen für 64x16 EEPROM ---

// Lese ein 16-Bit-Wort
uint16_t readWord64x16(byte wordAddr) {
  byte low  = eeprom.read(wordAddr * 2);       // LSB
  byte high = eeprom.read(wordAddr * 2 + 1);  // MSB
  return (high << 8) | low;
}

// Schreibe ein 16-Bit-Wort
void writeWord64x16(byte wordAddr, uint16_t word) {
  byte low  = word & 0xFF;
  byte high = (word >> 8) & 0xFF;
  eeprom.write(wordAddr * 2, low);       // LSB
  eeprom.write(wordAddr * 2 + 1, high);  // MSB
}

// --- Flashroutine ---
void flashProductString() {
  // Schreibschutz aufheben
  eeprom.ew_enable();

  // --- Product String 30-Byte ("SAULink9_ATPI") ---
  const char productString[] = "SAULink9_ATPI";  // 13 Zeichen
  byte startByte = 0x0B; // Startadresse des Product Strings

  for (byte i = 0; i < 30; i++) {
    byte wordAddr = (startByte + i) / 2;
    uint16_t word = readWord64x16(wordAddr);

    if ((startByte + i) % 2 == 0) { // LSB
      word = (word & 0xFF00) | (i < sizeof(productString) - 1 ? productString[i] : 0x00);
    } else { // MSB
      word = (word & 0x00FF) | ((i < sizeof(productString) - 1 ? productString[i] : 0x00) << 8);
    }

    writeWord64x16(wordAddr, word);
  }

  // Schreibschutz wieder aktivieren
  eeprom.ew_disable();

  Serial.println("✅ EEPROM Product String programmiert!");
}

// --- String einmal lesen und ausgeben ---
void printProductString() {
  const byte startByte = 0x0B;
  Serial.print("👁 EEPROM String: ");
  for (byte i = 0; i < 30; i++) {
    byte wordAddr = (startByte + i) / 2;
    uint16_t word = readWord64x16(wordAddr);
    char val = ((startByte + i) % 2 == 0) ? (word & 0xFF) : (word >> 8);
    if (val != 0x00) Serial.print(val);  // nur druckbare Zeichen
  }
  Serial.println();
}

void setup() {
  Serial.begin(9600);
  pinMode(BUTTON_PIN, INPUT_PULLUP); // Taster gegen GND
  Serial.println("⏳ Drücke den Taster, um den Flashvorgang zu starten.");
}

void loop() {
  // Button prüfen (LOW = gedrückt)
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("⚡ Flashvorgang gestartet...");
    flashProductString();
    delay(500);  // kleine Pause
    printProductString();  // String einmal auslesen
    Serial.println("⏳ Drücke den Taster, um den Flashvorgang zu starten.\n");
    delay(1000); // Entprellung / Mehrfachauslösung verhindern
  }

  // ansonsten: nichts tun → warten auf Taster
}
