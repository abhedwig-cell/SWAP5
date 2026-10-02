#!/usr/bin/env python3
"""Run unchanged test-only contact overlay against an exact detached canonical."""
import argparse,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OVERLAY=['tests/fapp/mod_top03_microrelief_top_provider.f90','tests/fapp/mod_top03_explicit_layer_provider.f90','tests/fapp/mod_top03_stateful_contact.f90','tests/fapp/test_sw_rib_top03_stateful_contact.f90','tests/fapp/run_sw_rib_top03_stateful_contact.py','tests/fmr/mod_fmr04_fixed_top_provider.f90']
def main():
 p=argparse.ArgumentParser();p.add_argument('--canonical-root',type=Path,required=True);p.add_argument('--canonical-sha',required=True);p.add_argument('--research-sha',required=True);p.add_argument('--build',type=Path,required=True);p.add_argument('--compiler',required=True);p.add_argument('--candidate-patch',type=Path);a=p.parse_args();c=a.canonical_root.resolve();b=a.build.resolve();b.mkdir(parents=True,exist_ok=True)
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=c,text=True).strip()==a.canonical_sha
 assert not subprocess.check_output(['git','diff','--','src'],cwd=c)
 evidence=[];patch_files={};patch_metadata=None
 if a.candidate_patch:
  patch=a.candidate_patch.resolve()
  assert subprocess.run(['git','symbolic-ref','--quiet','HEAD'],cwd=c,capture_output=True).returncode!=0,'requires detached checkout'
  subprocess.run(['git','apply','--check',str(patch)],cwd=c,check=True)
  subprocess.run(['git','apply',str(patch)],cwd=c,check=True)
  names=subprocess.check_output(['git','diff','--name-only','--','src'],cwd=c,text=True).splitlines()
  assert set(names)=={'src/solver/mod_soil_water_solver_contract.f90','src/legacy/b1_10_port/headcalc.f90'}
  patch_files={n:hashlib.sha256((c/n).read_bytes()).hexdigest() for n in names}
  patch_metadata=dict(sha256=hashlib.sha256(patch.read_bytes()).hexdigest(),output_files=patch_files,scope='Unadmitted prospective imposed-head discriminator only')
 for name in OVERLAY:
  data=subprocess.check_output(['git','show',a.research_sha+':'+name],cwd=ROOT);dest=c/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data);evidence.append(dict(path=name,sha256=hashlib.sha256(data).hexdigest()))
 (b/'overlay_manifest.json').write_text(json.dumps(dict(canonical_source=a.canonical_sha,research_overlay=a.research_sha,files=evidence,production_source_changed=bool(patch_files),candidate_patch=patch_metadata,canonical_admission=False),indent=2)+'\n')
 subprocess.run(['python',str(c/'tests/fapp/run_sw_rib_top03_stateful_contact.py'),'--build',str(b),'--compiler',a.compiler],check=True,cwd=c)
 assert {n:hashlib.sha256((c/n).read_bytes()).hexdigest() for n in patch_files}==patch_files
 if not patch_files:assert not subprocess.check_output(['git','diff','--','src'],cwd=c)
 # Reconcile every compilation input against either canonical or pinned overlay.
 overlay={x['path']:x['sha256'] for x in evidence};manifest=json.loads((b/'source_manifest.json').read_text());checked=[]
 for name,h in manifest.items():
  if name.startswith('generated'):continue
  origin=a.research_sha if name in overlay else a.canonical_sha
  if name in patch_files:
   origin='canonical+prospective-patch';assert patch_files[name]==h
  else:
   data=subprocess.check_output(['git','show',origin+':'+name],cwd=ROOT)
   assert hashlib.sha256(data).hexdigest()==h,(name,origin)
  checked.append(dict(path=name,source=origin,sha256=h))
 (b/'source_reconciliation.json').write_text(json.dumps(checked,indent=2)+'\n')
 print('CANONICAL_AND_OVERLAY_SOURCE_RECONCILIATION=PASS',flush=True)
if __name__=='__main__':main()
