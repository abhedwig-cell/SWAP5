#!/usr/bin/env python3
"""Two-day real Reference wet/drying qualification; optional exact live object reuse.
Cold: FC=gfortran python integration/audits/surface_age_longrun/run.py --out /tmp/age02
Reuse: add --reuse /path/to/completed/run_age.py/output (all sources must match).
No production changes, admission guard bypass, or stored binary cache is introduced.
"""
import argparse,hashlib,json,os,pathlib,shlex,shutil,subprocess,time
P=pathlib.Path;ROOT=P(__file__).resolve().parents[3];HERE=P(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--reuse');p.add_argument('--pilot',action='store_true');a=p.parse_args()
OUT=P(a.out).resolve();OUT.mkdir(exist_ok=False,parents=True)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];inputs={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def bind(p):inputs[str(p.relative_to(ROOT))]=sha(p)
def run(cmd,cwd,category):
 t=time.perf_counter();n=f'{len(events):04d}'
 with (OUT/(n+'.stdout')).open('wb')as so,(OUT/(n+'.stderr')).open('wb')as se:
  r=subprocess.run(list(map(str,cmd)),cwd=cwd,stdout=so,stderr=se)
 stdout=(OUT/(n+'.stdout')).read_text();stderr=(OUT/(n+'.stderr')).read_text()
 events.append(dict(command=list(map(str,cmd)),category=category,seconds=time.perf_counter()-t,returncode=r.returncode,stdout=n+'.stdout',stderr=n+'.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:print(stdout,stderr,flush=True);r.check_returncode()
 return stdout
for path in HERE.glob('*'):
 if path.is_file():bind(path)
compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0]
if a.reuse:old=P(a.reuse).resolve()
else:
 old=OUT/'cold';run(['env','AGE_RESULT_DIR='+str(old),'FC='+shlex.join(FC),'python3',ROOT/'tests/nut-sol/run_age.py'],ROOT,'cold_build_and_incumbents')
r=json.loads((old/'result.json').read_text());ee=json.loads((old/'events.json').read_text())
assert r['status']=='PHYSICAL_PASS_NOT_ADMITTED' and r['compiler']==compiler
assert all(e['returncode']==0 for e in ee)
for path,h in r['input_sha256'].items():assert sha(ROOT/path)==h,path;inputs[path]=h
# Retain the complete existing cold compile/link provenance and original source identity.
(OUT/'provider_result.json').write_text(json.dumps(r,indent=2)+'\n')
(OUT/'provider_events.json').write_text(json.dumps(ee,indent=2)+'\n')
artifacts={};results={};levels=[4] if a.pilot else [4,8,16]
for opt in (['O0'] if a.pilot else ['O0','O2']):
 build=OUT/opt;build.mkdir();provider=old/opt
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
 for f in provider.glob('*.mod'):shutil.copy2(f,build/f.name);artifacts[str(f)]=sha(f)
 for name in ['matrix_fixture.inc','literal_age.f90']:shutil.copy2(provider/name,build/name);artifacts[str(provider/name)]=sha(provider/name)
 linked=[e for e in ee if e['category']=='physical_link' and '-'+opt in e['command']]
 assert len(linked)==1
 objects=[P(x)for x in linked[0]['command']if x.endswith('.o')][:-1]
 for obj in objects:
  records=[e for e in ee if e['category']=='physical_compile' and e['command'][-1]==str(obj)]
  assert len(records)==1 and '-'+opt in records[0]['command'] and obj.is_file()
  artifacts[str(obj)]=sha(obj)
 # Re-execute original admitted native triplet before reusing providers.
 incumbent=run([provider/'surface','resume',provider/'triplet.bin',build/'incumbent.bin'],build,'incumbent_native')
 assert 'SURFACE_AGE_REAL_REFERENCE_TRIPLET=PASS' in incumbent
 assert (build/'incumbent.bin').read_bytes()==(provider/'surface_expected.bin').read_bytes()
 for driver in ['driver','dry_limit']:
  obj=build/(driver+'.o');exe=build/driver
  run(FC+flags+['-c',HERE/(driver+'.f90'),'-o',obj],build,'leaf_compile')
  run(FC+flags+objects+[obj,'-o',exe],build,'leaf_link')
 assert 'COMPLETE_DRY_LIMIT_REJECTED_WITHOUT_MUTATION=PASS' in run([build/'dry_limit'],build,'dry_limit_native')
 results[opt]={}
 for level in levels:
  snapshot=build/f'level{level}.snapshot';endpoint=build/f'level{level}.endpoint'
  # Save in wet phase; also take independent checkpoints at transitions and drying.
  cut=-1 if level==levels[-1] and not a.pilot else 1550*level
  stdout=run([build/'driver','write',level,snapshot,endpoint,cut],build,'long_native')
  assert 'SURFACE_AGE_TWO_DAY_REFERENCE=PASS' in stdout
  summaries=[list(map(float,l.split()[1:]))for l in stdout.splitlines()if l.startswith('SUMMARY ')]
  totals=[list(map(float,l.split()[1:]))for l in stdout.splitlines()if l.startswith('TOTAL_AGE_CM_DAY ')]
  assert len(summaries)==len(totals)==1 and summaries[0][0]==2.
  assert [int(l.split()[1])for l in stdout.splitlines()if l.startswith('EXECUTED_WINDOWS ')]==[2000*level]
  results[opt][str(level)]=dict(summary=summaries[0],age_budget=totals[0],endpoint_sha256=sha(endpoint),restarts=[])
  if a.pilot:continue
  # At finest mesh check wet, wet->dry, dry, dry->wet; all in fresh OS processes.
  for cut in ([1550*level,1600*level,1850*level,1500*level] if level==levels[-1] else [1550*level]):
   if level==levels[-1]:snapshot=build/f'level{level}.snapshot.cut{cut}'
   fresh=build/f'level{level}-fresh{cut}.endpoint'
   resumed=run([build/'driver','resume',level,snapshot,fresh,cut],build,'restart_native')
   assert fresh.read_bytes()==endpoint.read_bytes()
   results[opt][str(level)]['restarts'].append(dict(cut=cut,fresh_sha256=sha(fresh)))
 print('FINISHED',opt,flush=True)
if not a.pilot:
 for level in levels:
  assert (OUT/'O0'/f'level{level}.endpoint').read_bytes()==(OUT/'O2'/f'level{level}.endpoint').read_bytes()
 # Adaptive hydraulic meshes differ: test measured stabilization, no claimed formal order.
 for opt in results:
  v=[results[opt][str(l)]['summary'][3:5]for l in levels]
  steps=[]
  for level in levels:
   e=next(e for e in events if e['category']=='long_native'and '/'+opt+'/'in e['command'][0]and e['command'][2]==str(level))
   text=(OUT/e['stdout']).read_text()
   steps.append(next(float(l.split()[2])for l in text.splitlines()if l.startswith('ACTUAL_STEPS ')))
  assert steps[1]<=.501*steps[0]and steps[2]<=.501*steps[1],('actual accepted mesh did not refine',steps)
  results[opt]['actual_max_dt_day']=steps
  differences=[[abs(v[j+1][k]-v[j][k]) for k in range(2)]for j in range(2)]
  for k in range(2):
   assert differences[1][k]<differences[0][k],(opt,k,differences)
   assert differences[1][k]/max(1.,abs(v[-1][k]))<1e-3,(opt,k,differences)
  results[opt]['refinement_differences']=differences
assert all(sha(ROOT/q)==h for q,h in inputs.items())
assert all(sha(P(q))==h for q,h in artifacts.items())
result=dict(status='PILOT_PASS' if a.pilot else 'TWO_DAY_REFERENCE_QUALIFIED_BOUNDED',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=compiler,input_sha256=inputs,reused_artifact_sha256=artifacts,provider_execution=r['baseline'],results=results,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in {e['category']for e in events}})
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],result['cost_seconds'])
