"""Real incumbent trial/replay bodies plus independent external macro trace checks."""
import argparse,hashlib,json,os,re,resource,subprocess,time,gzip,datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--phase',choices=['pilot','full'],default='full');p.add_argument('--numeric-heat',action='store_true');p.add_argument('--root-drain',choices=['root','drain','joint']);a=p.parse_args();assert not a.root_drain or a.numeric_heat,'joint mode requires numeric heat'
build=a.build.resolve();out=a.output.resolve();out.mkdir();sha=lambda b:hashlib.sha256(b).hexdigest()
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
b=json.loads((build/'build-complete.json').read_text());assert b['status']=='BUILT'
for path,h in b['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
provider_root=Path(b.get('generated_input_root',next(x[2:]for x in b['flags']if x.startswith('-I'))))
for path,h in b['generated_input_sha256'].items():assert sha((provider_root/path).read_bytes())==h,path

link=next(e['command']for e in b['events']if e['category']=='link');objects=[Path(x)for x in link if x.endswith('.o')][:-1];archives=[Path(x)for x in link if x.endswith('.a')];flags=[x for x in b['flags']if not x.startswith('-J')];fc=b['compiler_command'];events=[];results={};inputs=dict(b['input_sha256']);bindings={str(x):sha(x.read_bytes())for x in objects+archives+list(build.glob('*.mod'))+list(provider_root.glob('*.mod'))}
def run(cmd,label,env=None,cwd=out):
 start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,env={**os.environ,**(env or {})},timeout=120)
 for k in ['stdout','stderr']:(out/(label+'.'+k)).write_bytes(getattr(r,k))
 events.append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,seconds=time.perf_counter()-start));(out/'events.json').write_text(json.dumps(events,indent=2));return r
bbcpath='tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-swap.bbc.gz'
bbc=gzip.decompress((ROOT/bbcpath).read_bytes());inputs[bbcpath]=sha((ROOT/bbcpath).read_bytes())
data=re.findall(rb'^\s*(1998-\d\d-\d\d)\s+(-?[\d.]+)\s*$',bbc,re.M);assert len(data)==365
dates=[(datetime.date.fromisoformat(d.decode())-datetime.date(1900,1,1)).days for d,h in data]
values=','.join(str(v)+'.0_real64'for v in dates);heads=','.join(h.decode()+'_real64'for d,h in data)
def control(name):return f"\n    allocate({name}%legacy_swbotb3_implicit_control)\n    call {name}%legacy_swbotb3_implicit_control%initialize_table(0.0_real64,{dates[0]}.0_real64,[{values}],[{heads}],10.0_real64,.true.,rutter_status)\n    if(rutter_status/=0)error stop 'BBC init'\n"
for name in ['trial','replay']:
 path='tests/fpm/test_ppa_wu05a9_fmr_top_input_'+name+'.f90';text=(ROOT/path).read_text();inputs[path]=sha(text.encode())
 text,n=re.subn(r'real\(real64\)\s*::\s*heads\(numnod\),water\(numnod\),cond\(numnod\),cap\(numnod\),dkdh\(numnod\)','real(real64),allocatable::heads(:),water(:),cond(:),cap(:),dkdh(:)',text);assert n==1
 text=text.replace('  implicit none','  use variables,only:context_qrot=>qrot\n  use mod_fmr_serialized_reference_backend,only:fmr_serialized_physical_observation_t\n  implicit none\n  logical::want_trace\n  character(len=1)::trace_flag\n',1)
 at=text.index("  call get_environment_variable(")
 text=text[:at]+"""  numnod=4
  allocate(context_qrot(4));context_qrot=0._real64
  allocate(z(4),dz(4),disnod(5),heads(4),water(4),cond(4),cap(4),dkdh(4))
  z=[-.25_real64,-.75_real64,-1.5_real64,-2.5_real64]
  dz=[.5_real64,.5_real64,1._real64,1._real64];disnod=1._real64
  call get_environment_variable('MACRO_TRACE_ON',trace_flag)
  want_trace=trace_flag=='1'
"""+text[at:]
 if a.numeric_heat:
  if name!='replay':continue
  text=text.replace('  implicit none','''  use mod_restricted_soil_temperature,only:initialize_soil_temperature_parameters,initialize_soil_temperature_state
  use mod_soil_temperature_contract,only:soil_temperature_field_view_t,build_soil_temperature_field_view
  implicit none''',1)
  text=text.replace('    if(migmac10)then\n      call fmr_new_b110_boesten_macropore_committed_state','''    fparams%soil_temperature_active=.true.
    allocate(fparams%soil_temperature,initial%soil_temperature)
    call initialize_soil_temperature_parameters(dz,[.25_real64,.5_real64,.75_real64,1._real64], &
      spread(.427494_real64,1,numnod),spread(.3_real64,1,numnod),spread(.2_real64,1,numnod), &
      spread(.02_real64,1,numnod),fparams%soil_temperature,rutter_status)
    if(rutter_status/=0)error stop 'macro heat parameters'
    call initialize_soil_temperature_state(spread(12._real64,1,numnod),initial%soil_temperature,rutter_status)
    if(rutter_status/=0)error stop 'macro heat initial state'
    allocate(forcing%soil_temperature)
    forcing%soil_temperature%prescribed_surface_temperature_c=20._real64
    if(migmac10)then
      call fmr_new_b110_boesten_macropore_committed_state''',1)
  text=text.replace('          negative_params%soil_temperature_active=.true.', '          deallocate(negative_params%soil_temperature)')
  text=text.replace('    same=.false.\n    select type (aa=>a)', '    type(soil_temperature_field_view_t)::ta,tb\n    integer::sa,sb\n    same=.false.\n    select type (aa=>a)',1)
  anchor='        if(same)same=allocated(aa%macropore).eqv.allocated(bb%macropore)'
  assert anchor in text
  text=text.replace(anchor,'''        if(same)same=allocated(aa%soil_temperature).eqv.allocated(bb%soil_temperature)
        if(same.and.allocated(aa%soil_temperature))then
          call build_soil_temperature_field_view(aa%soil_temperature,ta,sa)
          call build_soil_temperature_field_view(bb%soil_temperature,tb,sb)
          same=sa==0.and.sb==0
          if(same)same=all(transfer(ta%temperature_c,[0_int64],size(ta%temperature_c))== &
            transfer(tb%temperature_c,[0_int64],size(tb%temperature_c)))
        end if
'''+anchor)
  text=text.replace("    call committed%snapshot(after_trial_state,available)\n    if(.not.available .or. .not.same_fmr_state(before_state,after_trial_state)) &\n         error stop 'A9 FMR top-input candidate leaked into committed state'", "    call check_heat(backend%observation(),candidate)\n    call committed%snapshot(after_trial_state,available)\n    if(.not.available .or. .not.same_fmr_state(before_state,after_trial_state)) &\n         error stop 'A9 FMR top-input candidate leaked into committed state'")
  text=text.replace("    call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &\n         kres,candidate,kdiag", "    ! Additional active-heat rejection checks below.\n    call backend%run_trial(column,template,fparams,committed,forcing,numerical,0.0_real64,fmr_dt,checkpoint, &\n         kres,candidate,kdiag",1)
  helper_heat='''
  subroutine check_heat(obs,cand)
    type(fmr_serialized_physical_observation_t),intent(in)::obs
    type(kernel_candidate_state_t),intent(in)::cand
    class(transaction_state_t),allocatable::s
    type(soil_temperature_field_view_t)::v
    logical::ok
    integer::code
    if(.not.obs%soil_temperature_executed.or.obs%soil_temperature_status/=0.or. &
      .not.obs%soil_temperature_energy_accounting_complete)error stop 'macro heat execution'
    if(abs(obs%soil_temperature_energy_residual_j_cm2)>1e-9_real64)error stop 'macro heat energy closure'
    call cand%snapshot(s,ok)
    if(.not.ok)error stop 'macro heat candidate'
    select type(s)
    class is(fmr_b110_physical_state_t)
      if(.not.allocated(s%soil_temperature))error stop 'macro heat lost state'
      call build_soil_temperature_field_view(s%soil_temperature,v,code)
      if(code/=0.or..not.any(v%temperature_c>12._real64))error stop 'macro heat inactive'
      write(*,'(a,*(es25.17e3,1x))')'MACRO_HEAT_CHECK_PASS ',obs%soil_temperature_energy_residual_j_cm2, &
        v%temperature_c
    class default
      error stop 'macro heat wrong candidate'
    end select
  end subroutine
'''
  text=text.replace('\ncontains\n','\ncontains\n'+helper_heat,1)
  text=text.replace('    ! Additional active-heat rejection checks below.',"    do negative_case=1,8\n      negative_params=fparams;negative_forcing=forcing\n      select case(negative_case)\n      case(1)\n        negative_params%soil_temperature%solution_mode=2\n        negative_params%soil_temperature%analytic_damping_depth_cm=10._real64\n      case(2)\n        negative_params%soil_temperature%active_nodes=numnod-1\n      case(3)\n        negative_params%soil_temperature%initialized=.false.\n      case(4)\n        deallocate(negative_forcing%soil_temperature)\n      case(5)\n        negative_forcing%soil_temperature%top_boundary_mode=99\n      case(6)\n        negative_forcing%soil_temperature%bottom_boundary_mode=99\n      case(7)\n        negative_params%root_salinity_active=.true.\n      case(8)\n        negative_params%picard_conductivity_iteration=.true.\n      end select\n      call negative_backend%initialize(top)\n      call negative_backend%configure_macropore_policy(policy,policy_ok)\n      if(.not.policy_ok)error stop 'bad heat policy'\n      call negative_backend%run_trial(column,template,negative_params,committed,negative_forcing,numerical, &\n        0._real64,fmr_dt,checkpoint,negative_result,negative_candidate,negative_diag, &\n        trusted_prepared_parameters=.true.,trace_accepted_water_flux_substeps=want_trace)\n      if(negative_result%completed.or.negative_candidate%ready())error stop 'invalid macro heat accepted'\n      call committed%snapshot(after_trial_state,available)\n      if(.not.available.or..not.same_fmr_state(before_state,after_trial_state))error stop 'invalid macro heat leaked'\n    end do\n    print '(a)','MACRO_HEAT_EIGHT_REJECTIONS_ATOMIC_PASS'\n",1)
 if a.root_drain:
  text=text.replace('  implicit none','  use mod_fmr_drainage_response_binding,only:FMR_DRAIN_VARIANT_DRAMET3\n  use mod_drainage_dramet3_response,only:initialize_dramet3_channel_control,DRAMET3_OK\n  implicit none',1)
  text=text.replace('  heads=-100.0_real64','  heads=-0.75_real64-z').replace('initial%groundwater_level=-200.0_real64','initial%groundwater_level=-0.75_real64')
  roots=a.root_drain in ['root','joint'];drains=a.root_drain in ['drain','joint']
  setup=''
  if roots:
   text=text.replace('potential_transpiration_dry_cm_per_day=0.0_real64','potential_transpiration_dry_cm_per_day=0.05_real64').replace('potential_transpiration_wet_cm_per_day=0.0_real64','potential_transpiration_wet_cm_per_day=0.025_real64')
  if roots:
   setup+='    fparams%root_extraction_active=.true.\n    allocate(forcing%substep_root)\n    forcing%substep_root%parameters%active_nodes=numnod\n    forcing%substep_root%parameters%hlim3l=-900._real64\n    forcing%substep_root%parameters%hlim3h=-500._real64\n    forcing%substep_root%parameters%hlim4=-16000._real64\n    forcing%substep_root%parameters%adcrl=.1_real64\n    forcing%substep_root%parameters%adcrh=.5_real64\n    forcing%substep_root%request%potential_transpiration=.05_real64\n    forcing%substep_root%request%rooted_nodes=numnod\n    forcing%substep_root%request%cumulative_root_fraction=[0._real64,.4_real64,.7_real64,.9_real64,1._real64]\n'
  if drains:
   setup+="    fparams%drainage_response_active=.true.\n    allocate(fparams%drainage_response_levels(1),fparams%drainage_trial_distribution,forcing%drainage_response_controls(1))\n    deallocate(forcing%drainage_flux_by_level)\n    fparams%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_DRAMET3\n    fparams%drainage_response_levels(1)%dramet3%drain_bottom_cm=-1.5_real64\n    fparams%drainage_response_levels(1)%dramet3%drainage_resistance_day=500._real64\n    fparams%drainage_response_levels(1)%dramet3%infiltration_resistance_day=220._real64\n    fparams%drainage_response_levels(1)%dramet3%allocation_mode=3\n    fparams%drainage_response_levels(1)%dramet3%drain_type=1\n    call initialize_dramet3_channel_control(fparams%drainage_response_levels(1)%dramet3_channel,0._real64,0._real64, &\n      [0._real64,1._real64],[-1.5_real64,-1.5_real64],rutter_status)\n    if(rutter_status/=DRAMET3_OK)error stop 'joint drain control'\n    fparams%drainage_trial_distribution%active_nodes=numnod\n    fparams%drainage_trial_distribution%dz=dz\n    fparams%drainage_trial_distribution%zbotcp=z-.5_real64*dz\n    fparams%drainage_trial_distribution%saturated_conductivity=fparams%cofgen(3,:)\n    fparams%drainage_trial_distribution%horizontal_anisotropy_factor=1._real64+0._real64*dz\n    fparams%drainage_trial_distribution%drain_spacing=1000._real64\n"
   text=text.replace('negative_params%drainage_response_active=.true.','negative_params%drainage_response_active=.false.')
  helper='tests/nut-sol/macro_root_drain_heat_checks.inc';inputs[helper]=sha((ROOT/helper).read_bytes())
  text=text.replace('\ncontains\n','\ncontains\n'+(ROOT/helper).read_text()+'\n',1)
  call='\n    call check_macro_root_drain(backend%observation(),'+('.true.'if roots else'.false.')+','+('.true.'if drains else'.false.')+')'
  text=text.replace("    call check_heat(backend%observation(),candidate)","    call check_heat(backend%observation(),candidate)"+call)
  negative='''
    do negative_case=1,4
      negative_params=fparams;negative_forcing=forcing
      select case(negative_case)
      case(2)
ROOT_OXYGEN
      case(3)
DRAIN_VARIANT
      case(4)
MISSING_OWNER
      end select
      call negative_backend%initialize(top)
      call negative_backend%configure_macropore_policy(policy,policy_ok)
      if(.not.policy_ok)error stop 'joint negative policy'
      call negative_backend%run_trial(column,template,negative_params,committed,negative_forcing,numerical, &
        0._real64,fmr_dt,checkpoint,negative_result,negative_candidate,negative_diag, &
        trusted_prepared_parameters=.true.,trace_accepted_water_flux_substeps=negative_case/=1)
      if(negative_result%completed.or.negative_candidate%ready())error stop 'invalid joint composition accepted'
      call committed%snapshot(after_trial_state,available)
      if(.not.available.or..not.same_fmr_state(before_state,after_trial_state))error stop 'invalid joint composition leaked'
    end do
    print '(a)','MACRO_ROOT_DRAIN_FOUR_REJECTIONS_ATOMIC_PASS'
'''
  negative=negative.replace('ROOT_OXYGEN','        negative_forcing%substep_root%parameters%empirical_oxygen_enabled=.true.'if roots else'        negative_params%root_salinity_active=.true.')
  negative=negative.replace('DRAIN_VARIANT','        negative_params%drainage_response_levels(1)%dramet3%drain_type=2'if drains else'        negative_params%root_salinity_active=.true.')
  negative=negative.replace('MISSING_OWNER','        deallocate(negative_params%drainage_trial_distribution)'if drains else'        deallocate(negative_forcing%substep_root)')
  at="    print '(a)','MACRO_HEAT_EIGHT_REJECTIONS_ATOMIC_PASS'\n";assert at in text;text=text.replace(at,at+negative,1)
  anchor='    call committed%snapshot(before_state,available)'
  text=text.replace(anchor,setup+anchor,1)
 # A9 direct runtime retains its existing bottom7; only the composed FMR call uses the admitted implicit BBC.
 if name=='trial':
  text=text.replace('p%bottom_mode=7','p%bottom_mode=3; if(migmac11)p%bottom_mode=7')
  text=text.replace('f%bottom_head=-100.0_real64','f%bottom_head=-100.0_real64'+"\n  if(.not.migmac11)then\n"+control('f')+"  end if\n")
  text=text.replace('result,candidate,diagnostics)','result,candidate,diagnostics,trace_accepted_water_flux_substeps=want_trace)')
  text=text.replace('  observation=backend%observation()','  observation=backend%observation()\n  if(want_trace)call check_macro_trace(observation)')
 else:
  text=text.replace('fparams%bottom_mode=7','fparams%bottom_mode=3')
  text=text.replace('forcing%bottom_head=-100.0_real64','forcing%bottom_head=-100.0_real64'+control('forcing'))
  text=text.replace('trusted_prepared_parameters=.true.)','trusted_prepared_parameters=.true.,trace_accepted_water_flux_substeps=want_trace)')
  # Every successful original backend call is checked; original unsupported calls retain their rejection assertions.
  for end,backend in [('kres,candidate,kdiag,trusted_prepared_parameters=.true.,trace_accepted_water_flux_substeps=want_trace)','backend'),('replay_result,replay_candidate,replay_diag,trusted_prepared_parameters=.true.,trace_accepted_water_flux_substeps=want_trace)','backend')]:
   assert end in text;text=text.replace(end,end+'\n    if(want_trace.and.'+end.split(',')[0]+'%completed)call check_macro_trace('+backend+'%observation())')
 helper='tests/nut-sol/macro_trace_checks.inc';inputs[helper]=sha((ROOT/helper).read_bytes());ix=text.index('\ncontains\n');text=text[:ix]+text[ix:].replace('\ncontains\n','\ncontains\n'+(ROOT/helper).read_text()+'\n',1)
 driver=out/(name+'.f90');driver.write_text(text);exe=out/name;r=run(fc+flags+['-J'+str(out),driver,*objects,*archives,'-o',exe],name+'-link');assert r.returncode==0,r.stderr.decode()
 cases=[('rutter-static',{'WU05_MIGMAC10':'1','WU05_MIGMAC10_RUTTER':'1','WU05_MIGMAC02_DYNAMIC':'3'})]
 if a.phase=='full':
  cases += [(f'rutter-{k}',{'WU05_MIGMAC10':'1','WU05_MIGMAC10_RUTTER':'1','WU05_MIGMAC02_DYNAMIC':str(k)})for k in [1,2]]
  if name=='trial':cases += [(f'rutter-{k}',{'WU05_MIGMAC10':'1','WU05_MIGMAC10_RUTTER':'1','WU05_MIGMAC02_DYNAMIC':str(k)})for k in [4,5]]
  if name=='trial':cases += [(f'pond-{k}',{'WU05_MIGMAC11':'1','WU05_MIGMAC11_'+k:'1','WU05_MIGMAC02_DYNAMIC':'3'})for k in ['RUNON','PARTIAL']]
 for label,env in cases:
  streams=[]
  for trace in ([1]if a.root_drain else[0,1]):
   work=out/(name+'-'+label+'-'+str(trace));work.mkdir();r=run([exe],name+'-'+label+'-'+str(trace),{**env,'MACRO_TRACE_ON':str(trace)},work);assert r.returncode==0,(name,label,trace,r.stderr.decode()[-3000:],r.stdout.decode()[-2000:]);streams.append(r.stdout)
  clean=lambda b:b'\n'.join(l for l in b.splitlines()if not l.startswith(b'MACRO_TRACE_CHECK_PASS'))
  assert a.root_drain or clean(streams[0])==clean(streams[1]),('observer changed original physical/native stream',name,label)
  checks=[l.decode().split()for l in streams[-1].splitlines()if l.startswith(b'MACRO_TRACE_CHECK_PASS')];assert checks
  results[name+'/'+label]=checks
for p,h in bindings.items():assert sha(Path(p).read_bytes())==h,p
inputs[str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__).read_bytes());result=dict(status='MACRO_TRACE_REAL_TRIAL_REPLAY_O0_O2_PHASE_PASS',phase=a.phase,root_drain=a.root_drain,results=results,provider_build=str(build),build_sha256=sha((build/'build-complete.json').read_bytes()),provider_bindings=bindings,input_sha256=inputs,events=events,qualified=False,canonically_admitted=False)
(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps({'cases':len(results),'events':len(events),'status':result['status']}))
