"""Exercise the explicit backend seam in the same verified O0/O2 build."""
from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_THERMAL_POLICY_DIR']).resolve();OUT.mkdir(exist_ok=False)
COMPOSITION=Path(os.environ['N_THERMAL_COMPOSITION_DIR']).resolve()
r=json.loads((COMPOSITION/'result.json').read_text());assert r['status']=='PASS'
for p,h in r['input_sha256'].items():
 if p.startswith('generated/'):path=COMPOSITION/'drivers'/Path(p).name
 else:path=ROOT/p
 assert hashlib.sha256(path.read_bytes()).hexdigest()==h,p
source=(COMPOSITION/'drivers/test_thermal_joint.f90').read_text()
begin=source.index(' initial_water=water;initial_state=state;initial_soil=soil;old_crop=pack_crop_n_owner(crop)')
end=source.index('\ncontains',begin)
probe='''
 block
  type(fmr_b110_physical_parameters_t)::p
  type(fmr_template_t)::t
  type(kernel_checkpoint_t)::checkpoint
  type(kernel_candidate_state_t)::candidate
  type(kernel_result_t)::r
  type(kernel_diagnostics_t)::d
  integer::i
  initial_water=water
  do i=1,5
   p=cfg%tiles(1)%parameters;t=cfg%tiles(1)%template
   call water%capture_checkpoint(checkpoint,ok);call require(ok,'policy checkpoint')
   select case(i)
   case(1)
    call backend%run_trial(column,t,p,water,cfg%tiles(1)%base_forcing,cfg%numerical,0d0,1d0,checkpoint,r,candidate,d, &
     trace_accepted_water_flux_substeps=.true.)
   case(2)
    call backend%run_trial(column,t,p,water,cfg%tiles(1)%base_forcing,cfg%numerical,0d0,1d0,checkpoint,r,candidate,d, &
     trace_accepted_water_flux_substeps=.false.,trace_accepted_soil_n_heat=.true.)
   case default
    if(i==3)t%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
    if(i==4)p%frost_active=.true.
    if(i==5)p%soil_temperature_active=.false.
    call backend%run_trial(column,t,p,water,cfg%tiles(1)%base_forcing,cfg%numerical,0d0,1d0,checkpoint,r,candidate,d, &
     trace_accepted_water_flux_substeps=.true.,trace_accepted_soil_n_heat=.true.)
   end select
   call require(.not.r%completed.and..not.candidate%ready().and.d%admission_rejections==1,'explicit thermal trace exclusions')
   call require(water%current_revision()==0,'policy rejection revision unchanged')
   call thermal_water_unchanged(water,initial_water)
  end do
 end block
 block
  type(kernel_committed_state_t)::decoded,rejected
  type(crop_soil_state_t)::decoded_n,rejected_n
  type(fmr_b110_physical_parameters_t)::wrong
  call write_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,water,state,status)
  call require(status==0,'thermal native initial without pending')
  call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,9101_int64, &
   sp,cp,decoded,decoded_n,status,cfg%tiles(1)%parameters)
  call require(status==0.and.thermal_crop_soil_states_match(decoded,decoded_n),'thermal no-pending native roundtrip')
  call thermal_water_unchanged(decoded,water)
  wrong=cfg%tiles(1)%parameters;wrong%z(1)=wrong%z(1)-.01d0
  call read_crop_soil_n_joint_restart_file(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64,9101_int64, &
   sp,cp,rejected,rejected_n,status,wrong)
  call require(status/=0.and..not.rejected%ready().and..not.rejected_n%ready(),'no certificate minted from different supplied grid')
 end block
 print '(A)','THERMAL_TRACE_EXPLICIT_POLICY=PASS'
 stop
'''
source=source[:begin]+probe+source[end:]
driver=OUT/'test_trace_policy.f90';driver.write_text(source)
events=json.loads((COMPOSITION/'events.json').read_text());rows=[];artifact_hashes={}
for opt in ['O0','O2']:
 b=COMPOSITION/opt
 compile_cmd=next(e['command']for e in reversed(events)if e['category']=='driver_compile'and '-'+opt in e['command'])
 link_cmd=next(e['command']for e in reversed(events)if e['category']=='link'and '-'+opt in e['command'])
 obj=OUT/(opt+'.o');exe=OUT/(opt+'-policy')
 compile_cmd=list(compile_cmd);compile_cmd[compile_cmd.index('-c')+1]=str(driver);compile_cmd[-1]=str(obj)
 link_cmd=[str(obj)if x.endswith('/test_thermal_joint.o')else x for x in link_cmd];link_cmd[-1]=str(exe)
 for p in b.glob('*.o'):artifact_hashes[str(p)]=hashlib.sha256(p.read_bytes()).hexdigest()
 for kind,cmd in [('driver_compile',compile_cmd),('link',link_cmd),('native',[str(exe),'policy',str(OUT/(opt+'-initial.bin'))])]:
  begin=time.perf_counter();p=subprocess.run(cmd,cwd=b,capture_output=True)
  i=len(rows)
  for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(p,stream))
  rows.append(dict(category=kind,opt=opt,command=cmd,seconds=time.perf_counter()-begin,returncode=p.returncode))
  (OUT/'events.json').write_text(json.dumps(rows,indent=2)+'\n')
  assert p.returncode==0,(kind,opt,p.stdout,p.stderr)
  if kind=='native':assert b'THERMAL_TRACE_EXPLICIT_POLICY=PASS'in p.stdout
result=dict(status='PASS',cases=14,generated_driver_sha256=hashlib.sha256(source.encode()).hexdigest(),composition_result_sha256=hashlib.sha256((COMPOSITION/'result.json').read_bytes()).hexdigest(),shared_artifact_sha256=artifact_hashes,events=rows)
result['initial_native_sha256']={opt:hashlib.sha256((OUT/(opt+'-initial.bin')).read_bytes()).hexdigest()for opt in ['O0','O2']}
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(status='PASS',cases=14)))
