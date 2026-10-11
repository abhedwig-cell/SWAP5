#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
python3 - "$BUILD" <<'PY'
from pathlib import Path
import gzip,hashlib,sys,base64,io,tarfile
source=Path('tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz')
data=gzip.decompress(source.read_bytes())
build=Path(sys.argv[1]);build.joinpath('weather.999').write_bytes(data)
build.joinpath('backup.999').write_bytes(data)
# Verified corrected B1.11 source member, already admitted by MC-IRR01.
archive=base64.b64decode(Path('integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
with tarfile.open(fileobj=io.BytesIO(archive),mode='r:gz') as donor:
    meteo=donor.extractfile('SWAP/MOD_meteo.f90').read()
    crop=donor.extractfile('SWAP/MOD_cropdevelopment.f90').read()
    wofost=donor.extractfile('SWAP/wofost.f90').read()
assert hashlib.sha256(meteo).hexdigest()=='99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f'
statement=b'         tav = (tmx+tmn)*0.5d0'
assert meteo.splitlines().count(statement)==1
build.joinpath('daily_meteo_oracle.f90').write_bytes(
    b'function b111_daily_tav(tmin,tmax) result(tav)\nuse iso_fortran_env, only: real64\nimplicit none\n'
    b'real(real64),intent(in)::tmin,tmax\nreal(real64)::tmn,tmx,tav\ntmn=tmin\ntmx=tmax\n'+statement+b'\nend function\n')
print('CROP_FILE_WEATHER_B111_METEO_SHA256='+hashlib.sha256(meteo).hexdigest())

# Independent arithmetic oracle: compile the literal authenticated source
# case(3), not a translated copy of the new owner implementation. Caller
# provides the actual accepted soil sample and existing owner temperature sum.
assert hashlib.sha256(crop).hexdigest()=='aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210'
text=crop.decode().replace('\r\n','\n')
routine=text.split('   subroutine germination (task)',1)[1].split('   end subroutine germination',1)[0]
body=routine.split('      case (3)',1)[1].split('      case default',1)[0]
coefficients='\n'.join(line for line in routine.splitlines() if line.strip().startswith(('cgerm =','bgerm =')))
assert len(coefficients.splitlines())==2
header="""subroutine b111_germination_oracle(sw_germ,tsumgerm,tsumemeopt,tbasem,teffmx,tav, &
  sampled_head,hdrygerm,hwetgerm,agerm,fl_germ)
use iso_fortran_env, only: real64
implicit none
integer,intent(in)::sw_germ
real(real64),intent(inout)::tsumgerm
real(real64),intent(in)::tsumemeopt,tbasem,teffmx,tav,sampled_head,hdrygerm,hwetgerm,agerm
logical,intent(out)::fl_germ
real(real64)::tsumemesub,h_avg,pF_avg,cgerm,bgerm,dvs,zgerm
zgerm=0.0_real64
"""
footer="""contains
function h_average(depth) result(head)
real(real64),intent(in)::depth
real(real64)::head
head=sampled_head
end function
end subroutine
"""
build.joinpath('crop_germination_oracle.f90').write_text(header+coefficients+'\n'+body+footer)
print('CROP_FILE_WEATHER_B111_CROP_SHA256='+hashlib.sha256(crop).hexdigest())
# Compile the source task2 flag/counter branches unchanged. The sowing-node
# search is qualified separately by the existing certified geometry owner.
branches=[]
for name in ('preparation','sowing','germination'):
    routine=text.split('   subroutine '+name+' (task)',1)[1].split('   end subroutine '+name,1)[0]
    branch=routine.split('      case (2)',1)[1].split('         return',1)[0]
    if name=='sowing':
        branch=branch.split('         ! determine compartment',1)[0]
    branches.append(branch)
build.joinpath('task2_oracle.f90').write_text('''subroutine b111_task2_oracle(sw_prep,sw_sow,sw_germ,fl_prep,fl_sow,fl_germ,delay_prep,delay_sow,tsumgerm)
use iso_fortran_env, only: real64
implicit none
integer,intent(in)::sw_prep,sw_sow,sw_germ
logical,intent(out)::fl_prep,fl_sow,fl_germ
integer,intent(out)::delay_prep,delay_sow
real(real64),intent(out)::tsumgerm
logical::fl_start_croprotation
fl_start_croprotation=.true.
delay_prep=0;delay_sow=0;tsumgerm=0.0_real64
'''+''.join(branches)+'end subroutine\n')

assert hashlib.sha256(wofost).hexdigest()=='3f7daf222835c9b4b395feaa665614e8aef88a03125cdec9e0776ca793c6271b'
legacy=wofost.decode().replace('\r\n','\n')
init=legacy.split('   subroutine initialize_wofost (s)',1)[1].split('   end subroutine initialize_wofost',1)[0]
body=init[init.index('      if (fl_start_cropemergence) then'):init.index('      return')]
header="""subroutine b111_initial_owner_oracle(tdwi,fr0,fl0,fs0,fo0,sla0,ssa,spa,result)
use iso_fortran_env, only: real64
implicit none
real(real64),intent(in)::tdwi,fr0,fl0,fs0,fo0,sla0,ssa,spa
real(real64),intent(out)::result(10)
type params
 real(real64)::tdwi,ssa,spa
 real(real64)::frtb(2),fltb(2),fstb(2),fotb(2),slatb(2)
end type
type states
 real(real64)::wrt,wst,wlv,wso,dwrt,dwst,dwlv,lasum,laiexp,lai
 real(real64)::sla(1),lvage(1),lv(1)
 integer::ilv
end type
type(params)::p
type(states)::s
real(real64)::dvs,tsum,atmin7(7),vern,fr,fs,fl,fo,tadw
integer::nofd,macroptb
logical::fl_start_cropemergence,fl_anthesis,fl_vernalised
p%tdwi=tdwi;p%ssa=ssa;p%spa=spa
p%frtb=[0.0_real64,fr0];p%fltb=[0.0_real64,fl0]
p%fstb=[0.0_real64,fs0];p%fotb=[0.0_real64,fo0];p%slatb=[0.0_real64,sla0]
fl_start_cropemergence=.true.;macroptb=2
"""
footer="""result=[s%wrt,s%wst,s%lv(1),s%wso,s%laiexp,s%sla(1),s%lvage(1),dvs,tsum,s%lai]
contains
function afgen(table,n,x) result(value)
integer,intent(in)::n
real(real64),intent(in)::table(n),x
real(real64)::value
value=table(2)
end function
end subroutine
"""
build.joinpath('initial_owner_oracle.f90').write_text(header+body+footer)
print('CROP_FILE_WEATHER_B111_WOFOST_SHA256='+hashlib.sha256(wofost).hexdigest())


# Preserve all authentic input bytes for the positive production run. The
# negatives deliberately retain TAV while changing the underlying record.
lines=data.decode().splitlines(keepends=True)
for i,line in enumerate(lines):
    fields=line.split()
    if len(fields)==12 and fields[1:4]==['20','1','1999']:
        fields[5]='4.2';fields[6]='6.7'
        lines[i]=' '.join(fields)+'\n'
        break
else: raise AssertionError('missing authoritative historical record')
build.joinpath('altered.999').write_text(''.join(lines))
build.joinpath('bad.999').write_text("'ANDE-M' 20 1 1999 1 2 3 4 5 /\n")
print('CROP_FILE_WEATHER_INPUT_SHA256='+hashlib.sha256(data).hexdigest())
assert hashlib.sha256(data).hexdigest()=='ba5c1f880f6166842ed292c18fd12a142cfda4158002f9487fd1420e734e7b72'
# The admitted B110 bridge requires the linked grid and typed runtime
# geometry to agree. Declare a consistent physical 30cm qualification grid,
# as in the existing B19 current-source builder, without changing HeadCalc.
stub=Path('tests/fsi/fsi04_real_headcalc_stubs.f90').read_text()
replacements={
 '[-0.25d0, -0.75d0, -1.50d0, -2.50d0]':'[-2.5d0, -7.5d0, -15.0d0, -25.0d0]',
 '[0.50d0, 0.50d0, 1.00d0, 1.00d0]':'[5.0d0, 5.0d0, 10.0d0, 10.0d0]',
 'disnod(numnod+1) = 1.0d0':'disnod(numnod+1) = [2.5d0, 5.0d0, 7.5d0, 10.0d0, 5.0d0]',
}
for old,new in replacements.items():
    assert stub.count(old)==1
    stub=stub.replace(old,new)
build.joinpath('grid_stubs.f90').write_text(stub)
PY
mapfile -t SOURCES < <(python3 tests/support/augment_bartholomeus_backend_sources.py --all \
  tests/fsi/fsi04_real_headcalc_stubs.f90 src/runtime/mod_fmr_production_application_bootstrap.f90 \
  src/kernel/mod_kernel_committed_persistence.f90)
COMMON=(-std=f2008 -ffree-line-length-none -w -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  mkdir "$BUILD/o$opt"
  (
    cd "$BUILD/o$opt"
    for source in "${SOURCES[@]}"; do
      source_path="$ROOT/$source"
      if [[ "$source" == tests/fsi/fsi04_real_headcalc_stubs.f90 ]]; then source_path="$BUILD/grid_stubs.f90"; fi
      gfortran "${COMMON[@]}" -O"$opt" -J . -I . -c "$source_path"
    done
    gfortran "${COMMON[@]}" -O"$opt" -J . -I . \
      "$ROOT/tests/fmig431/test_crop_file_weather_production.f90" \
      "$ROOT/src/legacy/b1_10_port/headcalc.f90" "$BUILD/daily_meteo_oracle.f90" "$BUILD/crop_germination_oracle.f90" "$BUILD/initial_owner_oracle.f90" "$BUILD/task2_oracle.f90" ./*.o -o test
    for moisture in neutral dry hydraulic; do
      for mode in continuous restart; do
        output="$moisture-$mode"
        ./test "$BUILD/weather.999" "$BUILD/altered.999" "$BUILD/bad.999" "$BUILD/backup.999" "$mode" "$moisture" > "$output.txt" 2> "$output.diagnostics" || \
          { cat "$output.txt" "$output.diagnostics" >&2; exit 1; }
        grep -Fx 'CROP_FILE_WEATHER_PRODUCTION=PASS' "$output.txt"
      done
      cmp "$moisture-continuous.txt" "$moisture-restart.txt"
    done
    cp neutral-restart.txt output.txt
  )
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cmp "$BUILD/o0/dry-restart.txt" "$BUILD/o2/dry-restart.txt"
cmp "$BUILD/o0/hydraulic-restart.txt" "$BUILD/o2/hydraulic-restart.txt"
cat "$BUILD/o0/hydraulic-restart.txt"
cat "$BUILD/o0/output.txt"
cat "$BUILD/o0/dry-restart.txt"
echo 'CROP_FILE_WEATHER_PRODUCTION_O0_O2=PASS'
echo 'CROP_FILE_WEATHER_CONTINUOUS_RESTORED_O0_O2_IDENTICAL=PASS'
echo 'CROP_FILE_WEATHER_NEUTRAL_DRY_CONTINUOUS_RESTORED_O0_O2=PASS'
echo 'CROP_FILE_WEATHER_HYDRAULIC_CONTINUOUS_RESTORED_O0_O2=PASS'
