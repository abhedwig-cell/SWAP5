#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
PATCH="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-base01-p1-src-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$PATCH"
trap 'rm -rf "$PATCH"' EXIT

cp src/legacy/b1_10_port/headcalc.f90 "$PATCH/headcalc.f90"
cp src/adapter/mod_reference_richards_legacy_binding.f90 "$PATCH/mod_reference_richards_legacy_binding.f90"
cp src/runtime/mod_fmr_groundwater_swap_participant.f90 "$PATCH/mod_fmr_groundwater_swap_participant.f90"
cp src/runtime/mod_fmr_groundwater_swap_participant.f90 "$PATCH/mod_fmr_groundwater_swap_participant.f90"
cp tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 "$PATCH/mod_fgc44_real_swap_c_bridge.f90"

python3 - "$PATCH/headcalc.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()

use_line="   use mod_base01_headcalc_timing, only: base01_tic, base01_toc, BASE01_CAT_CONSTITUTIVE, &"
use_more="        BASE01_CAT_VECTOR, BASE01_CAT_JACOBIAN, BASE01_CAT_LINEAR, BASE01_CAT_BACKTRACK"
insert_at=next(i for i,s in enumerate(lines) if "use MOD_swap_base" in s)
lines[insert_at:insert_at]=[use_line,use_more]

def wrap_multiline_call(lines, needle, cat):
    out=[]; i=0; wrapped=0
    while i<len(lines):
        s=lines[i]
        if needle in s:
            indent=s[:len(s)-len(s.lstrip())]
            out.append(f"{indent}call base01_tic({cat})")
            bal=0
            while i<len(lines):
                q=lines[i]
                out.append(q)
                bal += q.count("(")-q.count(")")
                i+=1
                if bal<=0:
                    break
            out.append(f"{indent}call base01_toc({cat})")
            wrapped+=1
        else:
            out.append(s); i+=1
    return out,wrapped

for needle,cat in [
    ("call evaluation_context%constitutive%","BASE01_CAT_CONSTITUTIVE"),
    ("call vector_F(","BASE01_CAT_VECTOR"),
    ("call jacobian_F()","BASE01_CAT_JACOBIAN"),
    ("call reference_tridag(","BASE01_CAT_LINEAR"),
]:
    lines,n=wrap_multiline_call(lines,needle,cat)
    if n==0: raise SystemExit(f"no seam for {needle}")

# Time the entire backtracking loop as a nested family.
start=next(i for i,s in enumerate(lines) if "do itry = 1, MaxBackTr" in s)
lines.insert(start,"      call base01_tic(BASE01_CAT_BACKTRACK)")
# Find the exact loop terminator immediately before label 1.
end=next(i for i in range(start+1,len(lines)-1) if lines[i].strip()=="end do" and lines[i+1].strip().startswith("1"))
lines.insert(end+1,"      call base01_toc(BASE01_CAT_BACKTRACK)")

p.write_text("\n".join(lines)+"\n")
PY

python3 - "$PATCH/mod_reference_richards_legacy_binding.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); lines=p.read_text().splitlines()
insert_at=next(i for i,s in enumerate(lines) if "use mod_soil_water_solver_contract" in s)
lines[insert_at:insert_at]=[
"   use mod_base01_headcalc_timing, only: base01_tic, base01_toc, BASE01_CAT_HEADCALC"
]

out=[]; i=0; wrapped=0
while i<len(lines):
    s=lines[i]
    if "call headcalc(" in s:
        indent=s[:len(s)-len(s.lstrip())]
        out.append(f"{indent}call base01_tic(BASE01_CAT_HEADCALC)")
        bal=0
        while i<len(lines):
            q=lines[i]; out.append(q)
            bal += q.count("(")-q.count(")")
            i+=1
            if bal<=0: break
        out.append(f"{indent}call base01_toc(BASE01_CAT_HEADCALC)")
        wrapped+=1
    else:
        out.append(s); i+=1
if wrapped!=1: raise SystemExit(f"expected one headcalc call, got {wrapped}")
p.write_text("\n".join(out)+"\n")
PY

python3 - "$PATCH/mod_fmr_groundwater_swap_participant.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
src=src.replace(
"  integer, parameter, public :: FMR_TANGENT_CACHE_INVALID_CONFIG = 1\n",
"  integer, parameter, public :: FMR_TANGENT_CACHE_INVALID_CONFIG = 1\n"
"  logical, save :: BASE01_DIRECTION_ENABLED = .true.\n",1)
src=src.replace(
"  public :: resolve_fmr_groundwater_temporal_budget\n",
"  public :: resolve_fmr_groundwater_temporal_budget\n"
"  public :: base01_set_direction_enabled\n",1)
src=src.replace(
"    trial_numerical = numerical\n",
"    if (.not. BASE01_DIRECTION_ENABLED) refresh_tangent = .false.\n"
"    trial_numerical = numerical\n",1)
needle="end module mod_fmr_groundwater_swap_participant"
insert="""  subroutine base01_set_direction_enabled(enabled)
    logical, intent(in) :: enabled
    BASE01_DIRECTION_ENABLED = enabled
  end subroutine base01_set_direction_enabled

"""
if needle not in src: raise SystemExit("BASE01 participant end seam missing")
src=src.replace(needle,insert+needle,1)
p.write_text(src)
PY

python3 - "$PATCH/mod_fgc44_real_swap_c_bridge.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
old="  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t\n"
new="  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t, base01_set_direction_enabled\n"
if old not in src: raise SystemExit("BASE01 bridge participant-use seam missing")
src=src.replace(old,new,1)
src=src.replace(
"  public :: fgc44_predictor_run_diagnostics_c\n",
"  public :: fgc44_predictor_run_diagnostics_c\n"
"  public :: fgc44_base01_direction_c\n",1)
needle="contains\n\n"
insert="""contains

  integer(c_int) function fgc44_base01_direction_c(enabled) bind(C,name="fgc44_base01_direction_c")
    integer(c_int), value, intent(in) :: enabled
    call base01_set_direction_enabled(enabled /= 0_c_int)
    fgc44_base01_direction_c=0_c_int
  end function fgc44_base01_direction_c

"""
if needle not in src: raise SystemExit("BASE01 bridge contains seam missing")
src=src.replace(needle,insert,1)
p.write_text(src)
PY

python3 - "$PATCH/mod_fmr_groundwater_swap_participant.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
needle="    trial_numerical = numerical\n"
if needle not in src:
    raise SystemExit("BASE01 P1 participant tangent seam missing")
src=src.replace(needle,"    refresh_tangent = .false.\n    trial_numerical = numerical\n",1)
p.write_text(src)
PY

BASE01_HEADCALC_SOURCE="$PATCH/headcalc.f90" \
BASE01_LEGACY_BINDING_SOURCE="$PATCH/mod_reference_richards_legacy_binding.f90" \
BASE01_EXTRA_SOURCE="tests/fpe/mod_base01_headcalc_timing.f90" \
BASE01_PARTICIPANT_SOURCE="$PATCH/mod_fmr_groundwater_swap_participant.f90" \
BASE01_TEST_SCRIPT="tests/fpe/test_fpe_base01_p1_backend.py" \
BASE01_RAW_PREFIX="BASE01_P1_RAW" \
BASE01_PARTICIPANT_SOURCE="$PATCH/mod_fmr_groundwater_swap_participant.f90" \
BASE01_BRIDGE_SOURCE="$PATCH/mod_fgc44_real_swap_c_bridge.f90" \
BASE01_RAW_PREFIX="BASE01_P1_RAW" \
BASE01_REPS=3 \
BASE01_SKIP_AGGREGATE=1 \
bash tests/fpe/run_fpe_base01_p0_participant_boundary.sh | tee "$PATCH/raw.txt"

python3 - "$PATCH/raw.txt" <<'PY'
import json,statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if line.startswith("BASE01_P1_RAW|"):
        rows.append(json.loads(line.split("|",1)[1]))
if len(rows)!=60:
    raise SystemExit(f"expected 60 replicate rows, got {len(rows)}")

# Reproduce the P0 aggregation convention: median of three process replicates per live group,
# then aggregate those medians over the 12 frozen groups.
groups={}
for r in rows:
    key=(r["material"],r["h0"],r["imbalance"])
    groups.setdefault(key,[]).append(r)
if len(groups)!=12:
    raise SystemExit(f"expected 12 groups, got {len(groups)}")

keys=["participant_backend_ns","p1_headcalc_ns","p1_constitutive_ns","p1_vector_ns",
      "p1_jacobian_ns","p1_linear_ns","p1_backtrack_ns"]
agg={k:0.0 for k in keys}
counts={k:0.0 for k in ("p1_headcalc_calls","p1_constitutive_calls","p1_vector_calls",
                         "p1_jacobian_calls","p1_linear_calls","p1_backtrack_calls")}
diagkeys=("transaction_calls","accepted_substeps","attempts","retries","solver_rejections",
          "temporal_rejections","nonlinear_iterations","backtracking_attempts")
diags={k:0 for k in diagkeys}

for key,rr in sorted(groups.items()):
    if len(rr)!=5: raise SystemExit(f"group replicate count {key}: {len(rr)}")
    med={k:statistics.median(float(x[k]) for x in rr) for k in keys}
    medc={k:statistics.median(float(x[k]) for x in rr) for k in counts}
    medd={k:int(statistics.median(int(x[k]) for x in rr)) for k in diagkeys}
    for k in keys: agg[k]+=med[k]
    for k in counts: counts[k]+=medc[k]
    for k in diagkeys: diags[k]+=medd[k]
    b=med["participant_backend_ns"]; h=med["p1_headcalc_ns"]
    if h<=0: raise SystemExit(f"nonpositive HeadCalc timing {key}")
    print(
      f"BASE01_P1_GROUP|MATERIAL={key[0]}|H0={key[1]}|IMBALANCE={key[2]}"
      f"|BACKEND_NS={b:.3f}|HEADCALC_NS={h:.3f}|HEADCALC_BACKEND_SHARE={h/b:.9f}"
      f"|CONSTITUTIVE_QSTATE_SHARE={med['p1_constitutive_ns']/h:.9f}"
      f"|VECTOR_QSTATE_SHARE={med['p1_vector_ns']/h:.9f}"
      f"|JACOBIAN_QSTATE_SHARE={med['p1_jacobian_ns']/h:.9f}"
      f"|LINEAR_QSTATE_SHARE={med['p1_linear_ns']/h:.9f}"
      f"|BACKTRACK_QSTATE_SHARE={med['p1_backtrack_ns']/h:.9f}"
    )

b=agg["participant_backend_ns"]; h=agg["p1_headcalc_ns"]
if h<=0: raise SystemExit("nonpositive aggregate HeadCalc timing")
print(
 f"BASE01_P1_AGG|BACKEND_NS={b:.3f}"
 f"|HEADCALC_NS={h:.3f}|HEADCALC_BACKEND_SHARE={h/b:.9f}"
 f"|CONSTITUTIVE_NS={agg['p1_constitutive_ns']:.3f}|CONSTITUTIVE_QSTATE_SHARE={agg['p1_constitutive_ns']/h:.9f}"
 f"|VECTOR_NS={agg['p1_vector_ns']:.3f}|VECTOR_QSTATE_SHARE={agg['p1_vector_ns']/h:.9f}"
 f"|JACOBIAN_NS={agg['p1_jacobian_ns']:.3f}|JACOBIAN_QSTATE_SHARE={agg['p1_jacobian_ns']/h:.9f}"
 f"|LINEAR_NS={agg['p1_linear_ns']:.3f}|LINEAR_QSTATE_SHARE={agg['p1_linear_ns']/h:.9f}"
 f"|BACKTRACK_NS={agg['p1_backtrack_ns']:.3f}|BACKTRACK_QSTATE_SHARE={agg['p1_backtrack_ns']/h:.9f}"
)
print("BASE01_P1_CALLS|"+ "|".join(f"{k.upper()}={v:.0f}" for k,v in counts.items()))
print("BASE01_P1_DIAG|"+ "|".join(f"{k.upper()}={v}" for k,v in diags.items()))

# Instrumentation must preserve the frozen LIVE01/P0 discrete population.
if diags["solver_rejections"]!=0:
    raise SystemExit("new solver rejection under instrumentation")
if diags["retries"]!=20 or diags["temporal_rejections"]!=20:
    raise SystemExit(f"retry trajectory changed: {diags}")
if diags["nonlinear_iterations"]!=236:
    raise SystemExit(f"nonlinear trajectory changed: {diags['nonlinear_iterations']}")
print("FPE_BASE01_P1=PASS")
PY
