# Contributing to SMS Gateway Pro

Thank you for your interest in contributing to **SMS Gateway Pro**! We appreciate contributions from the community.

## Developer Profile & Attribution
- **Creator / Maintainer**: Lwena Adam Samson
- **Portfolio**: [lwena.techwareafrica.tech](https://lwena.techwareafrica.tech)
- **GitHub**: [@LwenaAdam](https://github.com/LwenaAdam)
- **Organization**: [TechWare Africa](https://techwareafrica.tech)

---

## Code of Conduct
Please be respectful, professional, and collaborative in all interactions across issues, pull requests, and discussions.

---

## Getting Started

1. **Fork the repository** on GitHub under your account.
2. **Clone your fork**:
   ```bash
   git clone https://github.com/LwenaAdam/sms_getway.git
   cd sms_getway
   ```
3. **Set up Flutter & Dependencies**:
   ```bash
   flutter pub get
   ```
4. **Environment Setup**:
   Copy `.env.example` to configure local variables or pass `--dart-define` parameters during `flutter run`:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co \
               --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```

---

## Development Workflow

1. Create a descriptive branch:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```
2. Follow Dart styling guidelines:
   ```bash
   dart format .
   flutter analyze
   ```
3. Run tests before submitting:
   ```bash
   flutter test
   ```

---

## Pull Request Guidelines

- Ensure your branch is rebased onto the latest `main`.
- Write clear, conventional commit messages (`feat: ...`, `fix: ...`, `docs: ...`).
- Document any schema changes or new settings.
- If editing endpoints, update [docs/API_DOCUMENTATION.md](docs/API_DOCUMENTATION.md) and [docs/openapi.yaml](docs/openapi.yaml).

---

## Reporting Issues & Security

- For bug reports or feature requests, open an issue on GitHub.
- For sensitive security findings, please contact `lwena@techwareafrica.tech` directly before opening public issues.
