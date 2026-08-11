# Hard-Slump

[![Hard-Slump](https://github.com/Syrinx-2112/Hard-Slump/raw/main/HWSlump.jpg)](/Syrinx-2112/Hard-Slump/blob/main/HWSlump.jpg)

Scripts de post-installation Ubuntu pour transformer une machine en **poste de hardware hacking** : développement Arduino/Microchip, dump et programmation d'EEPROM/Flash/BIOS, analyse/rétro-ingénierie de firmwares — et, avec la version ULTRA3, un laboratoire complet (SDR/SIGINT, IoT, automobile, side-channel, Linux embarqué, sécurité réseau, rétro-informatique avancée, PCB/fabrication).

Trois variantes sont fournies selon le niveau d'équipement souhaité :

| Script                                                                                                                                       | Description                                                                                                                                                        |
| ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`install_embedded_firmware_ubuntu.sh`](https://github.com/Syrinx-2112/Hard-Slump/blob/main/install_embedded_firmware_ubuntu.sh)               | Version complète (10 modules) : toolchains, programmateurs, BIOS/UEFI, analyse firmware, IDE, bus série **+ RFID/NFC, Bluetooth/BLE, analyse USB, JTAG discovery** |
| [`install_embedded_firmware_ubuntu-mini.sh`](https://github.com/Syrinx-2112/Hard-Slump/blob/main/install_embedded_firmware_ubuntu-mini.sh)     | Version allégée (9 modules), sans le bloc RFID/BLE/USB/JTAG — pour une install plus rapide ou un scope plus restreint                                              |
| [`install_embedded_firmware_ubuntu_ultra.sh`](https://github.com/Syrinx-2112/Hard-Slump/blob/main/install_embedded_firmware_ubuntu_ultra.sh) ★ | **Console Netrunner ULTRA3** (25 modules) : tout ce qui précède **+ SDR/SIGINT, IoT, automobile, side-channel, Linux embarqué, sécurité réseau, EDA/PCB, stockage, rétro-informatique avancée**. Documentation exhaustive dans [`Tools.md`](https://github.com/Syrinx-2112/Hard-Slump/blob/main/Tools.md) |

> 💡 Les scripts `full` et `mini` installent dans `/opt/embedded/` ; le script `ultra` installe dans `/opt/ultra2/` et journalise dans `/var/log/ultra2_install.log`. Ce sont des environnements indépendants, à ne pas mélanger sur la même machine sans le vouloir.

## Cible

- Ubuntu 22.04 LTS / 24.04 LTS (x86_64)
- Exécution en root via `sudo`
- Pour le script ULTRA3 : 20 Go d'espace disque minimum (100 Go+ recommandés si Yocto/Buildroot/Ghidra sont utilisés), 8 Go de RAM minimum

## Installation

```bash
git clone https://github.com/Syrinx-2112/Hard-Slump.git
cd Hard-Slump
chmod +x install_embedded_firmware_ubuntu.sh
sudo ./install_embedded_firmware_ubuntu.sh
```

Variantes disponibles :

- `install_embedded_firmware_ubuntu-mini.sh` pour la version allégée
- `install_embedded_firmware_ubuntu_ultra.sh` pour la version ULTRA3 (25 modules)

Un redémarrage est recommandé en fin d'installation pour appliquer les règles udev et l'ajout de l'utilisateur aux groupes (`dialout`, `plugdev`, `i2c`, et en plus `bluetooth`, `wireshark` pour les versions complète/ULTRA3, `lp` pour ULTRA3).

## Ce qui est installé

### Toolchains de développement

- **Arduino/AVR** : avr-gcc, avrdude, avr-libc, arduino-cli, PlatformIO Core
- **Microchip PIC** : gputils, SDCC, pk2cmd (si disponible)
- **ARM / Cortex-M** (SAM, STM32) : gcc-arm-none-eabi, OpenOCD, ST-Link tools, dfu-util
- **ESP32/ESP8266** : esptool.py
- **ULTRA3** : ESP-IDF complet, RISC-V, FPGA (Yosys/nextpnr/IceStorm/Trellis)

### Programmation et dump EEPROM / Flash / BIOS

- **flashrom** — lecture/écriture de puces SPI/LPC/FWH (BIOS, UEFI, routeurs)
- **minipro** — pilote libre pour programmateurs TL866A/CS/II+
- **ch341prog** — programmateurs SPI USB type CH341A
- **eeprog** — EEPROM I2C via bus Linux i2c-dev
- **stm32flash** — programmation STM32 via bootloader UART
- Règles udev pour les programmateurs courants (TL866, CH341A, FTDI, ST-Link, CH340, Bus Pirate)
- **ULTRA3** : SRecord, patch de ROMs (Flips, xdelta3, bsdiff), TommyPROM, fwtool, fwupd

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
- **ULTRA3** : angr, qiling, unicorn (émulation/exécution symbolique)

### IDE et debug

- Arduino IDE 2.x (AppImage)
- VS Code (utile avec PlatformIO IDE et Cortex-Debug)

### Bus et instrumentation

- **sigrok / PulseView** — analyseur logique (SPI/I2C)
- **UrJTAG** — chaîne JTAG générique / boundary-scan

### Module complémentaire (versions complète et ULTRA3)

- **RFID/NFC/Smartcard** : libnfc, mfoc/mfcuk, pcsc-tools, client Proxmark3 (fork Iceman)
- **Bluetooth/BLE** : bluez, bettercap, bleak, nrfutil
- **Analyse USB** : usbutils, Wireshark + capture `usbmon`, usbrply, Facedancer
- **JTAG discovery** : JTAGenum (alternative logicielle Arduino), intégration avec OpenOCD/UrJTAG une fois le pinout identifié

### Domaines additionnels ULTRA3 (25 modules)

Documentation exhaustive module par module dans [`Tools.md`](https://github.com/Syrinx-2112/Hard-Slump/blob/main/Tools.md).

| Domaine                          | Aperçu                                                             |
| --------------------------------- | ------------------------------------------------------------------- |
| Récupération mémoires de masse    | TestDisk/PhotoRec, ddrescue, smartmontools, nvme-cli, Clonezilla    |
| Radio Logicielle (SDR)            | GNU Radio, RTL-SDR, HackRF, GQRX, SoapySDR, URH                     |
| Protocoles IoT                    | Zigbee (zigpy), Z-Wave, LoRa, MQTT, Thread/Matter, BLE avancé       |
| Hacking automobile                | CAN Bus (can-utils, python-can), OBD-II, UDS, ICSim                |
| Side-channel & fault injection    | ChipWhisperer, GreatFET, JupyterLab                                 |
| Linux embarqué                    | Yocto/Poky, Buildroot, OpenWrt, QEMU                                |
| Sécurité réseau offensive         | Nmap, Metasploit, Aircrack-ng, Hydra, SQLMap, Hashcat                |
| EDA & PCB avancé                  | KiCad, NG-Spice, Icarus Verilog/GTKWave, GRBL, OpenSCAD              |
| Extensions ROM/Firmware/BIOS      | SRecord, patch IPS/BPS/xdelta (Flips), fwtool, fwupd                 |
| SIGINT & radio avancé             | ADS-B (readsb), AIS-catcher, POCSAG (multimon-ng), ACARS, satellites, modes numériques ham |
| Rétro-informatique avancée        | Formats disque (amitools, AppleCommander, tzxtools), cassettes, cryptologie historique, demoscene |

## Structure installée

### Versions `full` / `mini`

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

### Version ULTRA3

```
/opt/ultra2/
├── avr/ microchip/ flash/ bios_uefi/ firmware_analysis/ ide/ hw_hacking/
├── fpga/ retro/ eda/ media/
├── storage_recovery/ sdr/ iot/ automotive/ side_channel/
├── embedded_linux/ network_security/ pcb/ scopes/
└── README_ULTRA3.txt      → Guide de référence rapide (25 modules)
```

Journal complet : `/var/log/ultra2_install.log`. Détail module par module dans [`Tools.md`](https://github.com/Syrinx-2112/Hard-Slump/blob/main/Tools.md).

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

# RFID / NFC (version complète / ULTRA3)
nfc-list
mfoc -O dump.mfd
pm3

# Bluetooth / BLE (version complète / ULTRA3)
bettercap -iface bt0
bluetoothctl scan on

# Analyse USB (version complète / ULTRA3)
lsusb -v
wireshark -i usbmon1
usbrply -i capture.pcap

# JTAG discovery (version complète / ULTRA3)
picocom -b 115200 /dev/ttyUSB0
openocd -f interface/ftdi/jtagulator.cfg -f target/<mcu>.cfg

# ULTRA3 uniquement — SDR / SIGINT
rtl_fm -f 145500000 -M fm -s 250000 | aplay -r 48000 -f S16_LE -t raw -
hackrf_transfer -r capture.raw -f 433920000 -s 2000000
readsb --device-type rtlsdr --net

# ULTRA3 uniquement — Automobile
candump can0
cansend can0 123#DEADBEEF

# ULTRA3 uniquement — Stockage
ddrescue /dev/sda image.img mapfile.log
smartctl -a /dev/sda

# ULTRA3 uniquement — Rétro avancé
xdftool disk.adf list
flips --create original.bin patched.bin patch.ips
```

## Notes

- Les scripts journalisent leur exécution dans `/var/log/embedded_firmware_install.log` (`full`/`mini`) ou `/var/log/ultra2_install.log` (`ultra`).
- Certaines URLs de release GitHub (Ghidra, Arduino IDE, bettercap, UEFITool) évoluent selon les versions ; en cas d'échec de téléchargement, vérifier manuellement la dernière release.
- La compilation de Proxmark3 nécessite de préciser le bon flavor matériel (RDV4, Easy...) pour être pleinement fonctionnelle.
- Le groupe `wireshark` nécessite une reconnexion de session pour être effectif.
- Certains outils (Proxmark3, JTAGulator, ChipWhisperer, Greaseweazle, dongle sniffer BLE Nordic, Bus Pirate...) nécessitent du matériel dédié pour être réellement utiles.
- Le script ULTRA3 est volumineux (25 modules, plusieurs centaines d'outils) : compter 50–100 Go d'espace disque si Yocto/Buildroot/Ghidra sont installés, et une durée d'exécution significative selon la bande passante.

## Avertissement

Ces outils touchent à la programmation bas niveau de composants, au dump de firmwares propriétaires, à l'analyse de protocoles sans fil et, pour la version ULTRA3, à des domaines sensibles (SIGINT radio, audit réseau offensif, side-channel automobile). Leur usage doit rester conforme aux lois en vigueur et se limiter à du matériel dont vous êtes propriétaire ou pour lequel vous avez une autorisation explicite. La réception de signaux publics (ADS-B, AIS, météo) est généralement autorisée, mais l'interception de communications privées ne l'est pas.
