#!/bin/bash
# SAULink9 - Lüftersteuerung mit pigpio
# GPIO 18 EIN bei >65°C
# GPIO 18 AUS bei <50°C
#

GPIO=18
TEMP_ON=65
TEMP_OFF=50
INTERVAL=5

# Warten bis pigpiod erreichbar ist
for i in {1..10}; do
    pigs t >/dev/null 2>&1 && break
    sleep 0.5
done

if ! pigs t >/dev/null 2>&1; then
    exit 1
fi

pigs modes $GPIO w
pigs w $GPIO 0

STATE=0

while true; do
    TEMP=$(( $(< /sys/class/thermal/thermal_zone0/temp) / 1000 ))

    if [ "$TEMP" -ge "$TEMP_ON" ] && [ "$STATE" -eq 0 ]; then
        pigs w $GPIO 1
        STATE=1
    elif [ "$TEMP" -le "$TEMP_OFF" ] && [ "$STATE" -eq 1 ]; then
        pigs w $GPIO 0
        STATE=0
    fi

    sleep "$INTERVAL"
done