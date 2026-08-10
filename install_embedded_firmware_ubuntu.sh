#!/bin/bash
###############################################################################
# Post-Installation EMBEDDED / FIRMWARE sur Ubuntu
# Cible   : Ubuntu 22.04 LTS / 24.04 LTS (x86_64)
# Domaines: Arduino, Microchip (AVR/PIC/SAM), ESP32, STM32
#           Dump/Prog EEPROM - SPI/I2C Flash - BIOS/UEFI
#           Analyse & édition de firmwares (reverse engineering)
# Usage   : sudo chmod +x install_embedded_firmware.sh && sudo ./install_embedded_firmware.sh
###############################################################################

set -euo pipefail
IFS=$'\n\t'

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_FILE="/var/log/embedded_firmware_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Variables
INSTALL_DIR="/opt/embedded"
UDEV_RULES_DIR="/etc/udev/rules.d"
USER_DEV="${SUDO_USER:-$USER}"

###############################################################################
# Fonctions utilitaires
###############################################################################

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERR]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_err "Ce script doit être exécuté en root (sudo)"
        exit 1
    fi
}

check_ubuntu() {
    if ! grep -qE "Ubuntu" /etc/os-release; then
        log_warn "Distribution non-Ubuntu détectée. Le script est optimisé pour Ubuntu."
    fi
    log_info "Distribution : $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
}

install_pkgs() {
    apt-get install -y "$@" || {
        log_err "Échec installation de : $*"
        return 1
    }
}

clone_or_pull() {
    local repo_url="$1"
    local dest_dir="$2"
    if [[ -d "$dest_dir/.git" ]]; then
        log_info "Mise à jour de $(basename "$dest_dir")..."
        git -C "$dest_dir" pull --ff-only
    else
        log_info "Clonage de $(basename "$dest_dir")..."
        git clone --depth 1 "$repo_url" "$dest_dir"
    fi
}

###############################################################################
# 1. Préparation système
###############################################################################

prepare_system() {
    log_info "=== ÉTAPE 1/9 : Préparation du système ==="

    apt-get update
    apt-get upgrade -y

    install_pkgs build-essential cmake git wget curl unzip \
        pkg-config autoconf automake libtool \
        libusb-1.0-0-dev libusb-1.0-0 libftdi1-dev libftdi1 \
        python3-pip python3-dev python3-venv python3-setuptools \
        python3-numpy python3-serial \
        libssl-dev zlib1g-dev libpci-dev \
        gcc-multilib \
        screen minicom picocom \
        p7zip-full cabextract \
        htop tree

    pip3 install --upgrade pip
    pip3 install --break-system-packages \
        pyserial esptool intelhex bincopy \
        pyusb crcmod construct \
        2>/dev/null || pip3 install pyserial esptool intelhex bincopy pyusb crcmod construct \
        2>/dev/null || log_warn "Certains paquets Python n'ont pas pu être installés"

    mkdir -p "$INSTALL_DIR"
    chown "$USER_DEV:$USER_DEV" "$INSTALL_DIR"

    log_ok "Système préparé"
}

###############################################################################
# 2. Toolchains Arduino / AVR
###############################################################################

install_arduino_avr() {
    log_info "=== ÉTAPE 2/9 : Toolchains Arduino / AVR ==="

    local AVR_DIR="$INSTALL_DIR/avr"
    mkdir -p "$AVR_DIR"

    # Toolchain AVR classique (avr-gcc, avrdude, avr-libc)
    install_pkgs gcc-avr avr-libc avrdude binutils-avr gdb-avr \
        simulavr avarice || true

    # Arduino CLI (officiel, binaire portable)
    log_info "Installation d'arduino-cli..."
    if ! command -v arduino-cli &>/dev/null; then
        curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh \
            | BINDIR=/usr/local/bin sh
    fi
    arduino-cli config init --overwrite 2>/dev/null || true
    arduino-cli core update-index
    arduino-cli core install arduino:avr
    arduino-cli core install arduino:samd 2>/dev/null || true

    # PlatformIO (multi-plateformes : AVR, ESP32, STM32, SAM...)
    log_info "Installation de PlatformIO Core..."
    pip3 install --break-system-packages platformio 2>/dev/null || pip3 install platformio
    su - "$USER_DEV" -c "platformio platform install atmelavr" 2>/dev/null || true
    su - "$USER_DEV" -c "platformio platform install espressif32" 2>/dev/null || true

    # Ajout de l'utilisateur au groupe dialout (accès port série)
    usermod -aG dialout "$USER_DEV" 2>/dev/null || true

    log_ok "Toolchains Arduino / AVR installées"
}

###############################################################################
# 3. Toolchains Microchip (PIC / SAM) et outils ESP32/STM32
###############################################################################

install_microchip_toolchains() {
    log_info "=== ÉTAPE 3/9 : Toolchains Microchip PIC / SAM / ESP32 / STM32 ==="

    local MCU_DIR="$INSTALL_DIR/microchip"
    mkdir -p "$MCU_DIR"

    # GPUTILS : assembleur/linker libre pour PIC (gpasm, gplink, gpdasm)
    log_info "Installation de gputils (PIC)..."
    install_pkgs gputils || true

    # SDCC : compilateur C libre pour PIC14/16, 8051, STM8...
    log_info "Installation de SDCC..."
    install_pkgs sdcc || true

    # pk2cmd (PICkit2) - dépôts tiers, sinon build source
    log_info "Tentative d'installation de pk2cmd (PICkit2)..."
    install_pkgs pk2cmd 2>/dev/null || \
        log_warn "pk2cmd indisponible dans les dépôts (voir microchip.com ou AUR équivalent)"

    # ARM toolchain (SAM, STM32, et cœurs Cortex-M en général)
    log_info "Installation de la toolchain ARM (gcc-arm-none-eabi)..."
    install_pkgs gcc-arm-none-eabi gdb-multiarch binutils-arm-none-eabi \
        libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib || true

    # OpenOCD : programmation/debug JTAG-SWD (PIC32, SAM, STM32, ESP32 JTAG...)
    log_info "Installation d'OpenOCD..."
    install_pkgs openocd || true

    # ST-Link tools (STM32)
    install_pkgs stlink-tools || true

    # esptool déjà installé via pip (ESP32/ESP8266)
    log_info "esptool.py disponible pour ESP32/ESP8266 (dump/flash)"

    # dfu-util (bootloaders USB DFU : STM32, SAM, AVR via DFU)
    install_pkgs dfu-util || true

    log_ok "Toolchains Microchip / ARM / ESP installées"
}

###############################################################################
# 4. Programmateurs EEPROM / Flash SPI-I2C / BIOS
###############################################################################

install_eeprom_flash_programmers() {
    log_info "=== ÉTAPE 4/9 : Programmateurs EEPROM / Flash / BIOS ==="

    local FLASH_DIR="$INSTALL_DIR/flash"
    mkdir -p "$FLASH_DIR"

    # flashrom : lecture/écriture de puces SPI/LPC/FWH (BIOS, UEFI, routeurs...)
    log_info "Installation de flashrom..."
    install_pkgs flashrom || true

    # minipro : pilote libre pour programmateurs TL866A/CS/II+ (EEPROM, MCU, flash NOR/NAND)
    log_info "Installation de minipro (TL866)..."
    clone_or_pull "https://gitlab.com/DavidGriffith/minipro.git" "$FLASH_DIR/minipro"
    cd "$FLASH_DIR/minipro"
    make
    make install
    cp udev/*.rules "$UDEV_RULES_DIR/" 2>/dev/null || true

    # flashrocket / ch341a-eeprom : petits programmateurs USB SPI type CH341A
    log_info "Installation des outils CH341A (SPI EEPROM)..."
    clone_or_pull "https://github.com/setarcos/ch341prog.git" "$FLASH_DIR/ch341prog"
    cd "$FLASH_DIR/ch341prog"
    make
    cp ch341prog /usr/local/bin/ 2>/dev/null || true

    # bus_pirate / flashrom via serial : pas de compilation nécessaire (utilise flashrom -p buspirate_spi)

    # eeprom-utils divers (24Cxx / 25Cxx via I2C/SPI sur Raspberry/Arduino bridge)
    log_info "Récupération de eeprog (EEPROM I2C via bus Linux i2c-dev)..."
    install_pkgs i2c-tools libi2c-dev || true
    clone_or_pull "https://github.com/matteocroce/eeprog.git" "$FLASH_DIR/eeprog" 2>/dev/null || \
        log_warn "eeprog non disponible"
    if [[ -d "$FLASH_DIR/eeprog" ]]; then
        cd "$FLASH_DIR/eeprog"
        make 2>/dev/null && cp eeprog /usr/local/bin/ 2>/dev/null || \
            log_warn "Compilation eeprog échouée"
    fi

    # stm32flash : programmation STM32 via UART bootloader
    log_info "Installation de stm32flash..."
    install_pkgs stm32flash || true

    # Règles udev génériques pour programmateurs courants
    cat > "$UDEV_RULES_DIR/99-embedded-programmers.rules" << 'EOF'
# TL866 (minipro)
SUBSYSTEM=="usb", ATTR{idVendor}=="a466", MODE="0666", GROUP="plugdev"
# CH341A
SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", ATTR{idProduct}=="5512", MODE="0666", GROUP="plugdev"
# FTDI (FT232/FT2232 - JTAG/SWD/bitbang)
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", MODE="0666", GROUP="plugdev"
# ST-Link
SUBSYSTEM=="usb", ATTR{idVendor}=="0483", MODE="0666", GROUP="plugdev"
# CH340/CH341 (clones Arduino / adaptateurs série)
SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", ATTR{idProduct}=="7523", MODE="0666", GROUP="plugdev"
# Bus Pirate
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6001", MODE="0666", GROUP="plugdev"
EOF

    udevadm control --reload-rules
    udevadm trigger
    usermod -aG plugdev "$USER_DEV" 2>/dev/null || true
    usermod -aG i2c "$USER_DEV" 2>/dev/null || true

    log_ok "Programmateurs EEPROM / Flash / BIOS installés"
}

###############################################################################
# 5. Outils BIOS / UEFI spécifiques
###############################################################################

install_bios_uefi_tools() {
    log_info "=== ÉTAPE 5/9 : Outils BIOS / UEFI ==="

    local BIOS_DIR="$INSTALL_DIR/bios_uefi"
    mkdir -p "$BIOS_DIR"

    # UEFITool : édition/exploration d'images BIOS UEFI (modules, capsules, PE32)
    log_info "Installation de UEFITool..."
    cd "$BIOS_DIR"
    wget -q "https://github.com/LongSoft/UEFITool/releases/latest/download/UEFITool_NE.A68_linux_x86_64.zip" \
        -O uefitool.zip 2>/dev/null && unzip -o uefitool.zip -d uefitool >/dev/null 2>&1 && \
        chmod +x uefitool/UEFITool 2>/dev/null && \
        ln -sf "$BIOS_DIR/uefitool/UEFITool" /usr/local/bin/uefitool 2>/dev/null || \
        log_warn "Téléchargement UEFITool échoué, vérifier la release exacte sur GitHub"

    # CHIPSEC : sécurité/analyse bas niveau firmware (Intel/AMD)
    log_info "Installation de CHIPSEC..."
    clone_or_pull "https://github.com/chipsec/chipsec.git" "$BIOS_DIR/chipsec"
    cd "$BIOS_DIR/chipsec"
    python3 setup.py build_ext -i 2>/dev/null || log_warn "Build extensions CHIPSEC échoué (nécessite headers noyau)"

    # coreboot utils (cbfstool, ifdtool, amdfwtool) - via sources coreboot
    log_info "Installation des utilitaires coreboot (cbfstool, ifdtool)..."
    clone_or_pull "https://review.coreboot.org/coreboot.git" "$BIOS_DIR/coreboot" 2>/dev/null || \
        clone_or_pull "https://github.com/coreboot/coreboot.git" "$BIOS_DIR/coreboot"
    cd "$BIOS_DIR/coreboot/util/cbfstool" 2>/dev/null && make 2>/dev/null && \
        cp cbfstool /usr/local/bin/ 2>/dev/null || log_warn "cbfstool non compilé"
    cd "$BIOS_DIR/coreboot/util/ifdtool" 2>/dev/null && make 2>/dev/null && \
        cp ifdtool /usr/local/bin/ 2>/dev/null || log_warn "ifdtool non compilé"

    # me_cleaner : neutralisation partielle Intel ME dans les images BIOS
    log_info "Installation de me_cleaner..."
    clone_or_pull "https://github.com/corna/me_cleaner.git" "$BIOS_DIR/me_cleaner"

    log_ok "Outils BIOS / UEFI installés"
}

###############################################################################
# 6. Analyse et rétro-ingénierie de firmwares
###############################################################################

install_firmware_analysis() {
    log_info "=== ÉTAPE 6/9 : Analyse et édition de firmwares ==="

    local FW_DIR="$INSTALL_DIR/firmware_analysis"
    mkdir -p "$FW_DIR"

    # Binwalk : extraction/identification de systèmes de fichiers embarqués dans un dump
    log_info "Installation de binwalk..."
    install_pkgs binwalk 2>/dev/null || {
        clone_or_pull "https://github.com/ReFirmLabs/binwalk.git" "$FW_DIR/binwalk"
        cd "$FW_DIR/binwalk"
        pip3 install --break-system-packages . 2>/dev/null || pip3 install .
    }

    # Firmware Mod Kit (extraction/repackaging d'images routeur type squashfs/jffs2)
    log_info "Installation de Firmware Mod Kit..."
    clone_or_pull "https://github.com/rampageX/firmware-mod-kit.git" "$FW_DIR/firmware-mod-kit" 2>/dev/null || \
        log_warn "Firmware Mod Kit non disponible"

    # Outils de systèmes de fichiers embarqués
    install_pkgs squashfs-tools cramfsswap mtd-utils jefferson zlib1g-dev \
        device-tree-compiler || true

    # unblob : extracteur universel moderne (successeur pratique de binwalk pour l'auto-extraction récursive)
    log_info "Installation d'unblob..."
    pip3 install --break-system-packages unblob 2>/dev/null || pip3 install unblob 2>/dev/null || \
        log_warn "unblob non installé (dépendances système à vérifier : voir doc officielle)"

    # Radare2 : désassemblage/analyse binaire multi-architecture (utile pour firmwares MCU)
    log_info "Installation de radare2..."
    clone_or_pull "https://github.com/radareorg/radare2.git" "$FW_DIR/radare2"
    cd "$FW_DIR/radare2"
    sys/install.sh 2>/dev/null || ./sys/install.sh

    # Ghidra : suite de rétro-ingénierie (nécessite JDK)
    log_info "Installation de Ghidra..."
    install_pkgs openjdk-21-jdk 2>/dev/null || install_pkgs default-jdk
    if [[ ! -d "$FW_DIR/ghidra" ]]; then
        GHIDRA_URL=$(curl -s https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest \
            | grep "browser_download_url.*zip" | cut -d '"' -f4 | head -1)
        if [[ -n "${GHIDRA_URL:-}" ]]; then
            wget -q "$GHIDRA_URL" -O /tmp/ghidra.zip && \
                unzip -q /tmp/ghidra.zip -d "$FW_DIR/ghidra_tmp" && \
                mv "$FW_DIR"/ghidra_tmp/*/ "$FW_DIR/ghidra" && \
                rmdir "$FW_DIR/ghidra_tmp" 2>/dev/null
            ln -sf "$FW_DIR/ghidra/ghidraRun" /usr/local/bin/ghidra 2>/dev/null || true
        else
            log_warn "Impossible de résoudre l'URL de la dernière release Ghidra"
        fi
    fi

    # EMBA : framework d'analyse de sécurité firmware (orienté IoT)
    log_info "Installation d'EMBA (analyse de sécurité firmware)..."
    clone_or_pull "https://github.com/e-m-b-a/emba.git" "$FW_DIR/emba" 2>/dev/null || \
        log_warn "EMBA non cloné"

    # Outils Intel HEX / binaire
    pip3 install --break-system-packages srecord 2>/dev/null || true
    install_pkgs srecord || true

    log_ok "Outils d'analyse firmware installés"
}

###############################################################################
# 7. Environnements Arduino IDE / Cortex-Debug (édition/debug)
###############################################################################

install_ide_debug() {
    log_info "=== ÉTAPE 7/9 : IDE et environnements de debug ==="

    local IDE_DIR="$INSTALL_DIR/ide"
    mkdir -p "$IDE_DIR"

    # Arduino IDE 2.x (AppImage officielle)
    log_info "Téléchargement de l'Arduino IDE 2.x..."
    ARDUINO_URL=$(curl -s https://api.github.com/repos/arduino/arduino-ide/releases/latest \
        | grep "browser_download_url.*Linux_64bit.AppImage" | cut -d '"' -f4 | head -1)
    if [[ -n "${ARDUINO_URL:-}" ]]; then
        wget -q "$ARDUINO_URL" -O "$IDE_DIR/arduino-ide.AppImage" && \
            chmod +x "$IDE_DIR/arduino-ide.AppImage" && \
            ln -sf "$IDE_DIR/arduino-ide.AppImage" /usr/local/bin/arduino-ide 2>/dev/null
    else
        log_warn "URL Arduino IDE introuvable, installation manuelle recommandée"
    fi

    # VS Code (utile avec PlatformIO IDE et Cortex-Debug)
    if ! command -v code &>/dev/null; then
        log_info "Installation de VS Code..."
        wget -q https://go.microsoft.com/fwlink/?LinkID=760868 -O /tmp/vscode.deb 2>/dev/null && \
            apt-get install -y /tmp/vscode.deb || log_warn "VS Code non installé"
    fi

    log_ok "IDE et environnements de debug installés"
}

###############################################################################
# 8. Utilitaires série / bus pour dump et communication MCU
###############################################################################

install_serial_bus_tools() {
    log_info "=== ÉTAPE 8/9 : Utilitaires série et bus (UART/I2C/SPI/JTAG) ==="

    # sigrok / pulseview : analyseur logique (utile pour tracer SPI/I2C d'une EEPROM)
    log_info "Installation de sigrok / PulseView..."
    install_pkgs sigrok pulseview sigrok-cli libsigrok4 libsigrokdecode4 || true

    # urjtag : chaîne JTAG générique (boundary-scan, flash via JTAG)
    log_info "Installation d'UrJTAG..."
    install_pkgs urjtag || true

    # bus pirate scripts / flashrom en pont série déjà couverts par flashrom
    # esptool déjà présent (pip)

    log_ok "Utilitaires série et bus installés"
}

###############################################################################
# 9. Finalisation
###############################################################################

finalize() {
    log_info "=== ÉTAPE 9/9 : Finalisation ==="

    ldconfig

    cat > "$INSTALL_DIR/README.txt" << EOF
===============================================================================
ENVIRONNEMENT ARDUINO / MICROCHIP / DUMP-FLASH / ANALYSE FIRMWARE
===============================================================================

Répertoire d'installation : $INSTALL_DIR

STRUCTURE :
  $INSTALL_DIR/avr/                -> Toolchains Arduino/AVR
  $INSTALL_DIR/microchip/          -> Toolchains PIC/ARM/ESP32/STM32
  $INSTALL_DIR/flash/              -> Programmateurs EEPROM/Flash (minipro, ch341prog...)
  $INSTALL_DIR/bios_uefi/          -> Outils BIOS/UEFI (UEFITool, CHIPSEC, coreboot utils)
  $INSTALL_DIR/firmware_analysis/  -> Analyse firmware (binwalk, radare2, Ghidra, EMBA)
  $INSTALL_DIR/ide/                -> Arduino IDE 2.x (AppImage)

UTILISATEUR : $USER_DEV
  Ajouté aux groupes : dialout, plugdev, i2c

LOG D'INSTALLATION : $LOG_FILE

COMMANDES UTILES :
  arduino-cli compile --fqbn arduino:avr:uno sketch/          # Compiler un sketch
  arduino-cli upload -p /dev/ttyUSB0 --fqbn arduino:avr:uno   # Flasher
  avrdude -c usbasp -p m328p -U flash:r:dump.hex:i             # Dump flash AVR
  platformio run -t upload                                     # Upload via PlatformIO
  minipro -p ATMEGA328 -r dump.bin                              # Dump via TL866
  ch341prog -r dump.bin                                         # Dump SPI flash (CH341A)
  flashrom -p ch341a_spi -r bios_dump.bin                       # Dump BIOS SPI
  esptool.py --port /dev/ttyUSB0 read_flash 0 0x400000 dump.bin # Dump flash ESP32
  stm32flash -r dump.bin /dev/ttyUSB0                           # Dump STM32 UART
  binwalk -e dump.bin                                           # Extraction firmware
  uefitool bios_dump.bin                                        # Édition image UEFI
  ghidra                                                        # Rétro-ingénierie
  ifdtool -d bios_dump.bin                                      # Dump Flash Descriptor Intel

===============================================================================
EOF

    chown -R "$USER_DEV:$USER_DEV" "$INSTALL_DIR"

    log_ok "Installation terminée !"
    log_info "Redémarrage recommandé pour appliquer les règles udev et groupes"
    log_info "Consultez $INSTALL_DIR/README.txt pour un résumé"
}

###############################################################################
# Menu principal
###############################################################################

main() {
    clear
    echo "==============================================================================="
    echo "  POST-INSTALLATION ARDUINO / MICROCHIP / DUMP-FLASH / FIRMWARE - UBUNTU"
    echo "  AVR | PIC | ARM | ESP32 | STM32 | EEPROM | BIOS/UEFI | Reverse Engineering"
    echo "==============================================================================="
    echo ""

    check_root
    check_ubuntu

    log_info "Début de l'installation à $(date)"
    log_info "Utilisateur cible : $USER_DEV"
    log_info "Répertoire d'installation : $INSTALL_DIR"
    echo ""

    read -p "Appuyez sur Entrée pour commencer l'installation (Ctrl+C pour annuler)..."
    echo ""

    prepare_system
    install_arduino_avr
    install_microchip_toolchains
    install_eeprom_flash_programmers
    install_bios_uefi_tools
    install_firmware_analysis
    install_ide_debug
    install_serial_bus_tools
    finalize

    echo ""
    echo "==============================================================================="
    echo -e "${GREEN}INSTALLATION TERMINÉE AVEC SUCCÈS${NC}"
    echo "==============================================================================="
    echo ""
    echo "Redémarrez votre système pour finaliser la configuration (groupes/udev)."
    echo "Puis reconnectez-vous et testez vos périphériques :"
    echo "  arduino-cli board list   # Détection cartes Arduino"
    echo "  avrdude -c usbasp -p m328p -v   # Test programmateur AVR"
    echo "  flashrom -p ch341a_spi --probe  # Test programmateur SPI"
    echo "  minipro -D                       # Test TL866"
    echo ""
    echo "Pour lire le résumé : cat $INSTALL_DIR/README.txt"
    echo ""
}

main "$@"
