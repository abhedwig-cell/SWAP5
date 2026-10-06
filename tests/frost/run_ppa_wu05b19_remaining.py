#!/usr/bin/env python3
"""Sequential exact-source scientific/external/SALT/canonical preservation gates."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess
ROOT=Path(__file__).resolve().parents[2]
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--whole-record',required=True);ap.add_argument('--record',required=True);a=ap.parse_args()
    whole=json.loads(Path(a.whole_record).read_text());source=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip();assert source==whole['production_source']=='636e782080abdd2c0366f96317c4f59e8170dc53'
    checkout=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();results={}
    def run(name,command,extra=None):
        out=Path('/tmp/frost-b19-'+name+'.log')
        with out.open('w')as f:r=subprocess.run(command,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,env={**os.environ,'C3A_TESTED_SHA':checkout,**(extra or{})})
        receipt=dict(command=command,exit_code=r.returncode,stdout_sha256=hashlib.sha256(out.read_bytes()).hexdigest(),production_source=source,complete=r.returncode==0)
        Path(str(out)+'.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');assert r.returncode==0,(name,out.read_text()[-3000:]);results[name]=receipt
        print(f'B19_REMAINING_{name.upper()}=PASS',flush=True)
    run('scientific',['python','tests/frost/run_ppa_wu05b19_scientific.py'])
    run('exact',['python','tests/physics/run_ppa_wu05d_exact01.py'],{'C3A_RESULT':'/tmp/frost-b19-exact.json'})
    run('external-preservation',['python','tests/frost/run_ppa_wu05b19_external_preservation.py','--whole-record',a.whole_record,'--record','/tmp/frost-b19-external-preservation.json'])
    for method in ('jarvis','walsum'):
        for variant in ('','dispersion'):
            label=method+('-dispersion'if variant else'');record=Path('/tmp/frost-b19-'+label+'.json')
            run(label,['python','tests/physics/run_ppa_wu05e_mixed_salt_frost.py'],{'C3A_RESULT':str(record),'WU05E_COMPENSATION_METHOD':method,'WU05E_TRANSPORT_VARIANT':variant})
            m=json.loads(record.read_text());assert m['status']=='LOCAL_MATRIX_SALT_MIXED_GATES_PASS_NOT_ADMITTED'and len(m['source_sha256'])==180
            for f,h in m['source_sha256'].items():assert hashlib.sha256((ROOT/f).read_bytes()).hexdigest()==h,f
    run('canonical-preservation',['bash','tests/fci/run_fci_canonical_p2e05_moving_preservation.sh'])
    assert 'FCI_CANONICAL_PPA_WU05B19_EXACT_HIGHEST_RESPONSE_CANDIDATE=ACTIVE'in Path('/tmp/frost-b19-canonical-preservation.log').read_text()
    assert 'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS'in Path('/tmp/frost-b19-canonical-preservation.log').read_text()
    run('docs',['python','tools/docs/check_docs.py'])
    run('mkdocs',['python','-m','mkdocs','build','--strict','-d','/tmp/ppa-wu05b19-strict-docs'])
    result=dict(work_unit='PPA-WU05B19',status='LOCAL_COMPLETE_REMAINING_PRESERVATION_PASS_NOT_RUNTIME_ADMISSION',production_source=source,checkout=checkout,results=results)
    Path(a.record).write_text(json.dumps(result,indent=2)+'\n');print('B19_ALL_REMAINING_PRESERVATION=PASS',flush=True)
if __name__=='__main__':main()
