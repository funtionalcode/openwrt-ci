#!/bin/sh
# OpenWrt UFI103_CT Upgrade Tool (Linux/macOS)
# OpenWrt to OpenWrt only - does not touch baseband partitions

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo "${GREEN}[OK]${NC} $1"; }
error() { echo "${RED}[FAIL]${NC} $1"; exit 1; }

echo "============================================"
echo "  OpenWrt UFI103_CT Upgrade Tool"
echo "  (OpenWrt to OpenWrt only)"
echo "============================================"
echo ""

# ---- Check fastboot ----
if command -v fastboot >/dev/null 2>&1; then
    FB=fastboot
elif [ -x "$SCRIPT_DIR/fastboot" ]; then
    FB="$SCRIPT_DIR/fastboot"
else
    error "fastboot not found! Install android-platform-tools or place fastboot alongside this script."
fi
info "Using: $FB"
echo ""

# ---- Check device ----
echo "Checking for fastboot device..."
if ! $FB devices 2>/dev/null | grep -q "fastboot"; then
    error "No device in fastboot mode. Hold reset + plug USB, or: adb reboot bootloader"
fi
info "Device connected"
echo ""

# ---- Check required files ----
for f in gpt_both0.bin boot.img rootfs.img; do
    if [ ! -f "$SCRIPT_DIR/$f" ]; then
        error "Required file missing: $f"
    fi
done
info "Required files found"
echo ""

# ---- Confirm ----
echo "${YELLOW}WARNING: This will ERASE boot and rootfs partitions!${NC}"
printf "Press Enter to continue or Ctrl+C to cancel... "
read -r _
echo ""

# ---- Flash ----
echo "[1/3] Flashing partition table..."
$FB flash partition "$SCRIPT_DIR/gpt_both0.bin" || error "partition flash failed"

echo "[2/3] Flashing boot.img..."
$FB flash boot "$SCRIPT_DIR/boot.img" || error "boot flash failed"

echo "[3/3] Flashing rootfs.img..."
$FB -S 200m flash rootfs "$SCRIPT_DIR/rootfs.img" || error "rootfs flash failed"

echo ""
echo "Rebooting..."
$FB reboot

echo ""
echo "============================================"
echo "  Upgrade completed successfully!"
echo "============================================"
echo ""
echo "WiFi: SSID=OpenWrt-UFI103  Password=12345678"
echo "Web:  http://192.168.100.1"
echo ""
