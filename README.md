# bahibo

A new Flutter project.

## Project Docs

- [Workflow progress](docs/workflow-progress.md)
- [Database schema](docs/bahibo-database-schema.mmd)

## Mobile API Auto Config

For Android development, use the helper script below instead of changing the API host manually every time:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-mobile-auto.ps1
```

What it does automatically:

- Android emulator: uses `http://10.0.2.2:4000/api/v1`
- USB Android phone: runs `adb reverse tcp:4000 tcp:4000` and uses `http://127.0.0.1:4000/api/v1`
- Wi-Fi Android device: detects the PC LAN IP and uses `http://<pc-lan-ip>:4000/api/v1`

Notes:

- The script reads `PORT` from `backend/.env` if present.
- If multiple Android devices are connected, pass the device id explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-mobile-auto.ps1 -DeviceId <flutter-device-id>
```

- You can also launch it from VS Code with the task `Bahibo: Run Mobile Auto API`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
