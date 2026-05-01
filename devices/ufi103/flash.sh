#!/bin/sh
# OpenWrt UFI103_CT Flash Tool (Linux/macOS)
# 从安卓刷入 OpenWrt，基于 lk2nd 二次引导方案

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo "${GREEN}[OK]${NC} $1"; }
warn()  { echo "${YELLOW}[SKIP]${NC} $1"; }
error() { echo "${RED}[FAIL]${NC} $1"; exit 1; }

echo "============================================"
echo "  OpenWrt UFI103_CT Flash Tool"
echo "============================================"
echo ""

# ---- 查找 fastboot ----
if command -v fastboot >/dev/null 2>&1; then
    FB=fastboot
elif [ -x "$SCRIPT_DIR/fastboot" ]; then
    FB="$SCRIPT_DIR/fastboot"
else
    error "fastboot not found! Install android-platform-tools or place fastboot alongside this script."
fi
info "Using: $FB"

# ---- 查找 adb ----
if command -v adb >/dev/null 2>&1; then
    ADB=adb
elif [ -x "$SCRIPT_DIR/adb" ]; then
    ADB="$SCRIPT_DIR/adb"
else
    ADB=""
fi

# ---- 固件路径 ----
if [ -d "$SCRIPT_DIR/firmware" ]; then
    FW="$SCRIPT_DIR/firmware/"
else
    FW="$SCRIPT_DIR/"
fi

# ---- 检查必需文件 ----
for f in gpt_both0.bin boot.img rootfs.img lk2nd.img; do
    if [ ! -f "$SCRIPT_DIR/$f" ] && [ ! -f "${FW}${f}" ]; then
        error "Required file missing: $f"
    fi
done
info "Required files found"
echo ""

# ===========================================
# Phase 0: 检测设备
# ===========================================
echo "========== Phase 0: Device Detection =========="

# 先尝试 fastboot
if $FB devices 2>/dev/null | grep -q "fastboot"; then
    info "Device in fastboot mode"
elif [ -n "$ADB" ] && $ADB devices 2>/dev/null | grep -q "device$"; then
    info "Device in ADB mode, rebooting to bootloader..."
    $ADB reboot bootloader
    echo "Waiting for fastboot..."
    sleep 5
else
    error "No device found. Hold reset + plug USB, or enable USB debugging."
fi
echo ""

# ===========================================
# Phase 1: 刷入 lk2nd 二次引导
# ===========================================
echo "========== Phase 1: lk2nd Secondary Bootloader =========="

LK2ND="$SCRIPT_DIR/lk2nd.img"
[ ! -f "$LK2ND" ] && LK2ND="${FW}lk2nd.img"

$FB erase boot || true
$FB flash boot "$LK2ND" || error "lk2nd flash failed"
info "lk2nd flashed"
echo "Rebooting into lk2nd fastboot..."
$FB reboot
sleep 3
echo "Press Enter when device is back in fastboot..."
read -r _

# 等待 lk2nd fastboot
while ! $FB devices 2>/dev/null | grep -q "fastboot"; do
    sleep 2
done
info "lk2nd fastboot ready"
echo ""

# ===========================================
# Phase 2: 备份基带
# ===========================================
echo "========== Phase 2: Baseband Backup =========="

dump_part() {
    local part="$1"
    local out="${SCRIPT_DIR}/${part}.bin"
    echo -n "  Dumping $part... "
    if $FB oem dump "$part" 2>/dev/null; then
        sleep 1
        if $FB get_staged "$out" 2>/dev/null; then
            echo "OK"
            return 0
        fi
    fi
    echo "FAIL (will use firmware/ fallback)"
    return 1
}

dump_part fsc
dump_part fsg
dump_part modemst1
dump_part modemst2
echo ""

# ===========================================
# Phase 3: 刷入底层固件
# ===========================================
echo "========== Phase 3: Low-Level Firmware =========="

# 擦除 lk2nd，恢复原厂 fastboot
$FB erase lk2nd || true
$FB erase boot || true
$FB reboot bootloader
echo "Rebooting to stock fastboot..."
sleep 3
echo "Press Enter when device is back in fastboot..."
read -r _
while ! $FB devices 2>/dev/null | grep -q "fastboot"; do
    sleep 2
done
info "Stock fastboot ready"
echo ""

# 刷分区表
echo "Flashing partition table..."
$FB flash partition "$SCRIPT_DIR/gpt_both0.bin" || error "partition flash failed"

# 刷底层固件
flash_fw() {
    local part="$1"
    local file="$2"
    local fallback="$3"
    local path=""
    echo -n "  $part... "
    if [ -f "$SCRIPT_DIR/$file" ]; then
        path="$SCRIPT_DIR/$file"
    elif [ -f "${FW}${file}" ]; then
        path="${FW}${file}"
    elif [ -n "$fallback" ] && [ -f "${FW}${fallback}" ]; then
        path="${FW}${fallback}"
    fi
    if [ -n "$path" ]; then
        if $FB flash "$part" "$path" 2>/dev/null; then
            echo "OK"
        else
            echo "FAIL"
        fi
    else
        echo "SKIP (not found)"
    fi
}

flash_fw hyp  hyp.mbn
flash_fw rpm  rpm.mbn
flash_fw sbl1 sbl1.mbn
flash_fw tz   tz.mbn
# 优先使用 oem dump 产物 (.bin)，回退到 firmware/ 预置 (.mbn)
flash_fw fsc  fsc.bin  fsc.mbn
flash_fw fsg  fsg.bin  fsg.mbn
flash_fw modemst1 modemst1.bin modemst1.mbn
flash_fw modemst2 modemst2.bin modemst2.mbn
flash_fw aboot aboot.bin aboot.mbn
flash_fw cdt  sbc_1.0_8016.bin

# 擦除旧系统分区
$FB erase boot || true
$FB erase rootfs || true
$FB reboot
echo ""

# ===========================================
# Phase 4: 刷入 OpenWrt 系统
# ===========================================
echo "========== Phase 4: OpenWrt System =========="

echo "Waiting for fastboot..."
sleep 3
echo "Press Enter when device is back in fastboot..."
read -r _
while ! $FB devices 2>/dev/null | grep -q "fastboot"; do
    sleep 2
done
info "Fastboot ready"
echo ""

echo "Flashing boot.img..."
$FB flash boot "$SCRIPT_DIR/boot.img" || error "boot flash failed"

echo "Flashing rootfs.img..."
$FB -S 200m flash rootfs "$SCRIPT_DIR/rootfs.img" || error "rootfs flash failed"

echo ""
echo "Rebooting..."
$FB reboot

echo ""
echo "============================================"
echo "  Flash completed successfully!"
echo "============================================"
echo ""
echo "WiFi: SSID=OpenWrt-UFI103  Password=12345678"
echo "Web:  http://192.168.100.1"
echo ""
