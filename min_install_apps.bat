@echo off

echo warning run this script in android_app folder which has all the requried apps
echo starting minimal installation..

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

echo done installing apps!!

::granting the termux to storage
adb shell pm grant com.termux android.permission.READ_EXTERNAL_STORAGE
adb shell pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE

echo opening the termux
adb shell am start -n com.termux/.app.TermuxActivity

:: added %s becuase adb text has some shit understanding of utf-format
adb shell input text "curl%s-Lf%shttps://github.com/shiva1485/Server-In-Phone/blob/main/setupTermux.sh%s-o%ssetupTermux.sh"
adb shell input keyevent 66  :: Press Enter
adb shell input text "chmod%s+x%ssetupTermux.sh"
adb shell input keyevent 66  :: Press Enter
adb shell input text "./setupTermux.sh"
adb shell input keyevent 66  :: Press Enter

echo now termux will be configured try to do it.