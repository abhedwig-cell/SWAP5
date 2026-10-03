#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-top03-joint-nearsat-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
HEAD_SOURCE="$BUILD/top03_research_headcalc.f90"
PROVIDER_SOURCE="$BUILD/top03_joint_provider.f90"
TEST_SOURCE="$BUILD/top03_joint_test.f90"
DELTA_H_CM="${1:-0.02}"
MODE="${2:-research}"
STAGE_PROFILE="${3:-rise}"
if [[ "$MODE" != research && "$MODE" != production && "$MODE" != baseline ]]; then
  echo "mode must be research, production, or baseline" >&2
  exit 2
fi
if [[ "$STAGE_PROFILE" != rise && "$STAGE_PROFILE" != recession && "$STAGE_PROFILE" != surface-cv && "$STAGE_PROFILE" != surface-cv-small ]]; then
  echo "stage profile must be rise, recession, surface-cv, or surface-cv-small" >&2
  exit 2
fi
if [[ "$STAGE_PROFILE" == surface-cv* && "$MODE" != production ]]; then
  echo "surface-cv profile requires production mode" >&2
  exit 2
fi
CV_STAGE_SCALE=1
if [[ "$STAGE_PROFILE" == surface-cv ]]; then CV_STAGE_SCALE=100; fi
python3 tests/fapp/make_top03_terminal_trace_probe.py "$HEAD_SOURCE" --strict-descent
python3 tests/fapp/make_top03_joint_nearsaturation.py "$PROVIDER_SOURCE" "$TEST_SOURCE" "$DELTA_H_CM" "$MODE"
if [[ "$MODE" == production ]]; then
  python3 - "$TEST_SOURCE" "$DELTA_H_CM" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); text=p.read_text()
old="call initialize_b110_default_mvg_parameters(hp,cofgen)"
new=("call initialize_b110_default_mvg_parameters(hp,cofgen, &\n"
     "      near_saturation_transition_width_cm="+f"{float(sys.argv[2]):.16e}_real64)")
if text.count(old)!=1: raise SystemExit("expected unique initializer in generated test driver")
p.write_text(text.replace(old,new))
PY
  if [[ "$STAGE_PROFILE" == recession || "$STAGE_PROFILE" == surface-cv || "$STAGE_PROFILE" == surface-cv-small ]]; then
    python3 - "$TEST_SOURCE" "$STAGE_PROFILE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); text=p.read_text()
old="do history=3,3"
new="do history=4,4"
if sys.argv[2].startswith("surface-cv"): new="do history=5,5"
if text.count(old)!=1: raise SystemExit("expected unique rise-only driver selection")
p.write_text(text.replace(old,new))
PY
  fi
  HEAD_SOURCE=src/legacy/b1_10_port/headcalc.f90
  PROVIDER_SOURCE=src/solver/mod_b110_default_mvg_provider.f90
elif [[ "$MODE" == baseline ]]; then
  HEAD_SOURCE=src/legacy/b1_10_port/headcalc.f90
  PROVIDER_SOURCE=src/solver/mod_b110_default_mvg_provider.f90
fi
STUB=tests/fapp/top03_consistent_shallow_stubs.f90
TOP=tests/fmr/mod_fmr04_fixed_top_provider.f90

python3 - "$BUILD/compile-order.txt" "$STUB" "$TOP" "$HEAD_SOURCE" "$PROVIDER_SOURCE" "$TEST_SOURCE" <<'PY'
from pathlib import Path
import re,sys
order_file=Path(sys.argv[1]); stub,top,headcalc,provider,test=map(Path,sys.argv[2:])
candidates=[stub,top,Path("tests/fapp/mod_top03_observed_top.f90"),provider]+sorted(
    p for p in Path("src").rglob("*.f90")
    if "src/legacy/" not in p.as_posix() and p.name!="mod_b110_default_mvg_provider.f90")+[headcalc,test]
mr=re.compile(r"^\s*module\s+(?!procedure\b|subroutine\b|function\b)([a-zA-Z_]\w*)",re.I)
ur=re.compile(r"^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?([a-zA-Z_]\w*)",re.I)
mods={};uses={}
for p in candidates:
    ls=p.read_text(errors="replace").splitlines()
    mods[p]=[m.group(1).lower() for line in ls if (m:=mr.match(line))]
    uses[p]=[m.group(1).lower() for line in ls if (m:=ur.match(line))]
providers={}
for p in (stub,top):
    for m in mods[p]:providers[m]=p
for p in candidates:
    if p in (stub,top,headcalc,test):continue
    for m in mods[p]:providers.setdefault(m,p)
required=set();missing=set()
def add(p):
    if p in required:return
    required.add(p)
    for m in uses[p]:
        q=providers.get(m)
        if q is not None and q!=p:add(q)
        elif q is None and (m.startswith("mod_") or m=="variables"):missing.add((p.as_posix(),m))
add(test);add(headcalc)
if missing:raise SystemExit("unresolved modules: "+repr(sorted(missing)))
deps={p:{providers[m] for m in uses[p] if m in providers and providers[m] in required and providers[m]!=p} for p in required}
done=set();temp=set();ordered=[]
def visit(p):
    if p in done:return
    if p in temp:raise RuntimeError("module cycle at "+str(p))
    temp.add(p)
    for q in sorted(deps[p],key=lambda x:x.as_posix()):visit(q)
    temp.remove(p);done.add(p);ordered.append(p)
for p in sorted(required,key=lambda x:x.as_posix()):visit(p)
order_file.write_text("\n".join(p.as_posix() for p in ordered)+"\n")
print("JOINT_TRANSITION_COMPILE_CLOSURE_FILES="+str(len(ordered)))
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt";mkdir -p "$OUT";objects=()
  while IFS= read -r source;do
    key="$(printf '%s' "$source"|tr '/.' '__')";obj="$OUT/$key.o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done < "$BUILD/compile-order.txt"
  gfortran -O"$opt" "${objects[@]}" -o "$OUT/test"
  "$OUT/test" 2 "$CV_STAGE_SCALE" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 91; }
  if [[ "$opt" == 2 ]]; then
    python3 - "$BUILD/o0/output.txt" "$OUT/output.txt" "$BUILD/o0/numeric.txt" "$OUT/numeric.txt" <<'PY'
from pathlib import Path
import sys
for src,dst in ((Path(sys.argv[1]),Path(sys.argv[3])),(Path(sys.argv[2]),Path(sys.argv[4]))):
    lines=[]
    for line in src.read_text().splitlines():
        fields=line.split(",")
        if fields and fields[0] in {"-2","2"} and len(fields)>16:
            del fields[16]  # wall-clock timing is intentionally excluded
            line=",".join(fields)
        lines.append(line)
    dst.write_text("\n".join(lines)+"\n")
PY
    cmp -s "$BUILD/o0/numeric.txt" "$OUT/numeric.txt" || {
      echo "O0/O2 numeric output mismatch" >&2
      diff -u "$BUILD/o0/numeric.txt" "$OUT/numeric.txt" >&2 || true
      exit 92
    }
    echo "TOP03_JOINT_TRANSITION_O0_O2_IDENTICAL=true"
  fi
  cat "$OUT/output.txt"
  echo "TOP03_JOINT_TRANSITION_O${opt}=COMPLETED"
done
