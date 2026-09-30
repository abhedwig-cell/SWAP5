#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ART="$1"
BUILD="${RUNNER_TEMP:-/tmp}/elastic66-${GITHUB_RUN_ID:-local}"
mkdir -p "$BUILD"
python3 tests/fpe/prepare_fpe_elastic55.py select --artifact-dir "$ART" --output "$BUILD/selected.json"
python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py --root "$ROOT" --indicator-out "$BUILD/indicator.f90" --oracle-out "$BUILD/unused.f90"
: > "$BUILD/all.txt"
for pid in 11060 10260 8016 3030; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic60.py --repo-root "$ROOT" --artifact-dir "$ART" --work-dir "$P/work" --profile-id "$pid" --fixture "$P/test.f90" --geometry-json "$P/geometry.json"
  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py --source tests/fsi/fsi04_real_headcalc_stubs.f90 --geometry-json "$P/geometry.json" --output "$P/stub.f90"
  for opt in 0 2; do
    python3 tests/rom/compile_f_rom0_fortran_closure.py --root "$ROOT" --stub "$P/stub.f90" --target "$P/test.f90" --external-source "$BUILD/indicator.f90" --external-source src/legacy/b1_10_port/headcalc.f90 --build "$P/o$opt" --opt "$opt"
  done
  python3 tests/fpe/run_fpe_elastic66_profile.py --profile-id "$pid" --o0 "$P/o0/rom0_test" --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done
python3 tests/fpe/summarize_fpe_elastic66.py "$BUILD/all.txt"
echo F_PE_ELASTIC66_RUN=PASS
