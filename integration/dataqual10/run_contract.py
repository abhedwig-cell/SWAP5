import json,subprocess,time,hashlib
from pathlib import Path
root=Path.cwd();out=Path('/tmp/dq10-contract');out.mkdir(exist_ok=True);all_results=[]
for opt in ['O0','O2']:
 base=Path('/tmp/dq09-'+opt+'/shared');b=json.load(open(base/'build-complete.json'));fc=b['compiler_command'];flags=[f for f in b['flags']if not f.startswith(('-I','-J'))]
 for policy in ['baseline','candidate']:
  folder=out/(opt+'-'+policy);folder.mkdir(exist_ok=True);events=[];objects=[]
  binding=json.loads((root/('integration/dataqual09/BUILD_'+opt+'.json')).read_bytes())
  for p,h in b['input_sha256'].items():
   if not p.endswith('/mod_ppa_wu05a15_exchange_derivative.f90'):assert hashlib.sha256((root/p).read_bytes()).hexdigest()==h,p
  def run(c,label):
   t=time.monotonic();cp=subprocess.run(list(map(str,c)),cwd=folder,capture_output=True);events.append(dict(command=list(map(str,c)),category=label,seconds=time.monotonic()-t,returncode=cp.returncode));(folder/(label+'.stdout')).write_bytes(cp.stdout);(folder/(label+'.stderr')).write_bytes(cp.stderr);assert cp.returncode==0,(label,cp.stderr[-1000:]);return cp
  for e in b['events']:
   if e['category']!='compile' or e['command'][-3].endswith('/app/solute_crop/main.f90'):continue
   obj=e['command'][-1]
   assert hashlib.sha256(Path(obj).read_bytes()).hexdigest()==binding['reused_artifact_sha256'][obj],obj
   if policy=='candidate'and e['command'][-3].endswith('/mod_ppa_wu05a15_exchange_derivative.f90'):
    obj=folder/'derivative.o';run(fc+flags+['-I'+str(base),'-J'+str(folder),'-c',root/'src/process/macropore/mod_ppa_wu05a15_exchange_derivative.f90','-o',obj],'changed-module')
   objects.append(obj)
  extra=[root/'app/solute_column'/p for p in ['read_swp_macro_geometry.f90','read_swp_macro_initial.f90','read_swp_macro_configuration.f90']]
  run(fc+flags+['-I'+str(folder),'-I'+str(base),'-J'+str(folder),*extra,root/'tests/nut-sol/test_dataqual10_limiter_jacobian.f90',*objects,base/'libttutil.a','-o',folder/'driver'],'compile-link')
  c=[folder/'driver','/tmp/dq09-pairs-O2/low-v0p001-r1-e2/quiet/macro.nml']
  if policy=='baseline':c+=['expect-defect']
  cp=run(c,'native');all_results.append(dict(optimization=opt,policy=policy,events=events,result=cp.stdout.decode().splitlines()[-1],legacy_lines=[x for x in cp.stdout.decode().splitlines()if x.startswith('LEGACY')]))
 assert all_results[-1]['legacy_lines']==all_results[-2]['legacy_lines'],'production default derivative changed'
(out/'RESULT.json').write_text(json.dumps(all_results,indent=2)+'\n');print(json.dumps([{k:r[k]for k in ['optimization','policy','result']}for r in all_results],indent=2))
