#!/usr/bin/env python3
"""Run unchanged test-only contact overlay against an exact detached canonical."""
import argparse,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OVERLAY=['tests/fapp/mod_top03_microrelief_top_provider.f90','tests/fapp/mod_top03_explicit_layer_provider.f90','tests/fapp/mod_top03_stateful_contact.f90','tests/fapp/test_sw_rib_top03_stateful_contact.f90','tests/fapp/run_sw_rib_top03_stateful_contact.py','tests/fmr/mod_fmr04_fixed_top_provider.f90']
def main():
 p=argparse.ArgumentParser();p.add_argument('--canonical-root',type=Path,required=True);p.add_argument('--canonical-sha',required=True);p.add_argument('--research-sha',required=True);p.add_argument('--build',type=Path,required=True);p.add_argument('--compiler',required=True);a=p.parse_args();c=a.canonical_root.resolve();b=a.build.resolve();b.mkdir(parents=True,exist_ok=True)
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=c,text=True).strip()==a.canonical_sha
 assert not subprocess.check_output(['git','diff','--','src'],cwd=c)
 evidence=[]
 for name in OVERLAY:
  data=subprocess.check_output(['git','show',a.research_sha+':'+name],cwd=ROOT);dest=c/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data);evidence.append(dict(path=name,sha256=hashlib.sha256(data).hexdigest()))
 (b/'overlay_manifest.json').write_text(json.dumps(dict(canonical_source=a.canonical_sha,research_overlay=a.research_sha,files=evidence,production_source_changed=False),indent=2)+'\n')
 subprocess.run(['python',str(c/'tests/fapp/run_sw_rib_top03_stateful_contact.py'),'--build',str(b),'--compiler',a.compiler],check=True,cwd=c)
 assert not subprocess.check_output(['git','diff','--','src'],cwd=c)
 # Reconcile every compilation input against either canonical or pinned overlay.
 overlay={x['path']:x['sha256'] for x in evidence};manifest=json.loads((b/'source_manifest.json').read_text());checked=[]
 for name,h in manifest.items():
  if name.startswith('generated'):continue
  origin=a.research_sha if name in overlay else a.canonical_sha
  data=subprocess.check_output(['git','show',origin+':'+name],cwd=ROOT)
  assert hashlib.sha256(data).hexdigest()==h,(name,origin)
  checked.append(dict(path=name,source=origin,sha256=h))
 (b/'source_reconciliation.json').write_text(json.dumps(checked,indent=2)+'\n')
 print('CANONICAL_AND_OVERLAY_SOURCE_RECONCILIATION=PASS',flush=True)
if __name__=='__main__':main()
