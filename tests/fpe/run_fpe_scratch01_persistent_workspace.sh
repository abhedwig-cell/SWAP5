#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-scratch01-${GITHUB_RUN_ID:-local}-$$"
N="${SCRATCH01_N:-10000}"
REPS="${SCRATCH01_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_SCRATCH01_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/candidate_context.f90" <<'PY'
from pathlib import Path
import sys

p=Path("src/runtime/mod_fmr_groundwater_application_context.f90")
s=p.read_text()

type_anchor="""    logical, allocatable :: ledger_prepared(:)
    type(groundwater_coupling_window_t) :: window
"""
type_repl="""    logical, allocatable :: ledger_prepared(:)
    real(real64), allocatable :: scratch_tile_heads_m(:)
    real(real64), allocatable :: scratch_predicted_cost(:)
    real(real64), allocatable :: scratch_worker_load(:)
    integer, allocatable :: scratch_registry_status(:)
    integer, allocatable :: scratch_owner(:)
    integer, allocatable :: scratch_order(:)
    integer, allocatable :: scratch_merge_workspace(:)
    type(groundwater_coupling_window_t) :: window
"""
if type_anchor not in s:
    raise SystemExit("SCRATCH01 type anchor missing")
s=s.replace(type_anchor,type_repl,1)

bind_anchor="""    allocate(self%prepared_ledgers(size(tiles)))
    allocate(self%ledger_prepared(size(tiles)))

    self%participant_handles = participant_handles
"""
bind_repl="""    allocate(self%prepared_ledgers(size(tiles)))
    allocate(self%ledger_prepared(size(tiles)))
    if (self%worker_count > 1) then
      allocate(self%scratch_tile_heads_m(size(tiles)))
      allocate(self%scratch_predicted_cost(size(tiles)))
      allocate(self%scratch_worker_load(self%worker_count))
      allocate(self%scratch_registry_status(size(tiles)))
      allocate(self%scratch_owner(size(tiles)))
      allocate(self%scratch_order(size(tiles)))
      allocate(self%scratch_merge_workspace(size(tiles)))
    end if

    self%participant_handles = participant_handles
"""
if bind_anchor not in s:
    raise SystemExit("SCRATCH01 bind allocation anchor missing")
s=s.replace(bind_anchor,bind_repl,1)

start=s.index("  subroutine application_context_trial_cell_heads")
end=s.index("  end subroutine application_context_trial_cell_heads",start)
end=end+len("  end subroutine application_context_trial_cell_heads")
sub=s[start:end]

old_real="    real(real64), allocatable :: tile_heads_m(:), predicted_cost(:), worker_load(:)\n"
old_int="    integer, allocatable :: registry_status(:), owner(:), order(:), merge_workspace(:)\n"
if old_real not in sub or old_int not in sub:
    raise SystemExit("SCRATCH01 local declaration seam missing")
sub=sub.replace(old_real,"",1).replace(old_int,"",1)

old_alloc="""      allocate(tile_heads_m(size(self%tiles)), registry_status(size(self%tiles)), owner(size(self%tiles)), &
           predicted_cost(size(self%tiles)), worker_load(self%worker_count), order(size(self%tiles)), &
           merge_workspace(size(self%tiles)))
      registry_status = FMR_GW_REGISTRY_OK
"""
new_alloc="""      if (.not. allocated(self%scratch_tile_heads_m) .or. .not. allocated(self%scratch_registry_status) .or. &
          .not. allocated(self%scratch_owner) .or. .not. allocated(self%scratch_predicted_cost) .or. &
          .not. allocated(self%scratch_worker_load) .or. .not. allocated(self%scratch_order) .or. &
          .not. allocated(self%scratch_merge_workspace)) then
        status = FMR_GW_APP_CONTEXT_INVALID_REQUEST
        return
      end if
      self%scratch_registry_status = FMR_GW_REGISTRY_OK
"""
if old_alloc not in sub:
    raise SystemExit("SCRATCH01 per-trial allocation seam missing")
sub=sub.replace(old_alloc,new_alloc,1)

repls={
    "tile_heads_m":"self%scratch_tile_heads_m",
    "predicted_cost":"self%scratch_predicted_cost",
    "worker_load":"self%scratch_worker_load",
    "registry_status":"self%scratch_registry_status",
    "owner":"self%scratch_owner",
    "order":"self%scratch_order",
    "merge_workspace":"self%scratch_merge_workspace",
}
for old,new in repls.items():
    sub=sub.replace(old,new)

s=s[:start]+sub+s[end:]
Path(sys.argv[1]).write_text(s)
PY

python3 - "$BUILD/candidate_runner.sh" "$BUILD/candidate_context.f90" "$ROOT" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh").read_text()
context=Path(sys.argv[2]).resolve()
root=Path(sys.argv[3]).resolve()

old_root='ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"\ncd "$ROOT"'
new_root=f'ROOT="{root}"\ncd "$ROOT"'
if old_root not in runner:
    raise SystemExit("SCRATCH01 runner root seam missing")
runner=runner.replace(old_root,new_root,1)

runner=runner.replace(
    "mapfile -t MODULE_SRC < <(python3 - \"$fixture\" <<'PY'\nfrom pathlib import Path\nimport sys,re\nfixture=Path(sys.argv[1]).resolve()",
    "mapfile -t MODULE_SRC < <(python3 - \"$fixture\" \"$SCRATCH01_CONTEXT_SOURCE\" <<'PY'\nfrom pathlib import Path\nimport sys,re\nfixture=Path(sys.argv[1]).resolve()\ncontext=Path(sys.argv[2]).resolve()",1)

old="""    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    else:
        print(p)
"""
new="""    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/runtime/mod_fmr_groundwater_application_context.f90":
        print(context)
    else:
        print(p)
"""
if old not in runner:
    raise SystemExit("SCRATCH01 module substitution seam missing")
runner=runner.replace(old,new,1)
Path(sys.argv[1]).write_text(runner)
PY
chmod +x "$BUILD/candidate_runner.sh"

MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh | tee "$BUILD/baseline.txt"

SCRATCH01_CONTEXT_SOURCE="$BUILD/candidate_context.f90" MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"   bash "$BUILD/candidate_runner.sh" | tee "$BUILD/candidate.txt"

python3 - "$N" "$BUILD/baseline.txt" "$BUILD/candidate.txt" <<'PY'
import re,sys
n=int(sys.argv[1])

def parse(path):
    txt=open(path).read()
    m=re.search(
        r'MULTI04_P1C_SUMMARY\|N=(\d+)\|W1_SECONDS=([^|]+)\|W2_SECONDS=([^|]+)\|W4_SECONDS=([^|]+)\|'
        r'SPEEDUP2=([^|]+)\|SPEEDUP4=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)',txt)
    if not m:
        raise SystemExit(f"missing summary {path}")
    return dict(n=int(m.group(1)),w1=float(m.group(2)),w2=float(m.group(3)),w4=float(m.group(4)),
                s2=float(m.group(5)),s4=float(m.group(6)),q=float(m.group(7)),t=float(m.group(8)))

b=parse(sys.argv[2]); c=parse(sys.argv[3])
if b["n"]!=n or c["n"]!=n:
    raise SystemExit("N mismatch")
if b["q"]!=c["q"] or b["t"]!=c["t"]:
    raise SystemExit("semantic checksum mismatch")
speed1=b["w1"]/c["w1"]
speed4=b["w4"]/c["w4"]
ratio4=c["w4"]/b["w4"]
print(
    f"SCRATCH01_SUMMARY|N={n}|BASE_W1={b['w1']:.12f}|CAND_W1={c['w1']:.12f}|W1_SPEEDUP={speed1:.6f}|"
    f"BASE_W4={b['w4']:.12f}|CAND_W4={c['w4']:.12f}|W4_SPEEDUP={speed4:.6f}|"
    f"QSUM={b['q']:.17e}|TSUM={b['t']:.17e}"
)
if n==1000 and ratio4>1.02:
    raise SystemExit(f"N=1000 no-regression gate failed: {ratio4}")
if n==10000 and speed4<1.05:
    raise SystemExit(f"N=10000 speed gate failed: {speed4}")
if n==40000 and speed4<1.08:
    raise SystemExit(f"N=40000 speed gate failed: {speed4}")
print("FPE_SCRATCH01=PASS")
PY
