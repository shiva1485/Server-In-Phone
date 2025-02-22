@echo off
title Termux Auto Configure using ADB.

rem Use colour.bat to display colorful output
call colour.bat -s "WARNING: Run this script in the android_app folder which has all the required apps" -b 0 -f 12 -n -e
call colour.bat -s "Starting minimal installation..." -b 0 -f 10 -n -e

timeout /t 3 /nobreak >nul

adb install "com.termux.api_51.apk"
adb install "com.termux.boot_1000.apk"
adb install "com.termux.styling_1000.apk"
adb install "com.termux.widget_1000.apk"
adb install "com.termux.window_15.apk"
adb install "com.termux_1000.apk"
adb install "DevCheck Pro v5.35 Mod.apk"
adb install "com.kiwibrowser.browser-arm-8822657649-github.apk"
adb install "MacroDroid v5.50.9 (Premium).apk"

call colour.bat -s "Done installing apps!!" -b 0 -f 14 -n -e

adb shell pm grant com.termux android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE

call colour.bat -s "Preventing Android from putting Termux to sleep..." -b 0 -f 12 -n -e
adb shell dumpsys battery unplug
adb shell dumpsys deviceidle disable
adb shell dumpsys battery set status 3
adb shell settings put global battery_saver_constants "null"
adb shell settings put global app_standby_enabled 0

call colour.bat -s "Allowing Termux to run in the background..." -b 0 -f 13 -n -e
adb shell am set-inactive com.termux false
adb shell cmd appops set com.termux RUN_IN_BACKGROUND allow

call colour.bat -s "Whitelisting Termux from Android’s Doze Mode..." -b 0 -f 11 -n -e
adb shell dumpsys deviceidle whitelist +com.termux

call colour.bat -s "Enabling Wake Lock to prevent sleep..." -b 0 -f 9 -n -e
adb shell svc power stayon true
adb shell input keyevent KEYCODE_WAKEUP
adb shell am startservice --user 0 -n com.termux/.app.TermuxService

call colour.bat -s "Termux is now running persistently in the background!" -b 0 -f 10 -n -e

call colour.bat -s "Opening Termux in the background..." -b 0 -f 8 -n -e
adb shell monkey -p com.termux -c android.intent.category.LAUNCHER 1

echo wait 30 seconds for temux app to load.
echo Waiting 30 seconds for Termux app to load...
for /l %%i in (30,-1,1) do (
    echo %%i...
    timeout /t 1 /nobreak >nul
)

call colour.bat -s "Configuring Termux..." -b 0 -f 5 -n -e
adb shell input text "curl%%s-Lf%%shttps://raw.githubusercontent.com/shiva1485/Server-In-Phone/refs/heads/main/setupTermux.sh%%s-o%%ssetupTermux.sh"
adb shell input keyevent 66  :: Press Enter
adb shell input text "chmod%%s+x%%ssetupTermux.sh"
adb shell input keyevent 66  :: Press Enter
adb shell input text "./setupTermux.sh"
adb shell input keyevent 66  :: Press Enter

call colour.bat -s "Now Termux will be configured. Wait patiently for a few minutes to an hour." -b 0 -f 15 -n -e

call colour.bat -s "Press any key to exit..." -b 0 -f 1 -n -e
pause >nul
