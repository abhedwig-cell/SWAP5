#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
for optimization in 0 2; do
  (
    cd "$tmpdir"
    gfortran -std=f2008 -Wall -Wextra -fcheck=all "-O${optimization}" \
      "$repo_root/src/crop/mod_crop_previous_day_emergence_gate.f90" \
      "$repo_root/tests/fmig431/test_crop_previous_day_emergence_gate.f90" \
      -o "test_previous_day_emergence_O${optimization}"
    "./test_previous_day_emergence_O${optimization}"
  )
done
