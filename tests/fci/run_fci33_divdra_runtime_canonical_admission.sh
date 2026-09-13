#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
MODE="${FCI33_MODE:-admission}"

python3 tools/fci/fci33_divdra_runtime_canonical_gate.py --mode "$MODE"

BUILD="$ROOT/tests/fci/.fci33-build-${GITHUB_RUN_ID:-$$}-${GITHUB_RUN_ATTEMPT:-0}"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"

compile_and_run() {
  local opt="$1"
  local dir="$2"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/solver/mod_soil_water_solver_contract.f90 -o "$dir/contract.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/solver/mod_process_hydraulic_view.f90 -o "$dir/view.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/process/mod_drainage_spatial_distribution.f90 -o "$dir/divdra.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/runtime/mod_fmr_divdra_runtime_binding.f90 -o "$dir/binding.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" -c src/solver/mod_b110_source_sink_provider.f90 -o "$dir/source_sink.o"
  gfortran -std=f2008 -Wall -Wextra "$opt" -J"$dir" -I"$dir" tests/fci/fci33_divdra_runtime_admission_smoke.f90 \
    "$dir/contract.o" "$dir/view.o" "$dir/divdra.o" "$dir/binding.o" "$dir/source_sink.o" -o "$dir/smoke"
  "$dir/smoke" > "$dir/output.txt"
  grep -Fx 'FCI33_DIVDRA_RUNTIME_ADMISSION_SMOKE=PASS' "$dir/output.txt"
}

compile_and_run -O0 "$BUILD/o0"
compile_and_run -O2 "$BUILD/o2"
diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cp "$BUILD/o0/output.txt" F-CI33_O0.txt
cp "$BUILD/o2/output.txt" F-CI33_O2.txt
O0_HASH="$(sha256sum F-CI33_O0.txt | awk '{print $1}')"
O2_HASH="$(sha256sum F-CI33_O2.txt | awk '{print $1}')"
test "$O0_HASH" = "$O2_HASH"
HEAD_SHA="$(git rev-parse HEAD)"
cat > F-CI33_SUMMARY.json <<EOF
{
  "schema": "swap5.fci33_gate_summary.v1",
  "mode": "$MODE",
  "head": "$HEAD_SHA",
  "candidate_blob": "e4737fb6f00a11ed16e34bee44b3442ac84b31aa",
  "O0_output_sha256": "$O0_HASH",
  "O2_output_sha256": "$O2_HASH",
  "smoke": "PASS",
  "architecture_invariants": 30,
  "reference_delta": 0
}
EOF

printf 'FCI33_O0_SHA256=%s\n' "$O0_HASH"
printf 'FCI33_O2_SHA256=%s\n' "$O2_HASH"
echo 'FCI33_O0_O2_OUTPUT_IDENTICAL=PASS'
echo 'FCI33_DIVDRA_RUNTIME_CANONICAL_ADMISSION=PASS'
