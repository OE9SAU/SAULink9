#v1.0: service_led
#v2.0: inkl. watchdog funktion GPIO 21 und Service/Reflektor Check nur 1x/Sekunde prüfen
#v2.1: Watchdog aktiv bei fehlender Reflektorverbidung
#v2.2: GPIO_WATCHDOG = 21 / Neu: GIPO12

#!/usr/bin/env python3
import RPi.GPIO as GPIO
import time
import subprocess
import os

GPIO.setmode(GPIO.BCM)

GPIO_WATCHDOG = 12
GPIO_SVXLINK = 26
GPIO_REFLECTOR = 25


GPIO.setup(GPIO_WATCHDOG, GPIO.OUT)
GPIO.setup(GPIO_SVXLINK, GPIO.OUT)
GPIO.setup(GPIO_REFLECTOR, GPIO.OUT)

GPIO.output(GPIO_WATCHDOG, GPIO.LOW)
GPIO.output(GPIO_SVXLINK, GPIO.LOW)
GPIO.output(GPIO_REFLECTOR, GPIO.LOW)

LOGFILE = "/var/log/svxlink"
LINES_TO_READ = 200

BLINK_SVX = 0.15
BLINK_FAST = 0.15
BLINK_SLOW = 0.5

_last_svx = 0.0
_last_ref = 0.0
_svx_state = False
_ref_state = False

CHECK_INTERVAL = 1.0          # Service nur 1x/s prüfen
_last_check = 0
service_ok = False

REFLECTOR_CHECK_INTERVAL = 1.0
_last_reflector_check = 0
reflector_state = "DOWN"

TEST_MODE = False   # True = SVXLink Service ignorieren (nur mit Reflektor verbindung testen)


def svxlink_running():
    return subprocess.run(
        ["systemctl", "is-active", "--quiet", "svxlink"]
    ).returncode == 0


def reflector_status():
    if not os.path.isfile(LOGFILE):
        return "DOWN"

    try:
        with open(LOGFILE, "r", errors="ignore") as f:
            lines = f.readlines()[-LINES_TO_READ:]
    except Exception:
        return "DOWN"

    for line in reversed(lines):
        if "Authentication OK" in line:
            return "UP"
        if "Connection established" in line:
            return "CONNECTING"
        if (
            "Heartbeat timeout" in line
            or "Access denied" in line
            or "Disconnected from" in line
        ):
            return "ERROR"

    return "DOWN"


def update_reflector_led(status):
    global _last_ref, _ref_state
    now = time.monotonic()

    # ERROR → Dauer-AN
    if status == "ERROR":
        _ref_state = True
        GPIO.output(GPIO_REFLECTOR, GPIO.HIGH)
        return

    # DOWN → AUS
    if status == "DOWN":
        _ref_state = False
        GPIO.output(GPIO_REFLECTOR, GPIO.LOW)
        return

    # CONNECTING → langsam blinkend
    if status == "CONNECTING":
        interval = BLINK_SLOW

    # UP → schnell blinkend
    elif status == "UP":
        interval = BLINK_FAST

    else:
        GPIO.output(GPIO_REFLECTOR, GPIO.LOW)
        return

    if now - _last_ref >= interval:
        _ref_state = not _ref_state
        GPIO.output(GPIO_REFLECTOR, _ref_state)
        _last_ref = now


try:
    while True:
        now = time.monotonic()

        # --- Service Check 1x/s ---
        if now - _last_check >= CHECK_INTERVAL:
            new_state = svxlink_running()

            if new_state and not service_ok:
                _last_svx = 0
                _svx_state = False

            service_ok = new_state
            _last_check = now

        # --- Reflector Check 1x/s ---
        if now - _last_reflector_check >= REFLECTOR_CHECK_INTERVAL:
            reflector_state = reflector_status()
            _last_reflector_check = now

        # --- LED + Watchdog 50ms Loop ---

        # SVXLink LED blinkt immer (nur optisch)
        if now - _last_svx >= BLINK_SVX:
            _svx_state = not _svx_state
            GPIO.output(GPIO_SVXLINK, _svx_state)
            _last_svx = now

        # Reflektor LED aktualisieren
        update_reflector_led(reflector_state)

        # --- Watchdog Logik ---
        # --- Watchdog Logik ---
        if TEST_MODE:
            # Service wird ignoriert
            if reflector_state in ("UP", "CONNECTING"):
                GPIO.output(GPIO_WATCHDOG, _ref_state)
            else:
                GPIO.output(GPIO_WATCHDOG, GPIO.HIGH)

        else:
            # Produktionsbetrieb
            if service_ok:
                if reflector_state in ("UP", "CONNECTING"):
                    GPIO.output(GPIO_WATCHDOG, _ref_state)
                else:
                    GPIO.output(GPIO_WATCHDOG, GPIO.HIGH)
            else:
                # Service down → alles Fehler
                GPIO.output(GPIO_WATCHDOG, GPIO.HIGH)
                GPIO.output(GPIO_SVXLINK, GPIO.HIGH)
                GPIO.output(GPIO_REFLECTOR, GPIO.HIGH)

        time.sleep(0.05)

except KeyboardInterrupt:
    pass
finally:
    GPIO.cleanup()
