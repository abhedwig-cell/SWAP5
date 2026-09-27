#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p0-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

BASELINE="$BUILD/baseline.txt"
CANDIDATE="$BUILD/candidate.txt"
CAND_BOOT="$BUILD/mod_fmr_production_application_bootstrap_candidate.f90"

bash tests/fpe/run_fpe_multi02_p0_scaling_support.sh | tee "$BASELINE"

cp src/runtime/mod_fmr_production_application_bootstrap.f90 "$CAND_BOOT"
python3 - "$CAND_BOOT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()

needle="    type(fmr_serialized_reference_backend_t), pointer :: backend => null()\n"
repl=needle+"    type(fmr_serialized_reference_backend_t), pointer :: groundwater_backends(:) => null()\n"
if needle not in src: raise SystemExit("MULTI02 backend field seam missing")
src=src.replace(needle,repl,1)

needle="    call self%backend%initialize(self%top_boundary)\n\n    if (groundwater_profile) then\n"
repl="""    call self%backend%initialize(self%top_boundary)

    if (groundwater_profile) then
      allocate(self%groundwater_backends(n))
      do i = 1, n
        call self%groundwater_backends(i)%initialize(self%top_boundary)
      end do
"""
if needle not in src: raise SystemExit("MULTI02 backend allocation seam missing")
src=src.replace(needle,repl,1)

needle="        call self%registry%bind(config%tiles(i)%tile_id, self%backend, self%columns(i), self%templates(i), &\n"
repl="        call self%registry%bind(config%tiles(i)%tile_id, self%groundwater_backends(i), self%columns(i), self%templates(i), &\n"
if needle not in src: raise SystemExit("MULTI02 registry bind seam missing")
src=src.replace(needle,repl,1)

needle="    if (associated(self%backend)) deallocate(self%backend)\n"
repl="    if (associated(self%groundwater_backends)) deallocate(self%groundwater_backends)\n"+needle
if needle not in src: raise SystemExit("MULTI02 cleanup deallocation seam missing")
src=src.replace(needle,repl,1)

needle="    nullify(self%backend)\n"
repl="    nullify(self%groundwater_backends)\n"+needle
if needle not in src: raise SystemExit("MULTI02 cleanup nullify seam missing")
src=src.replace(needle,repl,1)

p.write_text(src)
PY

MULTI02_BOOTSTRAP_SOURCE="$CAND_BOOT" bash tests/fpe/run_fpe_multi02_p0_scaling_support.sh | tee "$CANDIDATE"

python3 - "$BASELINE" "$CANDIDATE" <<'PY'
import math,sys

def read(path):
    rows={}
    for line in open(path):
        if not line.startswith("MULTI01_P1_SUMMARY|"): continue
        d={}
        for part in line.strip().split("|")[1:]:
            k,v=part.split("=",1); d[k]=v
        rows[int(d["N"])]=d
    return rows

base=read(sys.argv[1]); cand=read(sys.argv[2])
if sorted(base)!=sorted(cand) or sorted(base)!=[10,100,1000]:
    raise SystemExit(f"unexpected scale rows baseline={sorted(base)} candidate={sorted(cand)}")

for n in sorted(base):
    b=base[n]; c=cand[n]
    qb=float(b["Q_CHECKSUM"]); qc=float(c["Q_CHECKSUM"])
    tb=float(b["T_CHECKSUM"]); tc=float(c["T_CHECKSUM"])
    qtol=128*2.220446049250313e-16*max(1.0,abs(qb),abs(qc))
    ttol=128*2.220446049250313e-16*max(1.0,abs(tb),abs(tc))
    if abs(qb-qc)>qtol: raise SystemExit(f"q drift N={n}: {qb} {qc}")
    if abs(tb-tc)>ttol: raise SystemExit(f"tangent drift N={n}: {tb} {tc}")
    ratio=float(c["TRIAL_SECONDS"])/float(b["TRIAL_SECONDS"])
    print(f"MULTI02_P0|N={n}|Q_ABS_DIFF={abs(qb-qc):.17e}|T_ABS_DIFF={abs(tb-tc):.17e}|SERIAL_RUNTIME_RATIO={ratio:.9f}")
print("FPE_MULTI02_P0=PASS")
PY
