#!/bin/bash
###############################################################################
# POST-INSTALLATION ULTRA2 - HARDWARE HACKING ULTIME
# Cible   : Ubuntu 22.04 LTS / 24.04 LTS (x86_64)
# Fusion  : install_embedded_firmware_ubuntu.sh
#           + install_embedded_firmware_ubuntu_ultra.sh
# Nouvelles sections :
#   - Réparation/Récupération mémoires de masse (HDD, SSD, USB, SD, NVMe)
#   - Radio Logicielle (SDR) : RTL-SDR, HackRF, GNU Radio
#   - Protocoles IoT : Zigbee, Z-Wave, LoRa, MQTT, Thread/Matter
#   - Hacking Automobile : CAN Bus, OBD-II, ECU
#   - Side-Channel & Fault Injection : ChipWhisperer, Riscure
#   - Linux Embarqué : Yocto, Buildroot, OpenWrt
#   - Sécurité réseau offensive : Nmap, Metasploit, Burp
#   - Outils PCB avancés & Fabrication
#   - Oscilloscopes & Analyseurs logiques logiciels
# Usage   : sudo chmod +x install_ultra2.sh && sudo ./install_ultra2.sh
###############################################################################
set -euo pipefail
IFS=$'\n\t'

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

LOG_FILE="/var/log/ultra2_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Variables globales
INSTALL_DIR="/opt/ultra2"
UDEV_RULES_DIR="/etc/udev/rules.d"
USER_DEV="${SUDO_USER:-$USER}"
TOTAL_STEPS=22
CURRENT_STEP=0

###############################################################################
# Fonctions utilitaires
###############################################################################
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()     { echo -e "${RED}[ERR]${NC} $1"; }
log_section() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ ÉTAPE ${CURRENT_STEP}/${TOTAL_STEPS} : $1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

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

check_resources() {
    local disk_free=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    local ram_total=$(free -g | awk 'NR==2 {print $2}')
    log_info "Espace disque disponible : ${disk_free} Go"
    log_info "RAM totale : ${ram_total} Go"
    if [[ $disk_free -lt 20 ]]; then
        log_warn "Espace disque insuffisant (< 20 Go). Certaines installations pourraient échouer."
    fi
}

install_pkgs() {
    apt-get install -y "$@" || {
        log_err "Échec installation de : $*"
        return 1
    }
}

install_pkgs_soft() {
    apt-get install -y "$@" 2>/dev/null || log_warn "Paquets optionnels non installés : $*"
}

clone_or_pull() {
    local repo_url="$1"
    local dest_dir="$2"
    if [[ -d "$dest_dir/.git" ]]; then
        log_info "Mise à jour de $(basename "$dest_dir")..."
        git -C "$dest_dir" pull --ff-only 2>/dev/null || true
    else
        log_info "Clonage de $(basename "$dest_dir")..."
        git clone --depth 1 "$repo_url" "$dest_dir" 2>/dev/null || {
            log_warn "Clonage échoué : $repo_url"
            return 1
        }
    fi
}

pip_install() {
    pip3 install --break-system-packages "$@" 2>/dev/null || \
    pip3 install "$@" 2>/dev/null || \
    log_warn "Échec pip install : $*"
}

add_udev_rule() {
    local filename="$1"
    shift
    cat > "$UDEV_RULES_DIR/$filename" << EOF
$@
EOF
}

###############################################################################
# 1. Préparation système
###############################################################################
prepare_system() {
    log_section "Préparation du système"

    apt-get update -qq
    apt-get upgrade -y -qq

    # Dépendances fondamentales
    install_pkgs build-essential cmake cmake-extras git wget curl unzip \
        pkg-config autoconf automake libtool libtool-bin \
        libusb-1.0-0-dev libusb-1.0-0 libftdi1-dev libftdi1 \
        python3-pip python3-dev python3-venv python3-setuptools python3-full \
        python3-numpy python3-serial python3-yaml python3-jsonschema \
        libssl-dev zlib1g-dev libpci-dev libffi-dev \
        gcc-multilib g++-multilib \
        screen minicom picocom putty \
        p7zip-full p7zip-rar cabextract unrar-free \
        htop iotop ncdu tree file hexedit xxd \
        jq bc lsof strace ltrace \
        net-tools iputils-ping dnsutils traceroute \
        software-properties-common apt-transport-https \
        ca-certificates gnupg lsb-release \
        libncurses5-dev libncursesw5-dev \
        libreadline-dev libbz2-dev liblzma-dev \
        swig libboost-all-dev libeigen3-dev \
        libsdl2-dev libgtk-3-dev \
        xorriso genisoimage

    # Pip upgrade
    pip3 install --upgrade pip 2>/dev/null || true

    # Paquets Python fondamentaux
    pip_install pyserial esptool intelhex bincopy \
        pyusb crcmod construct pyftdi \
        cryptography pycryptodome \
        requests aiohttp websockets \
        tqdm rich click typer

    mkdir -p "$INSTALL_DIR"/{avr,microchip,flash,bios_uefi,firmware_analysis,ide,hw_hacking,fpga,retro,eda,media,storage_recovery,sdr,iot,automotive,side_channel,embedded_linux,network_security,pcb,scopes,protocols}
    chown "$USER_DEV:$USER_DEV" "$INSTALL_DIR"

    log_ok "Système préparé"
}

###############################################################################
# 2. Toolchains Arduino / AVR
###############################################################################
install_arduino_avr() {
    log_section "Toolchains Arduino / AVR"

    local AVR_DIR="$INSTALL_DIR/avr"

    # Toolchain AVR
    install_pkgs_soft gcc-avr avr-libc avrdude binutils-avr gdb-avr \
        simulavr avarice

    # Arduino CLI
    log_info "Installation d'arduino-cli..."
    if ! command -v arduino-cli &>/dev/null; then
        curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh \
            | BINDIR=/usr/local/bin sh 2>/dev/null || true
    fi
    arduino-cli config init --overwrite 2>/dev/null || true
    arduino-cli core update-index 2>/dev/null || true
    arduino-cli core install arduino:avr 2>/dev/null || true
    arduino-cli core install arduino:samd 2>/dev/null || true
    arduino-cli core install arduino:megaavr 2>/dev/null || true

    # PlatformIO
    log_info "Installation de PlatformIO Core..."
    pip_install platformio
    su - "$USER_DEV" -c "platformio platform install atmelavr" 2>/dev/null || true
    su - "$USER_DEV" -c "platformio platform install espressif32" 2>/dev/null || true
    su - "$USER_DEV" -c "platformio platform install ststm32" 2>/dev/null || true

    usermod -aG dialout "$USER_DEV" 2>/dev/null || true
    log_ok "Toolchains Arduino / AVR installées"
}

###############################################################################
# 3. Toolchains Microchip / ARM / ESP32 / STM32
###############################################################################
install_microchip_toolchains() {
    log_section "Toolchains Microchip PIC/SAM + ARM/ESP32/STM32"

    local MCU_DIR="$INSTALL_DIR/microchip"

    # PIC
    log_info "Installation gputils + SDCC (PIC)..."
    install_pkgs_soft gputils sdcc

    # ARM
    log_info "Installation toolchain ARM..."
    install_pkgs_soft gcc-arm-none-eabi gdb-multiarch binutils-arm-none-eabi \
        libnewlib-arm-none-eabi libstdc++-arm-none-eabi-newlib

    # OpenOCD
    log_info "Installation OpenOCD..."
    install_pkgs_soft openocd || {
        clone_or_pull "https://github.com/openocd-org/openocd.git" "$MCU_DIR/openocd"
        cd "$MCU_DIR/openocd"
        ./bootstrap && ./configure --enable-ftdi --enable-jlink --enable-xds110 \
            --enable-stlink --enable-cmsis-dap && make -j"$(nproc)" && make install
    }

    # ST-Link
    install_pkgs_soft stlink-tools

    # ESP-IDF (SDK officiel Espressif)
    log_info "Installation ESP-IDF..."
    if [[ ! -d "$MCU_DIR/esp-idf" ]]; then
        git clone --depth 1 --recursive https://github.com/espressif/esp-idf.git "$MCU_DIR/esp-idf" 2>/dev/null || true
        if [[ -d "$MCU_DIR/esp-idf" ]]; then
            cd "$MCU_DIR/esp-idf"
            ./install.sh esp32,esp32s2,esp32s3,esp32c3 2>/dev/null || true
        fi
    fi

    # STM32CubeProgrammer CLI (st-flash, st-info déjà via stlink-tools)
    install_pkgs_soft dfu-util stm32flash

    # RISC-V toolchain (bonus pour ESP32-C3/C6, etc.)
    install_pkgs_soft gcc-riscv64-unknown-elf 2>/dev/null || true

    log_ok "Toolchains MCU installées"
}

###############################################################################
# 4. Programmateurs EEPROM / Flash SPI-I2C
###############################################################################
install_eeprom_flash_programmers() {
    log_section "Programmateurs EEPROM / Flash SPI-I2C"

    local FLASH_DIR="$INSTALL_DIR/flash"

    # flashrom
    log_info "Installation flashrom..."
    install_pkgs_soft flashrom

    # minipro (TL866)
    log_info "Installation minipro (TL866)..."
    clone_or_pull "https://gitlab.com/DavidGriffith/minipro.git" "$FLASH_DIR/minipro"
    if [[ -d "$FLASH_DIR/minipro" ]]; then
        cd "$FLASH_DIR/minipro" && make -j"$(nproc)" && make install
        cp udev/*.rules "$UDEV_RULES_DIR/" 2>/dev/null || true
    fi

    # CH341A tools
    log_info "Installation outils CH341A..."
    clone_or_pull "https://github.com/setarcos/ch341prog.git" "$FLASH_DIR/ch341prog"
    if [[ -d "$FLASH_DIR/ch341prog" ]]; then
        cd "$FLASH_DIR/ch341prog" && make && cp ch341prog /usr/local/bin/ 2>/dev/null || true
    fi

    # flashrom alternative: snandprog pour NAND
    clone_or_pull "https://github.com/981213/snandprog.git" "$FLASH_DIR/snandprog" 2>/dev/null || true

    # I2C tools
    install_pkgs_soft i2c-tools libi2c-dev

    # eeprog
    clone_or_pull "https://github.com/matteocroce/eeprog.git" "$FLASH_DIR/eeprog" 2>/dev/null || true
    if [[ -d "$FLASH_DIR/eeprog" ]]; then
        cd "$FLASH_DIR/eeprog" && make 2>/dev/null && cp eeprog /usr/local/bin/ 2>/dev/null || true
    fi

    # Règles udev
    cat > "$UDEV_RULES_DIR/99-embedded-programmers.rules" << 'EOF'
# TL866 (minipro)
SUBSYSTEM=="usb", ATTR{idVendor}=="a466", MODE="0666", GROUP="plugdev"
# CH341A SPI
SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", ATTR{idProduct}=="5512", MODE="0666", GROUP="plugdev"
# CH341A I2C/UART
SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", ATTR{idProduct}=="5523", MODE="0666", GROUP="plugdev"
# FTDI (FT232/FT2232/FT4232)
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", MODE="0666", GROUP="plugdev"
# ST-Link V2/V3
SUBSYSTEM=="usb", ATTR{idVendor}=="0483", MODE="0666", GROUP="plugdev"
# CH340 Serial
SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", ATTR{idProduct}=="7523", MODE="0666", GROUP="plugdev"
# CMSIS-DAP
SUBSYSTEM=="usb", ATTR{idVendor}=="0d28", MODE="0666", GROUP="plugdev"
# J-Link
SUBSYSTEM=="usb", ATTR{idVendor}=="1366", MODE="0666", GROUP="plugdev"
EOF

    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    usermod -aG plugdev "$USER_DEV" 2>/dev/null || true
    usermod -aG i2c "$USER_DEV" 2>/dev/null || true

    log_ok "Programmateurs EEPROM/Flash installés"
}

###############################################################################
# 5. Outils BIOS / UEFI
###############################################################################
install_bios_uefi_tools() {
    log_section "Outils BIOS / UEFI"

    local BIOS_DIR="$INSTALL_DIR/bios_uefi"

    # UEFITool
    log_info "Installation UEFITool..."
    cd "$BIOS_DIR"
    UEFITOOT_URL=$(curl -s https://api.github.com/repos/LongSoft/UEFITool/releases/latest 2>/dev/null \
        | grep "browser_download_url.*linux_x86_64" | head -1 | cut -d'"' -f4)
    if [[ -n "${UEFITOOT_URL:-}" ]]; then
        wget -q "$UEFITOOT_URL" -O uefitool.zip && unzip -o uefitool.zip -d uefitool >/dev/null 2>&1
        chmod +x uefitool/UEFITool 2>/dev/null || true
        ln -sf "$BIOS_DIR/uefitool/UEFITool" /usr/local/bin/uefitool 2>/dev/null || true
    else
        log_warn "UEFITool : URL introuvable"
    fi

    # CHIPSEC
    log_info "Installation CHIPSEC..."
    pip_install chipsec

    # Coreboot utilities
    log_info "Installation coreboot utils..."
    clone_or_pull "https://github.com/coreboot/coreboot.git" "$BIOS_DIR/coreboot"
    if [[ -d "$BIOS_DIR/coreboot" ]]; then
        cd "$BIOS_DIR/coreboot/util/cbfstool" 2>/dev/null && make 2>/dev/null && \
            cp cbfstool /usr/local/bin/ 2>/dev/null || true
        cd "$BIOS_DIR/coreboot/util/ifdtool" 2>/dev/null && make 2>/dev/null && \
            cp ifdtool /usr/local/bin/ 2>/dev/null || true
    fi

    # me_cleaner
    clone_or_pull "https://github.com/corna/me_cleaner.git" "$BIOS_DIR/me_cleaner"

    # AMI DMIEdit / Phoenix phwrite (liens informatifs)
    log_info "Outils AMI/Phoenix : téléchargement manuel requis (licences propriétaires)"

    log_ok "Outils BIOS/UEFI installés"
}

###############################################################################
# 6. Analyse et rétro-ingénierie de firmwares
###############################################################################
install_firmware_analysis() {
    log_section "Analyse et rétro-ingénierie de firmwares"

    local FW_DIR="$INSTALL_DIR/firmware_analysis"

    # Binwalk
    log_info "Installation binwalk..."
    pip_install binwalk

    # unblob
    log_info "Installation unblob..."
    pip_install unblob

    # Firmware Mod Kit
    clone_or_pull "https://github.com/rampageX/firmware-mod-kit.git" "$FW_DIR/firmware-mod-kit" 2>/dev/null || true

    # Filesystem tools
    install_pkgs_soft squashfs-tools cramfsswap mtd-utils jefferson \
        device-tree-compiler jffs2-tools uboot-tools

    # Radare2
    log_info "Installation radare2..."
    clone_or_pull "https://github.com/radareorg/radare2.git" "$FW_DIR/radare2"
    if [[ -d "$FW_DIR/radare2" ]]; then
        cd "$FW_DIR/radare2" && sys/install.sh 2>/dev/null || true
    fi

    # Ghidra
    log_info "Installation Ghidra..."
    install_pkgs_soft openjdk-21-jdk 2>/dev/null || install_pkgs_soft default-jdk
    if [[ ! -d "$FW_DIR/ghidra" ]]; then
        GHIDRA_URL=$(curl -s https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest 2>/dev/null \
            | grep "browser_download_url.*zip" | cut -d'"' -f4 | head -1)
        if [[ -n "${GHIDRA_URL:-}" ]]; then
            wget -q "$GHIDRA_URL" -O /tmp/ghidra.zip && \
            unzip -q /tmp/ghidra.zip -d "$FW_DIR/ghidra_tmp" && \
            mv "$FW_DIR"/ghidra_tmp/*/ "$FW_DIR/ghidra" && \
            rmdir "$FW_DIR/ghidra_tmp" 2>/dev/null
            ln -sf "$FW_DIR/ghidra/ghidraRun" /usr/local/bin/ghidra 2>/dev/null || true
        fi
    fi

    # Angr
    log_info "Installation Angr..."
    pip_install angr

    # Qiling
    log_info "Installation Qiling..."
    pip_install qiling

    # Unicorn Engine
    pip_install unicorn

    # Firmware Analysis Toolkit
    clone_or_pull "https://github.com/attify/firmware-analysis-toolkit.git" "$FW_DIR/fat"
    if [[ -d "$FW_DIR/fat" ]]; then
        cd "$FW_DIR/fat" && pip_install -r requirements.txt
        ln -sf "$FW_DIR/fat/fat.py" /usr/local/bin/fat 2>/dev/null || true
    fi

    # EMBA
    clone_or_pull "https://github.com/e-m-b-a/emba.git" "$FW_DIR/emba" 2>/dev/null || true

    # Ghidra Headless + scripts
    install_pkgs_soft srecord

    # capstone / keystone (disassembly/assembly engines)
    pip_install capstone keystone-engine lief

    log_ok "Outils d'analyse firmware installés"
}

###############################################################################
# 7. IDE et environnements de debug
###############################################################################
install_ide_debug() {
    log_section "IDE et environnements de debug"

    local IDE_DIR="$INSTALL_DIR/ide"

    # Arduino IDE 2.x
    log_info "Téléchargement Arduino IDE 2.x..."
    ARDUINO_URL=$(curl -s https://api.github.com/repos/arduino/arduino-ide/releases/latest 2>/dev/null \
        | grep "browser_download_url.*Linux_64bit.AppImage" | cut -d'"' -f4 | head -1)
    if [[ -n "${ARDUINO_URL:-}" ]]; then
        wget -q "$ARDUINO_URL" -O "$IDE_DIR/arduino-ide.AppImage" && \
        chmod +x "$IDE_DIR/arduino-ide.AppImage" && \
        ln -sf "$IDE_DIR/arduino-ide.AppImage" /usr/local/bin/arduino-ide 2>/dev/null
    fi

    # VS Code
    if ! command -v code &>/dev/null; then
        log_info "Installation VS Code..."
        wget -q "https://go.microsoft.com/fwlink/?LinkID=760868" -O /tmp/vscode.deb 2>/dev/null && \
        apt-get install -y /tmp/vscode.deb 2>/dev/null || log_warn "VS Code non installé"
    fi

    # Eclipse CDT (alternative)
    log_info "Eclipse CDT : installation manuelle recommandée si nécessaire"

    log_ok "IDE installés"
}

###############################################################################
# 8. Utilitaires série / bus (UART/I2C/SPI/JTAG)
###############################################################################
install_serial_bus_tools() {
    log_section "Utilitaires série et bus (UART/I2C/SPI/JTAG)"

    # Sigrok / PulseView
    log_info "Installation sigrok / PulseView..."
    install_pkgs_soft sigrok pulseview sigrok-cli libsigrok4 libsigrokdecode4

    # UrJTAG
    install_pkgs_soft urjtag

    # Saleae Logic (propriétaire mais utile)
    log_info "Saleae Logic 2 : téléchargement manuel depuis saleae.com"

    # Open Bench Logic Sniffer (OLS) client
    install_pkgs_soft ols 2>/dev/null || true

    # Logic analyzer via sigrok
    log_info "Analyseurs logiques supportés via sigrok (Voir README)"

    # Bus Pirate support
    log_info "Bus Pirate : utiliser flashrom -p buspirate_spi ou picocom"

    log_ok "Utilitaires série/bus installés"
}

###############################################################################
# 9. Hardware Hacking : RFID/NFC, BLE, USB, JTAG
###############################################################################
install_hw_hacking_extras() {
    log_section "Hardware Hacking : RFID/NFC, BLE, USB, JTAG"

    local HW_DIR="$INSTALL_DIR/hw_hacking"

    # === RFID / NFC ===
    log_info "--- RFID / NFC / Smartcard ---"
    install_pkgs_soft libnfc-bin libnfc-dev mfoc mfcuk
    install_pkgs_soft pcscd pcsc-tools libpcsclite-dev libccid

    # Proxmark3
    log_info "Installation Proxmark3 client (Iceman fork)..."
    install_pkgs_soft libreadline-dev libbluetooth-dev libbz2-dev qtbase5-dev
    clone_or_pull "https://github.com/RfidResearchGroup/proxmark3.git" "$HW_DIR/proxmark3"
    if [[ -d "$HW_DIR/proxmark3" ]]; then
        cd "$HW_DIR/proxmark3" && make -j"$(nproc)" client 2>/dev/null || true
    fi

    add_udev_rule "99-proxmark3.rules" \
        'SUBSYSTEM=="usb", ATTR{idVendor}=="9ac4", ATTR{idProduct}=="4b8f", MODE="0666", GROUP="plugdev"'

    # === Bluetooth / BLE ===
    log_info "--- Bluetooth / BLE ---"
    install_pkgs_soft bluez bluez-tools blueman libbluetooth-dev
    pip_install bleak

    # bettercap
    log_info "Installation bettercap..."
    if ! command -v bettercap &>/dev/null; then
        BC_URL=$(curl -s https://api.github.com/repos/bettercap/bettercap/releases/latest 2>/dev/null \
            | grep "browser_download_url.*linux_amd64" | grep -v ".sha256" | cut -d'"' -f4 | head -1)
        if [[ -n "${BC_URL:-}" ]]; then
            wget -q "$BC_URL" -O /tmp/bettercap.zip && \
            unzip -q -o /tmp/bettercap.zip -d /tmp/bc_bin && \
            find /tmp/bc_bin -name "bettercap" -exec install -m 0755 {} /usr/local/bin/bettercap \;
        fi
    fi

    # nRF tools
    pip_install nrfutil 2>/dev/null || true
    usermod -aG bluetooth "$USER_DEV" 2>/dev/null || true

    # === USB Analysis ===
    log_info "--- Analyse USB ---"
    install_pkgs_soft usbutils wireshark tshark
    modprobe usbmon 2>/dev/null || true
    grep -q "^usbmon" /etc/modules 2>/dev/null || echo "usbmon" >> /etc/modules
    dpkg-reconfigure -f noninteractive wireshark-common 2>/dev/null || true
    usermod -aG wireshark "$USER_DEV" 2>/dev/null || true

    # usbrply
    clone_or_pull "https://github.com/JohnDMcMaster/usbrply.git" "$HW_DIR/usbrply" 2>/dev/null || true

    # Facedancer
    pip_install facedancer 2>/dev/null || true

    # === JTAG Discovery ===
    log_info "--- JTAG Discovery ---"
    clone_or_pull "https://github.com/cyphunk/JTAGenum.git" "$HW_DIR/JTAGenum" 2>/dev/null || true

    log_ok "Hardware Hacking tools installés"
}

###############################################################################
# 10. FPGA (Altera/Intel, Xilinx, Lattice, Open-Source)
###############################################################################
install_fpga_tools() {
    log_section "Outils FPGA (Yosys, nextpnr, Quartus, Vivado)"

    local FPGA_DIR="$INSTALL_DIR/fpga"

    # Yosys
    log_info "Installation Yosys..."
    install_pkgs_soft yosys || {
        clone_or_pull "https://github.com/YosysHQ/yosys.git" "$FPGA_DIR/yosys"
        cd "$FPGA_DIR/yosys" && make -j"$(nproc)" && make install
    }

    # nextpnr
    log_info "Installation nextpnr..."
    install_pkgs_soft nextpnr-ice40 nextpnr-ecp5 nextpnr-generic || {
        clone_or_pull "https://github.com/YosysHQ/nextpnr.git" "$FPGA_DIR/nextpnr"
        cd "$FPGA_DIR/nextpnr"
        cmake -DARCH=ice40 -DARCH=ecp5 -DCMAKE_INSTALL_PREFIX=/usr/local . && \
        make -j"$(nproc)" && make install
    }

    # IceStorm + Trellis
    log_info "Installation IceStorm + Project Trellis..."
    install_pkgs_soft icestorm trellis || {
        clone_or_pull "https://github.com/YosysHQ/icestorm.git" "$FPGA_DIR/icestorm"
        cd "$FPGA_DIR/icestorm" && make -j"$(nproc)" && make install
        clone_or_pull "https://github.com/YosysHQ/prjtrellis.git" "$FPGA_DIR/prjtrellis"
        cd "$FPGA_DIR/prjtrellis/libtrellis" && cmake . && make -j"$(nproc)" && make install
    }

    # SymbiFlow / F4PGA
    log_info "Installation F4PGA (ex-SymbiFlow)..."
    pip_install f4pga 2>/dev/null || true

    # Verilator (simulation)
    install_pkgs_soft verilator

    # OpenOCD FPGA support
    install_pkgs_soft openocd

    # udev FPGA programmers
    cat > "$UDEV_RULES_DIR/99-fpga-programmers.rules" << 'EOF'
# Altera/Intel USB Blaster
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6001", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="0666", GROUP="plugdev"
# Xilinx Platform Cable
SUBSYSTEM=="usb", ATTR{idVendor}=="03fd", ATTR{idProduct}=="0008", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="03fd", ATTR{idProduct}=="0007", MODE="0666", GROUP="plugdev"
# Digilent
SUBSYSTEM=="usb", ATTR{idVendor}=="1443", MODE="0666", GROUP="plugdev"
# Lattice
SUBSYSTEM=="usb", ATTR{idVendor}=="1134", MODE="0666", GROUP="plugdev"
# iCEstick / iCEBreaker (FTDI)
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", MODE="0666", GROUP="plugdev"
EOF

    log_ok "Outils FPGA installés"
}

###############################################################################
# 11. Rétro-Informatique (ZX Spectrum, Commodore 64, Oric, Atari 8-bit)
###############################################################################
install_retro_tools() {
    log_section "Rétro-Informatique (Cassettes, Disquettes, ROMs, 8-bit)"
    local RETRO_DIR="$INSTALL_DIR/retro"

    ###########################################################################
    # 11.0 Outils génériques (audio, disquettes, ROMs)
    ###########################################################################
    install_pkgs_soft audacity sox libsndfile1-dev

    # --- ZX Spectrum : TZX/TAP -> WAV ---
    clone_or_pull "https://github.com/shred/tzx2wav.git" "$RETRO_DIR/tzx2wav"
    if [[ -d "$RETRO_DIR/tzx2wav" ]]; then
        cd "$RETRO_DIR/tzx2wav" && make && cp tzx2wav /usr/local/bin/ 2>/dev/null || true
    fi

    # --- Disquettes : formats génériques ---
    install_pkgs_soft fdutils mtools libdsk4-utils cpmtools

    clone_or_pull "https://github.com/keirf/Disk-Utilities.git" "$RETRO_DIR/disk-utilities"
    if [[ -d "$RETRO_DIR/disk-utilities" ]]; then
        cd "$RETRO_DIR/disk-utilities" && make && make install 2>/dev/null || true
    fi

    # --- Greaseweazle (lecture/écriture disquettes USB, multi-formats) ---
    clone_or_pull "https://github.com/keirf/greaseweazle.git" "$RETRO_DIR/greaseweazle"
    if [[ -d "$RETRO_DIR/greaseweazle" ]]; then
        cd "$RETRO_DIR/greaseweazle" && pip_install . 2>/dev/null || true
    fi

    # --- Cartouches / ROMs ---
    install_pkgs_soft rom-tools 2>/dev/null || true
    clone_or_pull "https://github.com/sanni/cartreader.git" "$RETRO_DIR/cartreader" 2>/dev/null || true

    # --- Émulateurs génériques ---
    install_pkgs_soft mame retroarch mednafen vice fs-uae 2>/dev/null || true

    log_info "KryoFlux : nécessite Java, installation manuelle depuis kryoflux.com"

    ###########################################################################
    # 11.1 COMMODORE 64 / 128 / VIC-20 / PET
    ###########################################################################
    log_info "--- Commodore 64 / 128 / VIC-20 ---"

    # VICE : x64sc (cycle-exact), x128, xvic, xpet
    # Inclus : c1541 (manipulation D64/D71/D81/TAP), petcat (BASIC),
    #          cartconv (cartouches CRT), cbm2ntsc/c1541-III
    install_pkgs_soft vice

    # Toolchain 6502 : assembleurs + compilateur C
    # (64tass, ACME, DASM et XA sont aussi valides pour Atari 8-bit et Oric)
    install_pkgs_soft 64tass acme dasm xa65 cc65

    # Exomizer : cruncher de données (standard de la scène demo C64)
    install_pkgs_soft exomizer

    # OpenCBM : piloter un vrai lecteur 1541/1571 depuis le PC
    # (câble XM1541 sur port parallèle, XA1541 sur USB)
    if ! apt-get install -y opencbm 2>/dev/null; then
        log_info "opencbm : compilation depuis les sources..."
        clone_or_pull "https://github.com/OpenCBM/OpenCBM.git" "$RETRO_DIR/opencbm"
        if [[ -d "$RETRO_DIR/opencbm" ]]; then
            cd "$RETRO_DIR/opencbm"
            make -f linux/Makefile 2>/dev/null && \
            make -f linux/Makefile install 2>/dev/null || true
        fi
    fi

    log_info "VICE : si ROMs absentes (kernal/basic/chargen), les placer dans /usr/lib/vice ou ~/.vice"
    log_info "C64 cassette : c1541/petcat génèrent les TAP ; pour TAP->WAV voir les outils communautaires 'tap2wav' (GitHub/zimmers.net)"

    ###########################################################################
    # 11.2 ORIC-1 / ORIC ATMOS / TELESTRAT
    ###########################################################################
    log_info "--- Oric-1 / Atmos ---"

    install_pkgs_soft libsdl2-dev libgtk-3-dev 2>/dev/null || true

    # Oricutron : l'émulateur de référence (SDL2)
    clone_or_pull "https://github.com/pete-gordon/oricutron.git" "$RETRO_DIR/oricutron"
    if [[ -d "$RETRO_DIR/oricutron" ]]; then
        cd "$RETRO_DIR/oricutron" && make 2>/dev/null && \
        cp oricutron /usr/local/bin/ 2>/dev/null || true
    fi

    # OSDK : toolchain de développement Oric (XA, libs C/asm, utilitaires TAP/DSK)
    clone_or_pull "https://github.com/oric-software/OSDK.git" "$RETRO_DIR/oric-osdk" 2>/dev/null || \
        log_info "OSDK : également disponible via SVN sur defence-force.org"

    log_info "Oricutron : ROMs (basic.rom, microdis.rom...) à placer dans le répertoire roms/"
    log_info "Oric cassette : l'OSDK fournit les convertisseurs TAP<->WAV pour chargement sur matériel réel"

    ###########################################################################
    # 11.3 ATARI 8-BIT (800XL / 65XE / 130XE)
    ###########################################################################
    log_info "--- Atari 8-bit (800XL / 65XE) ---"

    # atari800 : émulateur de référence (supporte ATR, XFD, CAS, CAR, BIN)
    install_pkgs_soft atari800

    # Bonus : famille Atari ST/TT/Falcon
    install_pkgs_soft hatari 2>/dev/null || true

    # XASM : assembleur historique de la scène Atari 8-bit (syntaxe .ASM)
    clone_or_pull "https://github.com/pfusik/xasm.git" "$RETRO_DIR/xasm"
    if [[ -d "$RETRO_DIR/xasm" ]]; then
        cd "$RETRO_DIR/xasm" && make 2>/dev/null && \
        cp xasm /usr/local/bin/ 2>/dev/null || true
    fi

    # Mad Pascal (optionnel : Pascal -> 6502, nécessite FreePascal)
    clone_or_pull "https://github.com/tebe6502/Mad-Pascal.git" "$RETRO_DIR/mad-pascal" 2>/dev/null || true

    log_info "atari800 : ROMs OS/BASIC à récupérer sur atari800.sourceforge.net (chemin demandé au 1er lancement)"
    log_info "Atari cassette : le format CAS est lu nativement par atari800 (menu 'Run Atari Program')"
    log_info "Atari disquettes réelles (1050/810 via SIO2PC) : voir atarisio.org"

    ###########################################################################
    # 11.4 Règles udev rétro
    ###########################################################################
    cat > "$UDEV_RULES_DIR/99-retro.rules" << 'EOF'
# Greaseweazle (STM32 USB CDC)
SUBSYSTEM=="tty", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="5740", MODE="0666", GROUP="dialout", SYMLINK+="greaseweazle"
EOF

    # Accès port parallèle (câble XM1541 pour OpenCBM)
    usermod -aG lp "$USER_DEV" 2>/dev/null || true
    grep -q "^ppdev" /etc/modules 2>/dev/null || echo "ppdev" >> /etc/modules

    log_ok "Outils Rétro installés"
}

###############################################################################
# 12. Simulation Électronique et EDA
###############################################################################
install_eda_tools() {
    log_section "Simulation Électronique et EDA"

    local EDA_DIR="$INSTALL_DIR/eda"

    # NG-Spice
    log_info "Installation NG-Spice..."
    install_pkgs_soft ngspice ngspice-doc

    # KiCad
    log_info "Installation KiCad..."
    add-apt-repository -y ppa:kicad/kicad-8.0-releases 2>/dev/null || true
    apt-get update -qq
    install_pkgs_soft kicad kicad-libraries

    # Icarus Verilog + GTKWave
    install_pkgs_soft iverilog gtkwave

    # QUCS (simulation GUI)
    install_pkgs_soft qucs qucs-s 2>/dev/null || true

    # Python scientific
    pip_install numpy scipy matplotlib PySpice sympy

    log_ok "Outils EDA installés"
}

###############################################################################
# 13. Multimédia, Torrent, P2P, IPTV
###############################################################################
install_media_p2p_tools() {
    log_section "Multimédia, Torrent, P2P, IPTV"

    local MEDIA_DIR="$INSTALL_DIR/media"

    # Audio
    install_pkgs_soft ffmpeg sox libavcodec-extra vorbis-tools flac \
        opus-tools lame wavpack audacity pulseaudio-utils \
        pd csound jackd2

    # Video
    install_pkgs_soft vlc mkvtoolnix gpac handbrake-cli \
        exiftool mediainfo gstreamer1.0-tools \
        imagemagick graphicsmagick

    # Torrent
    install_pkgs_soft qbittorrent-nox transmission-cli transmission-daemon rtorrent

    # yt-dlp
    log_info "Installation yt-dlp..."
    pip_install yt-dlp

    # IPTV tools
    pip_install m3u8 requests

    log_ok "Outils multimédia installés"
}

###############################################################################
# 14. *** NOUVEAU *** Réparation/Récupération Mémoires de Masse
###############################################################################
install_storage_recovery() {
    log_section "Réparation/Récupération Mémoires de Masse (HDD/SSD/USB/SD/NVMe)"

    local STORAGE_DIR="$INSTALL_DIR/storage_recovery"
    mkdir -p "$STORAGE_DIR"

    ###########################################################################
    # 14.1 Récupération de données (software)
    ###########################################################################
    log_info "--- Outils de récupération de données ---"

    # TestDisk & PhotoRec (récupération partitions + fichiers)
    install_pkgs_soft testdisk photorec

    # Scalpel / Foremost (carving de fichiers)
    install_pkgs_soft scalpel foremost

    # ddrescue / ddrrescue (clonage de disques endommagés)
    install_pkgs_soft gddrescue ddrescue

    # extundelete / ext4magic (récupération ext3/ext4)
    install_pkgs_soft extundelete ext4magic

    # R-Linux (gratuit) / R-Studio (payant) - info
    log_info "R-Studio : téléchargement manuel depuis r-studio.com"

    # Safecopy (lecture de secteurs endommagés)
    install_pkgs_soft safecopy

    # MyRescue
    install_pkgs_soft myrescue 2>/dev/null || true

    # Forensic tools
    install_pkgs_soft sleuthkit autopsy 2>/dev/null || true
    install_pkgs_soft afflib-tools ewf-tools 2>/dev/null || true

    # binwalk pour analyser les images de firmware de disques
    log_info "binwalk déjà installé (section firmware analysis)"

    ###########################################################################
    # 14.2 Diagnostics et réparation HDD/SSD
    ###########################################################################
    log_info "--- Diagnostics HDD/SSD ---"

    # smartmontools (S.M.A.R.T.)
    install_pkgs_soft smartmontools

    # hdparm (paramètres ATA, freeze lock, security erase)
    install_pkgs_soft hdparm

    # badblocks (test secteurs défectueux)
    log_info "badblocks inclus dans e2fsprogs"

    # nvme-cli (NVMe diagnostics)
    install_pkgs_soft nvme-cli

    # fstrim pour SSD
    log_info "fstrim inclus dans util-linux"

    # ATA Secure Erase
    log_info "ATA Secure Erase : hdparm --security-erase (voir README)"

    ###########################################################################
    # 14.3 Récupération Flash (SD, USB, eMMC, NAND)
    ###########################################################################
    log_info "--- Récupération Flash (SD/USB/eMMC/NAND) ---"

    # mmc-utils (eMMC/SD low-level)
    install_pkgs_soft mmc-utils 2>/dev/null || {
        clone_or_pull "https://git.kernel.org/pub/scm/utils/mmc/mmc-utils.git" "$STORAGE_DIR/mmc-utils"
        cd "$STORAGE_DIR/mmc-utils" && make && make install 2>/dev/null || true
    }

    # mtd-utils (NAND/NOR flash)
    install_pkgs_soft mtd-utils

    # Flashrom pour NOR/NAND SPI
    log_info "flashrom déjà installé (section programmateurs)"

    # nanddump / nandwrite
    log_info "nanddump/nandwrite inclus dans mtd-utils"

    ###########################################################################
    # 14.4 Réparation systèmes de fichiers
    ###########################################################################
    log_info "--- Réparation systèmes de fichiers ---"

    # fsck tools (ext2/3/4, xfs, btrfs, ntfs, fat)
    install_pkgs_soft e2fsprogs xfsprogs btrfs-progs ntfs-3g dosfstools \
        exfat-fuse exfat-utils f2fs-tools jfsutils reiserfsprogs

    # ntfsfix / ntfsclone
    log_info "ntfsfix/ntfsclone inclus dans ntfs-3g"

    ###########################################################################
    # 14.5 Clonage et imagerie
    ###########################################################################
    log_info "--- Clonage et imagerie ---"

    # Clonezilla
    install_pkgs_soft clonezilla 2>/dev/null || true

    # Partclone
    install_pkgs_soft partclone

    # partimage
    install_pkgs_soft partimage

    # FOG Project (imagerie réseau) - info
    log_info "FOG Project : installation serveur via fogproject.org"

    ###########################################################################
    # 14.6 Outils hardware (PC-3000 alternatives)
    ###########################################################################
    log_info "--- Outils avancés / Hardware ---"

    # MHDD (DOS) - info
    log_info "MHDD : outil DOS, utiliser via FreeDOS USB"

    # Victoria HDD (Windows) - info
    log_info "Victoria HDD : outil Windows, alternative Linux = hdparm + smartctl"

    # Open Source Firmware pour SSD (OpenSSD)
    clone_or_pull "https://github.com/OpenSSDProject/OpenSSD.git" "$STORAGE_DIR/opessd" 2>/dev/null || true

    # Outils pour récupération NAND (chip-off)
    log_info "Récupération chip-off NAND : nécessite programmateur dédié (RT809H, Easy JTAG, Medusa Pro)"
    log_info "Scripts d'aide pour Easy JTAG / Medusa :"
    clone_or_pull "https://github.com/hakin9/jtag-tools.git" "$STORAGE_DIR/jtag-tools" 2>/dev/null || true

    ###########################################################################
    # 14.7 Outils d'analyse forensique de stockage
    ###########################################################################
    log_info "--- Analyse forensique ---"

    # bulk_extractor
    install_pkgs_soft bulk-extractor 2>/dev/null || true

    # tcpflow, tcpdump pour analyse réseau des NAS
    install_pkgs_soft tcpflow tcpdump

    # hashdeep (vérification intégrité)
    install_pkgs_soft hashdeep

    log_ok "Outils de récupération/réparation stockage installés"
}

###############################################################################
# 15. *** NOUVEAU *** Radio Logicielle (SDR)
###############################################################################
install_sdr_tools() {
    log_section "Radio Logicielle (SDR) - RTL-SDR, HackRF, GNU Radio"

    local SDR_DIR="$INSTALL_DIR/sdr"
    mkdir -p "$SDR_DIR"

    # GNU Radio
    log_info "Installation GNU Radio..."
    install_pkgs_soft gnuradio gnuradio-dev gr-osmosdr

    # RTL-SDR
    log_info "Installation rtl-sdr..."
    install_pkgs_soft rtl-sdr librtlsdr-dev
    # Blacklist DVB-T driver
    cat > /etc/modprobe.d/blacklist-rtl.conf << 'EOF'
blacklist dvb_usb_rtl28xxu
blacklist rtl2832
blacklist rtl2830
EOF

    # HackRF
    log_info "Installation HackRF tools..."
    install_pkgs_soft hackrf libhackrf-dev

    # SoapySDR (interface universelle)
    install_pkgs_soft soapysdr-tools soapysdr-module-all 2>/dev/null || \
    install_pkgs_soft soapysdr-tools

    # GQRX (récepteur SDR GUI)
    install_pkgs_soft gqrx-sdr

    # SDR++ (multi-plateforme)
    log_info "SDR++ : téléchargement depuis github.com/AlexandreRouma/SDRPlusPlus"

    # Inspectrum (analyse de captures IQ)
    install_pkgs_soft inspectrum

    # baudline / baudline-ng
    log_info "baudline : téléchargement manuel (licence propriétaire)"

    # URH (Universal Radio Hacker)
    log_info "Installation URH..."
    pip_install urh 2>/dev/null || true

    # Scapy pour manipulation de paquets radio
    pip_install scapy

    # GNU Radio companion blocks additionnels
    install_pkgs_soft gr-rds 2>/dev/null || true
    install_pkgs_soft gr-ieee802-11 2>/dev/null || true
    install_pkgs_soft gr-ieee802-15-4 2>/dev/null || true

    # ADS-B (aviation)
    install_pkgs_soft dump1090-mutability 2>/dev/null || true

    # udev SDR
    cat > "$UDEV_RULES_DIR/99-sdr.rules" << 'EOF'
# RTL-SDR
SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="2838", MODE="0666", GROUP="plugdev"
# HackRF One
SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6089", MODE="0666", GROUP="plugdev"
# USRP
SUBSYSTEM=="usb", ATTR{idVendor}=="2500", MODE="0666", GROUP="plugdev"
# LimeSDR
SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="6100", MODE="0666", GROUP="plugdev"
# BladeRF
SUBSYSTEM=="usb", ATTR{idVendor}=="2cf0", MODE="0666", GROUP="plugdev"
EOF

    log_ok "Outils SDR installés"
}

###############################################################################
# 16. *** NOUVEAU *** Protocoles IoT (Zigbee, Z-Wave, LoRa, MQTT, Thread)
###############################################################################
install_iot_protocols() {
    log_section "Protocoles IoT (Zigbee, Z-Wave, LoRa, MQTT, Thread/Matter)"

    local IOT_DIR="$INSTALL_DIR/iot"
    mkdir -p "$IOT_DIR"

    # === Zigbee ===
    log_info "--- Zigbee ---"
    # Zigbee2MQTT
    log_info "Zigbee2MQTT : installation via Node.js"
    install_pkgs_soft nodejs npm 2>/dev/null || {
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        install_pkgs nodejs
    }

    # Zigpy (Python Zigbee stack)
    pip_install zigpy zigpy-znp zigpy-deconz bellows

    # KillerBee (Zigbee security research)
    clone_or_pull "https://github.com/riverloopsec/killerbee.git" "$IOT_DIR/killerbee"
    if [[ -d "$IOT_DIR/killerbee" ]]; then
        cd "$IOT_DIR/killerbee" && pip_install -r requirements.txt 2>/dev/null || true
    fi

    # ZigSniffer / Atmel RZUSBstick firmware
    log_info "ZigSniffer : nécessite RZUSBstick (Atmel), firmware sur killerbee"

    # === Z-Wave ===
    log_info "--- Z-Wave ---"
    # OpenZWave
    clone_or_pull "https://github.com/OpenZWave/open-zwave.git" "$IOT_DIR/open-zwave"
    if [[ -d "$IOT_DIR/open-zwave" ]]; then
        cd "$IOT_DIR/open-zwave" && make -j"$(nproc)" 2>/dev/null || true
    fi

    # Z-Wave JS (moderne)
    log_info "Z-Wave JS : npm install zwave-js"
    npm install -g zwave-js 2>/dev/null || true

    # === LoRa / LoRaWAN ===
    log_info "--- LoRa / LoRaWAN ---"
    # ChirpStack (LoRaWAN Network Server)
    log_info "ChirpStack : installation via Docker recommandée"
    install_pkgs_soft docker.io docker-compose 2>/dev/null || true

    # LMIC (LoRa MAC in C)
    clone_or_pull "https://github.com/matthijskooijman/arduino-lmic.git" "$IOT_DIR/arduino-lmic" 2>/dev/null || true

    # SX127x tools
    pip_install sx127x 2>/dev/null || true

    # === MQTT ===
    log_info "--- MQTT ---"
    install_pkgs_soft mosquitto mosquitto-clients
    pip_install paho-mqtt mqtt-tools

    # MQTT Explorer (GUI) - AppImage
    log_info "MQTT Explorer : téléchargement AppImage depuis mqtt-explorer.com"

    # === Thread / Matter ===
    log_info "--- Thread / Matter ---"
    # OpenThread
    clone_or_pull "https://github.com/openthread/openthread.git" "$IOT_DIR/openthread"
    if [[ -d "$IOT_DIR/openthread" ]]; then
        cd "$IOT_DIR/openthread" && ./script/bootstrap 2>/dev/null || true
    fi

    # CHIP (Matter SDK)
    clone_or_pull "https://github.com/project-chip/connectedhomeip.git" "$IOT_DIR/connectedhomeip" 2>/dev/null || true

    # === BLE avancé (rappel) ===
    log_info "--- BLE avancé ---"
    pip_install btlejack 2>/dev/null || true  # BLE sniffer/jammer (micro:bit)

    # === Autres protocoles IoT ===
    log_info "--- Autres protocoles ---"
    # CoAP
    pip_install aiocoap 2>/dev/null || true
    # AMQP
    pip_install pika 2>/dev/null || true

    # udev IoT devices
    cat > "$UDEV_RULES_DIR/99-iot.rules" << 'EOF'
# ConBee II (Zigbee)
SUBSYSTEM=="usb", ATTR{idVendor}=="1cf1", ATTR{idProduct}=="0030", MODE="0666", GROUP="plugdev"
# CC2531 (Zigbee sniffer)
SUBSYSTEM=="usb", ATTR{idVendor}=="0451", ATTR{idProduct}=="16a8", MODE="0666", GROUP="plugdev"
# Z-Wave USB sticks
SUBSYSTEM=="usb", ATTR{idVendor}=="0658", ATTR{idProduct}=="0200", MODE="0666", GROUP="plugdev"
# LoRa USB (RFM95/SX1276)
SUBSYSTEM=="usb", ATTR{idVendor}=="1a86", MODE="0666", GROUP="plugdev"
EOF

    log_ok "Protocoles IoT installés"
}

###############################################################################
# 17. *** NOUVEAU *** Hacking Automobile (CAN Bus, OBD-II, ECU)
###############################################################################
install_automotive_tools() {
    log_section "Hacking Automobile (CAN Bus, OBD-II, ECU)"

    local AUTO_DIR="$INSTALL_DIR/automotive"
    mkdir -p "$AUTO_DIR"

    # CAN tools kernel
    log_info "--- Outils CAN Bus ---"
    install_pkgs_soft can-utils

    # SocketCAN
    log_info "SocketCAN : support natif Linux (modules can, vcan, slcan)"
    modprobe vcan 2>/dev/null || true
    modprobe can 2>/dev/null || true

    # Python CAN
    pip_install python-can cantools can-isotp

    # SavvyCAN (GUI CAN analysis)
    log_info "SavvyCAN : téléchargement AppImage depuis savvyican.com"

    # ICSim (Instrument Cluster Simulator)
    clone_or_pull "https://github.com/zombieCraig/ICSim.git" "$AUTO_DIR/icSim"
    if [[ -d "$AUTO_DIR/icSim" ]]; then
        cd "$AUTO_DIR/icSim" && make 2>/dev/null || true
    fi

    # Kayak (CAN bus GUI)
    log_info "Kayak : outil Java, téléchargement depuis github.com/dschanoeh/Kayak"

    # OBD-II
    log_info "--- OBD-II ---"
    pip_install obd 2>/dev/null || true
    install_pkgs_soft scantool 2>/dev/null || true

    # ECU tools
    log_info "--- ECU / Flashing ---"
    # UDS (Unified Diagnostic Services)
    pip_install udsoncan 2>/dev/null || true

    # CANFlasher
    clone_or_pull "https://github.com/HubertD/can-flasher.git" "$AUTO_DIR/can-flasher" 2>/dev/null || true

    # OpenGarage (Car hacking platform)
    log_info "OpenGarage / Carloop : plateformes hardware, voir sites officiels"

    # Automotive Ethernet
    log_info "--- Automotive Ethernet ---"
    install_pkgs_soft tcpdump wireshark
    pip_install scapy

    # udev CAN interfaces
    cat > "$UDEV_RULES_DIR/99-can.rules" << 'EOF'
# CANtact / CANable
SUBSYSTEM=="usb", ATTR{idVendor}=="ad50", ATTR{idProduct}=="60c4", MODE="0666", GROUP="plugdev"
# PCAN-USB
SUBSYSTEM=="usb", ATTR{idVendor}=="0c72", MODE="0666", GROUP="plugdev"
# Kvaser
SUBSYSTEM=="usb", ATTR{idVendor}=="0bfd", MODE="0666", GROUP="plugdev"
# USB2CAN
SUBSYSTEM=="usb", ATTR{idVendor}=="16d0", ATTR{idProduct}=="0633", MODE="0666", GROUP="plugdev"
# OBD-II USB (ELM327)
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6001", MODE="0666", GROUP="plugdev"
EOF

    log_ok "Outils automobiles installés"
}

###############################################################################
# 18. *** NOUVEAU *** Side-Channel & Fault Injection
###############################################################################
install_side_channel() {
    log_section "Side-Channel & Fault Injection (ChipWhisperer)"

    local SC_DIR="$INSTALL_DIR/side_channel"
    mkdir -p "$SC_DIR"

    # ChipWhisperer
    log_info "Installation ChipWhisperer..."
    clone_or_pull "https://github.com/newaetech/chipwhisperer.git" "$SC_DIR/chipwhisperer"
    if [[ -d "$SC_DIR/chipwhisperer" ]]; then
        cd "$SC_DIR/chipwhisperer"
        pip_install -e . 2>/dev/null || true
        cd software && pip_install -e . 2>/dev/null || true
    fi

    # ChipWhisperer Jupyter notebooks
    pip_install jupyter jupyterlab 2>/dev/null || true

    # oscilloscope libraries
    install_pkgs_soft libsigrok4 libsigrokdecode4 2>/dev/null || true

    # PicoScope SDK
    log_info "PicoScope SDK : téléchargement depuis picotech.com"

    # LUNA (USB PHY pour analyse)
    clone_or_pull "https://github.com/greatscottgadgets/luna.git" "$SC_DIR/luna" 2>/dev/null || true

    # GreatFET
    log_info "Installation GreatFET tools..."
    pip_install greatfet 2>/dev/null || true

    # udev ChipWhisperer
    cat > "$UDEV_RULES_DIR/99-chipwhisperer.rules" << 'EOF'
# ChipWhisperer Lite / CW308 UFO
SUBSYSTEM=="usb", ATTR{idVendor}=="2b3e", MODE="0666", GROUP="plugdev"
# ChipWhisperer CW305
SUBSYSTEM=="usb", ATTR{idVendor}=="2b3e", ATTR{idProduct}=="ace1", MODE="0666", GROUP="plugdev"
# GreatFET
SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="60e6", MODE="0666", GROUP="plugdev"
EOF

    # Cryptographic analysis tools
    log_info "--- Outils crypto pour side-channel ---"
    pip_install pyaes pycryptodome 2>/dev/null || true

    log_ok "Outils side-channel installés"
}

###############################################################################
# 19. *** NOUVEAU *** Linux Embarqué (Yocto, Buildroot, OpenWrt)
###############################################################################
install_embedded_linux() {
    log_section "Linux Embarqué (Yocto, Buildroot, OpenWrt)"

    local EL_DIR="$INSTALL_DIR/embedded_linux"
    mkdir -p "$EL_DIR"

    # Dépendances Yocto
    log_info "Installation dépendances Yocto/Buildroot..."
    install_pkgs_soft gawk wget git diffstat unzip texinfo \
        gcc-multilib build-essential chrpath socat cpio python3 python3-pip \
        python3-pexpect xz-utils debianutils iputils-ping \
        python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev \
        pylint xterm python3-subunit mesa-common-dev zstd lz4

    # Yocto (clone poky uniquement, le build prend des heures)
    log_info "Clonage Yocto/Poky (référence)..."
    clone_or_pull "https://git.yoctoproject.org/poky" "$EL_DIR/poky" 2>/dev/null || true

    # Buildroot
    log_info "Clonage Buildroot..."
    clone_or_pull "https://github.com/buildroot/buildroot.git" "$EL_DIR/buildroot"

    # OpenWrt
    log_info "Clonage OpenWrt..."
    clone_or_pull "https://github.com/openwrt/openwrt.git" "$EL_DIR/openwrt" 2>/dev/null || true

    # U-Boot tools
    install_pkgs_soft u-boot-tools

    # QEMU pour émuler les targets
    log_info "Installation QEMU (émulation ARM/MIPS/RISC-V)..."
    install_pkgs_soft qemu-system-arm qemu-system-mips qemu-system-riscv64 \
        qemu-system-x86 qemu-utils

    # Device Tree Compiler
    install_pkgs_soft device-tree-compiler

    # cross-compilation helpers
    log_info "Cross-compilation : toolchains ARM déjà installées (étape 3)"

    log_ok "Linux embarqué installé"
}

###############################################################################
# 20. *** NOUVEAU *** Sécurité Réseau Offensive
###############################################################################
install_network_security() {
    log_section "Sécurité Réseau Offensive (Pentest)"

    local SEC_DIR="$INSTALL_DIR/network_security"
    mkdir -p "$SEC_DIR"

    # Nmap + scripts
    log_info "Installation Nmap..."
    install_pkgs_soft nmap ncat

    # Metasploit Framework
    log_info "Installation Metasploit..."
    if ! command -v msfconsole &>/dev/null; then
        curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
            -o /tmp/msfinstall && chmod +x /tmp/msfinstall && /tmp/msfinstall 2>/dev/null || \
        log_warn "Metasploit : installation manuelle recommandée"
    fi

    # Wireshark déjà installé
    # Aircrack-ng
    log_info "Installation Aircrack-ng..."
    install_pkgs_soft aircrack-ng

    # Hydra (brute force)
    install_pkgs_soft hydra hydra-gtk

    # SQLMap
    log_info "Installation SQLMap..."
    pip_install sqlmap 2>/dev/null || {
        clone_or_pull "https://github.com/sqlmapproject/sqlmap.git" "$SEC_DIR/sqlmap"
        ln -sf "$SEC_DIR/sqlmap/sqlmap.py" /usr/local/bin/sqlmap 2>/dev/null || true
    }

    # Burp Suite (Community) - téléchargement manuel
    log_info "Burp Suite Community : téléchargement depuis portswigger.net"

    # OWASP ZAP
    log_info "OWASP ZAP : installation via Docker ou téléchargement direct"

    # John the Ripper
    install_pkgs_soft john

    # Hashcat
    install_pkgs_soft hashcat

    # Responder (LLMNR/NBT-NS/MDNS poisoner)
    clone_or_pull "https://github.com/lgandx/Responder.git" "$SEC_DIR/responder"

    # Netcat / Socat
    install_pkgs_soft netcat-openbsd socat

    # Masscan
    install_pkgs_soft masscan 2>/dev/null || true

    # Nikto (web scanner)
    install_pkgs_soft nikto

    # Wifite (WiFi auditing)
    install_pkgs_soft wifite 2>/dev/null || true

    # DNS tools
    install_pkgs_soft dnsrecon dnsenum 2>/dev/null || true

    log_ok "Outils sécurité réseau installés"
}

###############################################################################
# 21. *** NOUVEAU *** PCB Avancé & Fabrication / Oscilloscopes
###############################################################################
install_pcb_scopes() {
    log_section "PCB Avancé, Fabrication & Oscilloscopes"

    local PCB_DIR="$INSTALL_DIR/pcb"
    local SCOPE_DIR="$INSTALL_DIR/scopes"
    mkdir -p "$PCB_DIR" "$SCOPE_DIR"

    # === PCB Design avancé ===
    log_info "--- PCB Design ---"
    # KiCad déjà installé, ajout des plugins
    log_info "KiCad plugins : Interactive BOM, JLCPCB Fabrication Toolkit"

    # Horizon EDA (alternative)
    install_pkgs_soft horizon-eda 2>/dev/null || true

    # Gerber viewers
    install_pkgs_soft gerbv 2>/dev/null || true
    pip_install pcb-tools 2>/dev/null || true

    # Fritzing (prototypage)
    install_pkgs_soft fritzing 2>/dev/null || true

    # === Fabrication ===
    log_info "--- Outils fabrication ---"
    # CNC / Laser (GRBL)
    pip_install pyserial 2>/dev/null || true
    clone_or_pull "https://github.com/grbl/grbl.git" "$PCB_DIR/grbl" 2>/dev/null || true

    # Universal G-Code Sender
    log_info "Universal G-Code Sender : Java, téléchargement depuis github.com/winder/Universal-G-Code-Sender"

    # 3D Printing (Cura, PrusaSlicer)
    install_pkgs_soft cura 2>/dev/null || true
    install_pkgs_soft prusa-slicer 2>/dev/null || true

    # OpenSCAD
    install_pkgs_soft openscad 2>/dev/null || true

    # === Oscilloscopes logiciels ===
    log_info "--- Oscilloscopes ---"
    # Sigrok/PulseView déjà installé
    # OpenScope
    log_info "OpenScope : voir digilent.com"

    # Bitscope (si hardware)
    log_info "Bitscope : voir bitscope.com"

    # Oscilloscope via sonde logique (sigrok)
    log_info "Utiliser PulseView avec un analyseur logique compatible sigrok"

    # === Protocoles de debug ===
    log_info "--- Protocoles ---"
    install_pkgs_soft sigrok-cli

    log_ok "Outils PCB/Scopes installés"
}

###############################################################################
# 22. Finalisation ULTRA2
###############################################################################
ultimate_finalize() {
    log_section "Finalisation ULTRA2"

    ldconfig

    # Groups
    usermod -aG dialout,plugdev,i2c,bluetooth,wireshark "$USER_DEV" 2>/dev/null || true

    # README final
    cat > "$INSTALL_DIR/README_ULTRA2.txt" << 'EOFREADME'
╔══════════════════════════════════════════════════════════════════════════════╗
║           CONSOLE NETRUNNER ULTRA2 - ENVIRONNEMENT HARDWARE HACKING         ║
║                    FUSION COMPLÈTE - 22 SECTIONS                             ║
╚══════════════════════════════════════════════════════════════════════════════╝

RÉPERTOIRE : /opt/ultra2
LOG : /var/log/ultra2_install.log
UTILISATEUR : $USER_DEV

STRUCTURE DES RÉPERTOIRES :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/opt/ultra2/avr/                → Toolchains Arduino/AVR
/opt/ultra2/microchip/          → Toolchains PIC/ARM/ESP32/STM32
/opt/ultra2/flash/              → Programmateurs EEPROM/Flash
/opt/ultra2/bios_uefi/          → Outils BIOS/UEFI
/opt/ultra2/firmware_analysis/  → Analyse firmware (binwalk, Ghidra, Angr...)
/opt/ultra2/ide/                → Arduino IDE, VS Code
/opt/ultra2/hw_hacking/         → RFID/NFC, BLE, USB, JTAG
/opt/ultra2/fpga/               → Yosys, nextpnr, IceStorm, Trellis
/opt/ultra2/retro/              → Cassettes, Disquettes, ROMs, Émulateurs
/opt/ultra2/eda/                → NG-Spice, KiCad, Icarus Verilog
/opt/ultra2/media/              → Multimédia, Torrent, IPTV
/opt/ultra2/storage_recovery/   → Récupération mémoires de masse ★ NOUVEAU
/opt/ultra2/sdr/                → Radio logicielle (RTL-SDR, HackRF) ★ NOUVEAU
/opt/ultra2/iot/                → Zigbee, Z-Wave, LoRa, MQTT, Thread ★ NOUVEAU
/opt/ultra2/automotive/         → CAN Bus, OBD-II, ECU ★ NOUVEAU
/opt/ultra2/side_channel/       → ChipWhisperer, Fault Injection ★ NOUVEAU
/opt/ultra2/embedded_linux/     → Yocto, Buildroot, OpenWrt ★ NOUVEAU
/opt/ultra2/network_security/   → Nmap, Metasploit, Aircrack ★ NOUVEAU
/opt/ultra2/pcb/                → PCB Design, CNC, 3D Printing ★ NOUVEAU
/opt/ultra2/scopes/             → Oscilloscopes, Analyseurs logiques ★ NOUVEAU

GROUPES UTILISATEUR : dialout, plugdev, i2c, bluetooth, wireshark

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
COMMANDES RAPIDES PAR DOMAINE :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

── MCU / FIRMWARE ──
arduino-cli compile --fqbn arduino:avr:uno sketch/
avrdude -c usbasp -p m328p -U flash:r:dump.hex:i
esptool.py --port /dev/ttyUSB0 read_flash 0 0x400000 dump.bin
stm32flash -r dump.bin /dev/ttyUSB0
platformio run -t upload
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg

── DUMP FLASH / BIOS ──
flashrom -p ch341a_spi -r bios_dump.bin
minipro -p ATMEGA328 -r dump.bin
ch341prog -r dump.bin
uefitool bios_dump.bin
ifdtool -d bios_dump.bin
me_cleaner.py bios_dump.bin -O clean_bios.bin

── ANALYSE FIRMWARE ──
binwalk -e firmware.bin
unblob firmware.bin
fat.py firmware.bin
angr ./binary
qiling ./firmware.bin
ghidra
r2 firmware.bin

── FPGA ──
yosys -p "synth_ice40 -top top" design.v
nextpnr-ice40 --hx1k --pcf pins.pcf --json top.json --asc top.asc
icepack top.asc top.bin
iceprog top.bin

── RÉCUPÉRATION STOCKAGE ★ NOUVEAU ──
testdisk /dev/sda                          # Récupération partitions
photorec /dev/sda                          # Carving fichiers
ddrescue /dev/sda image.img mapfile.log    # Clonage disque endommagé
smartctl -a /dev/sda                       # État S.M.A.R.T.
hdparm -I /dev/sda                         # Infos ATA
nvme smart-log /dev/nvme0                  # État NVMe
foremost -i image.img -o recovered/        # Carving
scalpel image.img -o output/               # Carving
extundelete /dev/sda1 --restore-all        # Restauration ext4
mmc extcsd read /dev/mmcblk0               # eMMC info
flash_erase /dev/mtd0 0 0                  # Effacer NAND
nanddump /dev/mtd0 -f nand_dump.bin        # Dump NAND
badblocks -sv /dev/sda                     # Test secteurs

── SDR ★ NOUVEAU ──
rtl_test                                    # Test RTL-SDR
rtl_fm -f 145500000 -M fm -s 250000 | aplay -r 48000 -f S16_LE -t raw -
hackrf_info                                 # Info HackRF
hackrf_transfer -r capture.raw -f 433920000 -s 2000000
gnuradio-companion                          # GNU Radio GUI
inspectrum capture.raw                      # Analyse spectrale
urh                                         # Universal Radio Hacker

── IoT ★ NOUVEAU ──
zbstumbler                                  # Zigbee scan (KillerBee)
zbassocflood -c 11                          # Zigbee attack
mosquitto_sub -t '#' -h localhost -v        # MQTT subscribe
mosquitto_pub -t 'test' -m 'hello'          # MQTT publish
python3 -c "import zigpy; print('ok')"      # Zigpy test

── AUTOMOBILE ★ NOUVEAU ──
candump can0                                # Capture CAN
cansend can0 123#DEADBEEF                   # Envoyer trame CAN
cangen can0                                 # Générer trafic CAN
python3 -c "import can; print(can.Bus('can0'))"
icsim                                       # Simulateur tableau de bord
obd_monitor                                 # OBD-II monitor

── SIDE-CHANNEL ★ NOUVEAU ──
python3 -c "import chipwhisperer as cw; print(cw.__version__)"
jupyter lab                                 # Notebooks ChipWhisperer
greatfet info                               # GreatFET status

── LINUX EMBARQUÉ ★ NOUVEAU ──
cd /opt/ultra2/embedded_linux/buildroot
make qemu_x86_64_defconfig && make
cd /opt/ultra2/embedded_linux/poky
source oe-init-build-env
qemu-system-arm -M vexpress-a9 -kernel zImage -dtb vexpress-v2p-ca9.dtb

── SÉCURITÉ RÉSEAU ★ NOUVEAU ──
nmap -sV -sC -p- target
msfconsole
airmon-ng start wlan0
airodump-ng wlan0mon
hydra -l admin -P wordlist.txt ssh://target
sqlmap -u "http://target/page?id=1"
john --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
hashcat -m 0 hash.txt wordlist.txt

── PCB / FABRICATION ★ NOUVEAU ──
kicad                                       # KiCad EDA
gerbv gerber_files/                         # Viewer Gerber
openscad model.scad                         # 3D modeling
cura                                        # Slicer 3D

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RÈGLES UDEV INSTALLÉES :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
/etc/udev/rules.d/99-embedded-programmers.rules  (TL866, CH341, FTDI, ST-Link)
/etc/udev/rules.d/99-fpga-programmers.rules      (USB Blaster, Xilinx, Digilent)
/etc/udev/rules.d/99-proxmark3.rules             (Proxmark3)
/etc/udev/rules.d/99-sdr.rules                   (RTL-SDR, HackRF, USRP)
/etc/udev/rules.d/99-iot.rules                   (ConBee, CC2531, Z-Wave, LoRa)
/etc/udev/rules.d/99-can.rules                   (CANtact, PCAN, Kvaser, ELM327)
/etc/udev/rules.d/99-chipwhisperer.rules         (ChipWhisperer, GreatFET)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NOTES IMPORTANTES :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Redémarrer après installation pour appliquer groupes et udev
• Quartus/Vivado : installateurs propriétaires à lancer manuellement
• Metasploit/Burp : licences/inscriptions requises pour certaines fonctions
• ChipWhisperer : nécessite le hardware CW308/CW312
• Yocto/Buildroot : premier build = plusieurs heures + 50-100 Go d'espace
• Docker recommandé pour : ChirpStack, OWASP ZAP, services IoT

═══════════════════════════════════════════════════════════════════════════════
  « The future is already here – it's just not evenly distributed. »
═══════════════════════════════════════════════════════════════════════════════
EOFREADME

    chown -R "$USER_DEV:$USER_DEV" "$INSTALL_DIR"

    log_ok "Installation ULTRA2 terminée !"
    log_info "Redémarrage recommandé pour appliquer toutes les configurations."
    log_info "Guide complet : cat $INSTALL_DIR/README_ULTRA2.txt"
}

###############################################################################
# Point d'entrée principal
###############################################################################
main() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                              ║${NC}"
    echo -e "${CYAN}║     ██╗   ██╗██╗  ████████╗██████╗  █████╗ ██████╗ ██████╗                  ║${NC}"
    echo -e "${CYAN}║     ██║   ██║██║  ╚══██╔══╝██╔══██╗██╔══██╗╚════██╗╚════██╗                 ║${NC}"
    echo -e "${CYAN}║     ██║   ██║██║     ██║   ██████╔╝███████║ █████╔╝ █████╔╝                 ║${NC}"
    echo -e "${CYAN}║     ██║   ██║██║     ██║   ██╔══██╗██╔══██║██╔═══╝  ╚═══██╗                 ║${NC}"
    echo -e "${CYAN}║     ╚██████╔╝██║     ██║   ██║  ██║██║  ██║███████╗██████╔╝                 ║${NC}"
    echo -e "${CYAN}║      ╚═════╝ ╚═╝     ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═════╝                  ║${NC}"
    echo -e "${CYAN}║                                                                              ║${NC}"
    echo -e "${CYAN}║     CONSOLE NETRUNNER ULTRA2 - POST-INSTALLATION HARDWARE HACKING           ║${NC}"
    echo -e "${CYAN}║     MCU | FPGA | Firmware | SDR | IoT | Auto | Side-Channel | Storage       ║${NC}"
    echo -e "${CYAN}║                                                                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_root
    check_ubuntu
    check_resources

    log_info "Début de l'installation ULTRA2 à $(date)"
    log_info "Utilisateur cible : $USER_DEV"
    log_info "Répertoire d'installation : $INSTALL_DIR"
    log_info "Nombre d'étapes : $TOTAL_STEPS"
    echo ""

    read -p "Appuyez sur Entrée pour lancer l'installation ULTRA2 (Ctrl+C pour annuler)..."
    echo ""

    # Sections originales (script 1)
    prepare_system                          # 1
    install_arduino_avr                     # 2
    install_microchip_toolchains            # 3
    install_eeprom_flash_programmers        # 4
    install_bios_uefi_tools                 # 5
    install_firmware_analysis               # 6
    install_ide_debug                       # 7
    install_serial_bus_tools                # 8
    install_hw_hacking_extras               # 9

    # Sections ultra (script 2)
    install_fpga_tools                      # 10
    install_retro_tools                     # 11
    install_eda_tools                       # 12
    install_media_p2p_tools                 # 13

    # Nouvelles sections ULTRA2
    install_storage_recovery                # 14 ★
    install_sdr_tools                       # 15 ★
    install_iot_protocols                   # 16 ★
    install_automotive_tools                # 17 ★
    install_side_channel                    # 18 ★
    install_embedded_linux                  # 19 ★
    install_network_security                # 20 ★
    install_pcb_scopes                      # 21 ★

    # Finalisation
    ultimate_finalize                       # 22

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              INSTALLATION ULTRA2 TERMINÉE AVEC SUCCÈS !                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}Redémarrez votre système :${NC} sudo reboot"
    echo -e "  ${YELLOW}Guide complet :${NC} cat $INSTALL_DIR/README_ULTRA2.txt"
    echo -e "  ${YELLOW}Log d'installation :${NC} cat $LOG_FILE"
    echo ""
    echo -e "  ${MAGENTA}« Wake up, Neo... The Matrix has you. »${NC}"
    echo ""
}

main "$@"
