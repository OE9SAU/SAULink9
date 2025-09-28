// CM108 EEPROM Utility
// V1.1 CHATGPT // OE9SAU
//
// LED <--> Arduino Uno:
// Anode <--> Digital 8 (PB0) via 220 Ohm resistor
// Cathode <--> GND
//
// 93C46 <--> Arduino Uno:
// CS <--> Digital D10
// SCK <--> Digital D13
// DI <--> Digital D11
// DO <--> Digital D12
// VCC <--> 5V
// GND <--> GND
//


#include <avr/io.h>
#include <util/delay.h>

const uint8_t PRODUCT_SIZE = 30;
char productString[PRODUCT_SIZE] = "SAULink9 ATPI v3.0";

#define CLEAN 0b00000000

#define DDR93C46  DDRB
#define PORT93C46 PORTB
#define PIN93C46  PINB

#define SK PB5
#define DO PB4
#define DI PB3
#define CS PB2
#define LED PB0

#define READ  0x02
#define EWEN1 0x00
#define EWEN2 0x30
#define WRITE 0x01
#define WRAL1 0x00
#define WRAL2 0x10
#define EWDS1 0x00
#define EWDS2 0x00

#define SET_CS PORT93C46 |= (1 << CS)
#define CLR_CS PORT93C46 &= ~(1 << CS)
#define SET_SK {PORT93C46 |= (1 << SK); _delay_us(1);}
#define CLR_SK PORT93C46 &= ~(1 << SK)
#define SET_DI PORT93C46 |= (1 << DI)
#define CLR_DI PORT93C46 &= ~(1 << DI)
#define SET_LED PORT93C46 |= (1 << LED)
#define CLR_LED PORT93C46 &= ~(1 << LED)

bool firstRun = true;
bool writeMode = false; // nur schreiben wenn W

class SPI_93C46N {
private:
  uint8_t Transfer(uint8_t data) {
    SPDR = data;
    while(!(SPSR & (1 << SPIF)));
    return SPDR;
  }
  void Opcode(uint8_t opcode, uint8_t address) {
    SET_CS;
    SPCR &= ~(1 << SPE);
    _delay_us(5);
    CLR_SK;
    SET_DI;
    SET_SK;
    CLR_SK;
    SPCR |= (1 << SPE);
    Transfer((opcode << 6) | address);
  }
public:
  SPI_93C46N() {
    SPCR = CLEAN & ~(1 << SPIE) | (1 << SPE) & ~(1 << DORD) | (1 << MSTR) & ~(1 << CPOL) & ~(1 << CPHA) | (1 << SPR1) & ~(1 << SPR0);
    SPSR = CLEAN & ~(1 << SPI2X);
    DDR93C46 = CLEAN | (1 << SK) | (1 << DI) | (1 << CS) | (1 << LED) & ~(1 << DO);
    PORT93C46 |= (1 << DO);
    CLR_DI; CLR_CS; CLR_SK; CLR_LED; _delay_us(5);
  }
  uint16_t Read(uint8_t address) {
    uint16_t data = 0;
    Opcode(READ, address);
    CLR_DI; SET_SK; CLR_SK;
    SPCR |= (1 << CPHA);
    data = Transfer(0);
    data = (data << 8) | Transfer(0);
    _delay_us(5);
    CLR_CS; CLR_DI;
    SPCR &= ~(1 << CPHA);
    return data;
  }
  void EraseWriteEnable() { Opcode(EWEN1, EWEN2); CLR_DI; CLR_CS; SET_CS; _delay_us(0.1); while(!(PIN93C46 & (1 << DO))); CLR_CS; }
  void EraseWriteDisable() { Opcode(EWDS1, EWDS2); CLR_DI; CLR_CS; SET_CS; _delay_us(0.1); while(!(PIN93C46 & (1 << DO))); CLR_CS; }
  void Write(uint8_t address, uint16_t data) {
    Opcode(WRITE, address);
    Transfer(data >> 8);
    Transfer(data & 0xFF);
    CLR_DI; CLR_CS; SET_CS; _delay_us(0.1);
    while(!(PIN93C46 & (1 << DO)));
    CLR_CS;
  }
    void EraseAll() {
    Opcode(WRAL1, WRAL2);
    Transfer(0xFF);
    Transfer(0xFF);
    CLR_DI; CLR_CS; SET_CS; _delay_us(0.1);
    while(!(PIN93C46 & (1 << DO))); // warten bis fertig
    CLR_CS;
  }
};

// --- Product String in EEPROM schreiben ---
void WriteProductString(SPI_93C46N &eeprom) {
    uint16_t data;
    for (uint8_t addr = 0x0B; addr <= 0x19; addr++) {
        uint8_t high = productString[(addr-0x0B)*2];
        uint8_t low  = productString[(addr-0x0B)*2 + 1];
        data = (high << 8) | low;
        eeprom.Write(addr, data);
    }
}

// --- Product String aus EEPROM auslesen ---
void ReadProductString(SPI_93C46N &eeprom) {
    Serial.println("Lese Product String aus EEPROM:");
    for (uint8_t addr = 0x0B; addr <= 0x19; addr++) {
        uint16_t data = eeprom.Read(addr);
        char high = (data >> 8) & 0xFF;
        char low  = data & 0xFF;
        Serial.print(high);
        Serial.print(low);
    }
    Serial.println();
}

void DumpEEPROM(SPI_93C46N &eeprom) {
    Serial.println(F("EEPROM Hex-Dump:"));
    for (uint8_t addr = 0; addr <= 0x3F; addr++) {  //93C46 EEPROM hat 64 × 16 Bit, also 64 Wörter, Adressen 0x00 bis 0x3F.
        uint16_t data = eeprom.Read(addr);
        Serial.print("0x");
        if (addr < 0x10) Serial.print("0");
        Serial.print(addr, HEX);
        Serial.print(": 0x");
        if (data < 0x100) Serial.print("0");
        Serial.println(data, HEX);
    }
}

// --- Menü anzeigen ---
void PrintMenu() {
    Serial.println(F("=== EEPROM Utility Menü ==="));
    Serial.println(F("R : Product String auslesen"));
    Serial.println(F("W : Product String schreiben (W und neuen String eingeben max.30 Zeichen)"));
    Serial.println(F("V : EEPROM Hex-Dump anzeigen"));
    Serial.println(F("E : EEPROM komplett löschen"));
    Serial.println(F("M : Menü anzeigen"));
    Serial.println(F("=================="));
}

void setup() {
  Serial.begin(115200);

  // Warten, bis der serielle Monitor verbunden ist
  while (!Serial) {
    ; // einfach warten
  }

  _delay_ms(100); // kleine Pause zur Stabilisierung
  Serial.println("CM108 EEPROM Utility gestartet");
}
void loop() {
    static SPI_93C46N _93C46N; // persistent zwischen loop-Aufrufen

    if (firstRun) {
        //ReadProductString(_93C46N);
        //PrintMenu();
        firstRun = false;
    }

    // --- Schreibmodus ---
    if (writeMode) {
        Serial.println("Schreibmodus aktiv -> String wird geschrieben:");
        writeMode = false; // einmalige Meldung

        String inputString = "";
        while (true) {
            // auf Eingabe warten
            if (Serial.available() > 0) {
                char c = Serial.read();
                if (c == '\n' || c == '\r') break; // Zeilenende
                if (inputString.length() < PRODUCT_SIZE - 1) inputString += c;
            }
        }

        // Input in Product-Array kopieren
        size_t len = inputString.length();
        for (size_t i = 0; i < len; i++) productString[i] = inputString[i];
        for (size_t i = len; i < PRODUCT_SIZE; i++) productString[i] = ' ';

        // EEPROM schreiben
        Serial.println("Schreibe neuen String in EEPROM...");
        _93C46N.EraseWriteEnable();
        WriteProductString(_93C46N);
        _93C46N.EraseWriteDisable();
        ReadProductString(_93C46N);

        // Menü erneut anzeigen
        // PrintMenu();
        return;
    }

    // --- Menü-Kommandos ---
    if (Serial.available() > 0) {
        char cmd = Serial.read(); // direkt lesen

        switch (cmd) {
            case 'R':
            case 'r':
                ReadProductString(_93C46N);
                break;

            case 'M':
            case 'm':
                PrintMenu();
                break;

            case 'W':
            case 'w':
                writeMode = true; // Schreibmodus aktivieren
                break;

            case 'E':
            case 'e':
            Serial.println("Lösche kompletten EEPROM...");
            _93C46N.EraseWriteEnable();
            _93C46N.EraseAll();
            _93C46N.EraseWriteDisable();
            Serial.println("EEPROM wurde gelöscht!");
            break;

            case 'V':
            case 'v':
            DumpEEPROM(_93C46N);
            break;
            
            default:
                // unbekanntes Zeichen verwerfen
                break;
        }
    }
}
