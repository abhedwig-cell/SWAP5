#!/usr/bin/env bash
set -euo pipefail

BASE="652783f7cb87ed876a17452e7a6d98b54b4b50c8"
ANCESTOR="6e4ddecb585833f42c3e27fb121345a40b5fa880"
INCOMING="194f66d413fdfc3b75fc12125412539ea2fc7d2d"
FMR13_MATERIALIZATION="e4ae5cb11f6e10d471e5cebfd33ab35e98047b64"

EXPECTED_KERNEL="af42c7d51ef545e20c76d3000f1ed1493690d68e"
EXPECTED_MULTI="7a60f8b8d18672098fed1c6890a95aac738ed21d"
EXPECTED_LINEAR_SOLVER="b292d284e5549049eac1c80df4cc30008154eb96"

nonoverlap=(
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/solver/mod_soil_water_solver_contract.f90
)

[[ "$(git rev-parse "$BASE^{commit}")" == "$BASE" ]]
[[ "$(git rev-parse "$ANCESTOR^{commit}")" == "$ANCESTOR" ]]
[[ "$(git rev-parse "$INCOMING^{commit}")" == "$INCOMING" ]]
[[ "$(git rev-parse "$FMR13_MATERIALIZATION^{commit}")" == "$FMR13_MATERIALIZATION" ]]

[[ "$(git rev-parse "$BASE:src/kernel/mod_kernel_transactions.f90")" == "$EXPECTED_KERNEL" ]]
[[ "$(git rev-parse "$BASE:src/runtime/mod_fmr_serialized_multiswap_runtime.f90")" == "$EXPECTED_MULTI" ]]
[[ "$(git rev-parse "$BASE:src/solver/mod_reference_linear_solver.f90")" == "$EXPECTED_LINEAR_SOLVER" ]]
echo "FMR15_PROBE_FMR14_OBSERVER_BASE_LOCK=PASS"
echo "FMR15_PROBE_FMR13_LINEAR_SOLVER_BLOB_LOCK=PASS"

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

# ---------------------------------------------------------------------------
# Overlap resolution is deliberately not an ours/theirs merge. F-MR11 changed
# HeadCalc/workspace broadly for explicit geometry/config/mode-5 semantics,
# while F-MR13 later added a small independently qualified linear-solver seam.
# Start from the exact F-MR11 postimage and apply only the exact semantic
# F-MR13 transformations, with one-occurrence assertions for every edit.
# ---------------------------------------------------------------------------
mkdir -p "$work/src/legacy/b1_10_port" "$work/src/solver"
git show "$INCOMING:src/legacy/b1_10_port/headcalc.f90" > "$work/src/legacy/b1_10_port/headcalc.f90"
git show "$INCOMING:src/solver/mod_reference_richards_workspace.f90" > "$work/src/solver/mod_reference_richards_workspace.f90"

python3 - "$work/src/legacy/b1_10_port/headcalc.f90" "$work/src/solver/mod_reference_richards_workspace.f90" <<'PY'
from pathlib import Path
import sys

headcalc = Path(sys.argv[1])
workspace = Path(sys.argv[2])


def replace_once(text: str, old: str, new: str, label: str) -> str:
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"FMR15_SEMANTIC_COMPOSE_FAIL {label} count={n}")
    return text.replace(old, new, 1)

h = headcalc.read_text()
h = replace_once(
    h,
    "   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n",
    "   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n"
    "   use mod_reference_linear_solver, only: reference_tridag, reference_band_solve\n",
    "headcalc_linear_solver_use",
)
h = replace_once(
    h,
    "   use MOD_arrays,         only: macp, mabbc\n",
    "   use MOD_arrays,         only: mabbc\n",
    "headcalc_remove_macp_import",
)
h = replace_once(
    h,
    "      call tridag(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, fsi_ws%residual, fsi_ws%delta_head, ierror)\n",
    "      call reference_tridag(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, &\n"
    "           fsi_ws%residual, fsi_ws%delta_head, fsi_ws%tridag_gamma, ierror)\n",
    "headcalc_reference_tridag",
)
h = replace_once(
    h,
    "   real(8)                    :: d\n",
    "",
    "headcalc_remove_band_d",
)
h = replace_once(
    h,
    "   call bandec(fsi_ws%band_matrix, NN, 1, 1, macp, 3, fsi_ws%band_aux, 1, fsi_ws%band_pivots, d)\n",
    "",
    "headcalc_remove_bandec",
)
h = replace_once(
    h,
    "   call banbks(fsi_ws%band_matrix,nn,1,1,macp,3,fsi_ws%band_aux,1,fsi_ws%band_pivots,fsi_ws%band_rhs)\n",
    "   call reference_band_solve(fsi_ws%band_matrix, fsi_ws%band_aux, fsi_ws%band_pivots(1:NN), &\n"
    "        fsi_ws%band_rhs(1:NN))\n",
    "headcalc_reference_band_solve",
)
headcalc.write_text(h)

w = workspace.read_text()
w = replace_once(
    w,
    "     real(real64), allocatable :: delta_head(:)\n",
    "     real(real64), allocatable :: delta_head(:)\n"
    "     real(real64), allocatable :: tridag_gamma(:)\n",
    "workspace_gamma_member",
)
w = replace_once(
    w,
    "       allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes))\n",
    "       allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes), workspace%tridag_gamma(active_nodes))\n",
    "workspace_gamma_allocate",
)
w = replace_once(
    w,
    "    workspace%delta_head = 0.0_real64\n",
    "    workspace%delta_head = 0.0_real64\n"
    "    workspace%tridag_gamma = 0.0_real64\n",
    "workspace_gamma_reset",
)
w = replace_once(
    w,
    "    workspace%delta_head = qnan\n",
    "    workspace%delta_head = qnan\n"
    "    workspace%tridag_gamma = qnan\n",
    "workspace_gamma_poison",
)
w = replace_once(
    w,
    "    if (allocated(workspace%delta_head)) deallocate(workspace%delta_head)\n",
    "    if (allocated(workspace%delta_head)) deallocate(workspace%delta_head)\n"
    "    if (allocated(workspace%tridag_gamma)) deallocate(workspace%tridag_gamma)\n",
    "workspace_gamma_release",
)
w = replace_once(
    w,
    "    if (allocated(workspace%delta_head)) nreal = nreal + size(workspace%delta_head, kind=int64)\n",
    "    if (allocated(workspace%delta_head)) nreal = nreal + size(workspace%delta_head, kind=int64)\n"
    "    if (allocated(workspace%tridag_gamma)) nreal = nreal + size(workspace%tridag_gamma, kind=int64)\n",
    "workspace_gamma_payload",
)
workspace.write_text(w)
PY

echo "FMR15_PROBE_SEMANTIC_OVERLAP_COMPOSITION=PASS"
echo "FMR15_PROBE_COMPOSED_HEADCALC_BLOB=$(git hash-object "$work/src/legacy/b1_10_port/headcalc.f90")"
echo "FMR15_PROBE_COMPOSED_WORKSPACE_BLOB=$(git hash-object "$work/src/solver/mod_reference_richards_workspace.f90")"

# Both parent capabilities must be visibly present in the composed sources.
grep -q 'use mod_reference_linear_solver, only: reference_tridag, reference_band_solve' \
  "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'call reference_tridag' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'call reference_band_solve' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'tridag_gamma' "$work/src/solver/mod_reference_richards_workspace.f90"
echo "FMR15_PROBE_FMR13_LINEAR_SOLVER_SEAM_PRESERVED=PASS"

grep -q 'explicit_step_duration' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'parameter_set' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'grid_disnod' "$work/src/legacy/b1_10_port/headcalc.f90"
grep -q 'provider_root_sink' "$work/src/solver/mod_reference_richards_workspace.f90"
echo "FMR15_PROBE_FMR11_PRESCRIBED_HEAD_SEAM_PRESERVED=PASS"

# Prove that the semantic resolution really is F-MR11 plus only the F-MR13
# linear-solver concepts, not an accidental import of unrelated branch state.
[[ "$(grep -c 'use mod_reference_linear_solver, only: reference_tridag, reference_band_solve' "$work/src/legacy/b1_10_port/headcalc.f90")" == 1 ]]
[[ "$(grep -c 'call reference_tridag' "$work/src/legacy/b1_10_port/headcalc.f90")" == 1 ]]
[[ "$(grep -c 'call reference_band_solve' "$work/src/legacy/b1_10_port/headcalc.f90")" == 1 ]]
[[ "$(grep -c 'real(real64), allocatable :: tridag_gamma(:)' "$work/src/solver/mod_reference_richards_workspace.f90")" == 1 ]]
echo "FMR15_PROBE_OVERLAP_CARDINALITY=PASS"

# Observer-only F-MR14 paths are outside the incoming production delta.
for path in src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_serialized_multiswap_runtime.f90; do
  if printf '%s\n' "${nonoverlap[@]}" \
      src/legacy/b1_10_port/headcalc.f90 \
      src/solver/mod_reference_richards_workspace.f90 | grep -Fxq "$path"; then
    echo "FMR15_PROBE_FAIL observer path included in incoming delta: $path"
    exit 22
  fi
done
echo "FMR15_PROBE_OBSERVER_PATH_SEPARATION=PASS"

echo "FMR15_THREE_WAY_COMPOSITION_PROBE PASS"
