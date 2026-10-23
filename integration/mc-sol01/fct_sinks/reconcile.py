"""Reconcile live canonical without rerunning unchanged numerical inputs."""
import argparse,hashlib,json,runpy,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--canonical',required=True);ap.add_argument('--write',action='store_true');a=ap.parse_args()
    v=runpy.run_path(str(HERE/'verify.py'));index=json.loads((HERE/'EVIDENCE_INDEX.json').read_text())
    f=v['unpack'](HERE/'EVIDENCE.tar.xz.b64',index['decoded_sha256']);result=v['assess'](f);controls=v['controls'](f)
    latest=json.loads(f['ROUNDS.json'])[-1];execution=json.loads(f[latest+'/execution.json'])
    delta=subprocess.check_output(['git','diff','--name-only','03c1c7a41d66924e2d974275cd14d4bdc4101047',a.canonical],cwd=ROOT,text=True).splitlines()
    overlap=set(delta)&set(execution['inputs']);assert not overlap,overlap
    owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_single_zero_pool.py'));r=owner['verify']();c=owner['self_test']();assert r['qualified']
    record=dict(canonical=a.canonical,validated_local_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
      qualified_inputs_byte_exact=len(execution['inputs']),generated_sources_byte_exact=len(execution['generated']),concurrent_paths=delta,concurrent_input_overlap=sorted(overlap),
      current_owner_qualified=r['qualified'],current_owner_controls=len(c),current_owner_result=r,current_owner_control_labels=c,new_capsule_controls=controls,new_result=result,
      numerical_rerun='NOT_SELECTED_IMPACT: all compiled/forcing/driver/generator inputs exact; current owner is checked separately.',production_activated=False)
    if a.write:(HERE/'CURRENT_RECONCILIATION.json').write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps({k:v for k,v in record.items() if k not in ['current_owner_result','current_owner_control_labels']},indent=2))
if __name__=='__main__':main()
