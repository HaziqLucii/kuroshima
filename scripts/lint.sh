#!/usr/bin/env bash
# /usr/bin/qmllint on this system is qt5-declarative's binary (Qt 5.15):
# syntax-only, silently accepts real errors (missing properties, unqualified
# access) with exit 0 and no output. The one that actually does semantic
# checking, matching qt6-declarative and this project's Qt6-style imports,
# is /usr/lib/qt6/bin/qmllint. Same trap as qmltestrunner, see
# docs/HANDOFF.md. Don't call bare `qmllint` here again.
#
# One known false positive, not a real issue: qs.* root-relative imports
# (Quickshell's own directory-as-module convention) aren't resolvable by
# qmllint outside the qs runtime, so every file using them warns on import
# and on every qs.*-singleton reference ("unqualified access"). Real
# problems (missing properties, unknown types, typos) still surface
# distinctly from that noise.
set -euo pipefail
cd "$(dirname "$0")/.."
find . -name '*.qml' -print0 | xargs -0 /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml
