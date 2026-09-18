#!/usr/bin/env bash
# qmllint over every .qml file. qs.* root-relative imports (Quickshell's own
# directory-as-module convention) aren't resolvable by qmllint, so those
# warnings are expected and not failures.
set -euo pipefail
cd "$(dirname "$0")/.."
find . -name '*.qml' -print0 | xargs -0 qmllint -I /usr/lib/qt6/qml
