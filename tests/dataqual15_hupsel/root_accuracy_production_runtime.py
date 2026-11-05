"""Actual current Hupsel numerical-profile execution, not a copied-source variant."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
import film_runtime as inputs_owner
import film_rotation as native
import film_rotation_audit as audit
from film_runtime_profiles import profile4

ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
SELECTOR=b'\n! Explicit SWAP5 numerical profile; original physical input above is unchanged.\nSWAP5_ROOT_ACCURACY = 1\n'

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--build',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
 p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args()
 build=a.build.resolve();out=a.output.resolve();out.mkdir();metadata=json.loads((build/'BUILD.json').read_text())
 assert metadata['status']=='BUILT'and metadata['provider_count']==236 and '-'+a.optimization in metadata['flags']and '-fcheck=all'in metadata['flags']
 assert all(sha(Path(n))==pin for n,pin in metadata['source_sha256'].items())
 assert all(sha(Path(n))==pin for n,pin in metadata['object_sha256'].items())
 exe=build/('swap5_hupsel_germination.exe'if os.name=='nt'else'swap5_hupsel_germination');assert sha(exe)==metadata['executable_sha256']
 inputs=inputs_owner.inputs(out/'inputs');original=(inputs/'swap.swp').read_bytes()
 assert b'SWAP5_ROOT_ACCURACY'not in original.upper();(inputs/'swap.swp').write_bytes(original+SELECTOR)
 (out/'PROFILE.json').write_text(json.dumps(dict(profile='pressure-film-refined',original_swp_sha256=hashlib.sha256(original).hexdigest(),
  selected_swp_sha256=sha(inputs/'swap.swp'),only_input_delta=SELECTOR.decode(),restart_binding='Existing exact SWP bytes; own current executable only',
  source_sha256=metadata['source_sha256'],executable_sha256=sha(exe)),indent=2)+'\n')
 registration=json.loads((BASE/'PRESSURE_FILM_PREREGISTRATION_20261105.json').read_text())
 captures=sorted(set(registration['capture_days']+[366,367]))
 os.environ['OMP_NUM_THREADS']='1';os.environ.pop('SWAP5_DIAG_PREDECESSOR',None)
 try:
  case=native.execute(exe,inputs,out/'full1096',1096,capture=captures)
  assert b'HUPSEL_ROOT_NUMERICAL_PROFILE=PRESSURE_FILM_REFINED'in(case/'stdout').read_bytes()
  native.ensure_captures(exe,inputs,case,out,captures)
  restarts=out/'restarts';restarts.mkdir()
  pairs=[p for cut in registration['wet_cuts']for p in ((cut-1,cut),(cut,cut+1))]+[(365,367),(1095,1096)]
  for first,last in pairs:
   strict=native.execute(exe,inputs,restarts/f'{first}-to-{last}',last,seed=case/f'checkpoint-{first}.bin')
   native.exact_window(case,strict,last)
  windows,daily,interval=audit.daily_data(case);crop=audit.rows(case/'crop.csv')
  points={d:profile4((case/f'checkpoint-{d}.bin').read_bytes())for d in captures}
  ledger=audit.ledger(daily,crop,{d:p for d,p in points.items()if d>=495},1096)
  audit.profile_checks(points,daily,audit.rows(case/'state.csv'))
  science=audit.science(daily,crop,points)
  result=dict(status='ACTUAL_CURRENT_ROOT_PROFILE_FULL1096_LEDGER_AND_STRICT_OWN_RESTARTS_PASS',optimization=a.optimization,
   days=1096,strict_windows=pairs,interval_ledger=interval,ledger=ledger,science=science,
   executable_sha256=sha(exe),source_sha256=metadata['source_sha256'],production_admission=False,whole_scientific_admission=False)
  (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items()if k!='source_sha256'},indent=2))
 except Exception as error:
  (out/'FAILED.json').write_text(json.dumps(dict(error=str(error),production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
  raise

if __name__=='__main__':main()
