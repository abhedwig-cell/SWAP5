#!/usr/bin/env python3
"""Bounded independent native SWAP5 runs from a versioned JSON manifest."""
import argparse,csv,gzip,hashlib,json,math,re,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write_json(p,v):p.write_text(json.dumps(v,indent=2,allow_nan=False)+'\n')
def rows(p):
 if not p.exists():return []
 with p.open() as f:return list(csv.DictReader(f))
def modify(folder,op):
 p=folder/op['file'];text=p.read_bytes().decode('utf-8')
 if op['kind']=='replace':
  text,n=re.subn(op['pattern'],op['replacement'],text,flags=re.M|re.I)
  if n!=op['count']:raise ValueError(f'patch count {p.name}: {n} != {op["count"]}')
 elif op['kind']=='scale_table':
  lines=text.splitlines(keepends=True);active=False;n=0
  for i,line in enumerate(lines):
   if re.search(op['header'],line,re.I):active=True;continue
   if not active or not line.strip() or line.lstrip().startswith(('*','!')):continue
   if '=' in line:active=False;continue
   fields=line.split();col=op['column']
   try:value=float(fields[col])
   except (ValueError,IndexError):active=False;continue
   value=value*op['factor'];fields[col]=format(value,'.10e');lines[i]=' '.join(fields)+'\n';n+=1
  if n!=op['count']:raise ValueError(f'table count {p.name}: {n} != {op["count"]}')
  text=''.join(lines)
 else:raise ValueError('unknown input transformation')
 p.write_bytes(text.encode())
def assess(folder,target):
 b=rows(folder/'budget.csv');pr=rows(folder/'progress.csv');state=rows(folder/'state.csv');temp=rows(folder/'temperature.csv')
 values=[float(v)for row in b+pr+state+temp for v in row.values()]
 finite=bool(b and state and temp)and all(math.isfinite(v)for v in values)
 cert=['max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']
 physical=finite and len(state)==len(temp)and all(0<=float(r['theta'])<=1 for r in state)
 certificates=physical and all(abs(float(r[k]))<=1e-10 for r in b for k in cert)and all(int(r['mass_rejections'])==0 for r in pr)
 end=float(b[-1]['t1'])if b else 0.
 complete=certificates and abs(end-target)<=1e-9 and (folder/'restart.bin').is_file()
 sums={k:sum(int(r[k])for r in pr)for k in ['attempts','solver_rejections','temporal_rejections','mass_rejections']}
 return dict(physical_complete=complete,completed_days=end,water_max_independent_cm=max((abs(float(r[k]))for r in b for k in cert),default=None),
  water_max_daily_residual_cm=max((abs(float(r['water_residual_cm']))for r in b),default=None),
  **sums,solver_iterations=None,solute_balance='not_applicable_SWSOLU0',
  flux_totals_cm={k:sum(float(r[k])for r in b)for k in ['root_cm','drainage_cm','rapid_cm','runoff_cm','bottom_cm','soil_evap_cm','pond_to_macro_cm','direct_macro_cm']},
  last_reported_interval_t0=float(pr[-1]['t0'])if pr else None,diagnostic_counts='completed_or_returned_intervals_only_inflight_unavailable')
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('manifest',type=Path);ap.add_argument('--bundle',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 spec=json.loads(a.manifest.read_text());out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 source=ROOT/spec['source_directory'];bundle=a.bundle.resolve();results=[]
 baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 write_json(out/'batch.json',dict(manifest=spec,manifest_sha256=sha(a.manifest),source_commit=baseline,
  dirty=subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True),bundle_sha256=sha(bundle/'bundle.json')))
 ids=[s['id']for s in spec['scenarios']]
 if len(ids)!=len(set(ids))or any(not re.fullmatch(r'[a-zA-Z0-9_-]+',s)for s in ids):raise ValueError('unique safe scenario IDs required')
 def save():
  write_json(out/'results.json',results)
  keys=['id','mode','status','completed_days','seconds','seconds_per_day','attempts','solver_rejections','temporal_rejections','mass_rejections','water_max_independent_cm','restart','failure']
  with(out/'summary.csv').open('w',newline='')as f:
   w=csv.DictWriter(f,fieldnames=keys,extrasaction='ignore');w.writeheader();w.writerows(results)
 for scenario in spec['scenarios']:
  case=out/scenario['id'];case.mkdir();inputs=case/'inputs';inputs.mkdir()
  for name in spec['input_files']:
   (inputs/name).write_bytes(gzip.decompress((source/('b111-'+name+'.gz')).read_bytes()))
  r=dict(id=scenario['id'],mode=scenario.get('mode','experimental'),configuration=scenario,source_commit=baseline,restart='not_tested',comparison='not_available',solver_iterations=None)
  start=time.monotonic()
  try:
   for op in scenario.get('transformations',[]):modify(inputs,op)
   r['input_sha256']={p.name:sha(p)for p in inputs.iterdir()}
   cmd=[sys.executable,str(ROOT/'tools/solute/run_native_water.py'),str(inputs/'swap.swp'),'--bundle',str(bundle),'--output',str(case/'run'),'--mode',r['mode'],
    '--stop-after',str(scenario['days']),'--timeout-seconds',str(scenario.get('timeout_seconds',spec['timeout_seconds']))]
   if 'stop_at_time'in scenario:cmd+=['--stop-at-time',str(scenario['stop_at_time'])]
   if scenario.get('anchored',True):cmd+=['--anchored-cauchy','--entry-ramp-width-cm',str(scenario.get('entry_width_cm',1e-4))]
   with(case/'launcher.stdout').open('wb')as so,(case/'launcher.stderr').open('wb')as se:
    cp=subprocess.run(cmd,cwd=ROOT,stdout=so,stderr=se,timeout=scenario.get('timeout_seconds',spec['timeout_seconds'])+240)
   r.update(assess(case/'run',scenario.get('stop_at_time',scenario['days'])))
   manifest=json.loads((case/'run/manifest.json').read_text())if(case/'run/manifest.json').exists()else{}
   native=next((e for e in manifest.get('events',[])if e['label']=='native'),{})
   r['seconds']=native.get('seconds',time.monotonic()-start)
   r['seconds_per_day']=r['seconds']/r['completed_days']if r['completed_days']>0 else None
   r['status']='PASS'if cp.returncode==0 and r['physical_complete']else'CENSORED'if native.get('censored')else'FAILED'
   log='\n'.join(p.read_text(errors='replace')for p in [case/'run/native.stdout',case/'run/native.stderr',case/'run/source_initial.stdout',case/'launcher.stderr']if p.exists())
   lines=[line.strip()for line in log.splitlines()if any(k in line for k in ['REJECTED','Error','error stop','ValueError','AssertionError'])]
   r['failure']='; '.join(lines[-4:])if r['status']!='PASS'else''
   if r['status']=='PASS'and scenario.get('restart_check')and scenario['days']>=2:
    for end,label,restart in [(1,'split',None),(scenario['days'],'resumed',case/'split/restart.bin')]:
     c=cmd.copy();c[c.index('--output')+1]=str(case/label);c[c.index('--stop-after')+1]=str(end)
     if label=='split'and'--stop-at-time'in c:
      pos=c.index('--stop-at-time');del c[pos:pos+2]
     if restart:c+=['--restart',str(restart)]
     with(case/(label+'.stdout')).open('wb')as so,(case/(label+'.stderr')).open('wb')as se:
      part=subprocess.run(c,cwd=ROOT,stdout=so,stderr=se,timeout=spec['timeout_seconds']+240)
     if part.returncode:raise ValueError('restart execution failed '+label)
    files=['state.csv','temperature.csv']
    exact=all((case/'run'/f).read_bytes()==(case/'resumed'/f).read_bytes()for f in files)
    # File binding header may include path-independent executable/source identity; compare entire files too.
    exact=exact and (case/'run/restart.bin').read_bytes()==(case/'resumed/restart.bin').read_bytes()
    r['restart']='exact'if exact else'mismatch'
    if not exact:r['status']='FAILED';r['failure']='restart mismatch'
   r['slow']=r['status']=='CENSORED'or(r['seconds_per_day']is not None and r['seconds_per_day']>spec['slow_seconds_per_day'])
  except Exception as e:
   r.update(status='FAILED',failure=type(e).__name__+': '+str(e),seconds=time.monotonic()-start)
  results.append(r);save();print(json.dumps({k:r.get(k)for k in ['id','status','completed_days','seconds','failure']}),flush=True)
if __name__=='__main__':main()
