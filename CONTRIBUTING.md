# Contributing

Thank you for your interest in contributing to **OrderPulse**.

## Development Setup

```bash
# Prerequisites: Flutter 3.41+, Android SDK (for APK builds)
git clone https://github.com/bachiep/orderpulse-flutter.git
cd orderpulse-flutter
flutter pub get
flutter analyze --no-pub
flutter test --concurrency=1       # run full test suite (58 tests)
```

## Workflow

1. **Open an Issue** describing the bug or feature.
2. **Create a branch** from `main`: `feat/issue-<n>-<slug>` or `fix/issue-<n>-<slug>`.
3. **Write widget/unit tests** for any new logic or UI.
4. **Follow Conventional Commits**: `feat(kds): add multi-station dispatch (#7)`.
5. **Ensure CI passes**: `flutter analyze && flutter test` locally before pushing.
6. **Open a Pull Request** referencing the issue: `Closes #<n>`.

## Code Standards

- Flutter 3.41+ with Dart null-safety.
- BLoC pattern with `bloc_concurrency` for event throttling.
- Dio HTTP client with `QueuedInterceptorsWrapper` for JWT refresh.
- WebSocket reconnection with exponential backoff.
- `CustomPainter` for shift analytics visualizations.

## Web Demo

The live web demo auto-deploys to GitHub Pages on `main` push via `.github/workflows/pages.yml`.