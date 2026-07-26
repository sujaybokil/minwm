# Contributing to minwm

minwm is a work in progress, and focused bug reports and small pull requests are
welcome.

## Before opening an issue

1. Reproduce the problem with the latest `main` branch.
2. Run minwm with `--debug true`.
3. Reduce the log to the relevant lines and remove anything you do not want to
   share publicly.
4. Include your Windows version, monitor scaling, application version, layout,
   and reproduction steps.

Use GitHub Security Advisories instead of a public issue for vulnerabilities;
see [SECURITY.md](SECURITY.md).

## Pull requests

- Keep window discovery, constraint selection, and layout calculations
  separated.
- Add pure unit tests for geometry or constraint changes.
- Keep debug logs actionable and avoid window titles or user content.
- Do not commit generated files under `dist\` or third-party runtimes.
- Run `.\tools\Test.ps1` before submitting.

By contributing, you agree that your contribution is licensed under the MIT
License.
