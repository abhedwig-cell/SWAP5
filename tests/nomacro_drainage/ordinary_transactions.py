"""Exercise the unchanged transaction owner on current ordinary water/CDE."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as runtime
from age_groundwater_controls import transactions


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('evidence','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir()
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=runtime.ROOT,text=True).strip(),cases={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for name,profile in [('water',a.evidence/f'ordinary-pond-chain-weighted-water-{a.optimization}-v1/short'),
                             ('cde',a.evidence/f'ordinary-pond-matrix-recovered-{a.optimization}-v1/cde-groundwater-history/short')]:
            raw=profile/'RESULT.json';before=runtime.m.sha(raw);record=json.loads(raw.read_text())
            build=Path(record['build_root']);buildsha=runtime.m.sha(build/'BUILD.json')
            project=runtime.m.e.load(record['input_root'],original_output=True)
            q['cases'][name]=transactions(build,a.reference_work,project,profile/'trajectory',a.output/name)
            assert all(v is True for v in q['cases'][name].values())
            assert runtime.m.sha(raw)==before and runtime.m.sha(build/'BUILD.json')==buildsha
            save()
        q['status']='ACTUAL_CURRENT_ORDINARY_WATER_CDE_TRANSACTION_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
