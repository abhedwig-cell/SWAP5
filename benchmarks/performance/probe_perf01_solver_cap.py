"""Research-only accepted-step cap after solver rejection; never production.

The original retained-proposal runtime remains available as the comparator.
All full/half, mass, solver, retry and app whole-day fallback gates stay intact.
"""
import argparse,csv,hashlib,json,os,statistics,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FILES=['budget.csv','state.csv','endpoint.csv','restart.bin']
RUNTIME='src/runtime/mod_canonical_interval_runtime.f90'
APP='app/solute_project/main.f90'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return list(csv.DictReader(p.open()))
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--bundle-prefix',type=Path,required=True);ap.add_argument('--oracle',type=Path,required=True)
 ap.add_argument('--compiler',required=True);ap.add_argument('--output',type=Path,required=True)
 a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 report=dict(status='RUNNING',production_changed=False,policy_changed_in_generated_probe_only=True,
  candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),script_sha256=sha(Path(__file__)),
  events=[],cases={},builds={},criteria=dict(daily_gross_water_mm=1e-9,daily_runoff_mm=.01,season_runoff_mm=.01,daily_storage_mm=.01,daily_total_evaporation_mm=1e-8,daily_transpiration_mm=1e-8))
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,label,expected_success=True):
  cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=60)
  for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
  report['events'].append(dict(label=label,command=cmd,seconds=time.perf_counter()-t,returncode=r.returncode));save()
  if expected_success:r.check_returncode()
  return r
 core=min(os.sched_getaffinity(0));report['core']=core
 for opt in ['O0','O2']:
  bundle=json.loads((Path(str(a.bundle_prefix)+'-'+opt)/'bundle.json').read_text());old=Path(bundle['exe'])
  meta=json.loads((old.parent/'build-complete.json').read_text());assert sha(old)==meta['executable_sha256']
  assert subprocess.check_output([a.compiler,'--version'],text=True).splitlines()[0]==meta['compiler']
  for p,h in meta['input_sha256'].items():
   if p!=APP:assert sha(ROOT/p)==h,p
  for p,h in meta['reused_artifact_sha256'].items():assert sha(Path(p))==h,p
  folder=out/opt;folder.mkdir();flags=[x for x in meta['flags']if not x.startswith('-J')]
  objects=[e['command'][-1]for e in meta['source_build']['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')]
  assert len(objects)==193
  archive=next(p for p in meta['reused_artifact_sha256']if p.endswith('/libttutil.a'))
  ordinary=folder/'ordinary';probe=folder/'probe'
  run([a.compiler,*flags,'-J'+str(folder),ROOT/APP,*objects,archive,'-o',ordinary],folder,opt+'-ordinary-build')
  raw=(ROOT/RUNTIME).read_text();anchor='      cursor = next_cursor'
  assert raw.count(anchor)==1
  raw=raw.replace(anchor,'''      ! RESEARCH ONLY: after a successful solver-limited transaction, retain
      ! its accepted size without temporal-only growth for this interval.
      if(config%retain_accepted_step_proposal.and.solver_limited)then
        proposed_dt=tx%accepted_dt
        proposal_active=ieee_is_finite(proposed_dt).and.proposed_dt>0.0_real64
      end if
'''+anchor)
  source=folder/'runtime.f90';source.write_text(raw);obj=folder/'runtime.o'
  run([a.compiler,*flags,'-J'+str(folder),'-c',source,'-o',obj],folder,opt+'-runtime-build')
  oldobj=next(e['command'][-1]for e in meta['source_build']['events']if e['category']=='compile'and e['command'][-3].endswith('/'+RUNTIME))
  objects[objects.index(oldobj)]=str(obj)
  run([a.compiler,'-I'+str(folder),*flags,'-J'+str(folder),ROOT/APP,*objects,archive,'-o',probe],folder,opt+'-probe-build')
  report['builds'][opt]=dict(compiler=a.compiler,flags=flags,input_sha256={p:sha(ROOT/p)for p in meta['input_sha256']},reused_artifact_sha256=meta['reused_artifact_sha256'],generated_runtime_sha256=sha(source),executable_sha256=sha(probe))
  for rain in [1,4]:
   previous=a.oracle/f'{opt}-{rain}x-on-0';samples=[];baseline=a.oracle/f'{opt}-{rain}x-off-0'
   for rep in range(3 if opt=='O2'else 1):
    for kind,binary in [('ordinary',ordinary),('cap',probe)]:
     label=f'{opt}-{rain}x-{rep}-{kind}';case=out/label;case.mkdir()
     for name in ['input.nml','input.swp']:(case/name).write_bytes((previous/name).read_bytes())
     r=run(['taskset','-c',core,binary,'input.nml','-','97','input.swp'],case,label,False)
     if r.returncode:
      report['status']='RESEARCH_CANDIDATE_REJECTED';report['failure']=label;save();print(json.dumps(report['failure']));return
     assert b'SWAP5_SOLUTE_COLUMN_COMPLETED'in r.stdout
     for name in FILES:
      target=previous if kind=='ordinary'else out/f'{opt}-{rain}x-0-cap'
      assert (case/name).read_bytes()==(target/name).read_bytes(),(label,name)
     samples.append(dict(kind=kind,repeat=rep,seconds=report['events'][-1]['seconds'],fallback_days=[int(l.split()[1])for l in r.stdout.decode().splitlines()if'SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK'in l]))
   current=out/f'{opt}-{rain}x-0-cap';data=rows(current/'budget.csv');reference=rows(baseline/'budget.csv');assert len(data)==len(reference)==97
   gross=10*max(abs(float(r['water_end_cm'])-float(r['water_start_cm'])-float(r['water_in_cm'])+float(r['water_out_cm']))for r in data)
   assert gross<1e-9 and max(abs(float(r['water_residual_cm']))for r in data)<1e-10
   # Reconstruct with unchanged external forcing, not just the internal ledger.
   assert 10*max(abs(float(r['water_end_cm'])-float(r['water_start_cm'])-float(s['water_in_cm'])+float(s['water_out_cm'])-float(s['runoff_cm'])-float(s['pond_evaporation_cm'])-float(s['soil_evaporation_cm'])-float(s['actual_transpiration_cm'])+float(r['runoff_cm'])+float(r['pond_evaporation_cm'])+float(r['soil_evaporation_cm'])+float(r['actual_transpiration_cm']))for r,s in zip(data,reference))<1e-9
   differences={k:dict(max_daily_mm=10*max(abs(float(r[k])-float(s[k]))for r,s in zip(data,reference)),sum_difference_mm=10*sum(float(r[k])-float(s[k])for r,s in zip(data,reference)))for k in ['runoff_cm','water_end_cm','soil_evaporation_cm','pond_evaporation_cm','actual_transpiration_cm']}
   assert differences['runoff_cm']['max_daily_mm']<.01 and abs(differences['runoff_cm']['sum_difference_mm'])<.01
   assert differences['water_end_cm']['max_daily_mm']<.01 and differences['actual_transpiration_cm']['max_daily_mm']<1e-8
   assert 10*max(abs(float(r['soil_evaporation_cm'])+float(r['pond_evaporation_cm'])-float(s['soil_evaporation_cm'])-float(s['pond_evaporation_cm']))for r,s in zip(data,reference))<1e-8
   for kind in ['half','resume','default']:
    label=f'{opt}-{rain}x-{kind}';case=out/label;case.mkdir()
    source=baseline if kind=='default'else current
    for name in ['input.nml','input.swp']:(case/name).write_bytes((source/name).read_bytes())
    restart=out/f'{opt}-{rain}x-half/restart.bin'if kind=='resume'else'-'
    run(['taskset','-c',core,probe,'input.nml',restart,'48'if kind=='half'else'97','input.swp'],case,label)
    if kind=='resume':
     for name in FILES[1:]:assert (case/name).read_bytes()==(current/name).read_bytes(),(label,name)
     assert rows(case/'budget.csv')==data[48:]
    if kind=='default':
     for name in FILES:assert (case/name).read_bytes()==(baseline/name).read_bytes(),(label,name)
   report['cases'][f'{opt}-{rain}x']=dict(samples=samples,native_median={kind:statistics.median(s['seconds']for s in samples if s['kind']==kind)for kind in ['ordinary','cap']},differences=differences,gross_mm=gross,accepted_substeps=sum(int(r['accepted_substeps'])for r in data));save()
 for rain in [1,4]:
  for name in FILES:assert (out/f'O0-{rain}x-0-cap'/name).read_bytes()==(out/f'O2-{rain}x-0-cap'/name).read_bytes(),(rain,name)
 report['status']='GENERATED_SOLVER_CAP_O0_O2_WATER_RUNOFF_DEFAULT_BYTES_RESTART_PASS';save()
 print(json.dumps(report['cases'],indent=2))
if __name__=='__main__':main()
