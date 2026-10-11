#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mc-irr01-literal-availability-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
python3 - "$BUILD" <<'PY'
import base64,tarfile,io,hashlib,pathlib,sys
bundle=pathlib.Path('integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64')
t=tarfile.open(fileobj=io.BytesIO(base64.b64decode(bundle.read_bytes())),mode='r:gz')
m=next(m for m in t.getmembers() if m.name.endswith('SWAP/irrigation.f90'))
b=t.extractfile(m).read()
assert hashlib.sha256(b).hexdigest()=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
s=b.decode().split('      case(4)')[1].split('      case(9)')[0]
body='\n'.join(s.splitlines()[1:])
assert 'gird = gird * f_irr_avail' in body
assert 'qssdi' not in body.lower()
program='''program literal_availability
use iso_fortran_env, only: real64
use mod_irrigation_availability_policy
implicit none
real(real64)::gird,dt_irr_event,irr_rate,f_irr_avail,qssdi,rate,duration
integer::i,j,k,status
logical::surface
 do i=0,1
 surface=i==0
 do j=0,1
 irr_rate=real(j,real64)*0.48_real64
 do k=0,2
 f_irr_avail=real(k,real64)*0.5_real64
 gird=0.48_real64
 qssdi=0.48_real64
 dt_irr_event=0.25_real64
 rate=qssdi
 duration=dt_irr_event
'''+body+'''
 call apply_irrigation_availability(.true.,f_irr_avail,irr_rate>0.0_real64,rate,duration,status,surface)
 if(status/=IRR_AVAIL_OK)error stop 1
 if(surface)then
 if(abs(rate-gird)>1e-15_real64)error stop 2
 else
 if(abs(rate-qssdi)>1e-15_real64)error stop 3
 endif
 if(abs(duration-dt_irr_event)>1e-15_real64)error stop 4
 enddo
 enddo
 enddo
 print '(A)','MC_IRR01_LITERAL_TASK4_12_CASES=PASS'
end program
'''
pathlib.Path(sys.argv[1],'oracle.f90').write_text(program)
PY
for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" \
    -J "$BUILD/o$opt" -I "$BUILD/o$opt" src/process/mod_irrigation_availability_policy.f90 "$BUILD/oracle.f90" -o "$BUILD/o$opt/test"
  "$BUILD/o$opt/test" > "$BUILD/o$opt/output"
done
cmp "$BUILD/o0/output" "$BUILD/o2/output"
cat "$BUILD/o0/output"
