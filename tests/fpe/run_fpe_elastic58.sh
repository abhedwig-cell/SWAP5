#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic58-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC58_FAIL $*" >&2; exit 1; }

# Part A: transaction core contract.
for opt in 0 2; do
  OUT="$BUILD/tx_o$opt"; mkdir -p "$OUT"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow     -O"$opt" -J "$OUT" -I "$OUT" -c src/transaction/mod_transaction_reference.f90 -o "$OUT/tx.o"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow     -O"$opt" -J "$OUT" -I "$OUT" -c tests/fpe/test_fpe_elastic58_transaction.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/tx.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/result.txt"
done
cmp -s "$BUILD/tx_o0/result.txt" "$BUILD/tx_o2/result.txt" || {
  diff -u "$BUILD/tx_o0/result.txt" "$BUILD/tx_o2/result.txt" >&2 || true
  fail "transaction O0/O2 drift"
}
cat "$BUILD/tx_o2/result.txt"
grep -Fq 'F_PE_ELASTIC58_TRANSACTION=PASS' "$BUILD/tx_o2/result.txt" || fail "transaction gate"
echo "F_PE_ELASTIC58_A1_TRANSACTION=PASS"

# Shared research mode-7 indicator.
python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

# Exact ELASTIC55 profile selection.
python3 tests/fpe/prepare_fpe_elastic55.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" > "$BUILD/select.txt"
python3 - "$BUILD/selected.json" <<'PY'
import json,sys
ids=[int(x["profile_id"]) for x in json.load(open(sys.argv[1],encoding="utf-8"))]
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL ids={ids}")
print("F_PE_ELASTIC58_B2_PROFILES=PASS")
PY

: > "$BUILD/all.txt"
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

while read -r pid; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work" --profile-id "$pid"     --fixture "$P/test.f90" --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  python3 tests/fpe/materialize_fpe_elastic58_work_fixture.py --fixture "$P/test.f90" > "$P/workfix.txt"
  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json" --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT" --stub "$P/stub.f90" --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
  done

  python3 tests/fpe/run_fpe_elastic58_profile.py     --profile-id "$pid" --o0 "$P/o0/rom0_test" --o2 "$P/o2/rom0_test" | tee "$P/result.txt"
  cat "$P/result.txt" >> "$BUILD/all.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all.txt" <<'PY'
import sys
lines=open(sys.argv[1],encoding="utf-8").read().splitlines()
rows=[x for x in lines if x.startswith("ELASTIC58_PROFILE_BUDGET|")]
if len(rows)!=16: raise SystemExit(f"F_PE_ELASTIC58_FAIL budget rows={len(rows)}")
agg={}
for line in rows:
    d={}
    for p in line.split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    b=d["budget"]
    A=agg.setdefault(b,{k:0 for k in (
        "cert_accept","cert_exhaust","identity_accept","identity_exhaust","cert_accept_ident_exhaust","both_exhaust",
        "paired_accept","unpaired_accept","cert_nonlinear","identity_nonlinear","cert_linear","identity_linear",
        "cert_tridiag","cert_jacobian","identity_jacobian","cert_backtracking","identity_backtracking")})
    for k in A: A[k]+=int(d[k])
for b,A in sorted(agg.items(),key=lambda kv:float(kv[0])):
    nr=A["cert_nonlinear"]/A["identity_nonlinear"] if A["identity_nonlinear"] else 0.0
    lr=A["cert_linear"]/A["identity_linear"] if A["identity_linear"] else 0.0
    hr=A["cert_jacobian"]/A["identity_jacobian"] if A["identity_jacobian"] else 0.0
    br=A["cert_backtracking"]/A["identity_backtracking"] if A["identity_backtracking"] else 0.0
    print(f"ELASTIC58_TOTAL_BUDGET|budget={b}|cert_accept={A['cert_accept']}|cert_exhaust={A['cert_exhaust']}|identity_accept={A['identity_accept']}|identity_exhaust={A['identity_exhaust']}|cert_accept_ident_exhaust={A['cert_accept_ident_exhaust']}|both_exhaust={A['both_exhaust']}|paired_accept={A['paired_accept']}|unpaired_accept={A['unpaired_accept']}|cert_nonlinear={A['cert_nonlinear']}|identity_nonlinear={A['identity_nonlinear']}|nonlinear_ratio={nr:.17e}|cert_linear={A['cert_linear']}|identity_linear={A['identity_linear']}|linear_ratio={lr:.17e}|cert_tridiag={A['cert_tridiag']}|cert_jacobian={A['cert_jacobian']}|identity_jacobian={A['identity_jacobian']}|jacobian_ratio={hr:.17e}|cert_backtracking={A['cert_backtracking']}|identity_backtracking={A['identity_backtracking']}|backtracking_ratio={br:.17e}")
print("F_PE_ELASTIC58_B5_AGGREGATE=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC58_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC58_A7_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC58_RUN=PASS"
