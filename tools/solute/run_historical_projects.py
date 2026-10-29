#!/usr/bin/env python3
"""Run original distribution projects independently; keep process-only results distinct.

Requires a current tools/solute/build_project.py --native-water bundle.
No physical selector or parameter in the original inputs is changed.
"""
import argparse,csv,hashlib,json,math,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PROJECTS=ROOT/'reference/swap-4.3.1/projects'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--days',type=int,default=5);p.add_argument('--timeout-seconds',type=float,default=30)
 a=p.parse_args()
 if a.days<1 or not math.isfinite(a.timeout_seconds) or a.timeout_seconds<=0:p.error('positive bounds required')
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 bundle=json.loads((a.bundle/'bundle.json').read_text());physical=bundle['physical_build']
 base=Path(a.bundle).resolve()/'shared'
 if not(base/'libttutil.a').is_file():raise ValueError('bundle must include its cold physical build')
 archive_meta=json.loads((a.bundle/'column/build-complete.json').read_text())
 assert sha(base/'libttutil.a')==archive_meta['reused_artifact_sha256'][str(base/'libttutil.a')]
 assert subprocess.check_output(physical['compiler_command']+['--version'],text=True).splitlines()[0]==physical['compiler']
 assert all(sha(ROOT/k)==v for k,v in physical['input_sha256'].items())
 assert all(sha(base/k)==v for k,v in physical['generated_input_sha256'].items())
 manifest=json.loads((PROJECTS/'MANIFEST.json').read_text())
 for name,row in manifest['members'].items():
  f=PROJECTS/name;assert sha(f)==row['sha256'] and f.stat().st_size==row['bytes']
 fc=physical['compiler_command'];flags=['-'+bundle['optimization'],'-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(out)]
 commands=[]
 def run(cmd,folder,label,timeout=60):
  start=time.monotonic()
  with(folder/(label+'.stdout')).open('wb')as so,(folder/(label+'.stderr')).open('wb')as se:
   try:r=subprocess.run(list(map(str,cmd)),cwd=folder,stdin=subprocess.DEVNULL,stdout=so,stderr=se,timeout=timeout);rc=r.returncode
   except subprocess.TimeoutExpired:rc=None
  event=dict(command=list(map(str,cmd)),returncode=rc,seconds=time.monotonic()-start)
  commands.append(event);return event
 for name,sources in [('inspect',['app/solute_project/inspect_historical.f90']),('duration',['src/process/mod_daily_rain_duration.f90','app/solute_project/prepare_rain_duration.f90'])]:
  e=run(fc+flags+[str(ROOT/s)for s in sources]+[base/'libttutil.a','-o',out/name],out,'build-'+name)
  if e['returncode']!=0:raise RuntimeError('native adapter build failed: '+name)
 results=[]
 for name in ['1.hupselbrook','2.grassgrowth','3.macroporeflow','4.salinitystress/tools/template']:
  case=out/name.split('/')[0];case.mkdir();swp=PROJECTS/name/'swap.swp'
  (case/'input.swp').write_bytes(swp.read_bytes())
  inspect=run([out/'inspect','input.swp'],case,'inspect')
  selectors=list(csv.DictReader((case/'capabilities.csv').open()))if inspect['returncode']==0 else []
  launch=run([sys.executable,ROOT/'tools/solute/run_native_water.py',swp,'--bundle',a.bundle.resolve(),'--output',case/'model',
   '--mode','experimental','--stop-after',a.days,'--timeout-seconds',a.timeout_seconds],case,'launcher',a.timeout_seconds+180)
  record=dict(project=name,original_swp_sha256=sha(swp),selectors=selectors,launcher=launch,
   full_project_qualified=False,model_completed_days=0.,restart='not_tested',historical_comparison='not_tested')
  model=case/'model';budget=model/'budget.csv'
  if budget.is_file():
   rows=list(csv.DictReader(budget.open()))
   if rows:
    record['model_completed_days']=float(rows[-1]['t1'])
    keys=['water_residual_cm','max_macro_cell_cm','max_matrix_cm','max_combined_cm','max_net_source_cm']
    record['water_max_abs_cm']={k:max(abs(float(r[k]))for r in rows)for k in keys}
  record['native_started']=(model/'manifest.json').is_file()and any(e['label']=='native' for e in json.loads((model/'manifest.json').read_text())['events'])
  if name=='2.grassgrowth':
   (case/'input.met').write_bytes((PROJECTS/name/'260.met').read_bytes())
   e=run([out/'duration','input.swp','input.met'],case,'duration')
   record['duration_process']=dict(event=e,whole_model=False)
  record['files']={str(f.relative_to(case)):sha(f)for f in case.rglob('*')if f.is_file()}
  results.append(record)
 report=dict(schema=1,distribution_sha256=manifest['distribution_sha256'],candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  independent_original_projects=3,template_sets=1,results=results,commands=commands,
  claim='Preparation failure is not model execution. Duration forcing is not integrated Grassgrowth qualification.')
 (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(dict(projects=3,output=str(out),model_processes=sum(r['native_started']for r in results))))
if __name__=='__main__':main()
