"""Run original serialized FMR replay bodies with explicit covered receipt oracles."""
import argparse,hashlib,json,os,re,resource,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--build',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--baseline',action='store_true');a=ap.parse_args();out=a.output.resolve();out.mkdir();base=a.build.resolve();b=json.loads((base/'build-complete.json').read_text());assert b['status']=='BUILT';events=[];results={}
 resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
 for p,h in b['input_sha256'].items():
  data=subprocess.check_output(['git','show','9d108ee89ae6e1e19d8705a696779555a4a0491c:'+p],cwd=ROOT) if a.baseline else(ROOT/p).read_bytes()
  assert hashlib.sha256(data).hexdigest()==h,p
 link=next(e['command']for e in b['events']if e['category']=='link');objects=[Path(x)for x in link if x.endswith('.o')][:-1];archives=[Path(x)for x in link if x.endswith('.a')];flags=[f for f in b['flags']if not f.startswith('-J')];fc=b['compiler_command'];bindings={str(p):sha(p)for p in objects+archives+list(base.glob('*.mod'))}
 source=ROOT/'tests/fpm/test_ppa_wu05a9_fmr_top_input_replay.f90';text=source.read_text();text,n=re.subn(r'real\(real64\)::heads\(numnod\),water\(numnod\),cond\(numnod\),cap\(numnod\),dkdh\(numnod\)','real(real64),allocatable::heads(:),water(:),cond(:),cap(:),dkdh(:)',text);assert n==1
 text=text.replace('  implicit none','  use variables,only:context_qrot=>qrot\n  use mod_fmr_serialized_reference_backend,only:fmr_serialized_physical_observation_t\n  implicit none\n  logical::want_trace,wet\n  character(len=1)::trace_flag,wet_flag\n',1)
 at=text.index("  call get_environment_variable(");text=text[:at]+'''  numnod=4
  allocate(context_qrot(4));context_qrot=0._real64
  allocate(z(4),dz(4),disnod(5),heads(4),water(4),cond(4),cap(4),dkdh(4))
  z=[-.25_real64,-.75_real64,-1.5_real64,-2.5_real64]
  dz=[.5_real64,.5_real64,1._real64,1._real64];disnod=1._real64
  call get_environment_variable('MACRO_TRACE_ON',trace_flag);want_trace=trace_flag=='1'
  call get_environment_variable('COVER_WET',wet_flag);wet=wet_flag=='1'
'''+text[at:]
 text=text.replace("  if(cover_flag=='1' .or. cover_flag=='2')macro_top=3","  if(cover_flag=='1' .or. cover_flag=='2')macro_top=3\n  if(wet)macro_top=4")
 text=text.replace('  heads=-100.0_real64','  heads=-100.0_real64\n  if(wet)heads=-.5_real64-z')
 start=text.index('  ! Disabled path:');end=text.index('\ncontains\n',start);policy=text[text.index('  policy%enabled=.true.',start):text.index('  call runtime%execute',text.index('  policy%enabled=.true.',start))];text=text[:start]+policy+"  call exercise_serialized_fmr()\n  print '(a)','COVERED_MACRO_REPLAY_PASS'\n"+text[end:]
 text=text.replace('    fmr_dt=fmr_dt_base\n','    fmr_dt=fmr_dt_base\n    ! Small saturated interface trial; no temporal tolerance change.\n    if(wet)fmr_dt=fmr_dt_base/4096._real64\n',1)
 text=text.replace('forcing%bottom_head=-100.0_real64','forcing%bottom_head=-100.0_real64\n    if(wet)forcing%bottom_head=2.5_real64')
 text=text.replace('trusted_prepared_parameters=.true.)','trusted_prepared_parameters=.true.,trace_accepted_water_flux_substeps=want_trace)')
 for suffix in ['kres,candidate,kdiag','replay_result,replay_candidate,replay_diag']:
  end=suffix+',trusted_prepared_parameters=.true.,trace_accepted_water_flux_substeps=want_trace)';assert end in text;text=text.replace(end,end+'\n    if(want_trace)call check_macro_trace(backend%observation())')
 helper=ROOT/('tests/nut-sol/macro_trace_checks.inc'if a.baseline else'tests/nut-sol/covered_macro_trace_checks.inc');text=text.replace('\ncontains\n','\ncontains\n'+helper.read_text()+'\n',1)
 driver=out/'replay.f90';driver.write_text(text);exe=out/'replay'
 def run(cmd,label,env=None,cwd=out):
  t=time.monotonic();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,env={**os.environ,**(env or {})},timeout=120)
  for name in ['stdout','stderr']:(out/(label+'.'+name)).write_bytes(getattr(cp,name))
  events.append(dict(label=label,command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-t));(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');return cp
 cp=run(fc+flags+['-J'+str(out),driver,*objects,*archives,'-o',exe],'link');assert cp.returncode==0,cp.stderr.decode()[-2500:]
 for wet in [0,1]:
  for trace in [0,1]:
   label=f'wet{wet}-trace{trace}';work=out/label;work.mkdir();cp=run([exe],label,{'WU05_MIGMAC08_COVER':'1','WU05_MIGMAC02_DYNAMIC':'3'if wet else'1','COVER_WET':str(wet),'MACRO_TRACE_ON':str(trace)},work);results[label]={'returncode':cp.returncode,'stdout_sha256':hashlib.sha256(cp.stdout).hexdigest(),'stderr':cp.stderr.decode()[-1500:]}
 r=dict(status='BASELINE_OBSERVED'if a.baseline else'REPLAY_OBSERVED',baseline=a.baseline,build=b,input_sha256={**b['input_sha256'],str(source.relative_to(ROOT)):sha(source),str(helper.relative_to(ROOT)):sha(helper),str(Path(__file__).relative_to(ROOT)):sha(Path(__file__))},provider_bindings=bindings,results=results,events=events,qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(results,indent=2))
if __name__=='__main__':main()
