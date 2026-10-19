# One UI 7 boot port — Samsung Galaxy A11 SM-A115F

This branch is exclusively for a device-specific One UI 7 / Android 15 port for `SM-A115F` (Snapdragon 450). It is not a generic GSI and must not be flashed on M11 or any other A115 variant.

The intended method is a Qualcomm Samsung donor system with One UI 7, while the A115F boot, kernel, vendor, DTBO, HALs, partition layout, and device identity remain the port side. Donor kernel, vendor, modem, PIT, and EFS are never used on A115F.

The first milestone is boot only: boot animation, display/touch, ADB, and `system_server`. Audio, camera, radio, Wi-Fi, Bluetooth, biometrics, performance, and Samsung AI are later milestones.

A real build is gated on the exact A115F stock package. Required values are the model, CSC, binary/bootloader revision, Android build, and verified AP/BL/CP/CSC checksums. Without those files the build system can only produce an unbootable placeholder, so no flashable ZIP is labeled ready before the gate is satisfied.
