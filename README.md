# Hard-Slump

![Hard-Slump](HWSlump.jpg)

Scripts de post-installation Ubuntu pour transformer une machine en **poste de hardware hacking** : développement Arduino/Microchip, dump et programmation d'EEPROM/Flash/BIOS, et analyse/rétro-ingénierie de firmwares.

Deux variantes sont fournies selon le niveau d'équipement souhaité :

| Script | Description |
| --- | --- |
| [`install_embedded_firmware_ubuntu.sh`](install_embedded_firmware_ubuntu.sh) | Version complète (10 modules) : toolchains, programmateurs, BIOS/UEFI, analyse firmware, IDE, bus série **+ RFID/NFC, Bluetooth/BLE, analyse USB, JTAG discovery** |
| [`install_embedded_firmware_ubuntu-mini.sh`](install_embedded_firmware_ubuntu-mini.sh) | Version allégée (9 modules), sans le bloc RFID/BLE/USB/JTAG — pour une install plus rapide ou un scope plus restreint |

## Cible

- Ubuntu 22.04 LTS / 24.04 LTS (x86_64)
- Exécution en root via `sudo`

## Installation

```bash
git clone https://github.com/KareyPyer/Hard-Slump.git
cd Hard-Slump
chmod +x install_embedded_firmware_ubuntu.sh
sudo ./install_embedded_firmware_ubuntu.sh
```

(ou `install_embedded_firmware_ubuntu-mini.sh` pour la version allégée)

Un redémarrage est recommandé en fin d'installation pour appliquer les règles udev et l'ajout de l'utilisateur aux groupes (`dialout`, `plugdev`, `i2c`, et en plus `bluetooth`, `wireshark` pour la version complète).

## Ce qui est installé

### Toolchains de développement
- **Arduino/AVR** : avr-gcc, avrdude, avr-libc, arduino-cli, PlatformIO Core
- **Microchip PIC** : gputils, SDCC, pk2cmd (si disponible)
- **ARM / Cortex-M** (SAM, STM32) : gcc-arm-none-eabi, OpenOCD, ST-Link tools, dfu-util
- **ESP32/ESP8266** : esptool.py

### Programmation et dump EEPROM / Flash / BIOS
- **flashrom** — lecture/écriture de puces SPI/LPC/FWH (BIOS, UEFI, routeurs)
- **minipro** — pilote libre pour programmateurs TL866A/CS/II+
- **ch341prog** — programmateurs SPI USB type CH341A
- **eeprog** — EEPROM I2C via bus Linux i2c-dev
- **stm32flash** — programmation STM32 via bootloader UART
- Règles udev pour les programmateurs courants (TL866, CH341A, FTDI, ST-Link, CH340, Bus Pirate)

### BIOS / UEFI
- **UEFITool** — exploration/édition d'images BIOS UEFI
- **CHIPSEC** — analyse de sécurité bas niveau firmware (Intel/AMD)
- **cbfstool / ifdtool** (utilitaires coreboot)
- **me_cleaner** — neutralisation partielle Intel ME

### Analyse et rétro-ingénierie de firmwares
- **binwalk**, **unblob** — extraction/identification de systèmes de fichiers embarqués
- **Firmware Mod Kit** — extraction/repackaging d'images routeur (squashfs/jffs2)
- **radare2**, **Ghidra** — désassemblage et analyse binaire
- **EMBA** — framework d'analyse de sécurité firmware orienté IoT

### IDE et debug
- Arduino IDE 2.x (AppImage)
- VS Code (utile avec PlatformIO IDE et Cortex-Debug)

### Bus et instrumentation
- **sigrok / PulseView** — analyseur logique (SPI/I2C)
- **UrJTAG** — chaîne JTAG générique / boundary-scan

### Module complémentaire (version complète uniquement)
- **RFID/NFC/Smartcard** : libnfc, mfoc/mfcuk, pcsc-tools, client Proxmark3 (fork Iceman)
- **Bluetooth/BLE** : bluez, bettercap, bleak, nrfutil
- **Analyse USB** : usbutils, Wireshark + capture `usbmon`, usbrply, Facedancer
- **JTAG discovery** : JTAGenum (alternative logicielle Arduino), intégration avec OpenOCD/UrJTAG une fois le pinout identifié

## Structure installée

```
/opt/embedded/
├── avr/                 → Toolchains Arduino/AVR
├── microchip/            → Toolchains PIC/ARM/ESP32/STM32
├── flash/                → Programmateurs EEPROM/Flash (minipro, ch341prog...)
├── bios_uefi/             → Outils BIOS/UEFI (UEFITool, CHIPSEC, coreboot utils)
├── firmware_analysis/    → Analyse firmware (binwalk, radare2, Ghidra, EMBA)
├── ide/                  → Arduino IDE 2.x (AppImage)
├── hw_hacking/            → RFID/NFC (Proxmark3), USB (usbrply), JTAG (JTAGenum) [version complète]
└── README.txt             → Résumé et commandes générées en fin d'installation
```

Un fichier `/opt/embedded/README.txt` est généré automatiquement en fin d'exécution avec la liste des commandes usuelles.

## Exemples de commandes

```bash
# Arduino / AVR
arduino-cli compile --fqbn arduino:avr:uno sketch/
arduino-cli upload -p /dev/ttyUSB0 --fqbn arduino:avr:uno
avrdude -c usbasp -p m328p -U flash:r:dump.hex:i

# EEPROM / Flash / BIOS
minipro -p ATMEGA328 -r dump.bin
ch341prog -r dump.bin
flashrom -p ch341a_spi -r bios_dump.bin
esptool.py --port /dev/ttyUSB0 read_flash 0 0x400000 dump.bin
stm32flash -r dump.bin /dev/ttyUSB0

# Analyse firmware
binwalk -e dump.bin
uefitool bios_dump.bin
ifdtool -d bios_dump.bin
ghidra

# RFID / NFC (version complète)
nfc-list
mfoc -O dump.mfd
pm3

# Bluetooth / BLE (version complète)
bettercap -iface bt0
bluetoothctl scan on

# Analyse USB (version complète)
lsusb -v
wireshark -i usbmon1
usbrply -i capture.pcap

# JTAG discovery (version complète)
picocom -b 115200 /dev/ttyUSB0
openocd -f interface/ftdi/jtagulator.cfg -f target/<mcu>.cfg
```

## Notes

- Les scripts journalisent leur exécution dans `/var/log/embedded_firmware_install.log`.
- Certaines URLs de release GitHub (Ghidra, Arduino IDE, bettercap, UEFITool) évoluent selon les versions ; en cas d'échec de téléchargement, vérifier manuellement la dernière release.
- La compilation de Proxmark3 nécessite de préciser le bon flavor matériel (RDV4, Easy...) pour être pleinement fonctionnelle.
- Le groupe `wireshark` nécessite une reconnexion de session pour être effectif.
- Certains outils (Proxmark3, JTAGulator, dongle sniffer BLE Nordic, Bus Pirate...) nécessitent du matériel dédié pour être réellement utiles.

## Avertissement

Ces outils touchent à la programmation bas niveau de composants, au dump de firmwares propriétaires et à l'analyse de protocoles sans fil. Leur usage doit rester conforme aux lois en vigueur et se limiter à du matériel dont vous êtes propriétaire ou pour lequel vous avez une autorisation explicite.
