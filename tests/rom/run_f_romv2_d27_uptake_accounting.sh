#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=40f8e60531037b0ab279fdbc690c8e2fee6c1c40
PREREG=integration/f-rom/F-ROMV2_D27_PREREGISTRATION.json
PREREG_BLOB=65c27e8a54cd2a80278899752a74ebf4964c1cc4
D26=integration/f-rom/F-ROMV2_D26_ROOT_UPTAKE_AUTHORITY.json
SWAP_TEST=tests/rom/test_f_romv2_d27_swap_unstressed_uptake.f90
ANALYZER=tests/rom/analyze_f_romv2_d27_uptake_accounting.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
ROOT_SOURCE=src/process/mod_root_water_uptake_process.f90
ROOT_SOURCE_BLOB=e6134587cf3c0164bbe09f2f4c87aef6886aaeb3

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d27-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D27_EVIDENCE_DIR:-$ROOT/F-ROMV2-D27-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D27_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D27 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "candidate not descendant of D27 base"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D27 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D27 preregistration blob drift"
[[ "$(git rev-parse HEAD:$ROOT_SOURCE)" == "$ROOT_SOURCE_BLOB" ]] || fail "F-CI31 root process source drift"

python3 - "$PREREG" "$D26" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); d26=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert d26["decision"]=="UNSTRESSED_TOTAL_UPTAKE_ACCOUNTING_PREFLIGHT_AUTHORIZED_NATIVE_FMC_TRAJECTORY_ET_HELD_PENDING_STATE_UPDATE_ORACLE"
assert p["synthetic_state"]["selected_bin_index"]==170
assert p["forcing"]["potential_transpiration_cm_per_day"]==0.4
assert p["SWAP_route"]["rooted_nodes"]==3
assert p["FMC_route"]["rightmost_active_bin"]==170
assert "NO_NATIVE_FMC_COMPOSITE_STATE_UPDATE_CLAIM" in p["firewalls"]
print("F_ROMV2_D27_PREREGISTRATION_LOCK=PASS")
PY

stub="$BUILD/stubs_n16.f90"
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16 --dz-cm 10

for opt in 0 2; do
  outdir="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$SWAP_TEST" \
    --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
  "$outdir/rom0_test" > "$EVIDENCE/SWAP_o$opt.txt" 2>&1 || {
    tail -n 400 "$EVIDENCE/SWAP_o$opt.txt" >&2
    fail "SWAP uptake O$opt execution"
  }
  grep -Fxq 'F_ROMV2_D27_SWAP_UPTAKE=PASS' "$EVIDENCE/SWAP_o$opt.txt" || fail "missing O$opt SWAP pass marker"
done

cmp "$EVIDENCE/SWAP_o0.txt" "$EVIDENCE/SWAP_o2.txt" || fail "SWAP O0/O2 uptake output drift"
echo "F_ROMV2_D27_SWAP_O0_O2_IDENTITY=PASS"

python3 "$ANALYZER" --prereg "$PREREG" --swap "$EVIDENCE/SWAP_o2.txt" \
  --output "$EVIDENCE/F-ROMV2_D27_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

grep -Fq '"decision": "D27_UNSTRESSED_TOTAL_UPTAKE_ACCOUNTING_PREFLIGHT_PASS"' "$EVIDENCE/F-ROMV2_D27_RESULT.json" \
  || fail "D27 accounting preflight no-go"

sha256sum "$EVIDENCE"/* > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D27_UNSTRESSED_UPTAKE_ACCOUNTING=PASS"
