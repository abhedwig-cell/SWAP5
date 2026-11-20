"""Refuse actual forged new composition policy/source before worker startup."""
import argparse
import copy
import json
from pathlib import Path
import shutil
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original

m=original.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();q=json.loads((a.profile/'RESULT.json').read_text())
    bundle=Path(q['build_root']);project=m.e.load(q['input_root'],original_output=True)
    meta,_=m.validate_bundle(bundle,a.reference_work,project);before=m.sha(bundle/'BUILD.json')
    result=dict(status='RUNNING',actual_BUILD_sha256=before,refusals=[],model_executions=0,compilations=0)
    fields=('groundwater_clock_composition_sha256','groundwater_trial_provider_sha256','groundwater_clock_policy','groundwater_new_physical_state','native_codec')
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    try:
        for label in [*('policy-'+v for v in fields),'head-relaxed-guard','head-missing-guard','head-foreign-parent','cde-private-source']:
            target=a.output/label;target.mkdir();bad=copy.deepcopy(meta)
            for path in bundle.iterdir():
                if path.name=='BUILD.json' or path.suffix.lower() in ('.f90','.dll','.so'):shutil.copyfile(path,target/path.name)
            if label.startswith('policy-'):
                field=label[len('policy-'):]
                for identity in (bad['identity'],bad['binding']['build']):identity['original_output'][field]='foreign'
                expected=('Foreign groundwater CDE clock source domain','Foreign original output policy')
            else:
                name='original_cde_output_state.f90' if label=='cde-private-source' else 'headcalc.f90'
                path=target/name;text=path.read_text(encoding='cp1252')
                anchor='         if(abs(hybrid_groundwater_cde_clock_trial(groundwater_bottom,groundwater_delta))>1d-10)flnonconv=.true.'
                if label=='head-relaxed-guard':assert text.count(anchor)==1;text=text.replace(anchor,anchor.replace('1d-10','1d-9'),1)
                elif label=='head-missing-guard':assert text.count(anchor)==1;text=text.replace(anchor,'',1)
                else:text+='\n! deliberately foreign actual composed source\n'
                path.write_text(text,encoding='cp1252')
                for identity in (bad['identity'],bad['binding']['build']):identity['donor_generated'][name]=m.sha(path)
                expected=('Foreign actual groundwater CDE clock',) if name=='headcalc.f90' else ('provider','source')
            (target/'BUILD.json').write_text(json.dumps(bad,indent=2)+'\n')
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:
                assert any(v in str(error) for v in expected),(label,str(error))
                assert not list(target.rglob('donor.stdout')) and not list(target.rglob('accepted-*.zip'))
                result['refusals'].append(dict(field=label,error=str(error),before_worker=True,no_publication=True,forged_source_inventory=not label.startswith('policy-')))
            else:raise AssertionError('Foreign composed policy/source accepted: '+label)
            save()
        assert len(result['refusals'])==9 and m.sha(bundle/'BUILD.json')==before
        result['status']='ACTUAL_NINE_GROUNDWATER_CLOCK_SOURCE_POLICY_REFUSALS_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(result['status'])


if __name__=='__main__':main()
