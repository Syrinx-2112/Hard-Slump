# 📖 Documentation Ultra-Détaillée — Console Netrunner ULTRA3

**Script de post-installation : Environnement Hardware Hacking & Embedded Firmware**
**Cible :** Ubuntu 22.04 LTS / 24.04 LTS (x86_64)
**Version :** ULTRA3 (fusion de `install_embedded_firmware_ubuntu.sh` + `install_embedded_firmware_ubuntu_ultra.sh`)

---

## 📑 Table des matières

1. [Présentation générale](#1-présentation-générale)
2. [Prérequis & lancement](#2-prérequis--lancement)
3. [Vue d'ensemble des 25 étapes](#3-vue-densemble-des-25-étapes)
4. [Détail des étapes 1–9 : Socle & Firmware](#4-détail-des-étapes-19)
5. [Détail des étapes 10–13 : FPGA, Rétro, EDA, Média](#5-détail-des-étapes-1013)
6. [Détail des étapes 14–21 : Domaines ULTRA2](#6-détail-des-étapes-1421)
7. [Détail des étapes 22–24 : Extensions ULTRA3](#7-détail-des-étapes-2224)
8. [Étape 25 : Finalisation](#8-étape-25--finalisation)
9. [Groupes utilisateurs](#9-groupes-utilisateurs)
10. [Règles udev installées](#10-règles-udev-installées)
11. [Cheat-sheet par domaine](#11-cheat-sheet-par-domaine)
12. [Recommandations & avertissements](#12-recommandations--avertissements)

---

## 1. Présentation générale

### 1.1 Objectif

Ce script transforme une installation Ubuntu vierge en un **laboratoire complet de hardware hacking, rétro-ingénierie firmware et électronique embarquée**. Il installe, configure et interconnecte plusieurs centaines d'outils couvrant :

| Domaine | Exemples |
|---|---|
| Microcontrôleurs | AVR, PIC, ARM Cortex-M, ESP32, STM32, RISC-V |
| Mémoires / Flash | EEPROM, SPI/I²C NOR/NAND, BIOS/UEFI |
| Analyse firmware | binwalk, Ghidra, Angr, Qiling |
| Radio logicielle | RTL-SDR, HackRF, GNU Radio, SIGINT |
| IoT | Zigbee, Z-Wave, LoRa, MQTT, Thread/Matter |
| Automobile | CAN Bus, OBD-II, ECU |
| Side-channel | ChipWhisperer, GreatFET |
| Rétro-informatique | C64, Oric, Atari, Amiga, disquettes, cassettes |
| Sécurité réseau | Nmap, Metasploit, Aircrack |
| EDA / PCB | KiCad, NG-Spice, Yosys, Icarus Verilog |
| Stockage | Récupération HDD/SSD/SD/NVMe |

### 1.2 Philosophie du script

- **Résilience** : chaque installation est enveloppée dans des fonctions qui n'arrêtent pas le script en cas d'échec d'un composant optionnel.
- **Hiérarchie d'installation** : `apt` d'abord, puis `pip`, puis clonage Git + compilation manuelle en dernier recours.
- **Traçabilité** : tout est journalisé dans `/var/log/ultra2_install.log`.
- **Centralisation** : tout est rangé dans `/opt/ultra2/` avec des sous-répertoires thématiques.

### 1.3 Mécanismes internes remarquables

| Fonction | Rôle |
|---|---|
| `log_section()` | Incrémente le compteur d'étape et affiche une bannière |
| `install_pkgs()` | `apt-get install` avec arrêt sur erreur critique |
| `install_pkgs_soft()` | `apt-get install` tolérant aux échecs (paquets optionnels) |
| `clone_or_pull()` | Clone un dépôt Git ou le met à jour s'il existe |
| `pip_install()` | Tente `pip` avec puis sans `--break-system-packages` |
| `add_udev_rule()` | Écrit un fichier de règles udev |
| `check_resources()` | Alerter si < 20 Go de disque libre |

---

## 2. Prérequis & lancement

### 2.1 Prérequis système

- **OS** : Ubuntu 22.04 ou 24.04 LTS, architecture x86_64.
- **Privilèges** : root (`sudo`).
- **Espace disque** : minimum **20 Go** (recommandé **100 Go+** si Yocto/Buildroot/Ghidra sont utilisés).
- **RAM** : 8 Go minimum recommandés.
- **Connexion Internet** : obligatoire (téléchargements massifs).

### 2.2 Lancement

```bash
sudo chmod +x install_embedded_firmware_ubuntu_ultra.sh
sudo ./install_embedded_firmware_ubuntu_ultra.sh
```

Le script demande une confirmation (appuyer sur **Entrée**) avant de démarrer. **Ctrl+C** annule.

### 2.3 Fichiers produits

| Fichier / Répertoire | Contenu |
|---|---|
| `/var/log/ultra2_install.log` | Journal complet d'installation |
| `/opt/ultra2/` | Racine de tous les outils |
| `/opt/ultra2/README_ULTRA3.txt` | Guide de référence rapide |
| `/etc/udev/rules.d/99-*.rules` | Règles de périphériques USB |

---

## 3. Vue d'ensemble des 25 étapes

| # | Étape | Catégorie |
|---|---|---|
| 1 | Préparation du système | Socle |
| 2 | Toolchains Arduino / AVR | MCU |
| 3 | Toolchains Microchip / ARM / ESP32 / STM32 | MCU |
| 4 | Programmateurs EEPROM / Flash SPI-I²C | Mémoire |
| 5 | Outils BIOS / UEFI | Firmware |
| 6 | Analyse & rétro-ingénierie firmware | Firmware |
| 7 | IDE & environnements de debug | Dev |
| 8 | Utilitaires série / bus (UART/I²C/SPI/JTAG) | Bus |
| 9 | Hardware Hacking : RFID/NFC, BLE, USB, JTAG | Hacking |
| 10 | FPGA (Yosys, nextpnr, Quartus, Vivado) | FPGA |
| 11 | Rétro-informatique (C64, Oric, Atari, ZX) | Rétro |
| 12 | Simulation électronique & EDA | EDA |
| 13 | Multimédia, Torrent, P2P, IPTV | Média |
| 14 | Récupération mémoires de masse ★ | Stockage |
| 15 | Radio Logicielle (SDR) ★ | Radio |
| 16 | Protocoles IoT ★ | IoT |
| 17 | Hacking Automobile ★ | Auto |
| 18 | Side-Channel & Fault Injection ★ | Sécurité |
| 19 | Linux Embarqué (Yocto, Buildroot, OpenWrt) ★ | Embarqué |
| 20 | Sécurité Réseau Offensive ★ | Réseau |
| 21 | PCB Avancé & Oscilloscopes ★ | PCB |
| 22 | Extensions ROM/Firmware/BIOS ★★ | ULTRA3 |
| 23 | SIGINT & Radio Avancé ★★ | ULTRA3 |
| 24 | Rétro-Informatique Avancée ★★ | ULTRA3 |
| 25 | Finalisation ULTRA3 | Final |

★ = ajouté en ULTRA2 · ★★ = ajouté en ULTRA3

---

## 4. Détail des étapes 1–9

### 🔹 Étape 1 — Préparation du système

Met à jour le système et installe la « boîte à outils » fondamentale commune à toutes les sections.

#### Mises à jour
```bash
apt-get update -qq
apt-get upgrade -y -qq
```

#### Paquets de compilation & développement

| Paquet | Rôle |
|---|---|
| `build-essential` | GCC, make, libc — base de toute compilation |
| `cmake`, `cmake-extras` | Système de build multiplateforme |
| `git`, `wget`, `curl`, `unzip` | Récupération de sources |
| `pkg-config`, `autoconf`, `automake`, `libtool` | Chaîne autotools |
| `libusb-1.0-0-dev`, `libftdi1-dev` | Accès USB bas niveau (programmateurs, SDR) |
| `gcc-multilib`, `g++-multilib` | Compilation 32 bits sur 64 bits |
| `swig`, `libboost-all-dev`, `libeigen3-dev` | Dépendances pour outils C++/Python |

#### Environnement Python

| Paquet | Rôle |
|---|---|
| `python3-pip`, `python3-dev`, `python3-venv`, `python3-setuptools`, `python3-full` | Runtime Python complet |
| `python3-numpy`, `python3-serial`, `python3-yaml`, `python3-jsonschema` | Librairies scientifiques & série |

Modules **pip** installés globalement :

| Module | Usage |
|---|---|
| `pyserial` | Communication série (tous les MCU) |
| `esptool` | Flashage ESP8266/ESP32 |
| `intelhex`, `bincopy` | Manipulation de fichiers Intel HEX |
| `pyusb`, `pyftdi` | Accès USB/FTDI depuis Python |
| `crcmod`, `construct` | Calcul CRC & parsing binaire |
| `cryptography`, `pycryptodome` | Crypto pour analyse firmware |
| `requests`, `aiohttp`, `websockets` | HTTP/WebSocket |
| `tqdm`, `rich`, `click`, `typer` | CLI modernes & barres de progression |

#### Outils d'analyse & debug système

| Paquet | Rôle |
|---|---|
| `screen`, `minicom`, `picocom`, `putty` | Terminaux série (console UART) |
| `hexedit`, `xxd`, `file` | Édition/visualisation hexadécimale |
| `jq`, `bc` | JSON & calcul |
| `strace`, `ltrace`, `lsof` | Traçage d'appels système/bibliothèque |
| `htop`, `iotop`, `ncdu` | Monitoring ressources |
| `p7zip-full`, `cabextract`, `unrar-free` | Extraction d'archives exotiques |
| `xorriso`, `genisoimage` | Création d'images ISO |

#### Structure de répertoires créée

```bash
/opt/ultra2/{avr,microchip,flash,bios_uefi,firmware_analysis,ide,hw_hacking,
             fpga,retro,eda,media,storage_recovery,sdr,iot,automotive,
             side_channel,embedded_linux,network_security,pcb,scopes,protocols}
```

---

### 🔹 Étape 2 — Toolchains Arduino / AVR

#### 2.1 Toolchain AVR native (apt)

| Paquet | Rôle |
|---|---|
| `gcc-avr` | Compilateur C/C++ pour AVR |
| `avr-libc` | Bibliothèque C standard AVR |
| `avrdude` | Programmateur universel AVR (ISP, USBasp…) |
| `binutils-avr` | objcopy, objdump pour AVR |
| `gdb-avr` | Débugueur AVR |
| `simulavr` | Simulateur AVR |
| `avarice` | Debug AVR via JTAG |

#### 2.2 Arduino CLI
Installé via le script officiel dans `/usr/local/bin`. Cœurs installés :
```bash
arduino-cli core install arduino:avr      # Uno, Mega…
arduino-cli core install arduino:samd     # MKR, Zero…
arduino-cli core install arduino:megaavr  # Uno WiFi Rev2…
```

#### 2.3 PlatformIO Core
Installé via pip. Plateformes installées pour l'utilisateur :
```bash
pio platform install atmelavr
pio platform install espressif32
pio platform install ststm32
```

> ⚙️ L'utilisateur est ajouté au groupe **`dialout`** pour accéder aux ports série sans root.

---

### 🔹 Étape 3 — Toolchains Microchip / ARM / ESP32 / STM32

#### 3.1 PIC
| Paquet | Rôle |
|---|---|
| `gputils` | Assembleur/linker PIC (gpasm, gplink) |
| `sdcc` | Compilateur C multi-architectures (PIC, 8051, Z80…) |

#### 3.2 ARM Cortex-M
| Paquet | Rôle |
|---|---|
| `gcc-arm-none-eabi` | Compilateur C/C++ bare-metal ARM |
| `gdb-multiarch` | Débugueur multi-architectures |
| `binutils-arm-none-eabi` | Outils binaires ARM |
| `libnewlib-arm-none-eabi` | libc bare-metal ARM |

#### 3.3 Debug / Flash
| Outil | Rôle |
|---|---|
| `openocd` | Débug/flash via JTAG/SWD (FTDI, J-Link, ST-Link, CMSIS-DAP) |
| `stlink-tools` | `st-flash`, `st-info` pour ST-Link |
| `dfu-util` | Flashage en mode DFU USB |
| `stm32flash` | Flash STM32 via UART/série |

#### 3.4 ESP-IDF (Espressif)
Cloné dans `/opt/ultra2/microchip/esp-idf`, installation des targets :
`esp32, esp32s2, esp32s3, esp32c3`.

#### 3.5 RISC-V
`gcc-riscv64-unknown-elf` (optionnel, pour ESP32-C3/C6 et autres cœurs RISC-V).

---

### 🔹 Étape 4 — Programmateurs EEPROM / Flash SPI-I²C

#### 4.1 Outils logiciels

| Outil | Installation | Matériel cible | Usage type |
|---|---|---|---|
| `flashrom` | apt | SPI/NOR/LPC/FSB | Dump/flash BIOS, EEPROM SPI |
| `minipro` | Git + make | TL866 (programmateurs universels) | EEPROM, Flash, MCU |
| `ch341prog` | Git + make | CH341A USB | Flash SPI 25xx |
| `snandprog` | Git | NAND | Flash NAND |
| `i2c-tools` | apt | Bus I²C | `i2cdetect`, `i2cdump`, `i2cset` |
| `eeprog` | Git + make | EEPROM I²C | Lecture/écriture 24xx |

#### 4.2 Commandes types
```bash
flashrom -p ch341a_spi -r bios_dump.bin        # Lire
flashrom -p ch341a_spi -w bios_dump.bin        # Écrire
minipro -p ATMEGA328 -r dump.bin               # Lire via TL866
i2cdetect -y 1                                  # Scanner le bus I²C
i2cdump -y 1 0x50                               # Dump EEPROM I²C
```

#### 4.3 Règles udev
Fichier `/etc/udev/rules.d/99-embedded-programmers.rules` couvrant :
- TL866 (minipro)
- CH341A SPI / I²C / UART
- FTDI FT232/FT2232/FT4232
- ST-Link V2/V3
- CH340 Serial
- CMSIS-DAP
- J-Link

> L'utilisateur est ajouté aux groupes **`plugdev`** et **`i2c`**.

---

### 🔹 Étape 5 — Outils BIOS / UEFI

| Outil | Installation | Rôle |
|---|---|---|
| **UEFITool** | Binaire GitHub (AppImage/zip) | Explorateur graphique d'images UEFI (volumes, modules FFS) |
| **CHIPSEC** | pip | Framework d'audit de sécurité plateforme Intel (SPI, MSR…) |
| **coreboot** (`cbfstool`, `ifdtool`) | Git + make | Manipulation d'images coreboot & Intel Flash Descriptor |
| **me_cleaner** | Git | Neutralisation du Management Engine Intel |

#### Commandes types
```bash
uefitool bios_dump.bin              # Explorer graphiquement
ifdtool -d bios_dump.bin            # Extraire régions du descriptor
me_cleaner.py bios_dump.bin -O clean_bios.bin   # Nettoyer le ME
chipsec_util spi dump bios.bin      # Dump SPI via CHIPSEC
```

---

### 🔹 Étape 6 — Analyse & rétro-ingénierie de firmwares

#### 6.1 Extraction / unpacking

| Outil | Installation | Rôle |
|---|---|---|
| `binwalk` | pip | Détection & extraction de signatures dans binaires |
| `unblob` | pip | Extraction automatique multi-formats |
| `firmware-mod-kit` | Git | Modification de firmwares routeurs |

#### 6.2 Systèmes de fichiers embarqués

| Paquet | Rôle |
|---|---|
| `squashfs-tools` | `mksquashfs` / `unsquashfs` |
| `cramfsswap` | Conversion CramFS |
| `mtd-utils` | NAND/NOR (`nanddump`, `flash_erase`…) |
| `jefferson` | Extraction JFFS2 |
| `device-tree-compiler` | `dtc` pour Device Tree |
| `jffs2-tools`, `uboot-tools` | Outils JFFS2 & U-Boot (`mkimage`) |

#### 6.3 Désassemblage / analyse statique

| Outil | Installation | Rôle |
|---|---|---|
| **radare2** | Git + `sys/install.sh` | Désassembleur/analyseur CLI (commande `r2`) |
| **Ghidra** | Binaire GitHub + JDK 21 | Rétro-ingénierie GUI (NSA) |
| **capstone** | pip | Moteur de désassemblage |
| **keystone-engine** | pip | Moteur d'assemblage |
| **lief** | pip | Parsing ELF/PE/Mach-O |

#### 6.4 Analyse dynamique / émulation

| Outil | Installation | Rôle |
|---|---|---|
| `angr` | pip | Exécution symbolique |
| `qiling` | pip | Émulation complète de firmwares |
| `unicorn` | pip | Émulation CPU |
| `fat` (Firmware Analysis Toolkit) | Git + deps | Émulation de firmwares routeurs |
| `emba` | Git | Analyse automatisée de sécurité firmware |

#### Commandes types
```bash
binwalk -e firmware.bin          # Extraire
unsquashfs firmware.squashfs     # Décompresser squashfs
r2 firmware.bin                  # Ouvrir dans radare2
angr ./binary                    # Exécution symbolique
qiling ./firmware.bin            # Émuler
```

---

### 🔹 Étape 7 — IDE & environnements de debug

| IDE | Installation | Rôle |
|---|---|---|
| **Arduino IDE 2.x** | AppImage GitHub | Édition/flash Arduino graphique |
| **VS Code** | .deb Microsoft | Éditeur universel + extensions embedded |
| **Eclipse CDT** | Mention manuelle | Alternative pour projets C/C++ |

Liens symboliques créés : `/usr/local/bin/arduino-ide`, `code`.

---

### 🔹 Étape 8 — Utilitaires série & bus

| Outil | Installation | Rôle |
|---|---|---|
| **sigrok** / **PulseView** / **sigrok-cli** | apt | Framework d'analyse logique multi-matériel |
| **UrJTAG** | apt | Accès JTAG générique |
| **Saleae Logic 2** | Mention manuelle | Analyseur logique propriétaire |
| **OLS** | apt (optionnel) | Open Bench Logic Sniffer |

> 💡 Le Bus Pirate est supporté via `flashrom -p buspirate_spi` ou `picocom`.

---

### 🔹 Étape 9 — Hardware Hacking (RFID/NFC, BLE, USB, JTAG)

#### 9.1 RFID / NFC / Smartcard

| Outil | Installation | Rôle |
|---|---|---|
| `libnfc-bin`, `libnfc-dev` | apt | Bibliothèque NFC |
| `mfoc`, `mfcuk` | apt | Attaques MIFARE Classic |
| `pcscd`, `pcsc-tools`, `libccid` | apt | Lecteurs de cartes à puce |
| **Proxmark3** (Iceman fork) | Git + make client | Outils ultime RFID/NFC (LF/HF) |

Règle udev dédiée : `99-proxmark3.rules`.

#### 9.2 Bluetooth / BLE

| Outil | Installation | Rôle |
|---|---|---|
| `bluez`, `bluez-tools`, `blueman` | apt | Pile Bluetooth Linux |
| `bleak` | pip | BLE cross-plateforme en Python |
| **bettercap** | Binaire GitHub | Framework d'attaque réseau/BLE |
| `nrfutil` | pip | Outils Nordic nRF |

#### 9.3 Analyse USB

| Outil | Installation | Rôle |
|---|---|---|
| `usbutils` | apt | `lsusb`, `usb-devices` |
| `wireshark`, `tshark` | apt | Capture & analyse |
| Module `usbmon` | modprobe + `/etc/modules` | Monitoring USB natif |
| `usbrply` | Git | Réplay de captures USB |
| `facedancer` | pip | Émulation/attaque de périphériques USB |

> L'utilisateur est ajouté aux groupes **`wireshark`** et **`bluetooth`**.

#### 9.4 JTAG Discovery
`JTAGenum` (Git) — énumération de broches JTAG sur cible inconnue.

---

## 5. Détail des étapes 10–13

### 🔹 Étape 10 — FPGA

#### 10.1 Chaîne open-source

| Outil | Installation | Rôle |
|---|---|---|
| **Yosys** | apt ou Git+make | Synthèse RTL |
| **nextpnr** (ice40/ecp5/generic) | apt ou Git+cmake | Place & route |
| **IceStorm** | apt ou Git+make | Bitstream iCE40 |
| **Project Trellis** | apt ou Git+cmake | Bitstream ECP5 |
| **F4PGA** | pip | Suite FPGA open-source (ex-SymbiFlow) |
| **Verilator** | apt | Simulation Verilog |

#### 10.2 Flux de compilation iCE40
```bash
yosys -p "synth_ice40 -top top" design.v
nextpnr-ice40 --hx1k --pcf pins.pcf --json top.json --asc top.asc
icepack top.asc top.bin
iceprog top.bin
```

#### 10.3 Règles udev
`99-fpga-programmers.rules` pour : USB Blaster (Altera), Platform Cable (Xilinx), Digilent, Lattice, iCEstick/iCEBreaker.

> 💡 Quartus & Vivado (propriétaires) : installation manuelle requise.

---

### 🔹 Étape 11 — Rétro-informatique (base)

#### 11.1 Outils génériques
| Outil | Rôle |
|---|---|
| `audacity`, `sox`, `libsndfile1-dev` | Traitement audio (cassettes) |
| `tzx2wav` | Conversion ZX Spectrum TZX → WAV |
| `fdutils`, `mtools`, `libdsk4-utils`, `cpmtools` | Manipulation disquettes |
| **Disk-Utilities** (keirf) | Formats disquettes variés |
| **Greaseweazle** | Lecteur/émulateur USB de disquettes |
| **cartreader** (sanni) | Dump de cartouches |
| `mame`, `retroarch`, `mednafen`, `vice`, `fs-uae` | Émulateurs |

#### 11.2 Commodore 64/128/VIC-20
- **VICE** : émulateurs `x64sc`, `x128`, `xvic`, `xpet` + `c1541`, `petcat`, `cartconv`
- Toolchain 6502 : `64tass`, `acme`, `dasm`, `xa65`, `cc65`
- **Exomizer** : cruncher de données (scène demo)
- **OpenCBM** : piloter un vrai lecteur 1541 via câble XM1541/XA1541

#### 11.3 Oric-1 / Atmos
- **Oricutron** : émulateur SDL2
- **OSDK** : toolchain Oric (XA, libs, TAP/DSK)

#### 11.4 Atari 8-bit
- **atari800** : émulateur de référence (ATR, XFD, CAS, CAR, BIN)
- **hatari** : Atari ST/TT/Falcon (bonus)
- **xasm** : assembleur de la scène Atari
- **Mad Pascal** : Pascal → 6502

#### 11.5 Règles udev
`99-retro.rules` pour Greaseweazle. Accès port parallèle (groupe `lp`, module `ppdev`).

---

### 🔹 Étape 12 — Simulation électronique & EDA

| Outil | Installation | Rôle |
|---|---|---|
| **NG-Spice** | apt | Simulation SPICE |
| **KiCad 8.x** | PPA + apt | Conception schéma/PCB |
| **Icarus Verilog** + **GTKWave** | apt | Simulation Verilog + visualisation de formes d'onde |
| **QUCS / QUCS-S** | apt (optionnel) | Simulation circuit GUI |
| `numpy`, `scipy`, `matplotlib`, `PySpice`, `sympy` | pip | Calcul scientifique & simulation Python |

---

### 🔹 Étape 13 — Multimédia, Torrent, P2P, IPTV

#### Audio
`ffmpeg`, `sox`, `vorbis-tools`, `flac`, `opus-tools`, `lame`, `wavpack`, `audacity`, `pulseaudio-utils`, `pd` (Pure Data), `csound`, `jackd2`

#### Vidéo
`vlc`, `mkvtoolnix`, `gpac`, `handbrake-cli`, `exiftool`, `mediainfo`, `gstreamer1.0-tools`, `imagemagick`, `graphicsmagick`

#### Torrent / P2P
`qbittorrent-nox`, `transmission-cli`, `transmission-daemon`, `rtorrent`

#### Outils web
`yt-dlp` (pip), `m3u8` (pip) pour IPTV.

---

## 6. Détail des étapes 14–21

### 🔹 Étape 14 — Récupération des mémoires de masse ★

#### 14.1 Récupération logicielle
| Outil | Rôle |
|---|---|
| `testdisk` | Récupération de partitions |
| `photorec` | Carving de fichiers |
| `scalpel`, `foremost` | Carving par signatures |
| `gddrescue`, `ddrescue` | Clonage de disques endommagés |
| `extundelete`, `ext4magic` | Restauration ext3/ext4 |
| `safecopy`, `myrescue` | Lecture de secteurs défectueux |
| `sleuthkit`, `autopsy` | Analyse forensique |
| `afflib-tools`, `ewf-tools` | Formats forensiques AFF/EWF |

#### 14.2 Diagnostics HDD/SSD
| Outil | Rôle |
|---|---|
| `smartmontools` | Données S.M.A.R.T. |
| `hdparm` | Paramètres ATA, Secure Erase |
| `nvme-cli` | Diagnostics NVMe |

#### 14.3 Flash (SD/USB/eMMC/NAND)
| Outil | Rôle |
|---|---|
| `mmc-utils` | Commandes bas niveau eMMC/SD |
| `mtd-utils` | `nanddump`, `nandwrite`, `flash_erase` |

#### 14.4 Systèmes de fichiers
`e2fsprogs`, `xfsprogs`, `btrfs-progs`, `ntfs-3g`, `dosfstools`, `exfat-fuse`, `f2fs-tools`, `jfsutils`, `reiserfsprogs`

#### 14.5 Clonage / imagerie
`clonezilla`, `partclone`, `partimage` (+ FOG Project en référence)

#### 14.6 Hardware avancé
- OpenSSD (firmware SSD open-source)
- Référence aux programmateurs chip-off : RT809H, Easy JTAG, Medusa Pro

#### 14.7 Forensique
`bulk-extractor`, `tcpflow`, `tcpdump`, `hashdeep`

#### Commandes clés
```bash
testdisk /dev/sda
photorec /dev/sda
ddrescue /dev/sda image.img mapfile.log
smartctl -a /dev/sda
nvme smart-log /dev/nvme0
extundelete /dev/sda1 --restore-all
nanddump /dev/mtd0 -f nand_dump.bin
```

---

### 🔹 Étape 15 — Radio Logicielle (SDR) ★

| Outil | Installation | Rôle |
|---|---|---|
| **GNU Radio** + `gr-osmosdr` | apt | Framework de traitement radio |
| **rtl-sdr** | apt | Pilotes RTL-SDR |
| **hackrf** | apt | Outils HackRF One |
| **SoapySDR** | apt | Interface universelle SDR |
| **GQRX** | apt | Récepteur SDR graphique |
| **inspectrum** | apt | Analyse de captures IQ |
| **URH** | pip | Universal Radio Hacker |
| **scapy** | pip | Manipulation de paquets |
| Blocs GNU Radio additionnels | `gr-rds`, `gr-ieee802-11`, `gr-ieee802-15-4` |
| **dump1090** | apt | ADS-B |

> 🛑 Le script **blackliste** les pilotes DVB-T (`dvb_usb_rtl28xxu`, `rtl2832`, `rtl2830`) pour libérer le RTL-SDR.

Règles udev `99-sdr.rules` : RTL-SDR, HackRF, USRP, LimeSDR, BladeRF.

#### Commandes types
```bash
rtl_test
rtl_fm -f 145500000 -M fm -s 250000 | aplay -r 48000 -f S16_LE -t raw -
hackrf_info
hackrf_transfer -r capture.raw -f 433920000 -s 2000000
gnuradio-companion
```

---

### 🔹 Étape 16 — Protocoles IoT ★

#### Zigbee
- **Zigbee2MQTT** (via Node.js)
- **zigpy** + dérivés (`zigpy-znp`, `zigpy-deconz`, `bellows`)
- **KillerBee** (recherche sécurité Zigbee)

#### Z-Wave
- **OpenZWave** (Git + make)
- **Z-Wave JS** (npm)

#### LoRa / LoRaWAN
- **ChirpStack** (via Docker)
- **LMIC** (MAC LoRa en C)
- `sx127x` (pip)

#### MQTT
- `mosquitto`, `mosquitto-clients`
- `paho-mqtt`, `mqtt-tools` (pip)

#### Thread / Matter
- **OpenThread** (Git)
- **CHIP / connectedhomeip** (Git)

#### BLE avancé
- `btlejack` (sniffer/jammer via micro:bit)

#### Autres
- CoAP (`aiocoap`), AMQP (`pika`)

Règles udev `99-iot.rules` : ConBee II, CC2531, sticks Z-Wave, LoRa USB.

---

### 🔹 Étape 17 — Hacking Automobile ★

#### CAN Bus
- `can-utils` (SocketCAN)
- Modules `vcan`, `can` chargés
- `python-can`, `cantools`, `can-isotp` (pip)
- **ICSim** : simulateur de tableau de bord

#### OBD-II
- `obd` (pip), `scantool`

#### ECU / Flashing
- `udsoncan` (pip) — UDS
- **CANFlasher** (Git)

#### Automotive Ethernet
- `tcpdump`, `wireshark`, `scapy`

Règles udev `99-can.rules` : CANtact/CANable, PCAN-USB, Kvaser, USB2CAN, ELM327.

#### Commandes types
```bash
candump can0
cansend can0 123#DEADBEEF
cangen can0
icsim
```

---

### 🔹 Étape 18 — Side-Channel & Fault Injection ★

| Outil | Installation | Rôle |
|---|---|---|
| **ChipWhisperer** | Git + pip `-e` | Plateforme d'analyse par canal auxiliaire |
| **Jupyter / JupyterLab** | pip | Notebooks d'expérimentation |
| `libsigrok4` | apt | Acquisition oscilloscope |
| **LUNA** | Git | PHY USB pour analyse |
| **GreatFET** | pip | Plateforme multi-usage |
| `pyaes`, `pycryptodome` | pip | Crypto pour analyse |

Règles udev `99-chipwhisperer.rules` : ChipWhisperer Lite/CW308/CW305, GreatFET.

```bash
python3 -c "import chipwhisperer as cw; print(cw.__version__)"
jupyter lab
greatfet info
```

---

### 🔹 Étape 19 — Linux Embarqué ★

#### Dépendances Yocto/Buildroot
`gawk`, `texinfo`, `chrpath`, `socat`, `cpio`, `python3-pexpect`, `pylint`, `mesa-common-dev`, `zstd`, `lz4`, etc.

#### Frameworks clonés
| Projet | Rôle |
|---|---|
| **Yocto / Poky** | Construction de distributions Linux sur mesure |
| **Buildroot** | Construction de systèmes embarqués simples |
| **OpenWrt** | Distribution pour routeurs |

#### Outils complémentaires
- `u-boot-tools` (`mkimage`)
- **QEMU** : émulation ARM/MIPS/RISC-V/x86
- `device-tree-compiler`

```bash
cd /opt/ultra2/embedded_linux/buildroot
make qemu_x86_64_defconfig && make
```

---

### 🔹 Étape 20 — Sécurité Réseau Offensive ★

| Outil | Installation | Rôle |
|---|---|---|
| **Nmap** + Ncat | apt | Scan de ports |
| **Metasploit** | Script omnibus | Framework d'exploitation |
| **Aircrack-ng** | apt | Audit WiFi |
| **Hydra** | apt | Brute force |
| **SQLMap** | pip ou Git | Injection SQL |
| **John the Ripper** | apt | Cassage de mots de passe |
| **Hashcat** | apt | Cassage GPU |
| **Responder** | Git | Empoisonnement LLMNR/NBT-NS |
| **Netcat / Socat** | apt | Couteaux suisses réseau |
| **Masscan** | apt | Scan ultra-rapide |
| **Nikto** | apt | Scanner web |
| **Wifite** | apt | Audit WiFi automatisé |
| **dnsrecon / dnsenum** | apt | Reconnaissance DNS |

```bash
nmap -sV -sC -p- target
msfconsole
airmon-ng start wlan0
airodump-ng wlan0mon
hashcat -m 0 hash.txt wordlist.txt
```

---

### 🔹 Étape 21 — PCB Avancé & Oscilloscopes ★

#### PCB Design
- **KiCad** (déjà installé) + plugins (Interactive BOM, JLCPCB)
- **Horizon EDA** (optionnel)
- **gerbv**, `pcb-tools` (visualisation Gerber)
- **Fritzing** (prototypage)

#### Fabrication
- **GRBL** (Git) — CNC/laser
- **Universal G-Code Sender** (référence Java)
- **Cura**, **PrusaSlicer**, **OpenSCAD** (impression 3D)

#### Oscilloscopes
- **Sigrok/PulseView** (déjà installé)
- Référence OpenScope (Digilent), Bitscope

---

## 7. Détail des étapes 22–24

### 🔹 Étape 22 — Extensions ROM / Firmware / BIOS ★★

#### 22.1 Conversion de formats binaires
- **SRecord** (`srec_cat`) : Motorola S-Record ↔ Intel HEX ↔ binaire
- `objcopy` (binutils) : ELF ↔ BIN ↔ HEX

```bash
srec_cat input.hex -Intel -o output.bin -Binary
```

#### 22.2 Patch de ROMs
- `xdelta3`, `bsdiff` : patchs différentiels
- **Flips** (Floating IPS) : IPS/BPS

```bash
flips --create original.bin patched.bin patch.ips
xdelta3 -e -s original.bin patched.bin patch.xd3
xdelta3 -d -s original.bin patch.xd3 patched.bin
```

#### 22.3 Programmateurs vintage
- **TommyPROM** : EEPROM parallèles 27xxx/28xxx via Arduino
- **picprog** : PIC via port série

#### 22.4 Rebuild d'images firmware
- **fwtool** (OpenWrt) : lecture/écriture d'en-têtes
- `mkimage` / `dumpimage` (uboot-tools)

#### 22.5 UEFI avancé
- **fwupd** / `fwupdmgr` : mises à jour firmware standard Linux

---

### 🔹 Étape 23 — SIGINT & Radio Avancé ★★

#### 23.1 Aviation / Maritime
- **readsb** : décodage ADS-B 1090 MHz
- **AIS-catcher** : identification navires (161/162 MHz)

#### 23.2 Signaux numériques large bande
- **multimon-ng** : POCSAG, FLEX, AFSK, DTMF (pagers)
- **acarsdec** : messages ACARS avionique
- **welle.io** : DAB/DAB+
- **rtl_433** : capteurs ISM 433/868/915 MHz

#### 23.3 Satellites / Espace
- **gpredict** : suivi orbital
- **gr-satellites** : décodage télémesure CubeSats
- **predict** : calcul de trajectoires CLI
- Référence **noaa-apt** pour images météo NOAA APT

#### 23.4 Radioamateur numérique
- **fldigi**, **flrig** : modes numériques
- **wsjt-x** : FT8, JT65…
- **js8call** : JS8
- **direwolf** : TNC logiciel APRS/Packet

```bash
readsb --device-type rtlsdr --net
ais-catcher -d 0 -o 2
multimon-ng -a POCSAG512 -f alpha /dev/stdin
gpredict
direwolf -c direwolf.conf
```

> ⚖️ **Rappel légal** : l'interception de communications privées est réglementée. Ces outils sont destinés à la réception passive de signaux publics (ADS-B, AIS, météo) ou à l'expérimentation sur du matériel dont vous êtes propriétaire.

---

### 🔹 Étape 24 — Rétro-informatique Avancée ★★

#### 24.1 Interfaces disquettes physiques
- **HxC Floppy Emulator tools** (conversion d'images)
- Référence Applesauce / KryoFlux (clients propriétaires)
- Greaseweazle déjà présent (`gw read/write`, `.scp`/`.hfe`)

#### 24.2 Conversion d'images par plateforme
| Plateforme | Outil |
|---|---|
| Amiga | **amitools** (`xdftool` pour ADF, `unadf`) |
| Apple II | **AppleCommander** (Java) — DSK/PO/2MG/WOZ |
| ZX Spectrum | **tzxtools** (TZX/TAP) |
| MSX | **openMSX** |

#### 24.3 Cassettes audio
- **wav-prg** : TAP ↔ WAV pour Commodore 64

#### 24.4 Cryptologie historique
- **py-enigma** : simulateur de machine Enigma (pédagogique)

#### 24.5 Demoscene & rétro-BBS
- **MilkyTracker**, **Schism Tracker** : MOD/XM/IT/S3M
- **ansilove** : rendu d'art ANSI/ASCII
- **lrzsz** : transferts X/Y/Zmodem
- **cool-retro-term** : terminal look CRT

```bash
xdftool disk.adf list
python3 -m tzxtools.tzxcat tape.tzx
java -jar AppleCommander.jar -l disk.dsk
ansilove art.ans -o art.png
```

---

## 8. Étape 25 — Finalisation

1. **`ldconfig`** : régénération du cache des bibliothèques partagées.
2. **Groupes utilisateurs** : ajout de l'utilisateur à `dialout, plugdev, i2c, bluetooth, wireshark`.
3. **README** : écriture de `/opt/ultra2/README_ULTRA3.txt` avec référence rapide.
4. **Permissions** : `chown -R` de tout `/opt/ultra2` vers l'utilisateur cible.

---

## 9. Groupes utilisateurs

| Groupe | Accès conféré |
|---|---|
| `dialout` | Ports série (`/dev/ttyUSB*`, `/dev/ttyACM*`) |
| `plugdev` | Périphériques USB via règles udev |
| `i2c` | Bus I²C (`/dev/i2c-*`) |
| `bluetooth` | Contrôleur Bluetooth |
| `wireshark` | Capture de paquets sans root |
| `lp` | Port parallèle (OpenCBM) |

> ⚠️ **Un redémarrage est nécessaire** pour que les groupes soient effectifs.

---

## 10. Règles udev installées

| Fichier | Périphériques couverts |
|---|---|
| `99-embedded-programmers.rules` | TL866, CH341A, FTDI, ST-Link, CH340, CMSIS-DAP, J-Link |
| `99-fpga-programmers.rules` | USB Blaster, Xilinx, Digilent, Lattice, iCEstick |
| `99-proxmark3.rules` | Proxmark3 |
| `99-sdr.rules` | RTL-SDR, HackRF, USRP, LimeSDR, BladeRF |
| `99-iot.rules` | ConBee II, CC2531, Z-Wave, LoRa USB |
| `99-can.rules` | CANtact, PCAN, Kvaser, USB2CAN, ELM327 |
| `99-chipwhisperer.rules` | ChipWhisperer, GreatFET |
| `99-retro.rules` | Greaseweazle |

Toutes les règles attribuent `MODE="0666"` et `GROUP="plugdev"` (ou `dialout`) pour un accès sans root.

---

## 11. Cheat-sheet par domaine

### 🔌 MCU / Firmware
```bash
arduino-cli compile --fqbn arduino:avr:uno sketch/
avrdude -c usbasp -p m328p -U flash:r:dump.hex:i
esptool.py --port /dev/ttyUSB0 read_flash 0 0x400000 dump.bin
stm32flash -r dump.bin /dev/ttyUSB0
platformio run -t upload
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg
```

### 💾 Dump Flash / BIOS
```bash
flashrom -p ch341a_spi -r bios_dump.bin
minipro -p ATMEGA328 -r dump.bin
uefitool bios_dump.bin
me_cleaner.py bios_dump.bin -O clean_bios.bin
```

### 🔍 Analyse Firmware
```bash
binwalk -e firmware.bin
unblob firmware.bin
r2 firmware.bin
ghidra
angr ./binary
```

### 📡 SDR
```bash
rtl_fm -f 145500000 -M fm
hackrf_transfer -r capture.raw -f 433920000
gnuradio-companion
```

### 🚗 Automobile
```bash
candump can0
cansend can0 123#DEADBEEF
icsim
```

### 💽 Stockage
```bash
testdisk /dev/sda
ddrescue /dev/sda image.img mapfile.log
smartctl -a /dev/sda
nanddump /dev/mtd0 -f nand_dump.bin
```

### 🕹️ Rétro
```bash
c1541 -format "disk,01" d64 mydisk.d64
xdftool disk.adf list
python3 -m tzxtools.tzxcat tape.tzx
milkytracker
```

---

## 12. Recommandations & avertissements

### ✅ À faire après installation
1. **Redémarrer** : `sudo reboot` (groupes + udev).
2. Vérifier le journal : `cat /var/log/ultra2_install.log`.
3. Consulter le guide : `cat /opt/ultra2/README_ULTRA3.txt`.
4. Tester un RTL-SDR ou un MCU simple pour valider les règles udev.

### ⚠️ Points de vigilance
- **Espace disque** : Yocto/Buildroot/Ghidra peuvent consommer 50–100 Go.
- **Licences** : Quartus, Vivado, Saleae Logic, Burp Suite nécessitent inscription/licence.
- **Matériel requis** : ChipWhisperer, Proxmark3, Greaseweazle, etc. ne fonctionnent qu'avec le hardware physique correspondant.
- **Légalité** : n'utilisez les outils radio/offensifs que sur du matériel vous appartenant ou avec autorisation explicite. La réception de signaux publics (ADS-B, AIS, météo) est généralement autorisée, mais l'interception de communications privées ne l'est pas.
- **Sécurité** : ne flashez jamais un firmware sans avoir sauvegardé l'original (dump préalable).

### 🐛 Dépannage courant
| Symptôme | Cause probable | Solution |
|---|---|---|
| `/dev/ttyUSB*` inaccessible | Groupe `dialout` non actif | Redémarrer / `sudo usermod -aG dialout $USER` |
| RTL-SDR non détecté | Pilote DVB-T chargé | Vérifier `/etc/modprobe.d/blacklist-rtl.conf` |
| Compilation échouée | Dépendance manquante | Relancer le script (idempotent) |
| `pip install` refusé | PEP 668 | Utiliser `--break-system-packages` ou venv |

---

*📄 Documentation générée à partir de `install_embedded_firmware_ubuntu_ultra.sh` — Console Netrunner ULTRA3.*

*« The future is already here – it's just not evenly distributed. »*

---
