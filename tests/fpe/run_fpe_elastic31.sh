#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic31-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"; rm -f elastic31-explicit.cfg elastic31-cli.cfg elastic31-env.cfg' EXIT

fail(){ echo "F_PE_ELASTIC31_FAIL $*" >&2; exit 1; }
LONG_VALUE="$(python3 - <<'PY'
print('x'*513)
PY
)"

python3 tests/rom/materialize_f_rom0_headcalc_stubs.py \
  --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
  --output "$BUILD/stub.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 tests/rom/compile_f_rom0_fortran_closure.py \
    --root "$ROOT" --stub "$BUILD/stub.f90" \
    --target tests/fpe/test_fpe_elastic31_request_discovery.f90 \
    --external-source src/legacy/b1_10_port/headcalc.f90 \
    --build "$OUT" --opt "$opt"

  : > "$OUT/output.txt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" none >> "$OUT/output.txt" 2>&1 || fail "none O$opt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" explicit >> "$OUT/output.txt" 2>&1 || fail "explicit O$opt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" cli --elastic-storage-config=elastic31-cli.cfg >> "$OUT/output.txt" 2>&1 || fail "cli O$opt"
  env SWAP5_ELASTIC_STORAGE_CONFIG=elastic31-env.cfg "$OUT/rom0_test" env >> "$OUT/output.txt" 2>&1 || fail "env O$opt"

  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" pair_explicit --elastic-storage-config=cli.cfg >> "$OUT/output.txt" 2>&1 || fail "explicit+cli O$opt"
  env SWAP5_ELASTIC_STORAGE_CONFIG=env.cfg "$OUT/rom0_test" pair_explicit >> "$OUT/output.txt" 2>&1 || fail "explicit+env O$opt"
  env SWAP5_ELASTIC_STORAGE_CONFIG=env.cfg "$OUT/rom0_test" pair_external --elastic-storage-config=cli.cfg >> "$OUT/output.txt" 2>&1 || fail "cli+env O$opt"
  env SWAP5_ELASTIC_STORAGE_CONFIG=env.cfg "$OUT/rom0_test" triple --elastic-storage-config=cli.cfg >> "$OUT/output.txt" 2>&1 || fail "triple O$opt"

  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" badcli --elastic-storage-config=a.cfg --elastic-storage-config=b.cfg >> "$OUT/output.txt" 2>&1 || fail "badcli O$opt"
  env SWAP5_ELASTIC_STORAGE_CONFIG="$LONG_VALUE" "$OUT/rom0_test" badenv >> "$OUT/output.txt" 2>&1 || fail "badenv O$opt"
  env -u SWAP5_ELASTIC_STORAGE_CONFIG "$OUT/rom0_test" reject >> "$OUT/output.txt" 2>&1 || fail "reject O$opt"

  for marker in \
    'F_PE_ELASTIC31_A1_NONE_INACTIVE=PASS' \
    'F_PE_ELASTIC31_A2_EXPLICIT_ONLY=PASS' \
    'F_PE_ELASTIC31_A3_CLI_ONLY=PASS' \
    'F_PE_ELASTIC31_A4_ENV_ONLY=PASS' \
    'F_PE_ELASTIC31_A5_PAIR_EXPLICIT_CONFLICT=PASS' \
    'F_PE_ELASTIC31_A5_PAIR_EXTERNAL_CONFLICT=PASS' \
    'F_PE_ELASTIC31_A6_TRIPLE_CONFLICT=PASS' \
    'F_PE_ELASTIC31_A7_CLI_PROVENANCE=PASS' \
    'F_PE_ELASTIC31_A8_ENV_PROVENANCE=PASS' \
    'F_PE_ELASTIC31_A9_LOADER_PROVENANCE=PASS'; do
    grep -Fq "$marker" "$OUT/output.txt" || {
      cat "$OUT/output.txt" >&2
      fail "missing O$opt marker $marker"
    }
  done
  cat "$OUT/output.txt"
done

cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || {
  diff -u "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" >&2 || true
  fail "O0/O2 drift"
}
echo "F_PE_ELASTIC31_A10_O0_O2=PASS"

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
allowed=["src/adapter/mod_fmr_elastic_storage_application_request_discovery.f90"]
if prod != allowed:
    raise SystemExit("F_PE_ELASTIC31_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC31_A10_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC31_RUN=PASS"
