#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-low01-output01-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail(){ echo "GC_LOW01_OUTPUT01_RUNNER_FAIL $*" >&2; exit 1; }

bash tests/research/run_gc_low01_constitutive_bridge.sh | tee "$BUILD/constitutive.txt"
grep -Fq 'GC_LOW01_CONSTITUTIVE_BRIDGE_QUALIFICATION=PASS' "$BUILD/constitutive.txt" || fail 'constitutive bridge prerequisite'

python3 tests/research/test_gc_low01_state_machine.py | tee "$BUILD/state01.txt"
grep -Fq 'GC_LOW01_STATE01_GATE=PASS' "$BUILD/state01.txt" || fail 'LOW01-STATE01 prerequisite'

python3 - "$BUILD/low01_headcalc_stubs.f90" <<'PY'
from pathlib import Path
import re
import sys

source = Path("tests/fsi/fsi04_real_headcalc_stubs.f90").read_text(encoding="utf-8")
pattern = re.compile(r"(?ms)^module MOD_MvG\b.*?^end module MOD_MvG\s*")
rewritten, count = pattern.subn("", source, count=1)
if count != 1:
    raise SystemExit(f"OUTPUT01 expected exactly one MOD_MvG stub block, got {count}")
Path(sys.argv[1]).write_text(rewritten, encoding="utf-8")
print("GC_LOW01_OUTPUT01_TEST_STUB_REBIND=PASS")
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"

  compile(){
    local source="$1"
    local obj="$2"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  }

  compile src/solver/mod_soil_water_solver_contract.f90 "$OUT/contract.o"
  compile src/solver/mod_b110_default_mvg_provider.f90 "$OUT/mvg_provider.o"
  compile tests/research/support/mod_gc_low01_constitutive_bridge.f90 "$OUT/mvg_bridge.o"
  compile "$BUILD/low01_headcalc_stubs.f90" "$OUT/stubs.o"
  compile src/solver/mod_soil_water_accepted_step_direction_contract.f90 "$OUT/accepted_direction_contract.o"
  compile src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 "$OUT/accepted_trajectory.o"
  compile src/runtime/mod_a23bu_worker_execution_context.f90 "$OUT/worker.o"
  compile src/solver/mod_reference_richards_workspace.f90 "$OUT/workspace.o"
  compile src/solver/mod_reference_richards_state_binding.f90 "$OUT/state_binding.o"
  compile src/solver/mod_reference_linear_solver.f90 "$OUT/linear.o"
  compile src/solver/mod_b110_source_sink_provider.f90 "$OUT/source_sink.o"
  compile src/solver/mod_fixed_flux_top_boundary_provider.f90 "$OUT/top.o"
  compile src/legacy/b1_10_port/headcalc.f90 "$OUT/headcalc.o"
  compile tests/research/support/mod_gc_low01_mode1_trial_carrier.f90 "$OUT/carrier.o"
  compile tests/research/test_gc_low01_output01.f90 "$OUT/test.o"

  gfortran -O"$opt"     "$OUT/contract.o" "$OUT/mvg_provider.o" "$OUT/mvg_bridge.o" "$OUT/stubs.o"     "$OUT/accepted_direction_contract.o" "$OUT/accepted_trajectory.o" "$OUT/worker.o" "$OUT/workspace.o" "$OUT/state_binding.o" "$OUT/linear.o"     "$OUT/source_sink.o" "$OUT/top.o" "$OUT/headcalc.o" "$OUT/carrier.o" "$OUT/test.o"     -o "$OUT/low01-output01"

  "$OUT/low01-output01" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    fail "OUTPUT01 executable O$opt"
  }

  for marker in     'GC_LOW01_OUTPUT01_TYPED_FIELDS=PASS'     'GC_LOW01_OUTPUT01_IMMUTABLE_ORIGIN=PASS'     'GC_LOW01_OUTPUT01_A_B_A_REPLAY=PASS'     'GC_LOW01_OUTPUT01_SCOPE_REFUSAL=PASS'     'GC_LOW01_OUTPUT01_MASS_CLOSURE=PASS'     'GC_LOW01_OUTPUT01_GATE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing $marker O$opt"
    }
  done
  cat "$OUT/output.txt"
  echo "GC_LOW01_OUTPUT01_O${opt}=PASS"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail 'OUTPUT01 O0/O2 semantic drift'
}
echo 'GC_LOW01_OUTPUT01_O0_O2_IDENTITY=PASS'

git diff --check --   integration/research/GC_LOW01_OUTPUT01_PREREGISTRATION.json   integration/research/GC_LOW01_OUTPUT01_PREREGISTRATION_AMENDMENT.json   tests/research/support/mod_gc_low01_mode1_trial_carrier.f90   tests/research/test_gc_low01_output01.f90   tests/research/run_gc_low01_output01.sh

echo 'GC_LOW01_OUTPUT01_QUALIFICATION=PASS'
