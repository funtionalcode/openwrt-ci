@echo off
echo OpenWrt UFI103_CT Flash Tool
echo Please make sure the device is in fastboot mode
pause
"%~dp0fastboot.exe" flash partition gpt_both0.bin
if exist hyp.mbn ("%~dp0fastboot.exe" flash hyp hyp.mbn) else (echo SKIP hyp.mbn - not found)
if exist rpm.mbn ("%~dp0fastboot.exe" flash rpm rpm.mbn) else (echo SKIP rpm.mbn - not found)
if exist sbl1.mbn ("%~dp0fastboot.exe" flash sbl1 sbl1.mbn) else (echo SKIP sbl1.mbn - not found)
if exist tz.mbn ("%~dp0fastboot.exe" flash tz tz.mbn) else (echo SKIP tz.mbn - not found)
if exist fsc.mbn ("%~dp0fastboot.exe" flash fsc fsc.mbn) else (echo SKIP fsc.mbn - not found)
if exist fsg.mbn ("%~dp0fastboot.exe" flash fsg fsg.mbn) else (echo SKIP fsg.mbn - not found)
if exist modemst1.mbn ("%~dp0fastboot.exe" flash modemst1 modemst1.mbn) else (echo SKIP modemst1.mbn - not found)
if exist modemst2.mbn ("%~dp0fastboot.exe" flash modemst2 modemst2.mbn) else (echo SKIP modemst2.mbn - not found)
if exist aboot.mbn ("%~dp0fastboot.exe" flash aboot aboot.mbn) else (echo SKIP aboot.mbn - not found)
"%~dp0fastboot.exe" erase boot
"%~dp0fastboot.exe" erase rootfs
"%~dp0fastboot.exe" reboot
echo Please wait for device to re-enter fastboot...
pause
"%~dp0fastboot.exe" flash boot boot.img
"%~dp0fastboot.exe" -S 200m flash rootfs rootfs.img
"%~dp0fastboot.exe" reboot
echo Flash completed!
pause
