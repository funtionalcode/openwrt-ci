@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   UFI103_CT 9008 Rescue
echo ============================================
echo.

if "%PYTHON%"=="" set "PYTHON=python"

set "ROOT=%~dp0"
set "FW=%ROOT%firmware\"

REM ---- Find edl ----
set "EDL="
where edl >nul 2>&1
if !errorlevel!==0 (
    set "EDL=edl"
    goto :edl_found
)
REM Check alongside script (edl.py or edl.exe)
if exist "%ROOT%edl.py" (
    set "EDL=%PYTHON% %ROOT%edl.py"
    goto :edl_found
)
if exist "%ROOT%edl.exe" (
    set "EDL=%ROOT%edl.exe"
    goto :edl_found
)
if exist "%ROOT%edl-src\edl-3.52.1\edl.py" (
    set "EDL=%PYTHON% %ROOT%edl-src\edl-3.52.1\edl.py"
    goto :edl_found
)
REM Check alongside Python (venv Scripts dir)
for %%p in ("%PYTHON%") do (
    if exist "%%~dpp\Scripts\edl.exe" (
        set "EDL=%%~dpp\Scripts\edl.exe"
        goto :edl_found
    ) else if exist "%%~dpp\Scripts\edl.py" (
        set "EDL=%PYTHON% %%~dpp\Scripts\edl.py"
        goto :edl_found
    ) else if exist "%%~dpp\edl.exe" (
        set "EDL=%%~dpp\edl.exe"
        goto :edl_found
    )
)
echo [FAIL] edl not found.
echo.
echo Options:
echo   1. Extract edl-3.52.1.zip and copy edl.py next to this script
echo   2. pip install path\to\edl-3.52.1
echo   3. pip install git+https://github.com/bkerler/edl.git
echo.
echo You can also set PYTHON= to your Python path.
pause
exit /b 1

:edl_found
echo [OK] edl: !EDL!

REM Verify it's the right edl (Qualcomm, not video editing)
!EDL! --help 2>&1 | findstr /C:"edl.py" >nul
if !errorlevel! neq 0 (
    echo [WARN] This may not be the Qualcomm EDL tool.
    echo        If you see video/EDL/Timecode errors below, you installed the wrong package.
    echo        Run: pip uninstall edl
    echo        Then: pip install git+https://github.com/bkerler/edl.git
    echo.
)
echo [OK] edl: !EDL!

REM ---- Find firehose ----
set "LOADER="
if exist "%ROOT%prog_firehose_8916_1.bin" (
    set "LOADER=--loader=%ROOT%prog_firehose_8916_1.bin"
    echo [OK] Firehose: prog_firehose_8916_1.bin
) else if exist "%ROOT%prog_firehose_8916_2.bin" (
    set "LOADER=--loader=%ROOT%prog_firehose_8916_2.bin"
    echo [OK] Firehose: prog_firehose_8916_2.bin
) else if exist "%ROOT%prog_firehose_8916_3.mbn" (
    set "LOADER=--loader=%ROOT%prog_firehose_8916_3.mbn"
    echo [OK] Firehose: prog_firehose_8916_3.mbn
)
if "%LOADER%"=="" (
    echo [WARN] No firehose programmer found.
)
echo.

REM ---- Detect 9008 device ----
echo Detecting 9008 device...
!EDL! !LOADER! printgpt >nul 2>&1
if !errorlevel! neq 0 (
    echo.
    echo [FAIL] No 9008 device found.
    echo.
    echo How to enter 9008 mode:
    echo   1. Short test point + plug USB
    echo   2. Or: fastboot oem reboot-edl
    echo.
    pause
    exit /b 1
)
echo [OK] Device in 9008 mode
echo.

echo ============================================
echo   WARNING: This will overwrite ALL partitions!
echo ============================================
echo Press Ctrl+C to cancel, or
pause
echo.

REM ===========================================
REM Helper: flash_part part file [fallback]
REM ===========================================
goto :flash_end

:flash_part
set "PART=%~1"
set "FILE=%~2"
set "FALLBACK=%~3"
set "FPATH="

if exist "%ROOT%%FILE%" (
    set "FPATH=%ROOT%%FILE%"
) else if exist "%FW%%FILE%" (
    set "FPATH=%FW%%FILE%"
) else if not "%FALLBACK%"=="" (
    if exist "%FW%%FALLBACK%" (
        set "FPATH=%FW%%FALLBACK%"
    )
)

if "!FPATH!"=="" (
    echo   %PART%... SKIP ^(not found^)
    goto :eof
)

set "TMPLOG=%TEMP%\edl_%PART%.log"
echo   %PART%...
!EDL! !LOADER! w %PART% "!FPATH!" >"!TMPLOG!" 2>&1
if !errorlevel! neq 0 (
    echo     [FAIL]
    echo     --- edl output: ---
    type "!TMPLOG!"
    echo     -------------------
) else (
    echo     [OK]
)
del "!TMPLOG!" 2>nul
goto :eof

:flash_end

REM ===========================================
REM 1. Partition Table
REM ===========================================
echo ========== [1/4] Partition Table ==========

echo   gpt...
!EDL! !LOADER! w gpt_main "%ROOT%gpt_both0.bin" >nul 2>&1
if !errorlevel! neq 0 (
    echo     [FAIL] gpt_main, trying wl...
    !EDL! !LOADER! wl 0 "%ROOT%gpt_both0.bin" >nul 2>&1
    if !errorlevel! neq 0 (
        echo     [WARN] GPT write failed, continuing anyway...
    ) else (
        echo     [OK] via wl
    )
) else (
    echo   [OK]
)

REM ===========================================
REM 2. Low-Level Firmware
REM ===========================================
echo.
echo ========== [2/4] Low-Level Firmware ==========

call :flash_part hyp   hyp.mbn         ""
call :flash_part rpm   rpm.mbn         ""
call :flash_part sbl1  sbl1.mbn        ""
call :flash_part tz    tz.mbn          ""
call :flash_part fsc   fsc.bin         fsc.mbn
call :flash_part fsg   fsg.bin         fsg.mbn
call :flash_part modemst1 modemst1.bin modemst1.mbn
call :flash_part modemst2 modemst2.bin modemst2.mbn
call :flash_part aboot aboot.bin       aboot.mbn
call :flash_part cdt   sbc_1.0_8016.bin ""
call :flash_part lk2nd lk2nd.img       ""

REM ===========================================
REM 3. OpenWrt System
REM ===========================================
echo.
echo ========== [3/4] OpenWrt System ==========

call :flash_part boot   boot.img   ""
call :flash_part rootfs rootfs.img ""

REM ===========================================
REM 4. Reboot
REM ===========================================
echo.
echo ========== [4/4] Reboot ==========
!EDL! !LOADER! reset 2>nul
if !errorlevel! neq 0 (
    echo [WARN] Reboot failed, manually unplug and replug USB.
) else (
    echo [OK] Device rebooting...
)

echo.
echo ============================================
echo   Rescue done!
echo   Wait 30s for device to boot...
echo ============================================
echo.
echo WiFi: SSID=OpenWrt-UFI103  Password=12345678
echo Web:  http://192.168.100.1
echo.
pause
