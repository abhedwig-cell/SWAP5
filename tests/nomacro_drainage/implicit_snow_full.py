"""Actual implicit Snow full period, reusing an unchanged successful short build."""
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
    for key in ('reference-work','reuse-case','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--cap',type=int,choices=(180,600),default=180)
    a=p.parse_args();a.output.mkdir()
    receipt=a.reuse_case/'RESULT.json';before=m.sha(receipt);short=json.loads(receipt.read_text())
    assert short['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'
    build=Path(short['build_root']);inputs=Path(short['input_root']);build_sha=m.sha(build/'BUILD.json')
    project=m.e.load(inputs,original_output=True);meta,_=m.validate_bundle(build,a.reference_work,project)
    report=m.e.inspect(inputs);s=report['selectors']
    assert s['SWKIMPL']==s['SWSNOW']==1 and meta['identity']['implicit_conductivity']['implicit_snow_composition'] is True
    assert short['trajectory']['build_sha256']==build_sha
    parameters={**short['parameters'],'phase':'full','implicit':1,'snow':1,'drainage':s['SWDRA']}
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
           parameters=parameters,build_root=str(build),input_root=str(inputs),
           actual_short_receipt=str(receipt),actual_short_receipt_sha256=before,fresh_compilations=0,
           fresh_short_models=0,full_resource_cap_seconds=a.cap,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        windows=[(2,4),(7,9),(30,34),(163,165),(199,201),(364,367),(530,532),(633,635),(1094,1096)]
        q['trajectory'],data=m.trajectory(build,a.reference_work,project,a.output/'trajectory',1096,
            {1096,*(day for pair in windows for day in pair)},a.cap)
        q['cold']=[];save()
        for low,high in windows:
            q['cold'].append(original.previous.own(build,a.reference_work,project,a.output/'trajectory',data,low,high,a.output/f'own-{low}'));save()
        assert m.sha(build/'BUILD.json')==build_sha and m.sha(receipt)==before
        q['status']='ACTUAL_IMPLICIT_SNOW_FULL_PHYSICAL_NATIVE_OUTPUT_PASS'
    except Exception as error:q.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
