#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-temporal11-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT"     -c tests/fpe/test_fpe_temporal11_direct_retention_certificate.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" | tee "$OUT/out.txt"
  grep -Fq 'FPE_TEMPORAL11_DIRECT_RETENTION_CERTIFICATE=PASS' "$OUT/out.txt"
done

cmp -s "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
echo 'FPE_TEMPORAL11_DIRECT_RETENTION_O0_O2_IDENTITY=PASS'

# Independent default-MvG certificate oracle and mode-5 preservation authority.
# The historical FSI38 runner predates the direct-retention module import now
# present in the production indicator. Build a temporary complete-module copy
# rather than mutating that historical authority.
python3 - "$BUILD/fsi38-temporal11.sh" "$ROOT" <<'PY'
from pathlib import Path
import sys
out=Path(sys.argv[1]); root=Path(sys.argv[2]).resolve()
s=Path("tests/fsi/run_fsi38_prescribed_qbot_temporal_certificate_gate.sh").read_text()
old_root='ROOT="$(cd "$(dirname "$0")/../.." && pwd)"'
if old_root not in s:
    raise SystemExit("TEMPORAL11 FSI38 root anchor missing")
s=s.replace(old_root,f'ROOT="{root}"',1)
anchor="  src/solver/mod_b110_default_mvg_provider.f90\n"
insert=anchor+"  src/solver/mod_b110_default_mvg_directional_provider.f90\n  src/solver/mod_b110_direct_retention_core.f90\n  src/solver/mod_b110_direct_retention_provider.f90\n"
if anchor not in s:
    raise SystemExit("TEMPORAL11 FSI38 constitutive module anchor missing")
s=s.replace(anchor,insert,1)
anchor="  src/runtime/mod_a23bu_worker_execution_context.f90\n"
insert="  src/solver/mod_soil_water_accepted_step_direction_contract.f90\n  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90\n"+anchor
if anchor not in s:
    raise SystemExit("TEMPORAL11 FSI38 trajectory module anchor missing")
s=s.replace(anchor,insert,1)
out.write_text(s)
PY
chmod +x "$BUILD/fsi38-temporal11.sh"
bash "$BUILD/fsi38-temporal11.sh"

echo 'FPE_TEMPORAL11_ADMISSION=PASS'
