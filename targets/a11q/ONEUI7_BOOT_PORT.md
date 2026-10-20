# One UI 7 boot port — Samsung Galaxy A11 SM-A115F

This branch is exclusively for a device-specific One UI 7 / Android 15 port for `SM-A115F` (Snapdragon 450). It is not a generic GSI and must not be flashed on M11 or any other A115 variant.

The intended method is a Qualcomm Samsung donor system with One UI 7, while the A115F boot, kernel, vendor, DTBO, HALs, partition layout, and device identity remain the port side. Donor kernel, vendor, modem, PIT, and EFS are never used on A115F.

The first milestone is boot only: boot animation, display/touch, ADB, and `system_server`. Audio, camera, radio, Wi-Fi, Bluetooth, biometrics, performance, and Samsung AI are later milestones.

A real build is gated on the exact A115F stock package. That gate is now satisfied locally:

- Target: `SM-A115F / EGY`
- Target firmware: `A115FXXS6CWK2/A115FOJM6CWK1/A115FXXS6CWK1/A115FXXS6CWK2`
- Target OS package: Android 12 (`OS12`), S6 bootloader binary
- Donor: `SM-A057F / TUR`
- Donor firmware: `A057FXXUFDZH2/A057FOJMFDZH2/A057FXXUFDZH2/A057FXXUFDZH2`
- Donor OS package: Android 15 (`OS15`), Qualcomm One UI 7

Both Samsung archives pass ZIP integrity checks and contain the expected AP, BL, CP, CSC, and HOME_CSC payloads. The local configuration preflight also passes. The remaining gate is the actual image build and hardware boot test; no flashable ZIP is labeled ready before that gate is satisfied.

## Overlay and target patches

The A115F target intentionally does not copy `overlay/` or `patches/` from A52s, A73, A71, or another device. Those folders are optional modules in this engine, and blindly copying them can introduce incompatible display resources, vendor libraries, SELinux labels, or linker dependencies before the first boot.

The first build uses the A115F stock boot, vendor, kernel, DTBO, HALs, partition layout, and device identity with the donor system. After extraction, `overlay/` will be populated only with resources confirmed from the A115F stock framework, starting with the 720×1560 display and no punch-hole cutout. Target patches will be added in stages: first boot-safe property/permission fixes, then only the stock A115F blobs required by linker or HAL logs, and finally camera/audio/blur compatibility fixes. The `sff.sh` flags for AI, clock transitions, and blur are experimental declarations; they do not replace the native libraries required for those features.
