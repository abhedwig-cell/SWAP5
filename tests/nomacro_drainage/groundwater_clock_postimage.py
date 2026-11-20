"""Current read-only guard postimages on unchanged actual composed bundles."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original

m=original.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','cohort','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--full-root',type=Path)
    a=p.parse_args();a.output.mkdir()
    cohort=json.loads((a.cohort/'RESULT.json').read_text())
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
           repeated_full_periods=0,fresh_compilations=0,cases={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(label,root,windows):
        receipt=root/'RESULT.json';record=json.loads(receipt.read_text());before=m.sha(receipt)
        bundle=Path(record['build_root']);build_sha=m.sha(bundle/'BUILD.json');project=m.e.load(record['input_root'],original_output=True)
        m.validate_bundle(bundle,a.reference_work,project)
        warm=root/'trajectory';data=m.rows(warm);out=a.output/label;out.mkdir()
        item=q['cases'][label]=dict(original_receipt=str(receipt),original_receipt_sha256=before,actual_BUILD_sha256=build_sha,cold=[]);save()
        for low,high in windows:
            item['cold'].append(original.previous.own(bundle,a.reference_work,project,warm,data,low,high,out/f'own-{low}'));save()
        assert m.sha(receipt)==before and m.sha(bundle/'BUILD.json')==build_sha
        item['actual_origin_receipt_BUILD_unchanged']=True;save()
    save()
    try:
        for name in ('h2-periodic','h1-step-explicit','h0-step-periodic','h1-explicit-monthly'):
            run(name,Path(cohort['cases'][name]['actual_case_root']),[(30,34)])
        if a.full_root:run('full',a.full_root,[(163,165),(364,367)])
        q['status']='ACTUAL_CURRENT_GROUNDWATER_CLOCK_SOURCE_GUARD_NATIVE_POSTIMAGE_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
