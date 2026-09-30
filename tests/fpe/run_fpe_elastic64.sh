#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic63-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC64_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select   --artifact-dir "$ARTIFACT_DIR"   --output "$BUILD/selected.json" > "$BUILD/select.txt"
grep -Fq 'F_PE_ELASTIC55_SELECT=PASS' "$BUILD/select.txt" || fail "selection"

python3 - "$BUILD/selected.json" <<'PY'
import json,sys
ids=[int(v["profile_id"]) for v in json.load(open(sys.argv[1],encoding="utf-8"))]
if ids!=[11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC64_FAIL selection ids={ids}")
print("F_PE_ELASTIC64_A1_SELECTION=PASS")
PY

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"
grep -Fq 'F_PE_ELASTIC53_MATERIALIZE=PASS' "$BUILD/indicator.txt" || fail "indicator materialize"

: > "$BUILD/all_diag.txt"
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
for x in json.load(open(sys.argv[1],encoding="utf-8")):
    print(int(x["profile_id"]))
PY

while read -r pid; do
  P="$BUILD/p$pid"
  mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic63.py     --repo-root "$ROOT"     --artifact-dir "$ARTIFACT_DIR"     --work-dir "$P/work"     --profile-id "$pid"     --fixture "$P/test.f90"     --geometry-json "$P/geometry.json" > "$P/prepare.txt"
  grep -Fq 'F_PE_ELASTIC64_PREP=PASS' "$P/prepare.txt" || fail "profile prepare $pid"

  python3 tests/fpe/materialize_fpe_elastic46_headcalc_stubs.py     --source tests/fsi/fsi04_real_headcalc_stubs.f90     --geometry-json "$P/geometry.json"     --output "$P/stub.f90"

  for opt in 0 2; do
    OUT="$P/o$opt"
    python3 tests/rom/compile_f_rom0_fortran_closure.py       --root "$ROOT"       --stub "$P/stub.f90"       --target "$P/test.f90"       --external-source "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"       --external-source src/legacy/b1_10_port/headcalc.f90       --build "$OUT" --opt "$opt"
    : > "$OUT/result.txt"
    for h0 in -75 -20 2 10; do
      for delta in -0.05 -0.035 0.035 0.05; do
        for regime in OFF FIXED_1E6 GENERATED; do
          dt=0.015625
          for retry in 0 1 2 3 4 5 6 7 8; do
            "$OUT/rom0_test" "$regime" "$h0" "$delta" "$dt" >> "$OUT/result.txt"
            dt="$(python3 -c "print(float('$dt')*0.5)")"
          done
        done
      done
    done
    test "$(grep -c '^ELASTIC64_SOLVE|' "$OUT/result.txt")" -eq 864 || fail "O$opt solve count profile $pid"
    test "$(grep -c '^F_PE_ELASTIC64_EXEC=PASS' "$OUT/result.txt")" -eq 432 || fail "O$opt case count profile $pid"
  done

  cmp -s "$P/o0/result.txt" "$P/o2/result.txt" || {
    diff -u "$P/o0/result.txt" "$P/o2/result.txt" >&2 || true
    fail "O0/O2 drift profile $pid"
  }
  grep '^ELASTIC64_SOLVE|' "$P/o2/result.txt" >> "$BUILD/all_diag.txt"
done < "$BUILD/profile_ids.txt"

python3 - "$BUILD/all_diag.txt" <<'PY'
import math,sys,collections
rows=[]
for line in open(sys.argv[1],encoding="utf-8"):
    d={}
    for p in line.strip().split("|")[1:]:
        if "=" not in p: continue
        k,v=p.split("=",1); d[k]=v.strip()
    rows.append(d)
if len(rows)!=3456:
    raise SystemExit(f"F_PE_ELASTIC64_FAIL diagnostic rows={len(rows)}")

counts=collections.Counter()
strict_pass=total_only_recovered=local_above_pass=other_retry_balance_pass=0
parent=[]
for r in rows:
    vals=[float(r[k]) for k in ("max_local_residual","abs_total_residual","floor_sum","baltol_rate")]
    if not all(math.isfinite(x) and x>=0 for x in vals):
        raise SystemExit("F_PE_ELASTIC64_FAIL nonfinite diagnostic")
    status=int(r["status"])
    local=float(r["max_local_residual"]); total=float(r["abs_total_residual"])
    floor_sum=float(r["floor_sum"])
    teff=max(1.0e-12,floor_sum)
    local_ok=local<=1.0e-12
    total_ok=total<=teff*(1+1e-12)
    candidate=local_ok and total_ok
    if status==1:
        cls="STRICT_SUCCESS"
        strict_pass+=int(candidate)
    elif status==2:
        if local>1.0e-12:
            cls="LOCAL_ABOVE_STRICT"
            local_above_pass+=int(candidate)
        elif total>1.0e-12:
            cls="TOTAL_ONLY_STRICT"
            total_only_recovered+=int(candidate)
        else:
            cls="OTHER_RETRY"
            other_retry_balance_pass+=int(candidate)
    else:
        cls="OTHER_STATUS"
    counts[cls]+=1

    if int(r["profile"])==8016 and r["stage"]=="HALF1" and float(r["h0"])==-20.0 and        float(r["dt"])==0.00048828125 and float(r["delta"]) in (0.035,0.05) and        r["regime"] in ("OFF","FIXED_1E6","GENERATED"):
        parent.append((cls,candidate,local,total,teff))

if len(parent)!=6:
    raise SystemExit(f"F_PE_ELASTIC64_FAIL parent count={len(parent)}")
if not all(c for _,c,_,_,_ in parent):
    raise SystemExit("F_PE_ELASTIC64_FAIL parent candidate not pass")

if strict_pass!=counts["STRICT_SUCCESS"]:
    raise SystemExit(f"F_PE_ELASTIC64_FAIL strict preservation {strict_pass}/{counts['STRICT_SUCCESS']}")
if total_only_recovered!=counts["TOTAL_ONLY_STRICT"]:
    raise SystemExit(f"F_PE_ELASTIC64_FAIL total-only recovery {total_only_recovered}/{counts['TOTAL_ONLY_STRICT']}")
if local_above_pass!=0:
    raise SystemExit(f"F_PE_ELASTIC64_FAIL local-above pass={local_above_pass}")

print("ELASTIC64_CLASS_COUNTS|"+("|".join(f"{k}={v}" for k,v in sorted(counts.items()))))
print(f"ELASTIC64_HYBRID|strict_pass={strict_pass}|total_only_recovered={total_only_recovered}|local_above_pass={local_above_pass}|other_retry_balance_pass={other_retry_balance_pass}")
print("F_PE_ELASTIC64_A2_O0_O2=PASS")
print("F_PE_ELASTIC64_A3_STRICT_SUCCESS=PASS")
print("F_PE_ELASTIC64_A4_TOTAL_ONLY=PASS")
print("F_PE_ELASTIC64_A5_LOCAL_GATE=PASS")
print("F_PE_ELASTIC64_A6_OTHER_RETRY_OWNERSHIP=PASS")
print("F_PE_ELASTIC64_A7_ELASTIC62_REPLAY=PASS")
PY
python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC64_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC64_A6_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC64_RUN=PASS"
