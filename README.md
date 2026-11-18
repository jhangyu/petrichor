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

Releases are built and published only by GitHub Actions
(`.github/workflows/release.yml`): set `version:` in pubspec.yaml, commit, then
push the matching tag.

```
git tag v0.0.1
git push origin v0.0.1
```

Each target (macOS universal, Linux x64/arm64, Windows x64/arm64, Android
universal APK) builds on its own GitHub-hosted runner with
`scripts/ci.py --platform <target> --tag <tag>`; the publish job then runs
`scripts/ci.py --publish --tag <tag>` and fails if any asset is missing. The tag
must equal `v` + the pubspec.yaml version.

Local builds only pre-check that flow; they never make release assets:

```
python3 scripts/ci.py                       # macOS + Android on this Mac
python3 scripts/ci.py --platform <target>   # one target on its own host
```

- Outputs go to `build/ci-dist/`.
- The apps are unsigned (the APK uses the debug signing key).
