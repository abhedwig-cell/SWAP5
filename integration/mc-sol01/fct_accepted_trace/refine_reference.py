"""Additional, preselected32/64-subcell reference and bounded accuracy review."""
import argparse,hashlib,json,runpy,subprocess,time
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def assess(out,replay,water):
 q=runpy.run_path(str(HERE/'qualify_replay.py'));prior=q['assess'](replay,water)
 r=json.loads((out/'execution.json').read_text());base=json.loads((replay/'execution.json').read_text())
 assert r['status']=='EXECUTED' and len(r['references'])==36
 assert r['replay_execution_sha256']==sha((replay/'execution.json').read_bytes())
 for p,h in r['inputs'].items():assert sha((ROOT/p).read_bytes())==h
 accuracy={};uncertainty_ratio=[];improvements=[]
 for case in base['cases']:
  if case['optimization']!='O2' or case['shape']!=0:continue
  n,factor,exponent=[case[k] for k in ['n','factor','exponent']]
  rows=np.array([[float(v) for v in l.split()[2:]] for l in (replay/case['stdout']).read_text().splitlines() if l.startswith('CELL ')])
  refs={a['subdivision']:np.array(a['mass']) for a in r['references'] if (a['n'],a['factor'],a['exponent'])==(n,factor,exponent)}
  assert set(refs)=={32,64} and all(np.isfinite(v).all() and np.min(v)>=0 for v in refs.values())
  lo=float(sum(abs(rows[:,2]+rows[:,3]-refs[64])));hi=float(sum(abs(rows[:,5]+rows[:,6]-refs[64])));unc=float(sum(abs(refs[64]-refs[32])))
  old=prior['accuracy'][f'{n}/{factor}/{exponent}']['reference_refinement_l1']
  assert unc<old,('reference not refining',n,factor,exponent)
  assert unc<=.25*hi,('reference uncertainty too large',n,factor,exponent,unc,hi)
  assert hi+2*unc<lo,('improvement ambiguous',n,factor,exponent)
  accuracy[f'{n}/{factor}/{exponent}']=dict(low_mass_l1=lo,corrected_mass_l1=hi,reference_refinement_l1=unc,corrected_to_low_ratio=hi/lo,refinement_to_corrected_ratio=unc/hi)
  uncertainty_ratio.append(unc/hi);improvements.append(hi/lo)
 for factor in [.8,1.2]:
  for exponent in [.5,1.,2.]:
   errors=[accuracy[f'{n}/{factor}/{exponent}']['corrected_mass_l1'] for n in [40,80,160]]
   assert errors[2]<errors[1]<errors[0],('coarse spatial refinement',factor,exponent,errors)
 return dict(status='BOUNDED_ACCEPTED_CARRIER_NONLINEAR_REPLAY_ACCURACY_O0_O2_PASS',water_cases=12,replays=72,late_atomic_rejections=360,exact_split_continuations=72,
  max_mass_residual=prior['max_mass_residual'],max_equilibrium_error=prior['max_equilibrium_error'],max_constant_error=prior['max_constant_error'],
  max_water_optimization_difference=prior['max_water_optimization_difference'],max_solute_optimization_difference=prior['max_solute_optimization_difference'],
  minimum_corrected_to_low_ratio=min(improvements),maximum_corrected_to_low_ratio=max(improvements),maximum_reference_refinement_to_corrected_ratio=max(uncertainty_ratio),
  accuracy=accuracy,actual_water_trace_qualified=True,time_series_accuracy_qualified=True,production_activated=False,native_qualified=False,full_mc_sol01_closed=False,
  qualification_ceiling='Two-day piecewise accepted carrier, prescribed pure downward no-sink advection, exact empty-pond physical option, positive-background Gaussian/constant, uniform40cm material. Reference refinement is empirical uncertainty, not a rigorous PDE error bound. No joint native/default/full-year or restart claim.')
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--replay',type=Path,required=True);ap.add_argument('--water',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--verify-only',action='store_true');a=ap.parse_args();out=a.output.resolve();replay=a.replay.resolve();water=a.water.resolve()
 q=runpy.run_path(str(HERE/'qualify_replay.py'))
 if not a.verify_only:
  q['assess'](replay,water);out.mkdir(parents=True,exist_ok=False);base=json.loads((replay/'execution.json').read_text());wr=json.loads((water/'execution.json').read_text())
  r=dict(status='RUNNING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in [Path(__file__),HERE/'qualify_replay.py']},replay_execution_sha256=sha((replay/'execution.json').read_bytes()),references=[])
  def save():(out/'execution.json').write_text(json.dumps(r,indent=2)+'\n')
  save()
  for case in base['cases']:
   if case['optimization']!='O2' or case['shape']!=0:continue
   wc=next(c for c in wr['water_cases'] if (c['optimization'],c['n'],c['factor'])==('O2',case['n'],case['factor']))
   n,tr=q['load_water'](water/wc['path']);lines=(replay/case['stdout']).read_text().splitlines();initial=np.array([float(l.split()[2]) for l in lines if l.startswith('CELL ')])
   for sub in [32,64]:
    start=time.monotonic();ref=q['reference'](tr,n,initial,case['exponent'],sub)
    r['references'].append(dict(**ref,n=n,factor=case['factor'],exponent=case['exponent'],seconds=time.monotonic()-start));save()
  r['status']='EXECUTED';save()
 result=assess(out,replay,water);(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
