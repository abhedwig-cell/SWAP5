#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI08="5b522c8f2767989161dae7faf382d5ee1b27c47c"
BUILD="${TMPDIR:-/tmp}/swap5-fsi09-b110-provider-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
PROVIDER="$ROOT/src/solver/mod_b110_default_mvg_provider.f90"
FINGERPRINT_DRIVER="$ROOT/tests/fsi/test_fsi09_b110_provider_fingerprint.f90"
ORACLE_DRIVER="$ROOT/tests/fsi/test_fsi09_b110_oracle_fingerprint.f90"
ORACLE_STUBS="$ROOT/tests/fsi/fsi09_b110_oracle_stubs.f90"
REFERENCE_PAYLOAD="$ROOT/reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64"
REFERENCE_VERIFY="$ROOT/tools/fsi/fsi09_verify_b110_reference_payload.py"
EVIDENCE="$ROOT/tests/fsi/F-SI09_B110_ACTUAL_SOURCE_EVIDENCE.json"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
ADAPTER="$ROOT/src/adapter/mod_reference_richards_legacy_binding.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
TOP_PROVIDER="$ROOT/tests/fsi/mod_fsi07_top_provider.f90"
PROCESS_FIXTURE="$ROOT/tests/fsi/mod_fsi08_provider_fixture.f90"
PARALLEL_DRIVER="$ROOT/tests/fsi/test_fsi09_b110_common_parallel.F90"
OWNER="$ROOT/integration/f-si/F-SI09_PROVIDER_ISOLATION_CONTRACT.json"
EXPECTED_SOURCE_SHA="4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"
EXPECTED_FP="1b61a61589c42c64d820b38c2071886dc7fde22595528159643080230f0fe8c1"

# F-SI09 adds only the concrete provider and qualification/reference harness. The qualified
# F-SI08 HeadCalc/adapter seam and F-KT/common state/workspace boundaries remain pinned.
for path in \
  src/legacy/b1_10_port/headcalc.f90 \
  src/adapter/mod_reference_richards_legacy_binding.f90 \
  src/runtime/mod_a23bu_worker_execution_context.f90 \
  src/transaction/mod_transaction_reference.f90 \
  src/solver/mod_soil_water_solver_contract.f90 \
  src/solver/mod_reference_richards_workspace.f90 \
  src/solver/mod_reference_richards_state_binding.f90; do
  [[ "$(git rev-parse "$FSI08:$path")" == "$(git rev-parse "HEAD:$path")" ]] || {
    echo "F-SI09_PROTECTED_SOURCE FAIL changed $path" >&2; exit 1; }
done

python3 "$REFERENCE_VERIFY"
ORACLE="$BUILD/MOD_MvG_functions.B1.10.f90"
python3 - "$REFERENCE_PAYLOAD" "$ORACLE" "$EXPECTED_SOURCE_SHA" <<'PY'
import base64,gzip,hashlib,pathlib,sys
raw=gzip.decompress(base64.b64decode(''.join(pathlib.Path(sys.argv[1]).read_text().split()),validate=True))
sha=hashlib.sha256(raw).hexdigest()
if sha != sys.argv[3]: raise SystemExit(f'F-SI09 corrected source SHA mismatch: {sha}')
pathlib.Path(sys.argv[2]).write_bytes(raw)
PY

python3 - "$OWNER" "$EVIDENCE" "$PROVIDER" <<'PY'
import json, pathlib, sys
owner=json.loads(pathlib.Path(sys.argv[1]).read_text())
ev=json.loads(pathlib.Path(sys.argv[2]).read_text())
p=pathlib.Path(sys.argv[3]).read_text().lower()
assert owner['basis']['corrected_mod_mvg_sha256']=='4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1'
assert owner['admitted_profile']['swkimpl']==0
assert owner['admission_flags_before_qualification']['production_b1_10_constitutive_provider_admitted'] is False
assert owner['admission_flags_before_qualification']['parallel_reference_backend_admitted'] is False
assert ev['result']=='PASS' and ev['o0']['byte_identical'] and ev['o2']['byte_identical'] and ev['o0_o2_identity']
assert ev['source_provenance']['corrected_b110_mod_mvg_sha256']==owner['basis']['corrected_mod_mvg_sha256']
assert ev['o0']['oracle_sha256']==ev['o0']['provider_sha256']==ev['o2']['oracle_sha256']==ev['o2']['provider_sha256']
for token in ['type, public :: b110_default_mvg_parameters_t','type, extends(constitutive_hydraulics_provider_t), public :: b110_default_mvg_provider_t',
              'procedure :: evaluate => b110_default_mvg_evaluate','dconductivity_dhead = 0.0_real64']:
    assert token in p, token
for forbidden in ['use mod_mvg','use variables','use mod_grid','save ::']:
    assert forbidden not in p, forbidden
print('F-SI09_STATIC_PROVIDER_CONTRACT PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
for opt in 0 2; do
  pdir="$BUILD/provider-fingerprint-o$opt"; odir="$BUILD/oracle-fingerprint-o$opt"
  mkdir -p "$pdir" "$odir"

  gfortran "${COMMON[@]}" -O"$opt" -J "$pdir" -I "$pdir" -c "$CONTRACT" -o "$pdir/contract.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$pdir" -I "$pdir" -c "$PROVIDER" -o "$pdir/provider.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$pdir" -I "$pdir" -c "$FINGERPRINT_DRIVER" -o "$pdir/driver.o"
  gfortran -O"$opt" "$pdir/driver.o" "$pdir/provider.o" "$pdir/contract.o" -o "$pdir/test"
  "$pdir/test" > "$pdir/fingerprint.txt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$odir" -I "$odir" -c "$ORACLE_STUBS" -o "$odir/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$odir" -I "$odir" -c "$ORACLE" -o "$odir/oracle.o"
  gfortran "${COMMON[@]}" -Werror -O"$opt" -J "$odir" -I "$odir" -c "$ORACLE_DRIVER" -o "$odir/driver.o"
  gfortran -O"$opt" "$odir/driver.o" "$odir/oracle.o" "$odir/stubs.o" -o "$odir/test"
  "$odir/test" > "$odir/fingerprint.txt"

  cmp "$odir/fingerprint.txt" "$pdir/fingerprint.txt"
  observed="$(sha256sum "$pdir/fingerprint.txt" | awk '{print $1}')"
  [[ "$observed" == "$EXPECTED_FP" ]] || {
    echo "F-SI09_B110_ORACLE_PROVIDER_FINGERPRINT_O${opt} FAIL expected=$EXPECTED_FP observed=$observed" >&2; exit 1; }
  echo "F-SI09_B110_ORACLE_PROVIDER_BITWISE_O${opt} PASS"
done
cmp "$BUILD/provider-fingerprint-o0/fingerprint.txt" "$BUILD/provider-fingerprint-o2/fingerprint.txt"
cmp "$BUILD/oracle-fingerprint-o0/fingerprint.txt" "$BUILD/oracle-fingerprint-o2/fingerprint.txt"
echo 'F-SI09_B110_ORACLE_PROVIDER_O0_O2_IDENTITY PASS'

OMP_COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_common_route() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${OMP_COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${OMP_COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${OMP_COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${OMP_COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${OMP_COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STATE" -o "$out/state.o"
  gfortran "${OMP_COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$TOP_PROVIDER" -o "$out/top.o"
  gfortran "${OMP_COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$PROCESS_FIXTURE" -o "$out/process.o"
  gfortran "${OMP_COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$PROVIDER" -o "$out/provider.o"
  gfortran "${OMP_COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$HEADCALC" -o "$out/headcalc.o"
  gfortran "${OMP_COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$ADAPTER" -o "$out/adapter.o"
  gfortran "${OMP_COMMON[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c "$PARALLEL_DRIVER" -o "$out/driver.o"
  gfortran "${OMP_COMMON[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/provider.o" \
    "$out/process.o" "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/test"
}

for opt in 0 2; do
  out="$BUILD/common-o$opt"
  compile_common_route "$opt" "$out"
  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$out/test" > "$out/t${threads}.txt"
    grep -Fq "F-SI09_B110_COMMON_ROUTE_${threads}_PASS" "$out/t${threads}.txt"
  done
  echo "F-SI09_B110_COMMON_ROUTE_O${opt}_1_2_4_8 PASS"
done
for threads in 1 2 4 8; do
  cmp "$BUILD/common-o0/t${threads}.txt" "$BUILD/common-o2/t${threads}.txt"
done
echo 'F-SI09_B110_COMMON_ROUTE_O0_O2_IDENTITY PASS'

bash "$ROOT/tests/fsi/run_fsi08_provider_context_gate.sh" >/dev/null
echo 'F-SI09_FSI08_REGRESSION PASS'

echo 'F-SI09_SWKIMPL1 NOT_ADMITTED'
echo 'F-SI09_OTHER_HYDRAULIC_MODEL_FAMILIES NOT_ADMITTED'
echo 'F-SI09_PRODUCTION_B110_DEFAULT_MVG_PROVIDER QUALIFIED_CANDIDATE'
echo 'F-SI09_PRODUCTION_SOURCE_SINK_PROVIDER NOT_ADMITTED'
echo 'F-SI09_PARALLEL_REFERENCE_BACKEND NOT_ADMITTED'
echo 'F-SI09_GATE PASS'
