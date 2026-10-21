"""Build wet-state reconstruction and rollback controls from their executed driver."""
import argparse,hashlib,json,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--build',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--weather',type=Path,required=True);ap.add_argument('--kind',choices=['wet-restart','rollback'],required=True);a=ap.parse_args()
base,out=a.build.resolve(),a.output.resolve();out.mkdir(parents=True,exist_ok=False);b=json.loads((base/'BUILD.json').read_text());assert b['status']=='BUILT' and sha(base/'weather')==b['executable_sha256']
s=(base/'driver.f90').read_text()
if a.kind=='wet-restart':
 assert s.count('d==days/2-1')==1;s=s.replace('d==days/2-1','d==34')
else:
 s=s.replace('H0_CM=-75.0_real64','H0_CM=-1.0_real64').replace('  integer::st,q,d,j,','  integer(int64),allocatable::before_bits(:),after_bits(:)\n  integer(int64)::crop_revision\n  integer::st,q,d,j,')
 anchor="  call ta%initialize(tc,st);call require(st==FMR_APP_BOOT_OK,'live weather crop bootstrap')";assert s.count(anchor)==1
 s=s.replace(anchor,'  tc%numerical%max_committed_substeps=1\n  tc%tiles(1)%initial_state%ponding_depth=.2d0\n'+anchor)
 anchor='    do q=0,windows-1\n';assert s.count(anchor)==1;s=s.replace(anchor,anchor+'      call ta%copy_committed_for_crop(1,ss,st)\n      call capture_bits(ss,before_bits)\n      crop_revision=cs%current_revision()\n')
 anchor="      call require(st==FMR_APP_BOOT_OK,'live weather hydrology')";assert s.count(anchor)==1
 s=s.replace(anchor,"""      call require(st/=FMR_APP_BOOT_OK,'forced whole-window rejection')
      call require(allocated(rr),'failed runtime result retained')
      call require(rr(1)%accepted_substeps>0,'private progress before rejection')
      call require(.not.rr(1)%committed.and..not.rr(1)%surface_fluxes_available,'no rejected receipt')
      call require(rr(1)%runoff_cm==0d0.and.rr(1)%bare_soil_evaporation_cm==0d0.and.rr(1)%pond_evaporation_cm==0d0,'gross receipts absent')
      call ta%copy_committed_for_crop(1,ss,st)
      call capture_bits(ss,after_bits)
      call require(all(before_bits==after_bits),'exact water heat history clock provenance rollback')
      call require(cs%current_revision()==crop_revision,'crop unchanged')
      print *, 'WEATHER_SURFACE_ROLLBACK_PASS',rr(1)%accepted_substeps
      stop
""")
 helper="""  subroutine capture_bits(soil,bits)
    type(kernel_committed_state_t),intent(in)::soil
    integer(int64),allocatable,intent(out)::bits(:)
    class(transaction_state_t),allocatable::state
    real(real64),allocatable::history(:),temperature(:)
    real(real64)::clock
    integer::n,code
    logical::valid
    call soil%snapshot(state,valid);call require(valid,'rollback snapshot')
    select type(state)
    type is(fmr_b110_temporal_indicator_state_t)
      n=state%active_nodes;allocate(bits(4*n+5))
      bits(1:n)=transfer(state%pressure_head,0_int64,n);bits(n+1:2*n)=transfer(state%water_content,0_int64,n)
      bits(2*n+1)=transfer(state%ponding_depth,0_int64);bits(2*n+2)=transfer(state%groundwater_level,0_int64)
      call state%temporal_history_snapshot(history,valid);call require(valid,'rollback history')
      bits(2*n+3:3*n+2)=transfer(history,0_int64,n)
      call copy_soil_temperature_profile(state%soil_temperature,temperature,code);call require(code==SOIL_TEMP_OK,'rollback heat')
      bits(3*n+3:4*n+2)=transfer(temperature,0_int64,n)
      bits(4*n+3)=soil%current_revision();bits(4*n+4)=soil%current_lineage_id()
      call soil%current_time(clock,valid);call require(valid,'rollback clock');bits(4*n+5)=transfer(clock,0_int64)
    class default
      call require(.false.,'rollback complete physical type')
    end select
  end subroutine
"""
 assert s.count('contains\n')==1;s=s.replace('contains\n','contains\n'+helper)
(out/'driver.f90').write_text(s);flags=[x for x in b['flags'] if not x.startswith(('-I','-J'))]+['-I'+str(base),'-J'+str(out)]
cmd=b['compiler_command']+flags+[str(out/'driver.f90'),str(ROOT/'src/legacy/b1_10_port/headcalc.f90'),*[str(base/f'{i:04d}.o') for i in range(len(b['sources']))],'-o',str(out/'weather')]
t=time.monotonic();p=subprocess.run(cmd,capture_output=True)
for stream in ('stdout','stderr'):(out/('link.'+stream)).write_bytes(getattr(p,stream))
p.check_returncode();shutil.copy2(a.weather,out/'weather.999');b.update(executable_sha256=sha(out/'weather'),control_variant=a.kind,generated_driver_sha256=sha(out/'driver.f90'),control_link=dict(command=cmd,seconds=time.monotonic()-t,returncode=p.returncode),weather_sha256=sha(out/'weather.999'));(out/'BUILD.json').write_text(json.dumps(b,indent=2)+'\n')
