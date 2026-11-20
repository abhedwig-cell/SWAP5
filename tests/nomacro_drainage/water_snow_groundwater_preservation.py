"""Target current unchanged dependencies; rebuild only changed CDE interval policy."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
from implicit_conductivity_forensics import output_records,output_continuation
from water_snow_groundwater_period import cold


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','manifest','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--recover-existing',type=Path)
    a=p.parse_args();a.output.mkdir();baselines=json.loads(a.manifest.read_text());before=original.m.sha(a.manifest)
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        baseline_sha256=before,cases={},fresh_unaffected_full_periods=0)
    if a.recover_existing:
        prior=a.recover_existing/'RESULT.json';oldrecord=json.loads(prior.read_text())
        assert oldrecord['status']=='FAILED' and 'No prescribed groundwater CDE native domain' in oldrecord['error']
        q['original_failed_observer']=str(prior);q['original_failed_observer_sha256']=original.m.sha(prior)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for label,base in baselines['cases'].items():
            oldbuild=Path(base['build_root']);inputs=Path(base['input_root']);old=Path(base['trajectory_root']);out=a.output/label;out.mkdir()
            assert original.m.sha(Path(base['receipt']))==base['receipt_sha256']
            project=original.m.e.load(inputs,original_output=True);oldmeta=json.loads((oldbuild/'BUILD.json').read_text());build=oldbuild
            if base['rebuild_changed_policy']:
                build=a.build_root/label/'bundle'
                command=[sys.executable,'-B',str(original.ROOT/'tools/solute/run_water.py'),'--model',project.model,
                    '--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),
                    '--build-only','--donor-opt',base['optimization'],'--kernel-opt',base['optimization'],'--output',str(build)]
                with (out/'build.stdout').open('x') as stdout,(out/'build.stderr').open('x') as stderr:subprocess.run(command,cwd=original.ROOT,stdout=stdout,stderr=stderr,timeout=180,check=True)
            meta,_=original.m.validate_bundle(build,a.reference_work,project)
            assert oldmeta['inputs']==meta['inputs'] and oldmeta['project']==meta['project']
            assert {p.name:p.read_bytes() for p in oldbuild.glob('*.f90')}=={p.name:p.read_bytes() for p in build.glob('*.f90')}
            delta=differences(oldmeta['identity'],meta['identity'])
            assert set(delta)<={'implicit_groundwater_trial.source_sha256','restart_publisher.library_sha256'},delta
            if 'restart_publisher.library_sha256' in delta:publisher_equivalence(oldbuild/'restart_publish.dll',build/'restart_publish.dll')
            warm=out/'trajectory';restart_path=out/'own-30'
            if a.recover_existing and (a.recover_existing/label/'trajectory/daily.jsonl').exists():
                warm=a.recover_existing/label/'trajectory';data=original.m.rows(warm);assert len(data)==35
                trajectory=dict(status='REUSED_COMPLETED_ORIGINAL_RAW35',days=35,build_sha256=original.m.sha(build/'BUILD.json'))
                restart_path=a.recover_existing/label/'own-30'
            else:trajectory,data=original.m.trajectory(build,a.reference_work,project,warm,35,{2,4,7,9,30,34,35},180)
            assert original.m.physical(data)==original.m.physical(original.m.rows(old))
            for day in (2,4,7,9,30,34,35):
                with zipfile.ZipFile(old/f'accepted-column-1-day-{day}.zip') as aold,zipfile.ZipFile(warm/f'accepted-column-1-day-{day}.zip') as anew:
                    assert all(aold.read(n)==anew.read(n) for n in ('macro.bin','result.end'))
            for name in ('result_output.csv','result_output.bin'):
                beforefile=old/'original'/name;afterfile=warm/'original'/name;assert beforefile.exists()==afterfile.exists()
                if beforefile.exists():assert output_records(beforefile.read_bytes(),name)==output_records(afterfile.read_bytes(),name)
            restart=cold(build,a.reference_work,project,warm,data,30,34,restart_path)
            q['cases'][label]=dict(status='ACTUAL_UNCHANGED_WATER_SNOW_GROUNDWATER_DEPENDENCY_POSTIMAGE_PASS',
                baseline=base,build_root=str(build),input_root=str(inputs),actual_BUILD_sha256=original.m.sha(build/'BUILD.json'),
                identity_changes=delta,fresh_compilations=int(base['rebuild_changed_policy']),trajectory=trajectory,cold=restart,
                trajectory_root=str(warm),cold_actual_root=str(restart_path))
            save()
        assert original.m.sha(a.manifest)==before
        if a.recover_existing:assert original.m.sha(a.recover_existing/'RESULT.json')==q['original_failed_observer_sha256']
        q['status']='ACTUAL_FIVE_UNCHANGED_WATER_SNOW_GROUNDWATER_POSTIMAGES_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['cases']))


if __name__=='__main__':main()
