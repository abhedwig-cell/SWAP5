#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-vzaa02-d0-$$"
OUTDIR="$ROOT/vzaa02-artifacts"
mkdir -p "$BUILD" "$OUTDIR"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASELINE_GATE="$ROOT/experiments/lmfp/run_lmfp04_ab_gate.sh"
PATCHER="$ROOT/experiments/vzaa/vzaa02_patch_trajectory.py"
ANALYZER="$ROOT/experiments/vzaa/vzaa02_analyze_trajectory.py"
DRIVER="$ROOT/experiments/lmfp/test_lmfp04_fullrichards_reference.f90"
INSTRUMENTED_DRIVER="$BUILD/test_vzaa02_fullrichards_trajectory.f90"
LINEAR_PATCHER="$ROOT/experiments/lmfp/lmfp04_patch_linear_stubs.py"
BASE_STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
STUBS="$BUILD/vzaa02_real_linear_stubs.f90"
TRAJECTORY="$OUTDIR/F-VZAA02_D0_TRAJECTORY.txt"
EVIDENCE="$OUTDIR/F-VZAA02_D0_LEDGER_EVIDENCE.json"

python3 -m py_compile "$PATCHER" "$ANALYZER"

# The existing qualified reference gate remains authoritative for FullRichards
# mass closure and A/B behavior.  D0 only adds diagnostic trajectory evidence.
bash "$BASELINE_GATE"

DRIVER_SHA_BEFORE="$(sha256sum "$DRIVER" | awk '{print $1}')"
python3 "$PATCHER" "$DRIVER" "$INSTRUMENTED_DRIVER"
DRIVER_SHA_AFTER="$(sha256sum "$DRIVER" | awk '{print $1}')"
if [[ "$DRIVER_SHA_BEFORE" != "$DRIVER_SHA_AFTER" ]]; then
  echo 'F-VZAA02 qualified LMFP04 driver changed during instrumentation' >&2
  exit 1
fi

python3 "$LINEAR_PATCHER" "$BASE_STUBS" "$STUBS"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -O2)
MOD="$BUILD/mod"
mkdir -p "$MOD"

compile() {
  local src="$1" obj="$2"
  gfortran "${COMMON[@]}" -J "$MOD" -I "$MOD" -c "$src" -o "$BUILD/$obj"
}

compile "$STUBS" stubs.o
compile "$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90" worker.o
compile "$ROOT/src/solver/mod_soil_water_solver_contract.f90" contract.o
compile "$ROOT/src/solver/mod_reference_richards_workspace.f90" workspace.o
compile "$ROOT/src/solver/mod_reference_richards_state_binding.f90" state.o
compile "$ROOT/tests/fsi/mod_fsi07_top_provider.f90" top.o
compile "$ROOT/tests/fsi/mod_fsi08_provider_fixture.f90" sources.o
compile "$ROOT/src/solver/mod_b110_default_mvg_provider.f90" hydraulics.o
compile "$ROOT/src/legacy/b1_10_port/headcalc.f90" headcalc.o
compile "$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90" adapter.o
compile "$INSTRUMENTED_DRIVER" driver.o

gfortran -O2 "$BUILD/driver.o" "$BUILD/adapter.o" "$BUILD/headcalc.o" "$BUILD/hydraulics.o" \
  "$BUILD/sources.o" "$BUILD/top.o" "$BUILD/state.o" "$BUILD/workspace.o" "$BUILD/contract.o" \
  "$BUILD/worker.o" "$BUILD/stubs.o" -o "$BUILD/fullrichards"

"$BUILD/fullrichards" | tee "$TRAJECTORY"
grep -Fq 'F-LMFP04_FULLRICHARDS_REFERENCE_PASS' "$TRAJECTORY"
grep -Fq 'VZAA02_STEP' "$TRAJECTORY"
grep -Fq 'VZAA02_NODE' "$TRAJECTORY"

python3 "$ANALYZER" "$TRAJECTORY" "$EVIDENCE" | tee "$OUTDIR/F-VZAA02_D0_LEDGER_EVIDENCE.stdout.txt"
grep -Fq 'F-VZAA02_TRAJECTORY_LEDGER_PASS' "$OUTDIR/F-VZAA02_D0_LEDGER_EVIDENCE.stdout.txt"

printf 'F-VZAA02_D0_GATE_PASS driver_sha256=%s\n' "$DRIVER_SHA_AFTER"
