#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic58-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC58_FAIL $*" >&2; exit 1; }

python3 tests/fpe/prepare_fpe_elastic55.py select --artifact-dir "$ARTIFACT_DIR" --output "$BUILD/selected.json" > "$BUILD/select.txt"
python3 - "$BUILD/selected.json" <<'PY' > "$BUILD/profile_ids.txt"
import json,sys
ids=[int(v["profile_id"]) for v in json.load(open(sys.argv[1],encoding="utf-8"))]
if ids != [11060,10260,8016,3030]:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL selection={ids}")
for pid in ids: print(pid)
PY
echo "F_PE_ELASTIC58_A1_SELECTION=PASS"

python3 tests/fpe/materialize_fpe_elastic53_mode7_indicator.py   --root "$ROOT"   --indicator-out "$BUILD/mod_fpe_elastic53_reference_richards_temporal_indicator.f90"   --oracle-out "$BUILD/unused_oracle.f90" > "$BUILD/indicator.txt"

: > "$BUILD/all.txt"
while read -r pid; do
  P="$BUILD/p$pid"; mkdir -p "$P/work"
  python3 tests/fpe/prepare_fpe_elastic55.py profile     --repo-root "$ROOT" --artifact-dir "$ARTIFACT_DIR" --work-dir "$P/work"     --profile-id "$pid" --fixture "$P/test.f90" --geometry-json "$P/geometry.json" > "$P/prepare.txt"

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
rows=[x for x in lines if x.startswith("ELASTIC58_BUDGET|")]
parents=[x for x in lines if x.startswith("ELASTIC58_PARENT|")]
if len(rows)!=8: raise SystemExit(f"F_PE_ELASTIC58_FAIL budget rows={len(rows)}")
if len(parents)!=4: raise SystemExit(f"F_PE_ELASTIC58_FAIL parent rows={len(parents)}")
eligible=violating=0
for line in parents:
    d={p.split("=",1)[0]:p.split("=",1)[1] for p in line.split("|")[1:]}
    eligible+=int(d["eligible"]); violating+=int(d["violating"])
if eligible!=170 or violating!=15:
    raise SystemExit(f"F_PE_ELASTIC58_FAIL parent replay {eligible=} {violating=}")

agg={}
for line in rows:
    d={p.split("=",1)[0]:p.split("=",1)[1] for p in line.split("|")[1:]}
    label=d["label"]
    a=agg.setdefault(label,dict(sequences=0,accepts=0,exhausted=0,paired=0,paired_safe=0,nonmono_total=0,nonmono_accept=0,nonmono_exhaust=0))
    for k in a: a[k]+=int(d[k])
for label,a in agg.items():
    if a["paired"]!=a["paired_safe"]:
        raise SystemExit(f"F_PE_ELASTIC58_FAIL paired safety {label}")
    frac=a["accepts"]/a["sequences"]
    cls="SAFE_AND_PRACTICAL_IN_BANK" if frac>=0.75 else "SAFE_BUT_OVERCONSERVATIVE_IN_BANK"
    print(f"ELASTIC58_TOTAL|label={label}|sequences={a['sequences']}|accepts={a['accepts']}|exhausted={a['exhausted']}|accept_fraction={frac:.17e}|paired={a['paired']}|paired_safe={a['paired_safe']}|nonmono_total={a['nonmono_total']}|nonmono_accept={a['nonmono_accept']}|nonmono_exhaust={a['nonmono_exhaust']}|classification={cls}")
print("F_PE_ELASTIC58_A3_ALPHA_FROZEN=PASS")
print("F_PE_ELASTIC58_A4_EXTERNAL_VALUES_FROZEN=PASS")
print("F_PE_ELASTIC58_A5_CSAFE=PASS")
print("F_PE_ELASTIC58_A6_PAIRED_SAFETY=PASS")
print("F_PE_ELASTIC58_A7_PARENT_NONMONOTONE=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
prod=[p for p in subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines() if p.startswith("src/")]
if prod: raise SystemExit("F_PE_ELASTIC58_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC58_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC58_RUN=PASS"
