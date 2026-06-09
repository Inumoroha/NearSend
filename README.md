# NearSend

NearSend is a Windows desktop file transfer prototype built with Flutter.

It is inspired by LocalSend and currently focuses on a chat-style desktop UI, LAN device discovery, manual/QR connection, and LocalSend-compatible file transfer basics.

## Current Features

- Windows desktop app UI.
- LAN device discovery.
- Manual connection by IP and port.
- QR connection payload for local clients.
- Basic LocalSend-compatible file send and receive.
- Multiple attachment selection with thumbnails.
- Clipboard image paste, including screenshots.
- Image preview.
- Auto-save received files.
- Overwrite same-name files option.
- Minimize to tray option.
- Light/dark mode and theme color switching.

## Development

```powershell
cd teasend_ui
flutter pub get
flutter run -d windows
```

Run checks:

```powershell
cd teasend_ui
flutter analyze
flutter test
flutter build windows --debug
```

The debug executable is generated at:

```text
teasend_ui/build/windows/x64/runner/Debug/nearsend.exe
```

## Notes

The `localsend/` directory is kept locally as a read-only reference and is intentionally ignored by Git.
