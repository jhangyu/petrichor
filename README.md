# petrichor

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Release build

```
python3 scripts/ci.py
python3 scripts/ci.py --version 0.0.1 --platform all [--publish]
```

- No arguments: builds macOS and Android (universal release APK, debug-signed) on this Mac with the pubspec.yaml version; no clean-tree check, no publish.
- `--platform` takes `macos`, `linux-arm64`, `linux-x64`, `windows`, `android` or `all`; `--publish` requires explicit `--version` and `--platform`.
- Outputs go to `build/ci-dist/`.
- The Windows box must be powered on.
- The apps are unsigned.
