#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mc-irr01-source-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

BUNDLE=integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64
test -f "$BUNDLE"
base64 -d "$BUNDLE" > "$BUILD/authority.tar.gz"
tar -xzf "$BUILD/authority.tar.gz" -C "$BUILD"
SRC="$(find "$BUILD" -type f -path '*/SWAP/irrigation.f90' -print -quit)"
test -n "$SRC"
test "$(sha256sum "$SRC" | awk '{print $1}')" = "65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1"

# Exact source excerpt is persisted in the workflow log for bounded contract reconstruction.
echo 'MC_IRR01_SOURCE_BEGIN'
nl -ba "$SRC" | sed -n '240,365p'
nl -ba "$SRC" | sed -n '445,645p'
nl -ba "$SRC" | sed -n '675,745p'
echo 'MC_IRR01_SOURCE_END'
echo 'MC_IRR01_SOURCE_RECONSTRUCTION=PASS'
