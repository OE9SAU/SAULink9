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
LINES_TO_READ = 200

BLINK_SVX = 0.1
BLINK_FAST = 0.1
BLINK_SLOW = 0.5

_last_svx = 0
_last_ref = 0
_svx_state = False
_ref_state = False


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
    now = time.time()

    if status == "ERROR":
        GPIO.output(GPIO_REFLECTOR, GPIO.HIGH)
        return

    if status == "UP":
        interval = BLINK_FAST
    elif status == "CONNECTING":
        interval = BLINK_SLOW
    else:
        GPIO.output(GPIO_REFLECTOR, GPIO.LOW)
        return

    if now - _last_ref >= interval:
        _ref_state = not _ref_state
        GPIO.output(GPIO_REFLECTOR, _ref_state)
        _last_ref = now


try:
    while True:
        now = time.time()

        if svxlink_running():
            if now - _last_svx >= BLINK_SVX:
                _svx_state = not _svx_state
                GPIO.output(GPIO_SVXLINK, _svx_state)
                _last_svx = now

            status = reflector_status()
            update_reflector_led(status)

        else:
            GPIO.output(GPIO_SVXLINK, GPIO.LOW)
            GPIO.output(GPIO_REFLECTOR, GPIO.LOW)

        time.sleep(0.05)

except KeyboardInterrupt:
    pass
finally:
    GPIO.cleanup()
