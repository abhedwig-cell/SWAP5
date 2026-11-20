"""Observe new Snow compositions using their actual unchanged source-probe bundles."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from implicit_snow_source_probe import CASES

m=original.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','source-probe','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--only-labels',nargs='+',choices=[c[0] for c in CASES])
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir();probe=json.loads(a.source_probe.read_text());before=m.sha(a.source_probe)
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        actual_source_probe=str(a.source_probe),actual_source_probe_sha256=before,cases={},fresh_compilations=0,canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for label,solute,hys,bottom,step,mode,npd,reset,mean in CASES:
            if label not in probe['cases'] or a.only_labels and label not in a.only_labels:continue
            c=probe['cases'][label];assert c['returncode']==0
            out=a.output/label;out.mkdir();build=Path(c['build_root']);inputs=Path(c['input_root'])
            project=m.e.load(inputs,original_output=True);build_sha=m.sha(build/'BUILD.json')
            report=m.e.inspect(inputs);s=report['selectors']
            item=dict(status='RUNNING',source_commit=q['source_commit'],parameters=dict(optimization=a.optimization,
                solute=solute,hysteresis=hys,bottom=bottom,kmean=mean,perstep=step,mode=mode,format=3,reset=reset,
                nprintday=npd,implicit=1,snow=1,drainage=s['SWDRA']),build_root=str(build),input_root=str(inputs))
            q['cases'][label]=dict(actual_case_root=str(out));save()
            def save_case():(out/'RESULT.json').write_text(json.dumps(item,indent=2)+'\n')
            save_case()
            try:
                meta,_=m.validate_bundle(build,a.reference_work,project)
                assert meta['identity']['implicit_conductivity']['implicit_snow_composition'] is True
                assert {'-'+a.optimization,'-ffp-contract=off'}<=set(meta['identity']['donor_flags'])
                windows=[(2,4),(7,9),(30,34)]
                item['trajectory'],data=m.trajectory(build,a.reference_work,project,out/'trajectory',35,
                    {35,*(d for pair in windows for d in pair)},180)
                item['cold']=[];save_case()
                for low,high in windows:
                    item['cold'].append(original.previous.own(build,a.reference_work,project,out/'trajectory',data,low,high,out/f'own-{low}'));save_case()
                item['snow_observation']=dict(maximum_stock_cm=max(r['stock_end_cm'][2] for r in data),
                    snow_rain_cm=sum(r['external_flux_cm'][1] for r in data),gross_snow_cm=sum(r['external_flux_cm'][2] for r in data))
                assert item['snow_observation']['maximum_stock_cm']>0
                assert m.sha(build/'BUILD.json')==build_sha
                item['status']='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'
            except Exception as error:item.update(status='FAILED',error=repr(error));raise
            finally:save_case()
        assert m.sha(a.source_probe)==before
        q['status']='ACTUAL_SELECTED_IMPLICIT_SNOW_SHORT_CONTEXTS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
