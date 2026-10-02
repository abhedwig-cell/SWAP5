#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
# Build the same persisted analytical-MvG chain before checking required boundaries.
bash tests/physics/run_bartholomeus_active_chain.sh
FC="${FC:-gfortran}"
B="${TMPDIR:-/tmp}/c3a_active"
"$FC" -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -I"$B" \
 tests/physics/test_bartholomeus_admission_boundaries.f90 "$B"/*.o -o "$B/boundaries"
"$B/boundaries"
