#!/usr/bin/env bash
# /usr/bin/qmltestrunner on this system is qt5-declarative's binary (Qt 5.15,
# needs versioned imports); the Qt6 one qs.* singletons and our unversioned
# imports need lives at /usr/lib/qt6/bin/qmltestrunner instead. Its Qt
# logging also goes to journald by default, not stdout, hence
# QT_FORCE_STDERR_LOGGING to actually see failures here.
set -euo pipefail
cd "$(dirname "$0")/.."
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 /usr/lib/qt6/bin/qmltestrunner -input tests
