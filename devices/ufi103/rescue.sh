#!/bin/sh
# UFI103_CT 9008 救砖脚本
# 进入 9008 方法: 短接主板触点后插 USB

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FW="$SCRIPT_DIR/firmware"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo "${GREEN}[OK]${NC} $1"; }
warn()  { echo "${YELLOW}[SKIP]${NC} $1"; }
die()   { echo "${RED}[FAIL]${NC} $1"; echo ""; printf "Press Enter to exit... "; read -r _; exit 1; }

echo "============================================"
echo "  UFI103_CT 9008 Rescue"
echo "============================================"
echo ""

# ---- Python 路径（可自定义） ----
PYTHON="${PYTHON:-python3}"

# ---- 检测 edl 命令 ----
if command -v edl >/dev/null 2>&1; then
    EDL="edl"
elif $PYTHON -m edl --help >/dev/null 2>&1; then
    EDL="$PYTHON -m edl"
else
    die "edl 未安装，请执行:
    pip uninstall edl
    pip install git+https://github.com/bkerler/edl.git

或下载 edl 二进制放到脚本同目录:
    https://github.com/bkerler/edl/releases"
fi

# 校验是否高通 EDL 工具（非视频编辑库）
if ! $EDL --help 2>&1 | grep -q "edl.py"; then
    warn "可能装成了视频编辑库 edl，而不是高通刷机工具"
    echo "  正确安装: pip uninstall edl && pip install git+https://github.com/bkerler/edl.git"
    echo ""
fi

info "Using: $EDL"

# ---- 找 firehose programmer ----
LOADER=""
for f in \
    "$SCRIPT_DIR"/prog_firehose_8916_*.bin \
    "$SCRIPT_DIR"/prog_firehose_8916_*.mbn \
    "$SCRIPT_DIR"/prog_emmc_firehose_8916*.mbn \
    "$FW"/prog_firehose_8916_*.bin \
    "$FW"/prog_emmc_firehose_8916*.mbn; do
    if [ -f "$f" ]; then
        LOADER="--loader=$f"
        info "Firehose: $(basename "$f")"
        break
    fi
done
if [ -z "$LOADER" ]; then
    warn "No firehose programmer found, will try without..."
fi
echo ""

# ---- 检测 9008 设备 ----
echo "Detecting 9008 device..."
if ! $EDL $LOADER printgpt >/dev/null 2>&1; then
    die "No 9008 device found.
   进入 9008 模式方法：
     1. 短接主板触点后插入 USB
     2. 或者 fastboot 可用时: fastboot oem reboot-edl"
fi
info "Device in 9008 mode"
echo ""

echo "${YELLOW}WARNING: This will overwrite ALL partitions!${NC}"
printf "Press Enter to continue or Ctrl+C to cancel... "
read -r _
echo ""

# ===========================================
# 刷机函数
# ===========================================
flash_part() {
    local part="$1"
    local file="$2"
    local fallback="$3"
    local path=""
    echo -n "  $part... "
    for candidate in "$SCRIPT_DIR/$file" "$FW/$file" "${fallback:+$FW/$fallback}"; do
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            path="$candidate"
            break
        fi
    done
    if [ -z "$path" ]; then
        echo "SKIP (not found)"
        return 0
    fi
    local tmp="/tmp/edl_flash_${part}.log"
    if $EDL $LOADER w "$part" "$path" >"$tmp" 2>&1; then
        echo "OK"
    else
        echo "FAIL"
        echo "    edl output:"
        sed 's/^/    /' "$tmp"
    fi
    rm -f "$tmp"
}

# ===========================================
# 1. 分区表
# ===========================================
echo "========== [1/4] Partition Table =========="

echo -n "  gpt... "
if $EDL $LOADER w gpt_main "$SCRIPT_DIR/gpt_both0.bin" >/dev/null 2>&1; then
    echo "OK"
else
    echo "FAIL"
    echo "    Trying alternative method..."
    echo -n "  gpt (raw)... "
    if $EDL $LOADER wl 0 "$SCRIPT_DIR/gpt_both0.bin" >/dev/null 2>&1; then
        echo "OK"
    else
        echo "FAIL"
        warn "GPT flash failed, but continuing anyway..."
    fi
fi

# ===========================================
# 2. 底层固件
# ===========================================
echo ""
echo "========== [2/4] Low-Level Firmware =========="

flash_part hyp   hyp.mbn
flash_part rpm   rpm.mbn
flash_part sbl1  sbl1.mbn
flash_part tz    tz.mbn
flash_part fsc   fsc.bin  fsc.mbn
flash_part fsg   fsg.bin  fsg.mbn
flash_part modemst1 modemst1.bin modemst1.mbn
flash_part modemst2 modemst2.bin modemst2.mbn
flash_part aboot aboot.bin aboot.mbn
flash_part cdt   sbc_1.0_8016.bin
flash_part lk2nd lk2nd.img

# ===========================================
# 3. OpenWrt 系统
# ===========================================
echo ""
echo "========== [3/4] OpenWrt System =========="

flash_part boot   boot.img
flash_part rootfs rootfs.img

# ===========================================
# 4. 重启
# ===========================================
echo ""
echo "========== [4/4] Reboot =========="
if $EDL $LOADER reset 2>/dev/null; then
    info "Device rebooting..."
else
    warn "Reboot failed, manually unplug & replug USB"
fi

echo ""
echo "============================================"
echo "  Rescue done!"
echo "  Wait 30s for device to boot..."
echo "============================================"
echo ""
echo "WiFi: SSID=OpenWrt-UFI103  Password=12345678"
echo "Web:  http://192.168.100.1"
echo ""
printf "Press Enter to exit... "
read -r _
