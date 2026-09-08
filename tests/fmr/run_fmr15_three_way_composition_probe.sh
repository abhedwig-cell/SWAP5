#!/usr/bin/env bash
set -euo pipefail

BASE="652783f7cb87ed876a17452e7a6d98b54b4b50c8"
ANCESTOR="6e4ddecb585833f42c3e27fb121345a40b5fa880"
INCOMING="194f66d413fdfc3b75fc12125412539ea2fc7d2d"

EXPECTED_KERNEL="af42c7d51ef545e20c76d3000f1ed1493690d68e"
EXPECTED_MULTI="7a60f8b8d18672098fed1c6890a95aac738ed21d"

nonoverlap=(
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/solver/mod_soil_water_solver_contract.f90
)
overlap=(
  src/legacy/b1_10_port/headcalc.f90
  src/solver/mod_reference_richards_workspace.f90
)

[[ "$(git rev-parse HEAD^{commit})" != "$BASE" ]] || true
[[ "$(git rev-parse "$BASE^{commit}")" == "$BASE" ]]
[[ "$(git rev-parse "$ANCESTOR^{commit}")" == "$ANCESTOR" ]]
[[ "$(git rev-parse "$INCOMING^{commit}")" == "$INCOMING" ]]

[[ "$(git rev-parse "$BASE:src/kernel/mod_kernel_transactions.f90")" == "$EXPECTED_KERNEL" ]]
[[ "$(git rev-parse "$BASE:src/runtime/mod_fmr_serialized_multiswap_runtime.f90")" == "$EXPECTED_MULTI" ]]
echo "FMR15_PROBE_FMR14_OBSERVER_BASE_LOCK=PASS"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for path in "${nonoverlap[@]}"; do
  mkdir -p "$work/$(dirname "$path")"
  git show "$INCOMING:$path" > "$work/$path"
  got="$(git hash-object "$work/$path")"
  want="$(git rev-parse "$INCOMING:$path")"
  [[ "$got" == "$want" ]]
  echo "FMR15_PROBE_NONOVERLAP_EXACT_POSTIMAGE=PASS path=$path blob=$got"
done

for path in "${overlap[@]}"; do
  mkdir -p "$work/merge/$(dirname "$path")" "$work/$(dirname "$path")"
  current="$work/merge/current"
  ancestor="$work/merge/ancestor"
  other="$work/merge/other"
  git show "$BASE:$path" > "$current"
  git show "$ANCESTOR:$path" > "$ancestor"
  git show "$INCOMING:$path" > "$other"
  set +e
  git merge-file -p "$current" "$ancestor" "$other" > "$work/$path"
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "FMR15_PROBE_THREE_WAY_MERGE=CONFLICT path=$path rc=$rc"
    grep -n -C 8 -E '^(<<<<<<<|=======|>>>>>>>)' "$work/$path" || true
    exit 20
  fi
  if grep -q -E '^(<<<<<<<|=======|>>>>>>>)' "$work/$path"; then
    echo "FMR15_PROBE_THREE_WAY_MERGE=CONFLICT_MARKERS path=$path"
    exit 21
  fi
  echo "FMR15_PROBE_THREE_WAY_MERGE=CLEAN path=$path blob=$(git hash-object "$work/$path")"
done

# Ensure the F-MR13 linear-solver seam survives in the composed HeadCalc/workspace.
grep -q 'use mod_reference_linear_solver, only: reference_tridag, reference_band_solve' \
  "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'call reference_tridag' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'call reference_band_solve' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'tridag_gamma' "$work/src/solver/mod_reference_richards_workspace.f90"
echo "FMR15_PROBE_FMR13_LINEAR_SOLVER_SEAM_PRESERVED=PASS"

# Ensure the F-MR11 explicit prescribed-head seam survives in the composition.
grep -q 'explicit_step_duration' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'parameter_set' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'grid_disnod' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'provider_root_sink' "$work/src/solver/mod_reference_richards_workspace.f90"
echo "FMR15_PROBE_FMR11_PRESCRIBED_HEAD_SEAM_PRESERVED=PASS"

# The observer-only F-MR14 paths are not among the incoming production paths.
for path in src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_serialized_multiswap_runtime.f90; do
  if printf '%s\n' "${nonoverlap[@]}" "${overlap[@]}" | grep -Fxq "$path"; then
    echo "FMR15_PROBE_FAIL observer path included in incoming delta: $path"
    exit 22
  fi
done
echo "FMR15_PROBE_OBSERVER_PATH_SEPARATION=PASS"

echo "FMR15_THREE_WAY_COMPOSITION_PROBE PASS"
