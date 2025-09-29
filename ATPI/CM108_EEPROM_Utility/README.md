# CM108_EEPROM_Utility

A Python tool for accessing the external configuration EEPROM via the ASIC's custom HID endpoint. by https://github.com/islandcontroller

## System requirements

* Python 3.8+
* Windows OS (limitation due to PyWinUSB.HID library)

## Installation

1. Create a new virtual environment using:

        python -m venv .venv

2. Activate the virtual environment

        .\.venv\Scripts\activate

3. Install the dependencies using the provided `requirements.txt` file:

        pip install -r requirements.txt

## Usage

Before running this tool, activate the Python virtual environment using:

    .\.venv\Scripts\activate

The tool uses a YAML configuration file to create and download an EEPROM image to the device. A blank configuration template is provided in [`config_template.yaml`](config_template.yaml). The proposed configuration for fiberaudio-108 boards is provided in [`fiberaudio-108.yaml`](fiberaudio-108.yaml).

To display a help message, use:

    python .\cm108ah.py -h

To list all available Cmedia devices, use: (**Note: Not all listed devices may support EEPROM features**)

    python .\cm108ah.py list

To program a configuration from an existing file into the device, use:

    python .\cm108ah.py program <filename>

Each mode command now supports fields for custom Vendor-ID, Product-ID and device index:

    python .\cm108ah.py read --vid 0d8c --pid 013c --device 1
