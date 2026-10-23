"""Retain failed32/64 review; refine only two unresolved reference cases."""
import argparse,hashlib,json,runpy,subprocess,time
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def assess(out,first,replay,water):
 old=runpy.run_path(str(HERE/'refine_reference.py'));q=runpy.run_path(str(HERE/'qualify_replay.py'));prior=q['assess'](replay,water)
 r=json.loads((out/'execution.json').read_text());base=json.loads((replay/'execution.json').read_text());original=json.loads((first/'execution.json').read_text())
 assert r['status']=='EXECUTED' and len(original['references'])==36 and len(r['extensions'])==2
 assert r['previous_execution_sha256']==sha((first/'execution.json').read_bytes())
 assert original['replay_execution_sha256']==sha((replay/'execution.json').read_bytes())
 for record in [r,original]:
  for p,h in record['inputs'].items():assert sha((ROOT/p).read_bytes())==h
 try:old['assess'](first,replay,water)
 except AssertionError as e:assert 'reference uncertainty too large' in str(e)
 else:raise AssertionError('original failed reference review relabelled PASS')
 accuracy={};ratios=[];unc_ratios=[];extended=[]
 for case in base['cases']:
  if case['optimization']!='O2' or case['shape']!=0:continue
  n,factor,exponent=[case[k] for k in ['n','factor','exponent']];key=f'{n}/{factor}/{exponent}'
  rows=np.array([[float(v) for v in l.split()[2:]] for l in (replay/case['stdout']).read_text().splitlines() if l.startswith('CELL ')])
  refs={a['subdivision']:np.array(a['mass']) for a in [*original['references'],*r['extensions']] if (a['n'],a['factor'],a['exponent'])==(n,factor,exponent)}
  assert all(np.isfinite(a).all() and np.min(a)>=0 for a in refs.values())
  a,b=sorted(refs)[-2:];assert (a,b) in [(32,64),(64,128)]
  lo=float(sum(abs(rows[:,2]+rows[:,3]-refs[b])));hi=float(sum(abs(rows[:,5]+rows[:,6]-refs[b])));unc=float(sum(abs(refs[b]-refs[a])))
  if b==128:
   previous_unc=float(sum(abs(refs[64]-refs[32])));previous_hi=float(sum(abs(rows[:,5]+rows[:,6]-refs[64])))
   assert previous_unc>.25*previous_hi;extended.append(key)
  assert unc<prior['accuracy'][key]['reference_refinement_l1'] and unc<=.25*hi,(key,unc,hi)
  assert hi+2*unc<lo,(key,lo,hi,unc)
  accuracy[key]=dict(low_mass_l1=lo,corrected_mass_l1=hi,reference_refinement_l1=unc,reference_subcells=[a,b],corrected_to_low_ratio=hi/lo,refinement_to_corrected_ratio=unc/hi)
  ratios.append(hi/lo);unc_ratios.append(unc/hi)
 assert set(extended)=={'160/0.8/1.0','160/1.2/2.0'}
 for factor in [.8,1.2]:
  for exponent in [.5,1.,2.]:
   e=[accuracy[f'{n}/{factor}/{exponent}']['corrected_mass_l1'] for n in [40,80,160]];assert e[2]<e[1]<e[0]
 return dict(status='BOUNDED_ACCEPTED_CARRIER_NONLINEAR_REPLAY_ACCURACY_O0_O2_PASS',water_cases=12,replays=72,late_atomic_rejections=360,exact_split_continuations=72,
  max_mass_residual=prior['max_mass_residual'],max_equilibrium_error=prior['max_equilibrium_error'],max_constant_error=prior['max_constant_error'],
  max_water_optimization_difference=prior['max_water_optimization_difference'],max_solute_optimization_difference=prior['max_solute_optimization_difference'],
  minimum_corrected_to_low_ratio=min(ratios),maximum_corrected_to_low_ratio=max(ratios),maximum_reference_refinement_to_corrected_ratio=max(unc_ratios),accuracy=accuracy,
  actual_water_trace_qualified=True,time_series_accuracy_qualified=True,production_activated=False,native_qualified=False,full_mc_sol01_closed=False,
  qualification_ceiling='Two-day piecewise accepted carrier, downward no-sink advection, exact empty-pond option, positive-background Gaussian/constant, uniform material. Empirical reference refinement, not rigorous full coupled PDE error bound; no joint/native/default/full-year/restart claim.')
def main():
 ap=argparse.ArgumentParser()
 for key in ['previous','replay','water','output']:ap.add_argument('--'+key,type=Path,required=True)
 ap.add_argument('--verify-only',action='store_true');a=ap.parse_args();out=a.output.resolve();first=a.previous.resolve();replay=a.replay.resolve();water=a.water.resolve()
 if not a.verify_only:
  out.mkdir(parents=True,exist_ok=False);q=runpy.run_path(str(HERE/'qualify_replay.py'));base=json.loads((replay/'execution.json').read_text());wr=json.loads((water/'execution.json').read_text())
  r=dict(status='RUNNING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [Path(__file__),HERE/'qualify_replay.py',HERE/'refine_reference.py']},previous_execution_sha256=sha((first/'execution.json').read_bytes()),extensions=[])
  def save():(out/'execution.json').write_text(json.dumps(r,indent=2)+'\n')
  save()
  for factor,exponent in [(.8,1.),(1.2,2.)]:
   c=next(c for c in base['cases'] if (c['optimization'],c['n'],c['factor'],c['exponent'],c['shape'])==('O2',160,factor,exponent,0))
   wc=next(c for c in wr['water_cases'] if (c['optimization'],c['n'],c['factor'])==('O2',160,factor));n,tr=q['load_water'](water/wc['path'])
   rows=(replay/c['stdout']).read_text().splitlines();initial=np.array([float(l.split()[2]) for l in rows if l.startswith('CELL ')])
   start=time.monotonic();ref=q['reference'](tr,n,initial,exponent,128);r['extensions'].append(dict(**ref,n=n,factor=factor,exponent=exponent,seconds=time.monotonic()-start));save()
  r['status']='EXECUTED';save()
 result=assess(out,first,replay,water);(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='accuracy'},indent=2))
if __name__=='__main__':main()
