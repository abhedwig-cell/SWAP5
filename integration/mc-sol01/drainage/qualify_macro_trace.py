"""Real incumbent trial/replay bodies plus independent external macro trace checks."""
import argparse,hashlib,json,os,re,resource,subprocess,time,gzip,datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--phase',choices=['pilot','full'],default='full');a=p.parse_args();build=a.build.resolve();out=a.output.resolve();out.mkdir();sha=lambda b:hashlib.sha256(b).hexdigest()
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
   assert end in text;text=text.replace(end,end+'\n    if(want_trace)call check_macro_trace('+backend+'%observation())')
 helper='tests/nut-sol/macro_trace_checks.inc';inputs[helper]=sha((ROOT/helper).read_bytes());ix=text.index('\ncontains\n');text=text[:ix]+text[ix:].replace('\ncontains\n','\ncontains\n'+(ROOT/helper).read_text()+'\n',1)
 driver=out/(name+'.f90');driver.write_text(text);exe=out/name;r=run(fc+flags+['-J'+str(out),driver,*objects,*archives,'-o',exe],name+'-link');assert r.returncode==0,r.stderr.decode()
 cases=[('rutter-static',{'WU05_MIGMAC10':'1','WU05_MIGMAC10_RUTTER':'1','WU05_MIGMAC02_DYNAMIC':'3'})]
 if a.phase=='full':
  cases += [(f'rutter-{k}',{'WU05_MIGMAC10':'1','WU05_MIGMAC10_RUTTER':'1','WU05_MIGMAC02_DYNAMIC':str(k)})for k in [1,2]]
  if name=='trial':cases += [(f'rutter-{k}',{'WU05_MIGMAC10':'1','WU05_MIGMAC10_RUTTER':'1','WU05_MIGMAC02_DYNAMIC':str(k)})for k in [4,5]]
  if name=='trial':cases += [(f'pond-{k}',{'WU05_MIGMAC11':'1','WU05_MIGMAC11_'+k:'1','WU05_MIGMAC02_DYNAMIC':'3'})for k in ['RUNON','PARTIAL']]
 for label,env in cases:
  streams=[]
  for trace in [0,1]:
   work=out/(name+'-'+label+'-'+str(trace));work.mkdir();r=run([exe],name+'-'+label+'-'+str(trace),{**env,'MACRO_TRACE_ON':str(trace)},work);assert r.returncode==0,(name,label,trace,r.stderr.decode()[-3000:],r.stdout.decode()[-2000:]);streams.append(r.stdout)
  clean=lambda b:b'\n'.join(l for l in b.splitlines()if not l.startswith(b'MACRO_TRACE_CHECK_PASS'))
  assert clean(streams[0])==clean(streams[1]),('observer changed original physical/native stream',name,label)
  checks=[l.decode().split()for l in streams[1].splitlines()if l.startswith(b'MACRO_TRACE_CHECK_PASS')];assert checks
  results[name+'/'+label]=checks
for p,h in bindings.items():assert sha(Path(p).read_bytes())==h,p
inputs[str(Path(__file__).relative_to(ROOT))]=sha(Path(__file__).read_bytes());result=dict(status='MACRO_TRACE_REAL_TRIAL_REPLAY_O0_O2_PHASE_PASS',phase=a.phase,results=results,provider_build=str(build),build_sha256=sha((build/'build-complete.json').read_bytes()),provider_bindings=bindings,input_sha256=inputs,events=events,qualified=False,canonically_admitted=False)
(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(json.dumps({'cases':len(results),'events':len(events),'status':result['status']}))
