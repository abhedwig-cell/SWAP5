#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-setup02-${GITHUB_RUN_ID:-local}-$$"
N="${SETUP02_N:-10000}"
REPS="${SETUP02_REPS:-3}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_SETUP02_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/candidate_bootstrap.f90" <<'PY'
from pathlib import Path
import sys
s=Path("src/runtime/mod_fmr_production_application_bootstrap.f90").read_text()

old_decl="""    integer :: i, local_status, n
    logical :: ok, hydraulic_prepared, groundwater_profile, standalone_profile, prescribed_qbot_profile
"""
new_decl="""    integer :: i, local_status, n
    integer :: tile_duplicate_position, ledger_duplicate_position
    logical :: ok, hydraulic_prepared, groundwater_profile, standalone_profile, prescribed_qbot_profile
"""
if old_decl not in s: raise SystemExit("declaration seam missing")
s=s.replace(old_decl,new_decl,1)

old_after_workers="""    if (config%groundwater_parallel_workers /= 1 .and. config%groundwater_parallel_workers /= 2 .and. &
        config%groundwater_parallel_workers /= 4) return

    groundwater_profile = .true.
"""
new_after_workers="""    if (config%groundwater_parallel_workers /= 1 .and. config%groundwater_parallel_workers /= 2 .and. &
        config%groundwater_parallel_workers /= 4) return

    tile_duplicate_position = first_duplicate_position_int64(config%tiles%tile_id)
    ledger_duplicate_position = first_duplicate_position_int64(config%tiles%ledger_id)

    groundwater_profile = .true.
"""
if old_after_workers not in s: raise SystemExit("precompute seam missing")
s=s.replace(old_after_workers,new_after_workers,1)

old_tile="""      if (i > 1) then
        if (any(config%tiles(1:i-1)%tile_id == config%tiles(i)%tile_id)) return
      end if
"""
new_tile="""      if (i == tile_duplicate_position) return
"""
if old_tile not in s: raise SystemExit("tile duplicate seam missing")
s=s.replace(old_tile,new_tile,1)

old_ledger="""        if (i > 1) then
          if (any(config%tiles(1:i-1)%ledger_id == config%tiles(i)%ledger_id)) return
        end if
"""
new_ledger="""        if (i == ledger_duplicate_position) return
"""
if old_ledger not in s: raise SystemExit("ledger duplicate seam missing")
s=s.replace(old_ledger,new_ledger,1)

helper=r'''
  integer function first_duplicate_position_int64(values) result(position)
    integer(int64), intent(in) :: values(:)
    integer(int64), allocatable :: work(:), scratch(:)
    integer :: n, width, left, middle, right, i, j, k

    position = 0
    n = size(values)
    if (n <= 1) return

    allocate(work(n), scratch(n))
    work = values

    width = 1
    do while (width < n)
      left = 1
      do while (left <= n)
        middle = min(left + width - 1, n)
        right = min(left + 2*width - 1, n)
        i = left
        j = middle + 1
        k = left
        do while (i <= middle .and. j <= right)
          if (work(i) <= work(j)) then
            scratch(k) = work(i)
            i = i + 1
          else
            scratch(k) = work(j)
            j = j + 1
          end if
          k = k + 1
        end do
        do while (i <= middle)
          scratch(k) = work(i)
          i = i + 1
          k = k + 1
        end do
        do while (j <= right)
          scratch(k) = work(j)
          j = j + 1
          k = k + 1
        end do
        left = left + 2*width
      end do
      work = scratch
      width = 2*width
    end do

    do i = 2, n
      if (work(i) == work(i-1)) then
        do j = 2, n
          if (any(values(1:j-1) == values(j))) then
            position = j
            return
          end if
        end do
      end if
    end do
  end function first_duplicate_position_int64

'''
marker="end module mod_fmr_production_application_bootstrap"
if marker not in s: raise SystemExit("module end seam missing")
s=s.replace(marker,helper+marker,1)
Path(sys.argv[1]).write_text(s)
PY

python3 - "$BUILD/candidate_runner.sh" "$BUILD/candidate_bootstrap.f90" "$ROOT" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fpe/run_fpe_setup01_decomposition.sh").read_text()
bootstrap=Path(sys.argv[2]).resolve()
root=Path(sys.argv[3]).resolve()
old_root='ROOT="$(cd "$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"\ncd "$ROOT"'
new_root=f'ROOT="{root}"\ncd "$ROOT"'
if old_root not in runner:
    raise SystemExit("runner root seam missing")
runner=runner.replace(old_root,new_root,1)

old='mapfile -t MODULE_SRC < <(python3 - "$BUILD/fixture.f90" <<\'PY\'\nfrom pathlib import Path\nimport sys,re\nfixture=Path(sys.argv[1]).resolve()'
new='mapfile -t MODULE_SRC < <(python3 - "$BUILD/fixture.f90" "$SETUP02_BOOTSTRAP_SOURCE" <<\'PY\'\nfrom pathlib import Path\nimport sys,re\nfixture=Path(sys.argv[1]).resolve()\nbootstrap=Path(sys.argv[2]).resolve()'
if old not in runner:
    raise SystemExit("runner argv seam missing")
runner=runner.replace(old,new,1)

old='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    else:
        print(p)
'''
new='''    if p=="tests/fpe/mod_fpe_temporal08_production_live_fixture.f90":
        print(fixture)
    elif p=="src/runtime/mod_fmr_production_application_bootstrap.f90":
        print(bootstrap)
    else:
        print(p)
'''
if old not in runner:
    raise SystemExit("runner module substitution seam missing")
runner=runner.replace(old,new,1)
Path(sys.argv[1]).write_text(runner)
PY
chmod +x "$BUILD/candidate_runner.sh"

SETUP01_N="$N" SETUP01_REPS="$REPS" bash tests/fpe/run_fpe_setup01_decomposition.sh | tee "$BUILD/baseline.txt"
SETUP02_BOOTSTRAP_SOURCE="$BUILD/candidate_bootstrap.f90" SETUP01_N="$N" SETUP01_REPS="$REPS"   bash "$BUILD/candidate_runner.sh" | tee "$BUILD/candidate.txt"

python3 - "$N" "$BUILD/baseline.txt" "$BUILD/candidate.txt" <<'PY'
import re,sys
n=int(sys.argv[1])

def parse(path):
    txt=open(path).read()
    m=re.search(r'SETUP01_SUMMARY\|N=(\d+)\|LIB_LOAD=([^|]+)\|INIT_OUTER=([^|]+)\|CONFIG=([^|]+)\|APP_INIT=([^|]+)\|TOPOLOGY=([^|]+)\|CONTEXT=([^|]+)\|CAPTURE=([^|]+)\|WARM=([^|]+)\|SETUP_TOTAL=([^|]+)\|INTERNAL_INIT_SUM=([^|]+)\|OUTER_TOTAL=([^\n]+)',txt)
    if not m: raise SystemExit(f"missing summary {path}")
    vals=[int(m.group(1))]+[float(m.group(i)) for i in range(2,13)]
    return vals

b=parse(sys.argv[2]); c=parse(sys.argv[3])
if b[0]!=n or c[0]!=n: raise SystemExit("N mismatch")
b_app=b[4]; c_app=c[4]
speed=b_app/c_app
setup_speed=b[9]/c[9]
print(f"SETUP02_SUMMARY|N={n}|BASE_APP_INIT={b_app:.12f}|CANDIDATE_APP_INIT={c_app:.12f}|APP_INIT_SPEEDUP={speed:.6f}|BASE_SETUP_TOTAL={b[9]:.12f}|CANDIDATE_SETUP_TOTAL={c[9]:.12f}|SETUP_SPEEDUP={setup_speed:.6f}")
if n==1000 and c_app>1.05*b_app:
    raise SystemExit(f"N=1000 regression gate failed: {c_app/b_app}")
if n==10000 and speed<2.0:
    raise SystemExit(f"N=10000 speed gate failed: {speed}")
if n==40000 and speed<5.0:
    raise SystemExit(f"N=40000 speed gate failed: {speed}")
print("FPE_SETUP02_PERFORMANCE=PASS")
PY
