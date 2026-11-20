"""Actual daily groundwater and head/plate clock postimages outside new scope."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from ordinary_pond_evidence import audit_short
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence

m=original.m;ROOT=original.ROOT


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('evidence','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
    oldcohort=json.loads((a.evidence/f'ordinary-pond-matrix-recovered-{a.optimization}-v1/RESULT.json').read_text())
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),cases={},fresh_unaffected_full_periods=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for name in ('cde-plate-history','cde-head-history1','cde-groundwater-history'):
            old=oldcohort['cases'][name]
            parent=Path(old.get('actual_case_root',a.evidence/f'ordinary-pond-matrix-recovered-{a.optimization}-v1'/name))
            before=json.loads((parent/'short/RESULT.json').read_text());params=before['parameters'];oldbuild=Path(before['build_root'])
            out=a.output/name;out.mkdir();inputs=out/'input';shutil.copytree(Path(before['input_root']),inputs)
            project=m.e.load(inputs,original_output=True);build=a.build_root/name/'bundle'
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            with (out/'build.stdout').open('w') as stdout,(out/'build.stderr').open('w') as stderr:
                r=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=180)
            r.check_returncode()
            command=[sys.executable,'-B',str(Path(original.__file__)),'--reference-work',str(a.reference_work),'--output',str(out/'short'),'--optimization',a.optimization,'--reuse-build',str(build),'--existing-input',str(inputs)]
            for key in ('solute','hysteresis','bottom','kmean','mode','format','reset','nprintday'):command+=['--'+key,str(params[key])]
            if params['perstep']:command.append('--perstep')
            with (out/'short.stdout').open('w') as stdout,(out/'short.stderr').open('w') as stderr:
                r=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=240)
            r.check_returncode()
            oldmeta=json.loads((oldbuild/'BUILD.json').read_text());meta=json.loads((build/'BUILD.json').read_text())
            assert {p.name:p.read_bytes() for p in oldbuild.glob('*.f90')}=={p.name:p.read_bytes() for p in build.glob('*.f90')}
            assert oldmeta['inputs']==meta['inputs'] and oldmeta['project']==meta['project']
            delta=differences(oldmeta['identity'],meta['identity'])
            assert set(delta)<={'original_output.source_sha256','groundwater_native_state.source_sha256','groundwater_native_state.predecessor_sha256','restart_publisher.library_sha256'},delta
            publisher=None
            if 'restart_publisher.library_sha256' in delta:
                for path,item in ((oldbuild,oldmeta),(build,meta)):assert m.sha(path/'restart_publish.dll')==item['identity']['restart_publisher']['library_sha256']
                publisher=publisher_equivalence(oldbuild/'restart_publish.dll',build/'restart_publish.dll')
            assert m.physical(m.rows(parent/'short/trajectory'))==m.physical(m.rows(out/'short/trajectory'))
            for day in (2,4,7,9,30,34,35):
                with zipfile.ZipFile(parent/f'short/trajectory/accepted-column-1-day-{day}.zip') as left,zipfile.ZipFile(out/f'short/trajectory/accepted-column-1-day-{day}.zip') as right:
                    assert all(left.read(n)==right.read(n) for n in ('result.end','macro.bin'))
            q['cases'][name]=dict(status='ACTUAL_UNSELECTED_CLOCK_INPUT_FORTRAN_PHYSICAL_NATIVE_EXACT',current_case=str(out),prior_case=str(parent),changed_identity_roles=delta,publisher=publisher,independent=audit_short(out),actual_days=35,exact_native_days=[2,4,7,9,30,34,35]);save()
        # Water has no changed source dependency and reuses its actual bundle.
        item=oldcohort['cases']['water-groundwater'];case=Path(item['actual_case_root']);record=json.loads((case/'short/RESULT.json').read_text())
        build=Path(record['build_root']);project=m.e.load(record['input_root'],original_output=True);before=m.sha(build/'BUILD.json')
        m.validate_bundle(build,a.reference_work,project)
        warm=case/'short/trajectory';q['water_unchanged_bundle_cold']=original.previous.own(build,a.reference_work,project,warm,m.rows(warm),30,34,a.output/'water-own30')
        assert m.sha(build/'BUILD.json')==before
        q['status']='ACTUAL_THREE_UNSELECTED_CDE_AND_WATER_NATIVE_PRESERVATION_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
