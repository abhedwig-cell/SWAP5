#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
src="$root/tests/nut-sol/candidates"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for opt in 0 2; do
  (
    cd "$tmp"
    gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all "-O$opt" \
      "$src/mod_b111_surface_receipt_gate.f90" \
      "$src/mod_b111_surface_loss_budget.f90" \
      "$src/mod_b111_surface_joint_candidate.f90" \
      "$src/test_joint_surface_candidate.f90" -o "joint_O$opt"
    "./joint_O$opt"
  )
done
