#!/bin/sh
# OpenWrt UFI103_CT Flash Tool (Linux/macOS)
# 基于 OpenStick 一键刷机工具验证过的流程

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FW="$SCRIPT_DIR/firmware"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo "${GREEN}[OK]${NC} $1"; }
warn()  { echo "${YELLOW}[SKIP]${NC} $1"; }
error() { echo "${RED}[FAIL]${NC} $1"; exit 1; }

echo "============================================"
echo "  OpenWrt UFI103_CT Flash Tool"
echo "============================================"
echo ""

# ---- 查找 fastboot / adb ----
FB=""; ADB=""
command -v fastboot >/dev/null 2>&1 && FB=fastboot
[ -x "$SCRIPT_DIR/fastboot" ] && FB="$SCRIPT_DIR/fastboot"
[ -z "$FB" ] && error "fastboot not found!"
info "fastboot: $FB"

command -v adb >/dev/null 2>&1 && ADB=adb
[ -x "$SCRIPT_DIR/adb" ] && ADB="$SCRIPT_DIR/adb"

# ===========================================
# Phase 1: 检测设备
# ===========================================
echo "========== [1/4] Device Detection =========="

if $FB devices 2>/dev/null | grep -q "fastboot"; then
    info "Device in fastboot mode"
elif [ -n "$ADB" ] && $ADB devices 2>/dev/null | grep -q "device$"; then
    info "Device in ADB mode, rebooting to bootloader..."
    $ADB reboot bootloader
    sleep 5
else
    error "No device found. Check USB connection or: adb reboot bootloader"
fi
echo ""

# ===========================================
# Phase 2: lk2nd + 基带备份
# ===========================================
echo "========== [2/4] lk2nd + Baseband Backup =========="

# 刷 lk2nd 二次引导
LK2ND="$SCRIPT_DIR/lk2nd.img"
[ ! -f "$LK2ND" ] && LK2ND="$FW/lk2nd.img"
[ ! -f "$LK2ND" ] && error "lk2nd.img not found!"

$FB erase boot
$FB flash boot "$LK2ND"
info "lk2nd flashed, rebooting..."
$FB reboot
sleep 3
echo "Press Enter when device is back in fastboot..."
read -r _
while ! $FB devices 2>/dev/null | grep -q "fastboot"; do sleep 2; done
info "lk2nd fastboot ready"

# 备份基带（仅在 lk2nd fastboot 下支持 oem dump）
echo "Dumping baseband..."
for part in fsc fsg modemst1 modemst2; do
    echo -n "  $part... "
    if $FB oem dump "$part" 2>/dev/null; then
        sleep 1
        if $FB get_staged "$SCRIPT_DIR/${part}.bin" 2>/dev/null; then
            echo "OK"
        else
            echo "get_staged failed"
        fi
    else
        echo "dump failed (will use firmware fallback)"
    fi
done

# 擦除 lk2nd，回原厂 fastboot
$FB erase lk2nd
$FB erase boot
$FB reboot bootloader
echo "Rebooting to stock fastboot..."
sleep 3
echo "Press Enter when device is back in fastboot..."
read -r _
while ! $FB devices 2>/dev/null | grep -q "fastboot"; do sleep 2; done
info "Stock fastboot ready"
echo ""

# ===========================================
# Phase 3: 底层固件
# ===========================================
echo "========== [3/4] Low-Level Firmware =========="

# 分区表
echo "Flashing partition table..."
$FB flash partition "$SCRIPT_DIR/gpt_both0.bin" || error "partition failed"

# 刷固件，优先使用 oem dump 产物 (.bin)，回退 firmware/ 预置文件 (.mbn)
flash_fw() {
    local part="$1"; local file="$2"; local fallback="$3"
    local path=""
    [ -f "$SCRIPT_DIR/$file" ] && path="$SCRIPT_DIR/$file"
    [ -z "$path" ] && [ -f "$FW/$file" ] && path="$FW/$file"
    [ -z "$path" ] && [ -n "$fallback" ] && [ -f "$FW/$fallback" ] && path="$FW/$fallback"
    echo -n "  $part... "
    if [ -n "$path" ]; then
        $FB flash "$part" "$path" 2>/dev/null && echo "OK" || echo "FAIL"
    else
        echo "SKIP (not found)"
    fi
}

flash_fw hyp   hyp.mbn
flash_fw rpm   rpm.mbn
flash_fw sbl1  sbl1.mbn
flash_fw tz    tz.mbn
flash_fw fsc   fsc.bin       fsc.mbn
flash_fw fsg   fsg.bin       fsg.mbn
flash_fw modemst1 modemst1.bin modemst1.mbn
flash_fw modemst2 modemst2.bin modemst2.mbn
flash_fw aboot aboot.bin     aboot.mbn
flash_fw cdt   sbc_1.0_8016.bin

$FB erase boot
$FB erase rootfs
$FB reboot
echo "Rebooting..."
sleep 3
echo "Press Enter when device is back in fastboot..."
read -r _
while ! $FB devices 2>/dev/null | grep -q "fastboot"; do sleep 2; done
info "Fastboot ready"
echo ""

# ===========================================
# Phase 4: OpenWrt 系统
# ===========================================
echo "========== [4/4] OpenWrt System =========="

echo "Flashing boot.img..."
$FB flash boot "$SCRIPT_DIR/boot.img" || error "boot failed"

echo "Flashing rootfs.img..."
$FB -S 200m flash rootfs "$SCRIPT_DIR/rootfs.img" || error "rootfs failed"

echo "Rebooting..."
$FB reboot

echo ""
echo "============================================"
echo "  Flash completed!"
echo "============================================"
echo ""
echo "WiFi: SSID=OpenWrt-UFI103  Password=12345678"
echo "Web:  http://192.168.100.1"
echo ""
<pause>
