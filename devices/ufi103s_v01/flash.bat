@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
color 0A

echo ============================================
echo   OpenWrt UFI103_CT Flash Tool
echo ============================================
echo.

set "ROOT=%~dp0"
set "FW=%ROOT%firmware\"

REM ---- Find fastboot ----
set "FB="
where fastboot >nul 2>&1
if !errorlevel!==0 (set "FB=fastboot") else if exist "%ROOT%fastboot.exe" (set "FB=%ROOT%fastboot.exe")
if "%FB%"=="" (
    echo [ERROR] fastboot not found.
    pause & exit /b 1
)
echo [OK] fastboot: %FB%

REM ---- Find adb ----
set "ADB="
where adb >nul 2>&1
if !errorlevel!==0 (set "ADB=adb") else if exist "%ROOT%adb.exe" (set "ADB=%ROOT%adb.exe")

REM ===========================================
REM Phase 1: Device Detection
REM ===========================================
echo ========== [1/4] Device Detection ==========

:check_device
%FB% devices 2>nul | findstr "fastboot" >nul
if !errorlevel!==0 (
    echo [OK] Device in fastboot mode
    goto :phase2
)

if not "%ADB%"=="" (
    %ADB% devices 2>nul | findstr /R "device$" >nul
    if !errorlevel!==0 (
        echo [OK] Device in ADB mode, rebooting to bootloader...
        %ADB% reboot bootloader
        timeout /NOBREAK /T 5 >nul
        goto :phase2
    )
)

echo [!] No device found.
echo    Hold reset + plug USB, or: adb reboot bootloader
echo.
echo    Press any key to retry...
pause >nul
goto :check_device

REM ===========================================
REM Phase 2: lk2nd + Baseband Backup
REM ===========================================
:phase2
echo.
echo ========== [2/4] lk2nd + Baseband Backup ==========

REM Flash lk2nd
%FB% erase boot >nul 2>&1
%FB% flash boot "%FW%lk2nd.img"
if !errorlevel! neq 0 (
    echo [FAIL] lk2nd flash failed!
    pause & exit /b 1
)
echo [OK] lk2nd flashed, rebooting...
%FB% reboot
timeout /NOBREAK /T 3 >nul
echo Press any key when device is back in fastboot...
pause >nul

:wait_lk2nd
%FB% devices 2>nul | findstr "fastboot" >nul
if !errorlevel! neq 0 (timeout /t 2 /nobreak >nul & goto :wait_lk2nd)
echo [OK] lk2nd fastboot ready

REM Backup baseband (only works in lk2nd fastboot)
echo Dumping baseband...
echo [1/4] fsc...
%FB% oem dump fsc >nul 2>&1 && (timeout /NOBREAK /T 1 >nul & %FB% get_staged "%ROOT%fsc.bin" >nul 2>&1 && echo  [OK] fsc.bin) || echo  [SKIP] dump failed

echo [2/4] fsg...
%FB% oem dump fsg >nul 2>&1 && (timeout /NOBREAK /T 1 >nul & %FB% get_staged "%ROOT%fsg.bin" >nul 2>&1 && echo  [OK] fsg.bin) || echo  [SKIP] dump failed

echo [3/4] modemst1...
%FB% oem dump modemst1 >nul 2>&1 && (timeout /NOBREAK /T 1 >nul & %FB% get_staged "%ROOT%modemst1.bin" >nul 2>&1 && echo  [OK] modemst1.bin) || echo  [SKIP] dump failed

echo [4/4] modemst2...
%FB% oem dump modemst2 >nul 2>&1 && (timeout /NOBREAK /T 1 >nul & %FB% get_staged "%ROOT%modemst2.bin" >nul 2>&1 && echo  [OK] modemst2.bin) || echo  [SKIP] dump failed

REM Erase lk2nd, back to stock fastboot
echo.
%FB% erase lk2nd >nul 2>&1
%FB% erase boot >nul 2>&1
%FB% reboot bootloader
echo Rebooting to stock fastboot...
timeout /NOBREAK /T 3 >nul
echo Press any key when device is back in fastboot...
pause >nul

:wait_stock
%FB% devices 2>nul | findstr "fastboot" >nul
if !errorlevel! neq 0 (timeout /t 2 /nobreak >nul & goto :wait_stock)
echo [OK] Stock fastboot ready

REM ===========================================
REM Phase 3: Low-Level Firmware
REM ===========================================
echo.
echo ========== [3/4] Low-Level Firmware ==========

echo [1/12] Partition table...
%FB% flash partition "%ROOT%gpt_both0.bin"
if !errorlevel! neq 0 (echo [FAIL] & pause & exit /b 1)

echo [2/12] hyp...
if exist "%FW%hyp.mbn" (%FB% flash hyp "%FW%hyp.mbn") else (echo  SKIP)

echo [3/12] rpm...
if exist "%FW%rpm.mbn" (%FB% flash rpm "%FW%rpm.mbn") else (echo  SKIP)

echo [4/12] sbl1...
if exist "%FW%sbl1.mbn" (%FB% flash sbl1 "%FW%sbl1.mbn") else (echo  SKIP)

echo [5/12] tz...
if exist "%FW%tz.mbn" (%FB% flash tz "%FW%tz.mbn") else (echo  SKIP)

echo [6/12] fsc (from dump or firmware)...
if exist "%ROOT%fsc.bin" (
    %FB% flash fsc "%ROOT%fsc.bin"
) else if exist "%FW%fsc.mbn" (
    %FB% flash fsc "%FW%fsc.mbn"
) else (echo  SKIP)

echo [7/12] fsg (from dump or firmware)...
if exist "%ROOT%fsg.bin" (
    %FB% flash fsg "%ROOT%fsg.bin"
) else if exist "%FW%fsg.mbn" (
    %FB% flash fsg "%FW%fsg.mbn"
) else (echo  SKIP)

echo [8/12] modemst1 (from dump or firmware)...
if exist "%ROOT%modemst1.bin" (
    %FB% flash modemst1 "%ROOT%modemst1.bin"
) else if exist "%FW%modemst1.mbn" (
    %FB% flash modemst1 "%FW%modemst1.mbn"
) else (echo  SKIP)

echo [9/12] modemst2 (from dump or firmware)...
if exist "%ROOT%modemst2.bin" (
    %FB% flash modemst2 "%ROOT%modemst2.bin"
) else if exist "%FW%modemst2.mbn" (
    %FB% flash modemst2 "%FW%modemst2.mbn"
) else (echo  SKIP)

echo [10/12] aboot...
if exist "%FW%aboot.bin" (
    %FB% flash aboot "%FW%aboot.bin"
) else if exist "%FW%aboot.mbn" (
    %FB% flash aboot "%FW%aboot.mbn"
) else (echo  SKIP)

echo [11/12] cdt...
if exist "%FW%sbc_1.0_8016.bin" (
    %FB% flash cdt "%FW%sbc_1.0_8016.bin" 2>&1 | findstr /V "partition table doesn't exist" >nul
) else (echo  SKIP)

echo [12/12] Erase old system...
%FB% erase boot >nul 2>&1
%FB% erase rootfs >nul 2>&1

echo Rebooting...
%FB% reboot
timeout /NOBREAK /T 3 >nul
echo Press any key when device is back in fastboot...
pause >nul

:wait_phase3
%FB% devices 2>nul | findstr "fastboot" >nul
if !errorlevel! neq 0 (timeout /t 2 /nobreak >nul & goto :wait_phase3)
echo [OK] Fastboot ready

REM ===========================================
REM Phase 4: OpenWrt System
REM ===========================================
echo.
echo ========== [4/4] OpenWrt System ==========

echo Flashing boot.img...
%FB% flash boot "%ROOT%boot.img"
if !errorlevel! neq 0 (echo [FAIL] & pause & exit /b 1)

echo Flashing rootfs.img...
%FB% -S 200m flash rootfs "%ROOT%rootfs.img"
if !errorlevel! neq 0 (echo [FAIL] & pause & exit /b 1)

echo Rebooting...
%FB% reboot

echo.
echo ============================================
echo   Flash completed!
echo ============================================
echo.
echo WiFi: SSID=OpenWrt-UFI103  Password=12345678
echo Web:  http://192.168.100.1
echo.
pause
