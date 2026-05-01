@echo off
setlocal enabledelayedexpansion

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
echo.

:: ---- Check device ----
echo [CHECK] Waiting for fastboot device...
"!FB!" devices 2>nul | findstr "fastboot" >nul
if !errorlevel! neq 0 (
    echo [ERROR] No device in fastboot mode detected.
    echo   Hold reset button + plug USB to enter fastboot
    echo   Or: adb reboot bootloader
    pause
    exit /b 1
)
echo [OK] Device connected
echo.

:: ---- Firmware path ----
set "ROOT=%~dp0"
if exist "%ROOT%firmware\" (
    set "FW=%ROOT%firmware\"
    echo [INFO] Baseband firmware dir: firmware\
) else (
    set "FW=%ROOT%"
    echo [INFO] No firmware\ subdir, looking for .mbn in current dir
)

:: ---- Check required files ----
set MISSING=0
if not exist "%ROOT%gpt_both0.bin" ( echo [MISSING] gpt_both0.bin & set MISSING=1 )
if not exist "%ROOT%boot.img"      ( echo [MISSING] boot.img      & set MISSING=1 )
if not exist "%ROOT%rootfs.img"    ( echo [MISSING] rootfs.img    & set MISSING=1 )
if !MISSING!==1 (
    echo.
    echo [ERROR] Required files missing. Aborting.
    pause
    exit /b 1
)
echo [OK] Required files found
echo.

:: ---- Confirm ----
echo WARNING: This will ERASE boot and rootfs partitions!
echo Press Ctrl+C to cancel, or
pause
echo.

:: ===========================================
:: Phase 1: Partition + Baseband
:: ===========================================
echo ========== Phase 1: Partition ^& Baseband ==========

echo [1/11] Flashing partition table...
"!FB!" flash partition "%ROOT%gpt_both0.bin"
if !errorlevel! neq 0 ( echo [FAIL] partition & pause & exit /b 1 )

echo [2/11] hyp.mbn...
if exist "%FW%hyp.mbn" (
    "!FB!" flash hyp "%FW%hyp.mbn"
) else ( echo [SKIP] hyp.mbn - not found )

echo [3/11] rpm.mbn...
if exist "%FW%rpm.mbn" (
    "!FB!" flash rpm "%FW%rpm.mbn"
) else ( echo [SKIP] rpm.mbn - not found )

echo [4/11] sbl1.mbn...
if exist "%FW%sbl1.mbn" (
    "!FB!" flash sbl1 "%FW%sbl1.mbn"
) else ( echo [SKIP] sbl1.mbn - not found )

echo [5/11] tz.mbn...
if exist "%FW%tz.mbn" (
    "!FB!" flash tz "%FW%tz.mbn"
) else ( echo [SKIP] tz.mbn - not found )

echo [6/11] fsc.mbn...
if exist "%FW%fsc.mbn" (
    "!FB!" flash fsc "%FW%fsc.mbn"
) else ( echo [SKIP] fsc.mbn - not found )

echo [7/11] fsg.mbn...
if exist "%FW%fsg.mbn" (
    "!FB!" flash fsg "%FW%fsg.mbn"
) else ( echo [SKIP] fsg.mbn - not found )

echo [8/11] modemst1.mbn...
if exist "%FW%modemst1.mbn" (
    "!FB!" flash modemst1 "%FW%modemst1.mbn"
) else ( echo [SKIP] modemst1.mbn - not found )

echo [9/11] modemst2.mbn...
if exist "%FW%modemst2.mbn" (
    "!FB!" flash modemst2 "%FW%modemst2.mbn"
) else ( echo [SKIP] modemst2.mbn - not found )

echo [10/11] aboot.mbn...
if exist "%FW%aboot.mbn" (
    "!FB!" flash aboot "%FW%aboot.mbn"
) else ( echo [SKIP] aboot.mbn - not found )

:: ===========================================
:: Phase 2: Erase + Reboot
:: ===========================================
echo.
echo ========== Phase 2: Erase ^& Reboot ==========

echo [11/11] Erasing boot and rootfs...
"!FB!" erase boot
"!FB!" erase rootfs
"!FB!" reboot

echo.
echo [WAIT] Device is rebooting. Wait for it to re-enter fastboot.
echo        Hold reset + plug USB if it does not enter fastboot automatically.
echo.
pause

:: ---- Wait for device ----
echo [CHECK] Waiting for device to re-enter fastboot...
:wait_loop
"!FB!" devices 2>nul | findstr "fastboot" >nul
if !errorlevel! neq 0 (
    timeout /t 2 /nobreak >nul
    goto wait_loop
)
echo [OK] Device back in fastboot
echo.

:: ===========================================
:: Phase 3: Boot + Rootfs
:: ===========================================
echo ========== Phase 3: Boot ^& Rootfs ==========

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
