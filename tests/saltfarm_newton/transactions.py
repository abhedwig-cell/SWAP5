"""Actual independent external columns and rejected-proposal replay at day454."""
from pathlib import Path
from dataclasses import replace
import argparse,json,sys,zipfile
root=Path(__file__).resolve().parents[2];sys.path[:0]=[str(root/'app/hybrid_water'),str(root/'tools/solute')]
import daily_host as h
from daily_coupling import CoupledDailyColumn,validate_bundle
from check_hupsel51_repair import bounded,physical,rows
p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--reference',type=Path,required=True);a=p.parse_args();out=a.work/'transactions';out.mkdir();results={}
for opt in ('O0','O2'):
 bundle=a.work/('qualified-'+opt);origin=a.work/('accept-'+opt)/'full/accepted-column-1-day-453.zip';digest=h.sha(origin);folder=out/opt;folder.mkdir()
 def trial():
  left=CoupledDailyColumn(bundle,a.reference,folder/'left',h.SALTFARM,'left',origin=origin,day=453,adopt_native=True);right=CoupledDailyColumn(bundle,a.reference,folder/'right',h.SALTFARM,'right',origin=origin,day=453,adopt_native=True)
  x=left.prepare();y=right.prepare();assert x.budget==y.budget;assert left.day==right.day==453 and left.revision==right.revision==0
  left.discard(x);assert h.sha(origin)==digest and left.day==453
  right.accept(y);right_hash=h.sha(right.checkpoint);z=left.prepare();assert z.budget==x.budget;left.accept(z)
  with zipfile.ZipFile(left.checkpoint) as pz,zipfile.ZipFile(right.checkpoint) as qz:assert all(pz.read(n)==qz.read(n) for n in ('result.end','macro.bin'))
  actual={k:v for k,v in z.budget.items() if k not in ('committed','candidate_only','revision','column')};expected={k:v for k,v in rows(a.work/('accept-'+opt)/'full')[453].items() if k not in ('committed','revision','column')};assert actual==expected
  zz=left.prepare();left.discard(zz);assert h.sha(right.checkpoint)==right_hash and right.day==454 and h.sha(origin)==digest
 _,seconds=bounded(25,trial)
 try:validate_bundle(bundle,a.reference,replace(h.SALTFARM,water_polish_policy=h.ALWAYS_WATER_POLISH))
 except ValueError as ex:assert 'polishing policy' in str(ex)
 else:raise AssertionError('Foreign numerical policy accepted')
 results[opt]=dict(discard_replay_exact=True,independent_columns_exact=True,continuous_day454_exact=True,origin_unchanged=True,foreign_policy_refused=True,seconds=seconds)
 (out/'RESULT.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
