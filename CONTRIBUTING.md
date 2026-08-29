# Contributing Guidelines

Thank you for your interest in contributing to **NSPFF (NSP Fast Forward)**.

## Code of Conduct

All contributors are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md).

## Workflow & Development Setup

1. **Fork and Clone:**
   ```bash
   git clone https://github.com/jxoesneon/NSPFF.git
   cd NSPFF
   ```

2. **Dependencies & Static Analysis:**
   Ensure all dependencies resolve cleanly and static analysis passes:
   ```bash
   flutter pub get
   flutter analyze
   ```

3. **Running Tests:**
   Run the test suite before submitting pull requests:
   ```bash
   flutter test
   ```

## Pull Request Guidelines

- Ensure code adheres to standard Dart formatting (`dart format .`).
- Add unit tests for any new binary parser or packaging logic.
- Keep commits descriptive and atomic.
