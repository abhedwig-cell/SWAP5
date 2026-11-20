"""Refuse forged actual implicit Snow source bytes and self-reported hashes."""
import argparse
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original

m=original.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','profile','scratch','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();a.scratch.mkdir(parents=True)
    report=json.loads((a.profile/'RESULT.json').read_text());bundle=Path(report['build_root'])
    project=m.e.load(report['input_root'],original_output=True);meta,_=m.validate_bundle(bundle,a.reference_work,project)
    before=m.sha(bundle/'BUILD.json');inventory={p.name:m.sha(p) for p in bundle.iterdir() if p.is_file()}
    sources=[n for n in ('headcalc.f90','timecontrol.f90','integral.f90','boundtop.f90',
        'implicit_snow_root_state.f90','original_cde_output_state.f90','thermal_output_snow_calendar_state.f90',
        'groundwater_history_native_state.f90','implicit_pond_event_state.f90','implicit_pond_availability.f90') if (bundle/n).exists()]
    if 'implicit_snow_root_carry' in meta['identity']['original_output']:sources.append('macropore.f90')
    policies=['implicit-policy','native-codec']
    if 'implicit_snow_root_carry' in meta['identity']['original_output']:policies += ['root-provider','root-layout']
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        actual_BUILD_sha256=before,refusals=[],model_executions=0,compilations=0,expected_refusals=len(sources)+len(policies))
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for label in [*policies,*sources]:
            target=a.scratch/label;shutil.copytree(bundle,target,copy_function=os.link)
            forged=copy.deepcopy(meta)
            if label=='implicit-policy':forged['identity']['implicit_conductivity']['implicit_snow_policy']='foreign'
            elif label=='native-codec':forged['identity']['original_output']['native_codec']='S5FORGED'
            elif label=='root-provider':forged['identity']['original_output']['implicit_snow_root_carry']['provider_sha256']='0'*64
            elif label=='root-layout':forged['identity']['original_output']['implicit_snow_root_carry']['bytes']=80
            else:
                path=target/label;raw=path.read_bytes()
                if label=='macropore.f90':
                    old=b'values=[alpwetnoddrz,alpdrynodrtz]';assert raw.count(old)==1
                    raw=raw.replace(old,b'values=[0d0,0d0]',1)
                else:raw+=b'\n! foreign actual source, self-reported generated hash forged\n'
                path.unlink();path.write_bytes(raw)
                if label in forged['identity']['donor_generated']:forged['identity']['donor_generated'][label]=m.sha(path)
                (a.output/(label+'.mutated')).write_bytes(raw)
            path=target/'BUILD.json';path.unlink();path.write_text(json.dumps(forged,indent=2)+'\n')
            (a.output/(label+'.BUILD.json')).write_bytes(path.read_bytes())
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:
                q['refusals'].append(dict(attack=label,status='REFUSED',authority='public_source_preflight',diagnostic=str(error)))
            else:raise AssertionError('Forged implicit Snow source accepted: '+label)
            assert m.sha(bundle/'BUILD.json')==before
            assert all(m.sha(bundle/name)==sha for name,sha in inventory.items())
            save()
        q['status']='ACTUAL_IMPLICIT_SNOW_PUBLIC_SOURCE_REFUSALS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['refusals']))


if __name__=='__main__':main()
