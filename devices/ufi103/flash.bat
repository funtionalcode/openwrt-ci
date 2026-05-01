@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
color 0A

echo ============================================
echo   OpenWrt UFI103_CT Flash Tool
echo ============================================
echo.

:: ---- Check fastboot ----
where fastboot >nul 2>&1
if !errorlevel!==0 (
    set "FB=fastboot"
) else if exist "%~dp0fastboot.exe" (
    set "FB=%~dp0fastboot.exe"
) else (
    echo [ERROR] fastboot not found.
    echo Place fastboot.exe alongside this script.
    pause
    exit /b 1
)
echo [OK] Using: !FB!

:: ---- Check adb ----
set "ADB="
where adb >nul 2>&1
if !errorlevel!==0 (
    set "ADB=adb"
) else if exist "%~dp0adb.exe" (
    set "ADB=%~dp0adb.exe"
)

:: ---- Paths ----
set "ROOT=%~dp0"
if exist "%ROOT%firmware\" (
    set "FW=%ROOT%firmware\"
) else (
    set "FW=%ROOT%"
)

:: ---- Check required files ----
set MISSING=0
if not exist "%ROOT%gpt_both0.bin" ( echo [MISSING] gpt_both0.bin & set MISSING=1 )
if not exist "%ROOT%boot.img"      ( echo [MISSING] boot.img      & set MISSING=1 )
if not exist "%ROOT%rootfs.img"    ( echo [MISSING] rootfs.img    & set MISSING=1 )
if not exist "%FW%lk2nd.img"       ( echo [MISSING] firmware\lk2nd.img & set MISSING=1 )
if !MISSING!==1 (
    echo.
    echo [ERROR] Required files missing. Aborting.
    pause
    exit /b 1
)
echo [OK] Required files found
echo.

:: ===========================================
:: Phase 0: Device Detection
:: ===========================================
echo ========== Phase 0: Device Detection ==========

"!FB!" devices 2>nul | findstr "fastboot" >nul
if !errorlevel!==0 (
    echo [OK] Device in fastboot mode
    goto phase1
)

if not "%ADB%"=="" (
    "%ADB%" devices 2>nul | findstr /R "device$" >nul
    if !errorlevel!==0 (
        echo [OK] Device in ADB mode, rebooting to bootloader...
        "%ADB%" reboot bootloader
        timeout /NOBREAK /T 5 >nul
        goto phase1
    )
)

echo [ERROR] No device found.
echo   Hold reset + plug USB to enter fastboot
echo   Or enable USB debugging for ADB detection
pause
exit /b 1

:phase1
echo.

:: ===========================================
:: Phase 1: lk2nd Secondary Bootloader
:: ===========================================
echo ========== Phase 1: lk2nd Secondary Bootloader ==========

"!FB!" erase boot >nul 2>&1
"!FB!" flash boot "%FW%lk2nd.img"
if !errorlevel! neq 0 (
    echo [FAIL] lk2nd flash failed
    pause
    exit /b 1
)
echo [OK] lk2nd flashed
echo Rebooting into lk2nd fastboot...
"!FB!" reboot
timeout /NOBREAK /T 3 >nul
echo Press any key when device is back in fastboot...
pause >nul

:wait_lk2nd
"!FB!" devices 2>nul | findstr "fastboot" >nul
if !errorlevel! neq 0 (
    timeout /t 2 /nobreak >nul
    goto wait_lk2nd
)
echo [OK] lk2nd fastboot ready
echo.

:: ===========================================
:: Phase 2: Baseband Backup
:: ===========================================
echo ========== Phase 2: Baseband Backup ==========

echo [1/4] Dumping fsc...
"!FB!" oem dump fsc >nul 2>&1
if !errorlevel!==0 (
    timeout /NOBREAK /T 1 >nul
    "!FB!" get_staged "%ROOT%fsc.bin" >nul 2>&1 && echo  [OK] fsc.bin saved
) else ( echo  [SKIP] fsc dump failed )

echo [2/4] Dumping fsg...
"!FB!" oem dump fsg >nul 2>&1
if !errorlevel!==0 (
    timeout /NOBREAK /T 1 >nul
    "!FB!" get_staged "%ROOT%fsg.bin" >nul 2>&1 && echo  [OK] fsg.bin saved
) else ( echo  [SKIP] fsg dump failed )

echo [3/4] Dumping modemst1...
"!FB!" oem dump modemst1 >nul 2>&1
if !errorlevel!==0 (
    timeout /NOBREAK /T 1 >nul
    "!FB!" get_staged "%ROOT%modemst1.bin" >nul 2>&1 && echo  [OK] modemst1.bin saved
) else ( echo  [SKIP] modemst1 dump failed )

echo [4/4] Dumping modemst2...
"!FB!" oem dump modemst2 >nul 2>&1
if !errorlevel!==0 (
    timeout /NOBREAK /T 1 >nul
    "!FB!" get_staged "%ROOT%modemst2.bin" >nul 2>&1 && echo  [OK] modemst2.bin saved
) else ( echo  [SKIP] modemst2 dump failed )
echo.

:: ===========================================
:: Phase 3: Low-Level Firmware
:: ===========================================
echo ========== Phase 3: Low-Level Firmware ==========

:: Erase lk2nd, back to stock fastboot
"!FB!" erase lk2nd >nul 2>&1
"!FB!" erase boot >nul 2>&1
"!FB!" reboot bootloader
echo Rebooting to stock fastboot...
timeout /NOBREAK /T 3 >nul
echo Press any key when device is back in fastboot...
pause >nul

:wait_stock
"!FB!" devices 2>nul | findstr "fastboot" >nul
if !errorlevel! neq 0 (
    timeout /t 2 /nobreak >nul
    goto wait_stock
)
echo [OK] Stock fastboot ready
echo.

:: Partition table
echo [1/10] Flashing partition table...
"!FB!" flash partition "%ROOT%gpt_both0.bin"
if !errorlevel! neq 0 ( echo [FAIL] partition & pause & exit /b 1 )

:: Flash firmware helper
set "HAS_FAIL=0"

echo [2/10] hyp.mbn...
if exist "%FW%hyp.mbn" (
    "!FB!" flash hyp "%FW%hyp.mbn" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

echo [3/10] rpm.mbn...
if exist "%FW%rpm.mbn" (
    "!FB!" flash rpm "%FW%rpm.mbn" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

echo [4/10] sbl1.mbn...
if exist "%FW%sbl1.mbn" (
    "!FB!" flash sbl1 "%FW%sbl1.mbn" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

echo [5/10] tz.mbn...
if exist "%FW%tz.mbn" (
    "!FB!" flash tz "%FW%tz.mbn" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

echo [6/10] fsc...
if exist "%ROOT%fsc.bin" (
    "!FB!" flash fsc "%ROOT%fsc.bin" || set HAS_FAIL=1
) else if exist "%FW%fsc.mbn" (
    "!FB!" flash fsc "%FW%fsc.mbn" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

echo [7/10] fsg...
if exist "%ROOT%fsg.bin" (
    "!FB!" flash fsg "%ROOT%fsg.bin" || set HAS_FAIL=1
) else if exist "%FW%fsg.mbn" (
    "!FB!" flash fsg "%FW%fsg.mbn" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

echo [8/10] modemst1...
if exist "%ROOT%modemst1.bin" (
    "!FB!" flash modemst1 "%ROOT%modemst1.bin" || set HAS_FAIL=1
) else if exist "%FW%modemst1.mbn" (
    "!FB!" flash modemst1 "%FW%modemst1.mbn" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

echo [9/10] modemst2...
if exist "%ROOT%modemst2.bin" (
    "!FB!" flash modemst2 "%ROOT%modemst2.bin" || set HAS_FAIL=1
) else if exist "%FW%modemst2.mbn" (
    "!FB!" flash modemst2 "%FW%modemst2.mbn" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

echo [10/10] aboot...
if exist "%FW%aboot.bin" (
    "!FB!" flash aboot "%FW%aboot.bin" || set HAS_FAIL=1
) else if exist "%FW%aboot.mbn" (
    "!FB!" flash aboot "%FW%aboot.mbn" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

:: CDT
echo [11/11] cdt...
if exist "%FW%sbc_1.0_8016.bin" (
    "!FB!" flash cdt "%FW%sbc_1.0_8016.bin" || set HAS_FAIL=1
) else ( echo  [SKIP] not found )

:: Erase old system
"!FB!" erase boot >nul 2>&1
"!FB!" erase rootfs >nul 2>&1
"!FB!" reboot
echo.

:: ===========================================
:: Phase 4: OpenWrt System
:: ===========================================
echo ========== Phase 4: OpenWrt System ==========

echo Waiting for fastboot...
timeout /NOBREAK /T 3 >nul
echo Press any key when device is back in fastboot...
pause >nul

:wait_final
"!FB!" devices 2>nul | findstr "fastboot" >nul
if !errorlevel! neq 0 (
    timeout /t 2 /nobreak >nul
    goto wait_final
)
echo [OK] Fastboot ready
echo.

echo Flashing boot.img...
"!FB!" flash boot "%ROOT%boot.img"
if !errorlevel! neq 0 ( echo [FAIL] boot & pause & exit /b 1 )

echo Flashing rootfs.img...
"!FB!" -S 200m flash rootfs "%ROOT%rootfs.img"
if !errorlevel! neq 0 ( echo [FAIL] rootfs & pause & exit /b 1 )

echo.
echo Rebooting...
"!FB!" reboot

echo.
echo ============================================
echo   Flash completed successfully!
echo ============================================
echo.
echo WiFi: SSID=OpenWrt-UFI103  Password=12345678
echo Web:  http://192.168.100.1
echo.
pause
