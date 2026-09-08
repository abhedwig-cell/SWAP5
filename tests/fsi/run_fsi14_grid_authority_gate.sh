#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi14-grid-authority-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE_STUB="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
BASE_DRIVER="$ROOT/tests/fsi/test_fsi09_b110_common_parallel.F90"
MUTABLE_STUB="$BUILD/fsi14_mutable_grid_stubs.f90"
DRIVER="$BUILD/fsi14_base_driver.F90"
CORE="$BUILD/fsi14_core.sh"

# Make only the legacy MOD_grid geometry mutable. Storage of legacy fixture arrays
# remains fixed at grid_capacity=4 so a poisoned numnod cannot resize or invalidate
# unrelated legacy process arrays.
python3 - "$BASE_STUB" "$MUTABLE_STUB" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
old='''module MOD_grid\n  implicit none\n  integer, parameter :: numnod = 4\n  real(8), parameter :: z(numnod) = [-0.25d0, -0.75d0, -1.50d0, -2.50d0]\n  real(8), parameter :: dz(numnod) = [0.50d0, 0.50d0, 1.00d0, 1.00d0]\n  real(8), parameter :: disnod(numnod+1) = 1.0d0\nend module MOD_grid\n'''
new='''module MOD_grid\n  implicit none\n  integer, parameter :: grid_capacity = 4\n  integer :: numnod = grid_capacity\n  real(8) :: z(grid_capacity) = [-0.25d0, -0.75d0, -1.50d0, -2.50d0]\n  real(8) :: dz(grid_capacity) = [0.50d0, 0.50d0, 1.00d0, 1.00d0]\n  real(8) :: disnod(grid_capacity+1) = 1.0d0\nend module MOD_grid\n'''
if s.count(old) != 1: raise SystemExit('F-SI14 mutable MOD_grid marker mismatch')
s=s.replace(old,new,1)
for name in ['variables','MOD_frost','MOD_drain','MOD_irrigation','MOD_swap_mp']:
    start=s.index('module '+name+'\n')
    end=s.index('end module '+name+'\n',start)+len('end module '+name+'\n')
    block=s[start:end]
    block=block.replace('numnod','grid_capacity')
    s=s[:start]+block+s[end:]
Path(sys.argv[2]).write_text(s)
PY

# Make the existing common-route driver independent of mutable legacy numnod after
# request construction. Request geometry itself is fingerprinted so any mutation of
# the shared immutable parameter target is detected.
python3 - "$BASE_DRIVER" "$DRIVER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('use MOD_grid, only: numnod, z, dz, disnod',
            'use MOD_grid, only: numnod, z, dz, disnod, grid_capacity',1)
s=s.replace('call initialize_reference_workspace(ws%richards, numnod)',
            'call initialize_reference_workspace(ws%richards, requests(column)%parameters%active_nodes)',1)
s=s.replace('residual = sum(dz*(result%candidate_state%water_content-request%base_state%water_content)) + &',
            'residual = sum(request%parameters%dz*(result%candidate_state%water_content-request%base_state%water_content)) + &',1)

def patch_block(start_token,end_token,fn):
    global s
    start=s.index(start_token)
    end=s.index(end_token,start)+len(end_token)
    block=s[start:end]
    block=fn(block)
    s=s[:start]+block+s[end:]

patch_block('  integer(int64) function result_fingerprint', '  end function result_fingerprint',
            lambda b:b.replace('do j = 1, numnod','do j = 1, result%candidate_state%active_nodes',1))

def req(b):
    b=b.replace('do j = 1, numnod','do j = 1, request%base_state%active_nodes',1)
    needle='''       fp = ieor(fp, transfer(request%base_state%water_content(j), fp))\n'''
    extra=needle+'''       fp = ieor(fp, transfer(request%parameters%z(j), fp))\n       fp = ieor(fp, transfer(request%parameters%dz(j), fp))\n       fp = ieor(fp, transfer(request%parameters%node_distance(j), fp))\n'''
    if b.count(needle)!=1: raise SystemExit('F-SI14 request fingerprint marker mismatch')
    return b.replace(needle,extra,1)
patch_block('  integer(int64) function request_fingerprint', '  end function request_fingerprint', req)
patch_block('  integer(int64) function global_state_fingerprint', '  end function global_state_fingerprint',
            lambda b:b.replace('do j = 1, numnod','do j = 1, size(h)',1))
Path(sys.argv[2]).write_text(s)
PY

# Reuse the already-qualified F-SI12 physical-profile generator, but stop before its
# legacy-direct section. Adjust only scope guards and paths needed by this F-SI14
# runtime authority experiment.
awk '/^# Legacy direct-call compatibility:/{exit} {print}' "$ROOT/tests/fsi/run_fsi12_explicit_controls_gate.sh" > "$CORE"
python3 - "$CORE" "$ROOT" "$DRIVER" "$MUTABLE_STUB" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); root=sys.argv[2]; driver=sys.argv[3]; stub=sys.argv[4]
s=p.read_text()
lines=s.splitlines()
for i,line in enumerate(lines):
    if line.startswith('ROOT='):
        lines[i]=f'ROOT="{root}"'
    elif line.startswith('BASE_DRIVER='):
        lines[i]=f'BASE_DRIVER="{driver}"'
    elif line.startswith('STUBS='):
        lines[i]=f'STUBS="{stub}"'
s='\n'.join(lines)+'\n'
s=s.replace("expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\\nsrc/legacy/b1_10_port/headcalc.f90'",
            "expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\\nsrc/legacy/b1_10_port/headcalc.f90\\nsrc/solver/mod_reference_richards_workspace.f90'",1)
s=s.replace('  src/solver/mod_reference_richards_workspace.f90 \\\n','',1)
marker="grep -Fq 'request%evaluation%root_sink => root_sink(column)' \"$CONTROL_DRIVER\"\n"
post=r"""python3 - "$CONTROL_DRIVER" "$POISON_DRIVER" <<'PY2'
from pathlib import Path
import sys
for filename in sys.argv[1:]:
    p=Path(filename); x=p.read_text()
    x=x.replace('fsi12_qdra(2,numnod,8)', 'fsi12_qdra(2,grid_capacity,8)')
    x=x.replace('fsi12_qssdi(numnod,8)', 'fsi12_qssdi(grid_capacity,8)')
    x=x.replace('fsi12_zero_root(numnod,8)', 'fsi12_zero_root(grid_capacity,8)')
    x=x.replace('fsi12_qrot(numnod,8)', 'fsi12_qrot(grid_capacity,8)')
    p.write_text(x)
p=Path(sys.argv[2]); x=p.read_text()
needle='''  critdevponddt = -75.0_real64

  call run_serial_baseline(failures)'''
poison='''  critdevponddt = -75.0_real64
  numnod = 1
  z = [91.0_real64, 92.0_real64, 93.0_real64, 94.0_real64]
  dz = [9.0_real64, 8.0_real64, 7.0_real64, 6.0_real64]
  disnod = [5.0_real64, 4.0_real64, 3.0_real64, 2.0_real64, 1.0_real64]

  call run_serial_baseline(failures)'''
if x.count(needle)!=1: raise SystemExit('F-SI14 grid poison insertion marker mismatch')
x=x.replace(needle,poison,1)
needle='''  if (global_state_fingerprint() /= globals_before) failures = failures + 1
  if (transfer(dt,0_int64) /= transfer(99.0_real64,0_int64)) failures = failures + 1'''
checks='''  if (global_state_fingerprint() /= globals_before) failures = failures + 1
  if (numnod /= 1) failures = failures + 1
  if (any(z /= [91.0_real64,92.0_real64,93.0_real64,94.0_real64])) failures = failures + 1
  if (any(dz /= [9.0_real64,8.0_real64,7.0_real64,6.0_real64])) failures = failures + 1
  if (any(disnod /= [5.0_real64,4.0_real64,3.0_real64,2.0_real64,1.0_real64])) failures = failures + 1
  if (transfer(dt,0_int64) /= transfer(99.0_real64,0_int64)) failures = failures + 1'''
if x.count(needle)!=1: raise SystemExit('F-SI14 grid persistence marker mismatch')
x=x.replace(needle,checks,1)
p.write_text(x)
PY2
"""
if marker not in s: raise SystemExit('F-SI14 generated-driver postprocess marker missing')
s=s.replace(marker,post+marker,1)
p.write_text(s)
PY
chmod +x "$CORE"

bash "$CORE"
echo 'F-SI14_MUTABLE_LEGACY_GRID_POISON PASS'
echo 'F-SI14_REQUEST_GRID_GEOMETRY_AUTHORITY PASS'
