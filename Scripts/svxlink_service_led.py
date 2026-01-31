#!/usr/bin/env python3
import RPi.GPIO as GPIO
import time
import subprocess
import os

GPIO.setmode(GPIO.BCM)

GPIO_SVXLINK = 26
GPIO_REFLECTOR = 25

GPIO.setup(GPIO_SVXLINK, GPIO.OUT)
GPIO.setup(GPIO_REFLECTOR, GPIO.OUT)

GPIO.output(GPIO_SVXLINK, GPIO.LOW)
GPIO.output(GPIO_REFLECTOR, GPIO.LOW)

LOGFILE = "/var/log/svxlink"
LINES_TO_READ = 50

BLINK_SVX = 0.1
BLINK_FAST = 0.1
BLINK_SLOW = 0.5

_last_svx = 0.0
_last_ref = 0.0
_svx_state = False
_ref_state = False


def svxlink_running():
    return subprocess.run(
        ["systemctl", "is-active", "--quiet", "svxlink"]
    ).returncode == 0

_reflector_state = "UNKNOWN"

def reflector_status():
    global _reflector_state

    if not os.path.isfile(LOGFILE):
        return _reflector_state

    try:
        with open(LOGFILE, "r", errors="ignore") as f:
            lines = f.readlines()[-LINES_TO_READ:]
    except Exception:
        return _reflector_state

    for line in reversed(lines):

        if "Authentication OK" in line:
            _reflector_state = "UP"
            break

        if "Connection established" in line:
            _reflector_state = "CONNECTING"
            break

        if (
            "Heartbeat timeout" in line
            or "Access denied" in line
            or "Disconnected from" in line
        ):
            _reflector_state = "ERROR"
            break

    return _reflector_state


def update_reflector_led(status):
    global _last_ref, _ref_state
    now = time.monotonic()

    # ERROR → Dauer-AN
    if status == "ERROR":
        GPIO.output(GPIO_REFLECTOR, GPIO.HIGH)
        return

    # UNKNOWN → AUS (Startzustand)
    if status == "UNKNOWN":
        GPIO.output(GPIO_REFLECTOR, GPIO.LOW)
        return

    # CONNECTING → langsam blinkend
    if status == "CONNECTING":
        interval = BLINK_SLOW

    # UP → schnell blinkend
    elif status == "UP":
        interval = BLINK_FAST

    else:
        return

    if now - _last_ref >= interval:
        _ref_state = not _ref_state
        GPIO.output(GPIO_REFLECTOR, _ref_state)
        _last_ref = now


try:
    while True:
        now = time.monotonic()

        if svxlink_running():
            if now - _last_svx >= BLINK_SVX:
                _svx_state = not _svx_state
                GPIO.output(GPIO_SVXLINK, _svx_state)
                _last_svx = now

            status = reflector_status()
            update_reflector_led(status)

        else:
            GPIO.output(GPIO_SVXLINK, GPIO.HIGH)
            GPIO.output(GPIO_REFLECTOR, GPIO.HIGH)

        time.sleep(0.05)

except KeyboardInterrupt:
    pass
finally:
    GPIO.cleanup()
