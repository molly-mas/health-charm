# HealthCharm Flutter conversion

This project converts the BLE behavior present in the supplied `BLEManager.swift` and keeps the supplied Pico W firmware. The ZIP did not include the SwiftUI app, `SensorDecoder`, `FaceEngine`, or `MLXBackend`, so there is no source implementation for Nemotron inference to port.

`lib/main.dart` currently runs a hardware-free UI preview with simulated signals and local ASCII faces. Settings offers pink, lavender, light blue, light green, light orange, and light red palettes, plus a face direction preset and an optional 80-character face hint. These choices last for the current app session. The earlier BLE-connected entry point is preserved in `../work/main_ble_preview.dart`; it is not wired into the preview build while Pub dependency resolution is being repaired.

`lib/face_prompt.dart` holds 20 curated text faces and packages the selected face direction, short user hint, sensor values, and face IDs into a request for Nemotron. The model selects an ID; the app displays the matching face only if the ID is valid. `lib/on_device_face_engine.dart` runs NVIDIA Nemotron 3 Nano 4B on Android through a vendored llama.cpp Flutter plugin. The Chrome preview uses the same local face presets.

## On-device Nemotron setup (Android)

1. Download NVIDIA's [Q4_K_M GGUF model](https://huggingface.co/nvidia/NVIDIA-Nemotron-3-Nano-4B-GGUF/blob/main/NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf) (2.84 GB) on the phone. The Settings sheet also has a **Get model file** button.
2. In HealthCharm Settings, tap **Import model** and choose the downloaded `.gguf` file. The app verifies NVIDIA's SHA-256 hash while copying it into private app storage. Keep at least 3.2 GB free for the copy.
3. Wait for **Nemotron ready on this phone**. Press, Shake, and Touch will send simulated sensor readings, the selected face direction, and the optional face hint to the on-device model. A valid face ID selects one of the curated ASCII faces. If model loading or selection fails, the preset remains visible.

The model runs on the phone after import; no API key or server is used. The Android build uses the CPU first (4 threads, 1024-token context) for predictable memory use on the Galaxy S23 Ultra. GPU offload and latency still need a physical-device check. The model file is deliberately outside the APK to keep installation practical. Real BLE sensor callbacks and sending selected rows to the Pico W are still separate integration work.

Build the Android project with JDK 21 (available here at `C:\Users\molly\.jdks\jbr-21.0.11`). Android Studio's bundled JDK 25 fails in this project's Gradle Kotlin setup. The on-device model path still needs an APK build and a physical-device inference test.

## Converted behavior

- Scans for `FaceKeychain` advertising service `FFE0`, connects, discovers `FFE1` and `FFE2`, and subscribes to sensor notifications.
- Decodes the four-byte packet as button flags, signed little-endian Int16 velocity divided by 100, and touch state, matching `firmware/PicoW/main.py`.
- Displays the connection state, sensor values, and compact five-row ASCII expressions. Press, Shake, and Touch buttons preview and send the matching face when connected.
- Sends each row as `[row index][up to 15 ASCII bytes]` with a BLE write response, matching the Swift implementation and firmware.

The demo responses are local face presets; they are not Nemotron output. Firmware remains MicroPython and should be copied to the Pico W as `main.py`.

## Build on an Android development machine

The Flutter SDK command did not return a version in this workspace, so Android scaffolding and a build could not be verified here. On a machine with Flutter installed, from this directory run:

```powershell
flutter create --platforms=android .
flutter pub get
flutter run
```

After scaffolding, confirm `android/app/src/main/AndroidManifest.xml` retains the Bluetooth permissions for Android 12+ (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`) and legacy Bluetooth/location permissions for older Android versions. The provided manifest is a starting point for that scaffold.

## Remaining conversion work

To port the original on-device model flow, provide the missing SwiftUI, `SensorDecoder`, `FaceEngine`, and `MLXBackend` sources plus the exact model/backend requirements. MLX is Apple-only and cannot be directly reused in Flutter on Android.

## Pico W reminder icons

Copy both files from firmware/PicoW (main.py and reminder_icons.py) to the Pico W, then restart it. The bitmaps are included in reminder_icons.py. Turn on Bluetooth on the Android phone and allow Nearby devices access when asked.

With HealthCharm open, set a reminder to Every 30 sec for a quick check. At the scheduled time the app scans for the Pico W service (FFE0) and writes byte FF followed by the ASCII icon ID (eat, water, chat, walk, or custom) to FFE2. The reference firmware displays the corresponding bitmap for five seconds and then restores the face. Existing face row commands still use their original format. Timers are in memory and require the app to stay running. Web preview shows a local message.
