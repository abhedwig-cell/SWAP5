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
cp src/transaction/mod_transaction_reference.f90 "$PATCH/mod_transaction_reference.f90"
cp src/runtime/mod_canonical_interval_runtime.f90 "$PATCH/mod_canonical_interval_runtime.f90"
cp src/kernel/mod_kernel_transactions.f90 "$PATCH/mod_kernel_transactions.f90"
cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$PATCH/mod_fmr_serialized_reference_backend.f90"

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
# Stop at label 1 so both the normal loop exit and the historical goto 1 path are timed.
end=next(i for i in range(start+1,len(lines)-1) if lines[i].strip()=="end do" and lines[i+1].strip().startswith("1"))
label=end+1
lines.insert(label+1,"      call base01_toc(BASE01_CAT_BACKTRACK)")

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

python3 - "$PATCH/mod_fmr_serialized_reference_backend.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
needle="  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n"
use=needle+"  use mod_base01_outer_timing, only: base01_outer_tic, base01_outer_toc, &\n" \
    "       BASE01_OUTER_KERNEL_CORE, BASE01_OUTER_TEMPORAL\n"
if needle not in src: raise SystemExit("P1B backend use seam missing")
src=src.replace(needle,use,1)

def wrap_call(src,needle,cat):
    lines=src.splitlines(); out=[]; i=0; n=0
    while i<len(lines):
        s=lines[i]
        if needle in s:
            ind=s[:len(s)-len(s.lstrip())]
            out.append(f"{ind}call base01_outer_tic({cat})")
            bal=0
            while i<len(lines):
                q=lines[i]; out.append(q)
                bal += q.count("(")-q.count(")")
                i+=1
                if bal<=0: break
            out.append(f"{ind}call base01_outer_toc({cat})"); n+=1
        else:
            out.append(s); i+=1
    if n==0: raise SystemExit(f"P1B backend call seam missing: {needle}")
    return "\n".join(out)+"\n"

src=wrap_call(src,"call fmr_trial_from_checkpoint(","BASE01_OUTER_KERNEL_CORE")
src=wrap_call(src,"call evaluate_temporal_history_service(","BASE01_OUTER_TEMPORAL")
p.write_text(src)
PY

python3 - "$PATCH/mod_kernel_transactions.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
needle="  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n"
use=needle+"  use mod_base01_outer_timing, only: base01_outer_tic, base01_outer_toc, &\n" \
    "       BASE01_OUTER_KERNEL_CLONE, BASE01_OUTER_CANONICAL_TOTAL, BASE01_OUTER_KERNEL_POST\n"
if needle not in src: raise SystemExit("P1B kernel use seam missing")
src=src.replace(needle,use,1)

for call in ("call checkpoint%physical_state%clone(working)","call committed_state%physical_state%clone(working)"):
    if call not in src: raise SystemExit(f"P1B kernel clone seam missing: {call}")
    src=src.replace(call,f"call base01_outer_tic(BASE01_OUTER_KERNEL_CLONE)\\n      {call}\\n      call base01_outer_toc(BASE01_OUTER_KERNEL_CLONE)",1)

lines=src.splitlines(); out=[]; i=0; n=0
while i<len(lines):
    s=lines[i]
    if "call run_canonical_interval(" in s:
        ind=s[:len(s)-len(s.lstrip())]; out.append(f"{ind}call base01_outer_tic(BASE01_OUTER_CANONICAL_TOTAL)")
        bal=0
        while i<len(lines):
            q=lines[i]; out.append(q); bal+=q.count("(")-q.count(")"); i+=1
            if bal<=0: break
        out.append(f"{ind}call base01_outer_toc(BASE01_OUTER_CANONICAL_TOTAL)"); n+=1
    else:
        out.append(s); i+=1
if n==0: raise SystemExit("P1B canonical call seam missing in kernel")
src="\n".join(out)+"\n"

start="    call map_runtime_result(runtime_result, result)\n"
if start not in src: raise SystemExit("P1B kernel post start seam missing")
src=src.replace(start,"    call base01_outer_tic(BASE01_OUTER_KERNEL_POST)\n"+start,1)
end="  end subroutine kernel_advance_interval\n"
if end not in src: raise SystemExit("P1B kernel post end seam missing")
src=src.replace(end,"    call base01_outer_toc(BASE01_OUTER_KERNEL_POST)\n"+end,1)
p.write_text(src)
PY

python3 - "$PATCH/mod_canonical_interval_runtime.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
needle="  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n"
use=needle+"  use mod_base01_outer_timing, only: base01_outer_tic, base01_outer_toc, &\n" \
    "       BASE01_OUTER_CANONICAL_PREP, BASE01_OUTER_TX_TOTAL\n"
if needle not in src: raise SystemExit("P1B canonical use seam missing")
src=src.replace(needle,use,1)
start="    call committed%clone(working)\n"
stop="    call model%prepare_interval(forcing, interval, config)\n"
if start not in src or stop not in src: raise SystemExit("P1B canonical prep seam missing")
src=src.replace(start,"    call base01_outer_tic(BASE01_OUTER_CANONICAL_PREP)\n"+start,1)
src=src.replace(stop,stop+"    call base01_outer_toc(BASE01_OUTER_CANONICAL_PREP)\n",1)
call="      call execute_reference_interval(model, working, cursor, transaction_t1, transaction_policy, tx)\n"
if call not in src: raise SystemExit("P1B transaction total seam missing")
src=src.replace(call,"      call base01_outer_tic(BASE01_OUTER_TX_TOTAL)\n"+call+
                "      call base01_outer_toc(BASE01_OUTER_TX_TOTAL)\n",1)
p.write_text(src)
PY

python3 - "$PATCH/mod_transaction_reference.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
needle="  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n"
use=needle+"  use mod_base01_outer_timing, only: base01_outer_tic, base01_outer_toc, &\n" \
    "       BASE01_OUTER_TX_CLONE, BASE01_OUTER_MODEL_ADVANCE, BASE01_OUTER_TX_CONTEXT\n"
if needle not in src: raise SystemExit("P1B transaction use seam missing")
src=src.replace(needle,use,1)

def wrap_single(src,needle,cat):
    lines=src.splitlines(); out=[]; n=0
    for s in lines:
        if needle in s:
            ind=s[:len(s)-len(s.lstrip())]
            out.append(f"{ind}call base01_outer_tic({cat})")
            out.append(s)
            out.append(f"{ind}call base01_outer_toc({cat})")
            n+=1
        else: out.append(s)
    if n==0: raise SystemExit(f"P1B transaction seam missing: {needle}")
    return "\n".join(out)+"\n"

# These cover both transaction modes; only model-certificate executes in BASE01.
src=wrap_single(src,"call committed%clone(checkpoint)","BASE01_OUTER_TX_CLONE")
src=wrap_single(src,"call checkpoint%clone(","BASE01_OUTER_TX_CLONE")
src=wrap_single(src,"call model%advance(","BASE01_OUTER_MODEL_ADVANCE")
src=wrap_single(src,"call model%capture_attempt_context(","BASE01_OUTER_TX_CONTEXT")
src=wrap_single(src,"call model%restore_attempt_context(","BASE01_OUTER_TX_CONTEXT")
p.write_text(src)
PY

BASE01_HEADCALC_SOURCE="$PATCH/headcalc.f90" \
BASE01_LEGACY_BINDING_SOURCE="$PATCH/mod_reference_richards_legacy_binding.f90" \
BASE01_PRE_SOURCE="tests/fpe/mod_base01_outer_timing.f90" \
BASE01_EXTRA_SOURCE="tests/fpe/mod_base01_headcalc_timing.f90" \
BASE01_TRANSACTION_SOURCE="$PATCH/mod_transaction_reference.f90" \
BASE01_CANONICAL_RUNTIME_SOURCE="$PATCH/mod_canonical_interval_runtime.f90" \
BASE01_KERNEL_SOURCE="$PATCH/mod_kernel_transactions.f90" \
BASE01_BACKEND_SOURCE="$PATCH/mod_fmr_serialized_reference_backend.f90" \
BASE01_PARTICIPANT_SOURCE="$PATCH/mod_fmr_groundwater_swap_participant.f90" \
BASE01_BRIDGE_SOURCE="$PATCH/mod_fgc44_real_swap_c_bridge.f90" \
BASE01_TEST_SCRIPT="tests/fpe/test_fpe_base01_p1b_outer.py" \
BASE01_RAW_PREFIX="BASE01_P1B_RAW" \
BASE01_REPS=5 \
BASE01_SKIP_AGGREGATE=1 \
bash tests/fpe/run_fpe_base01_p0_participant_boundary.sh | tee "$PATCH/raw.txt"

python3 - "$PATCH/raw.txt" <<'PY'
import json,statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if line.startswith("BASE01_P1B_RAW|"):
        payload=line.strip().split("|REGIME=",1)[0]
        rows.append(json.loads(payload.split("|",1)[1]))
if len(rows)!=60: raise SystemExit(f"expected 60 replicate rows, got {len(rows)}")
groups={}
for r in rows:
    key=(r["material"],r["h0"],r["imbalance"])
    groups.setdefault(key,[]).append(r)
if len(groups)!=12: raise SystemExit(f"expected 12 groups, got {len(groups)}")

keys=["participant_backend_ns","p1_headcalc_ns","p1b_kernel_core_ns","p1b_kernel_clone_ns",
      "p1b_canonical_total_ns","p1b_canonical_prep_ns","p1b_tx_total_ns","p1b_tx_clone_ns",
      "p1b_model_advance_ns","p1b_tx_context_ns","p1b_temporal_ns","p1b_kernel_post_ns"]
agg={k:0.0 for k in keys}
diagkeys=("transaction_calls","accepted_substeps","attempts","retries","solver_rejections",
          "temporal_rejections","nonlinear_iterations","backtracking_attempts")
diags={k:0 for k in diagkeys}
for key,rr in sorted(groups.items()):
    if len(rr)!=5: raise SystemExit(f"group replicate count {key}: {len(rr)}")
    med={k:statistics.median(float(x[k]) for x in rr) for k in keys}
    medd={k:int(statistics.median(int(x[k]) for x in rr)) for k in diagkeys}
    for k in keys: agg[k]+=med[k]
    for k in diagkeys: diags[k]+=medd[k]
    b=med["participant_backend_ns"]
    tx_other=max(0.0,med["p1b_tx_total_ns"]-med["p1b_model_advance_ns"]-med["p1b_tx_clone_ns"]-med["p1b_tx_context_ns"])
    model_other=max(0.0,med["p1b_model_advance_ns"]-med["p1_headcalc_ns"]-med["p1b_temporal_ns"])
    print(f"BASE01_P1B_GROUP|MATERIAL={key[0]}|H0={key[1]}|IMBALANCE={key[2]}"
          f"|BACKEND_NS={b:.3f}|KERNEL_CORE_SHARE={med['p1b_kernel_core_ns']/b:.9f}"
          f"|CANONICAL_SHARE={med['p1b_canonical_total_ns']/b:.9f}|TX_SHARE={med['p1b_tx_total_ns']/b:.9f}"
          f"|MODEL_ADVANCE_SHARE={med['p1b_model_advance_ns']/b:.9f}|HEADCALC_SHARE={med['p1_headcalc_ns']/b:.9f}"
          f"|MODEL_OTHER_SHARE={model_other/b:.9f}|TX_OTHER_SHARE={tx_other/b:.9f}"
          f"|TEMPORAL_SHARE={med['p1b_temporal_ns']/b:.9f}|TX_CLONE_SHARE={med['p1b_tx_clone_ns']/b:.9f}"
          f"|TX_CONTEXT_SHARE={med['p1b_tx_context_ns']/b:.9f}|KERNEL_CLONE_SHARE={med['p1b_kernel_clone_ns']/b:.9f}"
          f"|KERNEL_POST_SHARE={med['p1b_kernel_post_ns']/b:.9f}")
b=agg["participant_backend_ns"]
tx_other=max(0.0,agg["p1b_tx_total_ns"]-agg["p1b_model_advance_ns"]-agg["p1b_tx_clone_ns"]-agg["p1b_tx_context_ns"])
model_other=max(0.0,agg["p1b_model_advance_ns"]-agg["p1_headcalc_ns"]-agg["p1b_temporal_ns"])
canonical_other=max(0.0,agg["p1b_canonical_total_ns"]-agg["p1b_canonical_prep_ns"]-agg["p1b_tx_total_ns"])
kernel_other=max(0.0,agg["p1b_kernel_core_ns"]-agg["p1b_kernel_clone_ns"]-agg["p1b_canonical_total_ns"]-agg["p1b_kernel_post_ns"])
print(f"BASE01_P1B_AGG|BACKEND_NS={b:.3f}"
      f"|KERNEL_CORE_NS={agg['p1b_kernel_core_ns']:.3f}|KERNEL_CORE_SHARE={agg['p1b_kernel_core_ns']/b:.9f}"
      f"|KERNEL_CLONE_NS={agg['p1b_kernel_clone_ns']:.3f}|KERNEL_CLONE_SHARE={agg['p1b_kernel_clone_ns']/b:.9f}"
      f"|CANONICAL_NS={agg['p1b_canonical_total_ns']:.3f}|CANONICAL_SHARE={agg['p1b_canonical_total_ns']/b:.9f}"
      f"|CANONICAL_PREP_NS={agg['p1b_canonical_prep_ns']:.3f}|CANONICAL_PREP_SHARE={agg['p1b_canonical_prep_ns']/b:.9f}"
      f"|TX_NS={agg['p1b_tx_total_ns']:.3f}|TX_SHARE={agg['p1b_tx_total_ns']/b:.9f}"
      f"|MODEL_ADVANCE_NS={agg['p1b_model_advance_ns']:.3f}|MODEL_ADVANCE_SHARE={agg['p1b_model_advance_ns']/b:.9f}"
      f"|HEADCALC_NS={agg['p1_headcalc_ns']:.3f}|HEADCALC_SHARE={agg['p1_headcalc_ns']/b:.9f}"
      f"|TEMPORAL_NS={agg['p1b_temporal_ns']:.3f}|TEMPORAL_SHARE={agg['p1b_temporal_ns']/b:.9f}"
      f"|TX_CLONE_NS={agg['p1b_tx_clone_ns']:.3f}|TX_CLONE_SHARE={agg['p1b_tx_clone_ns']/b:.9f}"
      f"|TX_CONTEXT_NS={agg['p1b_tx_context_ns']:.3f}|TX_CONTEXT_SHARE={agg['p1b_tx_context_ns']/b:.9f}"
      f"|KERNEL_POST_NS={agg['p1b_kernel_post_ns']:.3f}|KERNEL_POST_SHARE={agg['p1b_kernel_post_ns']/b:.9f}"
      f"|MODEL_OTHER_NS={model_other:.3f}|MODEL_OTHER_SHARE={model_other/b:.9f}"
      f"|TX_OTHER_NS={tx_other:.3f}|TX_OTHER_SHARE={tx_other/b:.9f}"
      f"|CANONICAL_OTHER_NS={canonical_other:.3f}|CANONICAL_OTHER_SHARE={canonical_other/b:.9f}"
      f"|KERNEL_OTHER_NS={kernel_other:.3f}|KERNEL_OTHER_SHARE={kernel_other/b:.9f}")
print("BASE01_P1B_DIAG|"+"|".join(f"{k.upper()}={v}" for k,v in diags.items()))
if diags["solver_rejections"]!=0: raise SystemExit("new solver rejection")
if diags["retries"]!=20 or diags["temporal_rejections"]!=20: raise SystemExit(f"retry trajectory changed: {diags}")
if diags["nonlinear_iterations"]!=236 or diags["backtracking_attempts"]!=236:
    raise SystemExit(f"nonlinear trajectory changed: {diags}")
print("FPE_BASE01_P1B=PASS")
PY
