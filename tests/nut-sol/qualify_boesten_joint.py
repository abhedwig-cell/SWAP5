"""Actual Boesten/root/pond-solute composition and V3 disk roundtrip."""
import argparse,hashlib,json,runpy,struct,subprocess,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 out=a.output.resolve();out.mkdir();bundle=json.loads((a.bundle/'bundle.json').read_text());build=json.loads((Path(bundle['exe']).parent/'build-complete.json').read_text());events=[]
 def run(cmd,valid=True):
  t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=out,capture_output=True,timeout=180);idx=len(events)
  for stream in ['stdout','stderr']:(out/f'{idx:03}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.perf_counter()-t));assert (r.returncode==0)==valid,r.stdout.decode()+r.stderr.decode();return r
 src=(ROOT/'tests/nut-sol/test_root_substep_transaction.f90').read_text()
 src=src.replace(' use iso_fortran_env,only:real64,int64',' use iso_fortran_env,only:real64,int64\n use mod_restricted_surface_evaporation,only:boesten_evaporation_state_t')
 src=src.replace(' use mod_restricted_surface_evaporation,only:boesten_evaporation_state_t',' use mod_restricted_surface_evaporation,only:boesten_evaporation_state_t\n use mod_root_uptake_compensation,only:ROOT_COMP_WALSUM')
 src=src.replace('allocate(forcing%pond_input);forcing%pond_input%ponding_max_cm=1d6', 'p%boesten_evaporation_active=.true.;allocate(p%boesten_evaporation,forcing%boesten_evaporation)\n p%boesten_evaporation%cofred=.35d0\n forcing%boesten_evaporation%ponding_max_cm=1d6\n forcing%boesten_evaporation%potential_bare_soil_evaporation_cm_per_day=.002d0')
 src=src.replace('config%transaction%temporal_tolerance=1d-4','config%transaction%temporal_tolerance=1d-3')
 src=src.replace('call fmr_new_b110_committed_state(water,column%column_id,initial,0d0,ok)', 'template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION\n call fmr_new_b110_boesten_evaporation_committed_state(water,column%column_id,initial,boesten_evaporation_state_t(.5d0,.2d0),0d0,ok)')
 src=src.replace('type is(fmr_b110_physical_state_t)','type is(fmr_b110_boesten_evaporation_state_t)')
 src=src.replace("call check(result%status==JOINT_CHEMICAL_REJECTED", "print *, 'JOINT_DEBUG',result%status,result%water%status,result%diagnostics\n call check(result%status==JOINT_CHEMICAL_REJECTED")
 src=src.replace("x%ponding_depth==y%ponding_depth,'root binding", "x%ponding_depth==y%ponding_depth.and.x%boesten_evaporation%spev==y%boesten_evaporation%spev.and. &\n      x%boesten_evaporation%saev==y%boesten_evaporation%saev,'root binding")
 src=src.replace(' invalid=supply;invalid%rain_c=-1d0', ''' block
  type(fmr_b110_physical_parameters_t)::unsupported
  unsupported=p;unsupported%root_compensation%method=ROOT_COMP_WALSUM
  call run_pond_joint_interval(backend,column,template,unsupported,water,forcing,config,chemical,supply,0d0,.2d0,result)
  call check(result%status/=JOINT_OK,'unqualified root compensation rejected')
  call compare_water(water,base)
  call write_matrix_joint_restart_file('unsupported.bin',column,template,p%parameter_set_id,water,chemical,s,allow_surface_mass=.true.)
  call check(s==JOINT_OK,'unsupported composition snapshot')
 end block
 invalid=supply;invalid%rain_c=-1d0''')
 # Same setup and real state owners in a separate process for decoder checks.
 at=src.index(' base=water;original=chemical;other=water;other_chemical=chemical')
 decoder=src[:at]+''' block
  type(kernel_committed_state_t)::decoded
  type(matrix_solute_state_t)::decoded_chemical
  character(512)::path,arg
  logical::present_file
  call get_command_argument(1,path);call get_command_argument(2,arg)
  if(trim(arg)=='layout')template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
  call read_matrix_joint_restart_file(trim(path),column,template,p%parameter_set_id,9001_int64,chemistry, &
    decoded,decoded_chemical,s,allow_surface_mass=.true.)
  if(trim(arg)=='valid')then
   call check(s==JOINT_OK,'V3 decode')
   call write_matrix_joint_restart_file('decoded.bin',column,template,p%parameter_set_id,decoded,decoded_chemical,s,allow_surface_mass=.true.)
   call check(s==JOINT_OK,'V3 encode')
  else
   call check(s/=JOINT_OK.and..not.decoded%ready().and..not.decoded_chemical%ready(),'atomic invalid decode')
  end if
 end block
''' +src[src.index('contains\n'):]
 flags=[f for f in build['flags']if not f.startswith('-J')]+['-J'+str(out)]
 objects=[path for path in build['reused_artifact_sha256']if path.endswith('.o')];tt=[path for path in build['reused_artifact_sha256']if path.endswith('/libttutil.a')];assert len(objects)==193 and len(tt)==1
 for name,text in [('joint',src),('decode',decoder)]:
  path=out/(name+'.f90');path.write_text(text);run(build['compiler_command']+flags+[path,*objects,*tt,'-o',out/name])
 run([out/'joint'])
 for x,y in [('original.bin','rejected.bin'),('original.bin','unsupported.bin'),('retry.bin','fresh.bin'),('retry.bin','again.bin'),('original.bin','invalid.bin'),('absent.bin','absent-fresh.bin')]:assert(out/x).read_bytes()==(out/y).read_bytes(),(x,y)
 raw=(out/'retry.bin').read_bytes();assert raw[:8]==b'S5MJ0003';run([out/'decode','retry.bin','valid']);assert raw==(out/'decoded.bin').read_bytes()
 run([out/'decode','retry.bin','layout'])
 bad=bytearray(raw);bad[-5]^=1;(out/'crc.bin').write_bytes(bad);run([out/'decode','crc.bin','bad'])
 # Header has 8-byte tag, schema metadata, then 4*n+2 physical reals.
 pattern=struct.pack('dd',.5,.2);initial=(out/'original.bin').read_bytes();offset=initial.index(pattern);assert initial.count(pattern)==1
 for value,name in [(-1.,'negative'),(float('nan'),'nan')]:
  bad=bytearray(initial);struct.pack_into('d',bad,offset,value);struct.pack_into('I',bad,len(bad)-4,zlib.crc32(bad[:-4]));(out/(name+'.bin')).write_bytes(bad);run([out/'decode',name+'.bin','bad'])
 r=dict(status='BOESTEN_ROOT_POND_SOLUTE_REJECTION_RETRY_ABA_V3_FRESH_DECODE_PASS',optimization=bundle['optimization'],events=events,inputs={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in build['input_sha256']},driver_sha256=hashlib.sha256(src.encode()).hexdigest())
 (out/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
if __name__=='__main__':main()
