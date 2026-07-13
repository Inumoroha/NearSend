# NearSend

[中文文档](README.zh-CN.md)

NearSend is a Flutter application inspired by LocalSend. It currently targets
Windows and provides initial Android support for LAN discovery, chat messages,
and LocalSend-compatible file transfer.

## Features

- LAN device discovery, manual IP connection, and QR connection payloads.
- Basic LocalSend v1/v2 file transfer with HTTPS and certificate fingerprint checking.
- Multi-file selection, thumbnails, image preview, clipboard image, and screenshot sending.
- Transfer tasks with progress, speed, remaining time, cancel, retry, and receive confirmation.
- Automatic saving, custom save directory, and same-name file handling.
- Receive history with search, open file/folder, delete, clear, and stale-record cleanup.
- Favorite devices with automatic receiving and optional clipboard auto-send.
- Windows tray support and firewall/network diagnostics.
- Light/dark mode and theme color switching.

Remaining LocalSend feature gaps are tracked in
[`localsend_feature_gap.md`](localsend_feature_gap.md).

## Project Layout

```text
.
├── .github/workflows/       Release workflows
├── android/                 Android platform code
├── docs/                    Development and troubleshooting notes
├── lib/                     Dart application code
├── test/                    Tests
├── windows/                 Windows platform code
├── fonts/                   Application fonts
├── pubspec.yaml             Flutter dependencies and metadata
├── README.md                English documentation
├── README.zh-CN.md          Chinese documentation
└── localsend_feature_gap.md
```

## Development

```powershell
flutter pub get
flutter run -d windows
```

Run checks:

```powershell
flutter analyze
flutter test
flutter build windows --debug
```

The debug executable is generated at:

```text
build/windows/x64/runner/Debug/nearsend.exe
```

The `localsend/` directory may be kept locally as a read-only reference and is
intentionally ignored by Git.
