#!/usr/bin/env bash
# Run the shell against the repo directly (hot reloads on save).
set -euo pipefail
cd "$(dirname "$0")/.."
exec qs -n -p .
