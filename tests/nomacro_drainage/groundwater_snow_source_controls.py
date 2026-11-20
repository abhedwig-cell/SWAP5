"""Refuse forged Snow groundwater policies and complete actual source providers."""
import argparse
import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original

m=original.m


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','profile','output'):parser.add_argument('--'+name,type=Path,required=True)
    args=parser.parse_args();args.output.mkdir(parents=True)
    report=json.loads((args.profile/'RESULT.json').read_text());bundle=Path(report['build_root'])
    project=m.e.load(report['input_root'],original_output=True);meta,_=m.validate_bundle(bundle,args.reference_work,project)
    before=m.sha(bundle/'BUILD.json');selected=meta['identity']['original_output']
    fields=[key for key in ('groundwater_snow_cde_output','groundwater_snow_composition_sha256',
            'groundwater_snow_policy','groundwater_snow_new_physical_state','groundwater_new_physical_state',
            'groundwater_trial_provider_sha256','groundwater_snow_soil_trial_provider_sha256',
            'groundwater_snow_print_domain_provider_sha256','native_codec','swdra') if key in selected]
    sources={'head-relaxed-guard':'headcalc.f90','head-missing-guard':'headcalc.f90',
             'head-foreign-parent':'headcalc.f90','cde-private-source':'original_cde_output_state.f90',
             'snow-private-source':'thermal_output_snow_calendar_state.f90',
             'thermal-domain-source':'original_output_thermal_domain.f90',
             'groundwater-native-source':'groundwater_history_native_state.f90'}
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
                actual_BUILD_sha256=before,policy_fields=fields,refusals=[],model_executions=0,compilations=0)
    def save():(args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for label in [*('policy-'+key for key in fields),*sources]:
            target=args.output/label;target.mkdir();bad=copy.deepcopy(meta)
            for path in bundle.iterdir():
                if path.name in ('BUILD.json','day_donor','day_kernel') or path.suffix.lower() in ('.f90','.dll','.so','.exe'):
                    shutil.copyfile(path,target/path.name)
            m.validate_bundle(target,args.reference_work,project)
            if label.startswith('policy-'):
                field=label[len('policy-'):]
                for identity in (bad['identity'],bad['binding']['build']):identity['original_output'][field]='foreign'
            else:
                name=sources[label];path=target/name;text=path.read_text(encoding='cp1252')
                anchor=('         if(abs(hybrid_groundwater_cde_clock_trial(groundwater_bottom,groundwater_delta))>1d-10)flnonconv=.true.'
                        if selected.get('cde_clock_output') else
                        '         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.')
                if label=='head-relaxed-guard':assert text.count(anchor)==1;text=text.replace(anchor,anchor.replace('1d-10','1d-9'),1)
                elif label=='head-missing-guard':assert text.count(anchor)==1;text=text.replace(anchor,'',1)
                else:text+='\n! deliberately foreign actual Snow groundwater provider\n'
                path.write_text(text,encoding='cp1252')
                for identity in (bad['identity'],bad['binding']['build']):identity['donor_generated'][name]=m.sha(path)
            (target/'BUILD.json').write_text(json.dumps(bad,indent=2)+'\n',encoding='utf-8')
            try:m.validate_bundle(target,args.reference_work,project)
            except ValueError as error:
                expected=('Foreign original output policy','Foreign explicit Snow groundwater',
                          'Foreign actual Snow groundwater','Foreign actual explicit Snow groundwater')
                assert any(str(error).startswith(value) for value in expected),(label,str(error))
                assert not list(target.rglob('donor.stdout')) and not list(target.rglob('accepted-*.zip'))
                result['refusals'].append(dict(field=label,error=str(error),before_worker=True,no_publication=True,
                                               forged_source_inventory=not label.startswith('policy-')))
            else:raise AssertionError('Forged Snow groundwater policy/source accepted: '+label)
            save()
        assert len(result['refusals'])==len(fields)+len(sources) and m.sha(bundle/'BUILD.json')==before
        result['status']='ACTUAL_EXPLICIT_SNOW_GROUNDWATER_SOURCE_POLICY_REFUSALS_PASS'
    except Exception as error:
        result.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(result['status'],len(result['refusals']))


if __name__=='__main__':main()
