@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   OpenWrt UFI103_CT Upgrade Tool
echo   (OpenWrt to OpenWrt only)
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

:: ---- Check required files ----
set MISSING=0
if not exist "%~dp0gpt_both0.bin" ( echo [MISSING] gpt_both0.bin & set MISSING=1 )
if not exist "%~dp0boot.img"      ( echo [MISSING] boot.img      & set MISSING=1 )
if not exist "%~dp0rootfs.img"    ( echo [MISSING] rootfs.img    & set MISSING=1 )
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

:: ---- Flash ----
echo [1/3] Flashing partition table...
"!FB!" flash partition "%~dp0gpt_both0.bin"
if !errorlevel! neq 0 ( echo [FAIL] partition & pause & exit /b 1 )

echo [2/3] Flashing boot.img...
"!FB!" flash boot "%~dp0boot.img"
if !errorlevel! neq 0 ( echo [FAIL] boot & pause & exit /b 1 )

echo [3/3] Flashing rootfs.img...
"!FB!" -S 200m flash rootfs "%~dp0rootfs.img"
if !errorlevel! neq 0 ( echo [FAIL] rootfs & pause & exit /b 1 )

echo.
echo Rebooting...
"!FB!" reboot

echo.
echo ============================================
echo   Upgrade completed successfully!
echo ============================================
echo.
echo WiFi: SSID=OpenWrt-UFI103  Password=12345678
echo Web:  http://192.168.100.1
echo.
pause
