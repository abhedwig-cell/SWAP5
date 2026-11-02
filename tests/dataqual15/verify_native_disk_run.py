"""Verify real source-bound restart suffixes and independently reconstruct water."""
import argparse,csv,hashlib,json,math
from pathlib import Path
from checkpoint_layout import layout,payload

def verify(continuous,resumed,paired=None):
    load=lambda p:json.loads(p.read_text())
    original=load(continuous/'RESULT.json');suffix=load(resumed/'RESULT.json')
    assert original['returncode']==suffix['returncode']==0
    assert not original['censored'] and not suffix['censored']
    assert original['completed_days']==suffix['completed_days']
    assert original['source_sha256']==suffix['source_sha256']
    assert original['executable_sha256']==suffix['executable_sha256']
    assert (continuous/'checkpoint.bin').read_bytes()==(resumed/'checkpoint.bin').read_bytes()
    incoming=resumed/'restart-origin.bin';clock=layout(incoming.read_bytes())['clock']
    assert load(resumed/'LAUNCH.json')['restart_sha256']==hashlib.sha256(incoming.read_bytes()).hexdigest()
    rows=lambda folder,name:list(csv.DictReader((folder/name).open()))
    for name in ['budget.csv','crop.csv']:
        assert [r for r in rows(continuous,name)if int(r['day'])>clock]==rows(resumed,name),name
    budget=rows(continuous,'budget.csv')
    assert [int(r['day'])for r in budget]==list(range(int(budget[0]['day']),int(original['completed_days'])+1))
    maximum=0.0
    for r in budget:
        assert all(math.isfinite(float(v))for v in r.values())
        residual=float(r['water_end_cm'])-float(r['water_start_cm'])-float(r['input_cm'])+float(r['output_cm'])
        assert abs(residual)<1e-10 and abs(float(r['residual_cm']))<1e-10
        assert abs(float(r['potential_cm'])-float(r['uptake_cm'])-float(r['drought_cm'])-float(r['oxygen_cm']))<1e-10
        maximum=max(maximum,abs(residual))
    if paired:
        other=load(paired/'RESULT.json');assert other['returncode']==0 and not other['censored']
        for name in ['budget.csv','crop.csv','state.csv','endpoint.csv']:
            assert(continuous/name).read_bytes()==(paired/name).read_bytes(),name
        assert payload((continuous/'checkpoint.bin').read_bytes())==payload((paired/'checkpoint.bin').read_bytes())
    return dict(status='NATIVE_DISK_RUN_EXACT_AND_WATER_PASS',days=original['completed_days'],
                restart_from_day=clock,paired_optimization_exact=bool(paired),
                maximum_independent_water_residual_cm=maximum,
                maximum_reported_water_residual_cm=original['maximum_water_residual_cm'],
                source_sha256=original['source_sha256'],executable_sha256=original['executable_sha256'],
                scope='Same-build native restart and water/demand ledgers; not full energy or whole-model scientific equivalence')

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--continuous',type=Path,required=True)
    p.add_argument('--resumed',type=Path,required=True);p.add_argument('--paired',type=Path)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=verify(a.continuous,a.resumed,a.paired);a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items()if k!='source_sha256'},indent=2))
if __name__=='__main__':main()
