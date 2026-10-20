# A115F boot logging guide

The first A115F build is boot-first. Do not add a permanent init logging daemon before the first boot: an early daemon can introduce SELinux, storage, or timing failures and hide the original fault. Use the least invasive collector that matches the failure stage.

## 1. If ADB appears during the bootloop

Connect the phone to a computer and run:

```bash
mkdir -p a115f-logs
adb kill-server
adb start-server
adb wait-for-device
adb shell getprop > a115f-logs/getprop.txt
adb logcat -b all -v threadtime -d > a115f-logs/logcat-all.txt
adb shell dmesg > a115f-logs/dmesg.txt 2>&1 || true
adb shell dumpsys dropbox --print system_server_crash > a115f-logs/system-server-crash.txt 2>&1 || true
adb bugreport a115f-logs/bugreport.zip
```

For a repeating bootloop, keep a live capture running while the device reconnects:

```bash
while true; do
  adb wait-for-device
  adb logcat -b all -v threadtime -d >> a115f-logs/logcat-reconnect.txt
  adb shell getprop sys.boot_completed >> a115f-logs/boot-state.txt 2>&1 || true
  sleep 1
done
```

Stop the loop with `Ctrl+C`, then compress the folder and send the ZIP.

## 2. If it stops at the Samsung/OEM logo and ADB never appears

Boot to TWRP/OrangeFox recovery without wiping data. In recovery Terminal, run:

```sh
mkdir -p /sdcard/a115f-logs
cat /proc/last_kmsg > /sdcard/a115f-logs/last_kmsg.txt 2>&1 || true
cat /sys/fs/pstore/* > /sdcard/a115f-logs/pstore.txt 2>&1 || true
dmesg > /sdcard/a115f-logs/recovery-dmesg.txt 2>&1 || true
logcat -b all -d > /sdcard/a115f-logs/recovery-logcat.txt 2>&1 || true
getprop > /sdcard/a115f-logs/recovery-getprop.txt 2>&1 || true
```

Then copy the folder with:

```bash
adb pull /sdcard/a115f-logs ./a115f-logs
```

If `/sys/fs/pstore` is empty, that is useful information too: it usually means the kernel did not expose persistent crash storage or the crash happened before pstore was written.

## 3. If recovery itself can only provide a recovery log

Try:

```bash
adb pull /cache/recovery/last_log ./a115f-logs-last_log.txt
adb pull /cache/recovery/last_install ./a115f-logs-last_install.txt
```

Some recoveries store these files elsewhere. Do not delete them before copying.

## What to send back

Send the compressed `a115f-logs` folder and state exactly where it stopped:

- Samsung/OEM logo
- boot animation
- lock screen
- repeated reboot
- black screen with ADB
- recovery only

Do not send modem/EFS backups or personal data. The logs will be classified into kernel, AVB/vbmeta, init/vendor, SurfaceFlinger/SystemUI, or SystemServer failure before the next patch is selected.
