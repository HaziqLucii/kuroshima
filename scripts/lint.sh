#!/usr/bin/env bash
# qmllint over every .qml file. Two known false positives, not real issues:
# - qs.* root-relative imports (Quickshell's own directory-as-module
#   convention) aren't resolvable by qmllint.
# - qmllint (qt6-declarative 6.11) crashes outright (exit 255, no output) on
#   typed function parameters (`function f(x: string): void`), which
#   IpcHandler requires. shell.qml is excluded for this reason; it's still
#   exercised at runtime every dev session via scripts/dev.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
find . -name '*.qml' -not -name 'shell.qml' -print0 | xargs -0 qmllint -I /usr/lib/qt6/qml
