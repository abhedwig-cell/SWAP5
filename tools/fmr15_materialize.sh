#!/usr/bin/env bash
set -euo pipefail

BASE="652783f7cb87ed876a17452e7a6d98b54b4b50c8"
INCOMING="194f66d413fdfc3b75fc12125412539ea2fc7d2d"

EXPECTED_KERNEL="af42c7d51ef545e20c76d3000f1ed1493690d68e"
EXPECTED_MULTI="7a60f8b8d18672098fed1c6890a95aac738ed21d"
EXPECTED_HEADCALC="55893f1f5ccba2052ad681743aa155b69f351246"
EXPECTED_WORKSPACE="59ef9d037c1875610d45ac83387ebab9e917e0fe"

paths=(
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/legacy/b1_10_port/headcalc.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_soil_water_solver_contract.f90
)

[[ "$(git rev-parse "$BASE:src/kernel/mod_kernel_transactions.f90")" == "$EXPECTED_KERNEL" ]]
[[ "$(git rev-parse "$BASE:src/runtime/mod_fmr_serialized_multiswap_runtime.f90")" == "$EXPECTED_MULTI" ]]
[[ "$(git hash-object src/kernel/mod_kernel_transactions.f90)" == "$EXPECTED_KERNEL" ]]
[[ "$(git hash-object src/runtime/mod_fmr_serialized_multiswap_runtime.f90)" == "$EXPECTED_MULTI" ]]
echo "FMR15_MATERIALIZE_FMR14_OBSERVER_LOCK=PASS"

if [[ "$(git hash-object src/adapter/mod_b110_serialized_context_binding.f90)" == "e21c964eac48d5feb91388cfd06a646c4002a497" \
   && "$(git hash-object src/adapter/mod_reference_richards_legacy_binding.f90)" == "db432cac3f1156a179c636435a25f52cdececffc" \
   && "$(git hash-object src/legacy/b1_10_port/headcalc.f90)" == "$EXPECTED_HEADCALC" \
   && "$(git hash-object src/runtime/mod_fmr_serialized_reference_backend.f90)" == "6f39d60a87c1987ae95d7faec2f55f865af90a08" \
   && "$(git hash-object src/solver/mod_reference_richards_workspace.f90)" == "$EXPECTED_WORKSPACE" \
   && "$(git hash-object src/solver/mod_soil_water_solver_contract.f90)" == "4271372085d800fd5da969a2ed073b00422d79c6" ]]; then
  echo "FMR15_MATERIALIZE_ALREADY_EXACT=PASS"
  exit 0
fi

# Exact non-overlap F-MR11 postimages.
git show "$INCOMING:src/adapter/mod_b110_serialized_context_binding.f90" > src/adapter/mod_b110_serialized_context_binding.f90
git show "$INCOMING:src/adapter/mod_reference_richards_legacy_binding.f90" > src/adapter/mod_reference_richards_legacy_binding.f90
git show "$INCOMING:src/runtime/mod_fmr_serialized_reference_backend.f90" > src/runtime/mod_fmr_serialized_reference_backend.f90
git show "$INCOMING:src/solver/mod_soil_water_solver_contract.f90" > src/solver/mod_soil_water_solver_contract.f90

# Exact F-MR11 overlap postimages, followed by only the independently qualified
# F-MR13 reference-linear-solver semantic delta.
git show "$INCOMING:src/legacy/b1_10_port/headcalc.f90" > src/legacy/b1_10_port/headcalc.f90
git show "$INCOMING:src/solver/mod_reference_richards_workspace.f90" > src/solver/mod_reference_richards_workspace.f90

python3 - src/legacy/b1_10_port/headcalc.f90 src/solver/mod_reference_richards_workspace.f90 <<'PY'
from pathlib import Path
import sys

headcalc = Path(sys.argv[1])
workspace = Path(sys.argv[2])

def replace_once(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"FMR15_MATERIALIZE_FAIL {label} count={n}")
    return text.replace(old, new, 1)

h = headcalc.read_text()
h = replace_once(h,
    "   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n",
    "   use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace\n"
    "   use mod_reference_linear_solver, only: reference_tridag, reference_band_solve\n",
    "headcalc_linear_solver_use")
h = replace_once(h,
    "   use MOD_arrays,         only: macp, mabbc\n",
    "   use MOD_arrays,         only: mabbc\n",
    "headcalc_remove_macp_import")
h = replace_once(h,
    "      call tridag(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, fsi_ws%residual, fsi_ws%delta_head, ierror)\n",
    "      call reference_tridag(NN, fsi_ws%dfdh_upper, fsi_ws%dfdh_main, fsi_ws%dfdh_lower, &\n"
    "           fsi_ws%residual, fsi_ws%delta_head, fsi_ws%tridag_gamma, ierror)\n",
    "headcalc_reference_tridag")
h = replace_once(h, "   real(8)                    :: d\n", "", "headcalc_remove_band_d")
h = replace_once(h,
    "   call bandec(fsi_ws%band_matrix, NN, 1, 1, macp, 3, fsi_ws%band_aux, 1, fsi_ws%band_pivots, d)\n",
    "", "headcalc_remove_bandec")
h = replace_once(h,
    "   call banbks(fsi_ws%band_matrix,nn,1,1,macp,3,fsi_ws%band_aux,1,fsi_ws%band_pivots,fsi_ws%band_rhs)\n",
    "   call reference_band_solve(fsi_ws%band_matrix, fsi_ws%band_aux, fsi_ws%band_pivots(1:NN), &\n"
    "        fsi_ws%band_rhs(1:NN))\n",
    "headcalc_reference_band_solve")
headcalc.write_text(h)

w = workspace.read_text()
w = replace_once(w,
    "     real(real64), allocatable :: delta_head(:)\n",
    "     real(real64), allocatable :: delta_head(:)\n     real(real64), allocatable :: tridag_gamma(:)\n",
    "workspace_gamma_member")
w = replace_once(w,
    "       allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes))\n",
    "       allocate(workspace%residual(active_nodes), workspace%delta_head(active_nodes), workspace%tridag_gamma(active_nodes))\n",
    "workspace_gamma_allocate")
w = replace_once(w,
    "    workspace%delta_head = 0.0_real64\n",
    "    workspace%delta_head = 0.0_real64\n    workspace%tridag_gamma = 0.0_real64\n",
    "workspace_gamma_reset")
w = replace_once(w,
    "    workspace%delta_head = qnan\n",
    "    workspace%delta_head = qnan\n    workspace%tridag_gamma = qnan\n",
    "workspace_gamma_poison")
w = replace_once(w,
    "    if (allocated(workspace%delta_head)) deallocate(workspace%delta_head)\n",
    "    if (allocated(workspace%delta_head)) deallocate(workspace%delta_head)\n    if (allocated(workspace%tridag_gamma)) deallocate(workspace%tridag_gamma)\n",
    "workspace_gamma_release")
w = replace_once(w,
    "    if (allocated(workspace%delta_head)) nreal = nreal + size(workspace%delta_head, kind=int64)\n",
    "    if (allocated(workspace%delta_head)) nreal = nreal + size(workspace%delta_head, kind=int64)\n"
    "    if (allocated(workspace%tridag_gamma)) nreal = nreal + size(workspace%tridag_gamma, kind=int64)\n",
    "workspace_gamma_payload")
workspace.write_text(w)
PY

# Exact postimage locks derived by the read-only probe.
[[ "$(git hash-object src/adapter/mod_b110_serialized_context_binding.f90)" == "e21c964eac48d5feb91388cfd06a646c4002a497" ]]
[[ "$(git hash-object src/adapter/mod_reference_richards_legacy_binding.f90)" == "db432cac3f1156a179c636435a25f52cdececffc" ]]
[[ "$(git hash-object src/legacy/b1_10_port/headcalc.f90)" == "$EXPECTED_HEADCALC" ]]
[[ "$(git hash-object src/runtime/mod_fmr_serialized_reference_backend.f90)" == "6f39d60a87c1987ae95d7faec2f55f865af90a08" ]]
[[ "$(git hash-object src/solver/mod_reference_richards_workspace.f90)" == "$EXPECTED_WORKSPACE" ]]
[[ "$(git hash-object src/solver/mod_soil_water_solver_contract.f90)" == "4271372085d800fd5da969a2ed073b00422d79c6" ]]
echo "FMR15_MATERIALIZE_EXACT_POSTIMAGES=PASS"

# No source path outside the six declared composition paths may change.
mapfile -t changed < <(git diff --name-only -- src | sort)
mapfile -t expected < <(printf '%s\n' "${paths[@]}" | sort)
[[ "$(printf '%s\n' "${changed[@]}")" == "$(printf '%s\n' "${expected[@]}")" ]]
echo "FMR15_MATERIALIZE_SOURCE_PATH_SET=PASS"

# Historical trailing whitespace in the exact F-MR11 postimage is preserved on
# purpose. Only the newly overlaid F-MR13 semantic delta must be whitespace-clean.
git diff --check "$INCOMING" -- \
  src/legacy/b1_10_port/headcalc.f90 \
  src/solver/mod_reference_richards_workspace.f90
echo "FMR15_MATERIALIZE_NEW_OVERLAP_DELTA_DIFF_CHECK=PASS"
