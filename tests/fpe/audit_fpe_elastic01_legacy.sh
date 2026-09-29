#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic01-legacy-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT
base64 -d reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64 | gzip -dc > "$TMP/MOD_MvG_functions.f90"
echo "F_PE_ELASTIC01_LEGACY_ELAS_LINES_BEGIN"
grep -ni -C 5 'elas' "$TMP/MOD_MvG_functions.f90" || true
echo "F_PE_ELASTIC01_LEGACY_ELAS_LINES_END"
