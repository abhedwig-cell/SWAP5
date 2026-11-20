"""Actual unchanged NoSnow and explicit Snow postimages, without full replays."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
from implicit_conductivity_forensics import output_records

m=original.m
ALLOWED={'experimental_input_adapter','implicit_conductivity.source_sha256',
    'implicit_groundwater_trial.source_sha256','implicit_groundwater_trial.original_projection_owner_sha256',
    'ordinary_implicit_pond_switch.source_sha256','restart_publisher.library_sha256',
    'original_output.source_sha256','original_output.predecessor_owner_sha256',
    'original_output.groundwater_trial_provider_sha256',
    'original_output.groundwater_snow_composition_sha256'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','baseline','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--reuse-existing-builds',action='store_true')
    a=p.parse_args();a.output.mkdir();before=m.sha(a.baseline);baselines=json.loads(a.baseline.read_text())
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        baseline=str(a.baseline),baseline_sha256=before,cases={},fresh_unaffected_full_periods=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for name,b in baselines['profiles'].items():
            parent=Path(b['trajectory_root']);oldbuild=Path(b['build_root']);oldmeta=json.loads((oldbuild/'BUILD.json').read_text())
            assert m.sha(Path(b['receipt']))==b['receipt_sha256']
            out=a.output/name;out.mkdir();inputs=out/'input';shutil.copytree(b['input_root'],inputs)
            project=m.e.load(inputs,original_output=True);build=a.build_root/name/'bundle'
            command=[sys.executable,'-B',str(original.ROOT/'tools/solute/run_water.py'),'--model',project.model,
                '--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),
                '--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            if (build/'BUILD.json').exists():assert a.reuse_existing_builds
            else:
                with (out/'build.stdout').open('x') as stdout,(out/'build.stderr').open('x') as stderr:
                    subprocess.run(command,cwd=original.ROOT,stdout=stdout,stderr=stderr,timeout=180,check=True)
            meta,_=m.validate_bundle(build,a.reference_work,project)
            assert {p.name:p.read_bytes() for p in oldbuild.glob('*.f90')}=={p.name:p.read_bytes() for p in build.glob('*.f90')}
            assert oldmeta['inputs']==meta['inputs'] and oldmeta['project']==meta['project']
            assert not (meta['identity'].get('implicit_conductivity') or {}).get('implicit_snow_composition')
            delta=differences(oldmeta['identity'],meta['identity']);assert set(delta)<=ALLOWED,delta
            publisher=publisher_equivalence(oldbuild/'restart_publish.dll',build/'restart_publish.dll') if 'restart_publisher.library_sha256' in delta else None
            trajectory,data=m.trajectory(build,a.reference_work,project,out/'trajectory',35,{2,4,7,9,30,34,35},180)
            assert m.physical(data)==m.physical(m.rows(parent))
            records={}
            for filename in ('result_output.csv','result_output.bin'):
                old=parent/'original'/filename;new=out/'trajectory/original'/filename
                assert old.exists()==new.exists()
                if old.exists():
                    values=output_records(old.read_bytes(),filename);assert output_records(new.read_bytes(),filename)==values
                    records[filename]=len(values)
            for day in (2,4,7,9,30,34,35):
                with zipfile.ZipFile(parent/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as y:
                    assert all(x.read(n)==y.read(n) for n in ('macro.bin','result.end'))
            cold=original.previous.own(build,a.reference_work,project,out/'trajectory',data,30,34,out/'own-30')
            q['cases'][name]=dict(status='ACTUAL_UNCHANGED_FORTRAN_INPUT_PHYSICAL_NATIVE_POSTIMAGE_PASS',
                baseline=b,build_root=str(build),input_root=str(inputs),actual_BUILD_sha256=m.sha(build/'BUILD.json'),
                identity_changes=delta,publisher=publisher,trajectory=trajectory,cold=cold,exact_original_user_record_counts=records)
            save()
        assert m.sha(a.baseline)==before
        q['status']='ACTUAL_UNSELECTED_IMPLICIT_SNOW_DEPENDENCY_POSTIMAGES_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['cases']))


if __name__=='__main__':main()
