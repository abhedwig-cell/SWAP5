"""Changed-accuracy RESEARCH ONLY: cellwise water L1 and pond temporal metric.

The generated fixture geometry module is application initialized. This is not a
production interface proposal or an implementation-only speedup.
"""
import argparse,csv,hashlib,json,os,statistics,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SOURCE='src/process/mod_pond_water_temporal_difference.f90';APP='app/solute_project/main.f90'
FILES=['budget.csv','state.csv','endpoint.csv','restart.bin']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return list(csv.DictReader(p.open()))
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--compiler',required=True)
 ap.add_argument('--previous',type=Path,required=True);ap.add_argument('--bundle-prefix',type=Path,required=True)
 ap.add_argument('--flux-rate-guard',action='store_true');ap.add_argument('--root-stress',action='store_true')
 ap.add_argument('--state-depth-budget',action='store_true')
 a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 report=dict(status='RUNNING',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),script_sha256=sha(Path(__file__)),
  production_changed=False,changed_accuracy=True,flux_rate_guard=a.flux_rate_guard,root_stress=a.root_stress,state_depth_budget=a.state_depth_budget,metric='sum(abs(theta_full-theta_half)*dz)+abs(pond_full-pond_half), with incumbent groundwater-head guard',budget_cm=.001,events=[],builds={},cases={})
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,label,required=True):
  cmd=list(map(str,cmd));t=time.perf_counter()
  try:r=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=60)
  except subprocess.TimeoutExpired as e:r=subprocess.CompletedProcess(cmd,124,e.stdout or b'',e.stderr or b'')
  for s in ['stdout','stderr']:(out/(label+'.'+s)).write_bytes(getattr(r,s))
  report['events'].append(dict(label=label,command=cmd,seconds=time.perf_counter()-t,returncode=r.returncode));save()
  if required:r.check_returncode()
  return r
 fc=['sh',a.compiler];core=min(os.sched_getaffinity(0));report['core']=core
 for opt in ['O0','O2']:
  b=json.loads((Path(str(a.bundle_prefix)+'-'+opt)/'bundle.json').read_text());exe=Path(b['exe']);m=json.loads((exe.parent/'build-complete.json').read_text())
  assert sha(exe)==m['executable_sha256']
  for p,h in m['input_sha256'].items():assert sha(ROOT/p)==h,p
  for p,h in m['reused_artifact_sha256'].items():assert sha(Path(p))==h,p
  assert subprocess.check_output(fc+['--version'],text=True).splitlines()[0]==m['compiler']
  report['builds'][opt]=dict(input_sha256=m['input_sha256'],reused_artifact_sha256=m['reused_artifact_sha256'],compiler=m['compiler'],flags=m['flags'])
  folder=out/opt;folder.mkdir();flags=[f for f in m['flags']if not f.startswith('-J')]
  objects=[e['command'][-1]for e in m['source_build']['events']if e['category']=='compile'and not e['command'][-3].endswith('/app/solute_crop/main.f90')];assert len(objects)==193
  archive=next(p for p in m['reused_artifact_sha256']if p.endswith('/libttutil.a'))
  p=folder/'geometry.f90';p.write_text('module research_geometry\n use iso_fortran_env,only:real64\n implicit none\n real(real64),allocatable::dz(:)\n end module\n')
  run([*fc,*flags,'-J'+str(folder),'-c',p,'-o',folder/'geometry.o'],folder,opt+'-geometry-build')
  raw=(ROOT/SOURCE).read_text();anchor='    real(real64),intent(in)::hf(:)';assert raw.count(anchor)==1
  raw=raw.replace(anchor,'    use research_geometry,only:dz\n'+anchor)
  anchor='    value=max(maxval(abs(hf-hh)),abs(pf-ph),abs(gf-gh))';assert raw.count(anchor)==1
  raw=raw.replace(anchor,'    if(.not.allocated(dz))return\n    if(size(dz)/=n.or.any(dz<=0d0))return\n    value=max(sum(abs(wf-wh)*dz)+abs(pf-ph),abs(gf-gh))')
  p=folder/'difference.f90';p.write_text(raw);obj=folder/'difference.o'
  run([*fc,'-I'+str(folder),*flags,'-J'+str(folder),'-c',p,'-o',obj],folder,opt+'-difference-build')
  old=next(e['command'][-1]for e in m['source_build']['events']if e['category']=='compile'and e['command'][-3].endswith('/'+SOURCE));objects[objects.index(old)]=str(obj)
  if a.flux_rate_guard:
   tx='src/transaction/mod_transaction_reference.f90';raw=(ROOT/tx).read_text()
   anchor='      terr = model%temporal_error(full_state, half_state)';assert raw.count(anchor)==1
   raw=raw.replace(anchor,anchor+'''
      ! GENERATED RESEARCH ONLY: control per-day water and root/export errors.
      if(full_outcome%actual_transpiration_available.and.half1_outcome%actual_transpiration_available.and. &
         half2_outcome%actual_transpiration_available)then
        terr=max(terr,abs(full_outcome%actual_transpiration_amount- &
          half1_outcome%actual_transpiration_amount-half2_outcome%actual_transpiration_amount), &
          abs(full_outcome%mass_out-half1_outcome%mass_out-half2_outcome%mass_out))/attempt_dt
      else
        terr=huge(0.0_real64)
      end if''')
   if a.state_depth_budget:
    raw=raw.replace('terr=max(terr,abs(full_outcome%actual_transpiration_amount-','terr=max(terr,max(abs(full_outcome%actual_transpiration_amount-').replace('half2_outcome%mass_out))/attempt_dt','half2_outcome%mass_out))/attempt_dt)')
   p=folder/'transaction.f90';p.write_text(raw);obj=folder/'transaction.o'
   run([*fc,'-I'+str(folder),*flags,'-J'+str(folder),'-c',p,'-o',obj],folder,opt+'-transaction-build')
   old=next(e['command'][-1]for e in m['source_build']['events']if e['category']=='compile'and e['command'][-3].endswith('/'+tx));objects[objects.index(old)]=str(obj)
   backend='src/runtime/mod_fmr_serialized_reference_backend.f90';raw=(ROOT/backend).read_text()
   anchor='    if(self%root_extraction_active.and.publish_root_result) then';assert raw.count(anchor)==1
   # The native plain/empirical root route has the actual qrot vector, but the
   # incumbent generic result publishes it only for other qualified root modes.
   # Export real metadata in this generated prototype; no sink changes.
   raw=raw.replace(anchor,'    if(associated(self%qrot)) then')
   p=folder/'backend.f90';p.write_text(raw);obj=folder/'backend.o'
   run([*fc,'-I'+str(folder),*flags,'-J'+str(folder),'-c',p,'-o',obj],folder,opt+'-backend-build')
   old=next(e['command'][-1]for e in m['source_build']['events']if e['category']=='compile'and e['command'][-3].endswith('/'+backend));objects[objects.index(old)]=str(obj)
  raw=(ROOT/APP).read_text();anchor='  use iso_fortran_env,';assert raw.count(anchor)==1;raw=raw.replace(anchor,'  use research_geometry,only:research_dz=>dz\n'+anchor)
  anchor='  do j=first,stop_after';assert raw.count(anchor)==1;raw=raw.replace(anchor,'  research_dz=dz\n'+anchor)
  p=folder/'main.f90';p.write_text(raw);probe=folder/'probe'
  run([*fc,'-I'+str(folder),*flags,'-J'+str(folder),p,*objects,folder/'geometry.o',archive,'-o',probe],folder,opt+'-link')
  for rain in [1,4]:
   prior=a.previous/(f'{opt}-{rain}x-stress-ordinary'if a.root_stress else f'{opt}-{rain}x-ordinary-0');samples=[]
   for repeat in range(3 if opt=='O2'else 1):
    for kind,binary in [('ordinary',exe),('water',probe)]:
     label=f'{opt}-{rain}x-{kind}-{repeat}';case=out/label;case.mkdir()
     for n in ['input.nml','input.swp']:(case/n).write_bytes((prior/n).read_bytes())
     r=run(['taskset','-c',core,binary,'input.nml','-','97','input.swp'],case,label,False)
     if r.returncode:
      report['status']='WATER_METRIC_RESEARCH_REJECTED';report['failure']=label;save();return
     target=prior if kind=='ordinary'else out/f'{opt}-{rain}x-water-0'
     for n in FILES:assert (case/n).read_bytes()==(target/n).read_bytes(),(label,n)
     samples.append(dict(kind=kind,repeat=repeat,seconds=report['events'][-1]['seconds']))
   current=out/f'{opt}-{rain}x-water-0';data=rows(current/'budget.csv');reference=rows(prior/'budget.csv');assert len(data)==len(reference)==97
   differences={k:dict(max_mm=10*max(abs(float(d[k])-float(s[k]))for d,s in zip(data,reference)),sum_mm=10*sum(float(d[k])-float(s[k])for d,s in zip(data,reference)))for k in ['runoff_cm','water_end_cm','actual_transpiration_cm','soil_evaporation_cm','pond_evaporation_cm']}
   criteria=dict(internal_water=max(abs(float(d['water_residual_cm']))for d in data)<1e-10,runoff_daily=differences['runoff_cm']['max_mm']<.01,runoff_season=abs(differences['runoff_cm']['sum_mm'])<(.05 if a.root_stress else .01),storage=differences['water_end_cm']['max_mm']<.01,transpiration=differences['actual_transpiration_cm']['max_mm']<(.01 if a.root_stress else 1e-8),total_evaporation=10*max(abs(float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])-float(s['soil_evaporation_cm'])-float(s['pond_evaporation_cm']))for d,s in zip(data,reference))<(.01 if a.root_stress else 1e-8))
   if a.root_stress:criteria['season_transpiration']=abs(differences['actual_transpiration_cm']['sum_mm'])<.05
   for kind in ['half','resume']:
    label=f'{opt}-{rain}x-{kind}';case=out/label;case.mkdir()
    for n in ['input.nml','input.swp']:(case/n).write_bytes((prior/n).read_bytes())
    run(['taskset','-c',core,probe,'input.nml',out/f'{opt}-{rain}x-half/restart.bin'if kind=='resume'else'-','48'if kind=='half'else'97','input.swp'],case,label)
    if kind=='resume':
     for n in FILES[1:]:assert (case/n).read_bytes()==(current/n).read_bytes()
     assert rows(case/'budget.csv')==data[48:]
   report['cases'][f'{opt}-{rain}x']=dict(samples=samples,criteria=criteria,differences=differences,native_median={k:statistics.median(s['seconds']for s in samples if s['kind']==k)for k in ['ordinary','water']},accepted_halfsteps=sum(int(d['accepted_substeps'])for d in data),head_difference_cm=max(abs(float(d['head_cm'])-float(s['head_cm']))for d,s in zip(rows(current/'state.csv'),rows(prior/'state.csv'))));save()
 for rain in [1,4]:
  for n in FILES:assert (out/f'O0-{rain}x-water-0'/n).read_bytes()==(out/f'O2-{rain}x-water-0'/n).read_bytes(),(rain,n)
 report['status']='WATER_METRIC_CHANGED_ACCURACY_O0_O2_RESTART_COMPLETE';report['physical_criteria_pass']=all(all(c['criteria'].values())for c in report['cases'].values());save();print(json.dumps(report['cases'],indent=2))
if __name__=='__main__':main()
