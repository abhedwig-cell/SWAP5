"""Target unchanged admitted routes using exact original source and postimages."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from calendar_evidence import differences
from implicit_conductivity_forensics import output_records
from water_snow_groundwater_period import cold
from calendar_publisher import publisher_equivalence


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','baseline','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--recover-existing',type=Path)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
    m=original.m;baseline=json.loads(a.baseline.read_text());assert len(baseline['cases'])==6
    q=dict(status='RUNNING',baseline=str(a.baseline),baseline_sha256=m.sha(a.baseline),cases={},fresh_unaffected_full_periods=0)
    recovered={}
    if a.recover_existing:
        previous=a.recover_existing/'RESULT.json';prior=json.loads(previous.read_text(encoding='utf-8'))
        assert prior['status']=='FAILED_OR_INCOMPLETE' and prior['baseline_sha256']==q['baseline_sha256']
        q['original_failed_observer']=dict(path=str(previous),sha256=m.sha(previous))
        recovered={k:v for k,v in prior['cases'].items() if v.get('status')=='ACTUAL_UNCHANGED_SOURCE_PHYSICAL_NATIVE_OUTPUT_POSTIMAGE_PASS'}
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for label,base in baseline['cases'].items():
            receipt=Path(base['receipt']);assert m.sha(receipt)==base['receipt_sha256'];old=json.loads(receipt.read_text())
            inputs=Path(old['input_root']);parent=Path(old['build_root']);oldbuild=json.loads((parent/'BUILD.json').read_text())
            project=m.e.load(inputs,original_output=True)
            from snow_undrained import selection
            assert selection(project) is None
            out=a.output/label;out.mkdir();build=parent
            item=q['cases'][label]=dict(baseline=base,input_root=str(inputs),fresh_compilations=0);save()
            try:m.validate_bundle(parent,a.reference_work,project)
            except ValueError as error:
                item['old_source_preflight_refusal']=str(error);build=a.build_root/label/'bundle'
                command=[sys.executable,'-B',str(original.ROOT/'tools/solute/run_water.py'),'--model',project.model,
                    '--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work),
                    '--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
                if (build/'BUILD.json').exists():
                    m.validate_bundle(build,a.reference_work,project)
                    item['reused_current_compilation_after_metadata_observer_refusal']=True
                else:
                    with (out/'build.stdout').open('x') as stdout,(out/'build.stderr').open('x') as stderr:
                        result=subprocess.run(command,cwd=original.ROOT,stdout=stdout,stderr=stderr,timeout=180)
                    item['build_returncode']=result.returncode;save();result.check_returncode();item['fresh_compilations']=1
            current,_=m.validate_bundle(build,a.reference_work,project)
            source=lambda root:{p.name:m.sha(p) for p in root.glob('*.f90')}
            assert source(parent)==source(build),'Unselected original Fortran changed'
            assert oldbuild['inputs']==current['inputs']
            project_changes=differences(oldbuild['project'],current['project'])
            assert set(project_changes)<={'case'} and current['project']['case']==project.case
            delta=differences(oldbuild['identity'],current['identity'])
            assert set(delta)<={'experimental_input_adapter','implicit_conductivity.implicit_snow_composition_source_sha256',
                'original_output.implicit_snow_composition_source_sha256',
                'implicit_groundwater_trial.source_sha256','implicit_groundwater_trial.original_projection_owner_sha256',
                'restart_publisher.library_sha256'},delta
            if 'restart_publisher.library_sha256' in delta:
                item['publisher_equivalence']=publisher_equivalence(parent/'restart_publish.dll',build/'restart_publish.dll')
            item.update(build_root=str(build),actual_BUILD_sha256=m.sha(build/'BUILD.json'),
                unchanged_Fortran=source(build),identity_changes=delta,project_metadata_changes=project_changes)
            warm=a.recover_existing/label/'trajectory' if label in recovered else out/'trajectory'
            restart=a.recover_existing/label/'own-30' if label in recovered else out/'own-30'
            if label in recovered:
                data=m.rows(warm);assert len(data)==35
                item['trajectory']=dict(status='REUSED_COMPLETED_ORIGINAL_RAW35',days=35,build_sha256=m.sha(build/'BUILD.json'))
            else:item['trajectory'],data=m.trajectory(build,a.reference_work,project,warm,35,{2,4,7,9,30,34,35},180)
            item.update(trajectory_root=str(warm),cold_actual_root=str(restart))
            parent_trajectory=Path(old.get('trajectory_root',receipt.parent/'trajectory'))
            assert m.physical(data)==m.physical(m.rows(parent_trajectory)),'Unchanged physical trajectory changed'
            for day in (2,4,7,9,30,34,35):
                with zipfile.ZipFile(parent_trajectory/f'accepted-column-1-day-{day}.zip') as left,zipfile.ZipFile(warm/f'accepted-column-1-day-{day}.zip') as right:
                    assert all(left.read(n)==right.read(n) for n in ('macro.bin','result.end')),'Unchanged complete native postimage changed'
            for path in (parent_trajectory/'original').glob('result_output.*'):
                if path.suffix in ('.csv','.bin'):
                    assert output_records(path.read_bytes(),path.name)==output_records((warm/'original'/path.name).read_bytes(),path.name)
            item['cold']=cold(build,a.reference_work,project,warm,data,30,34,restart)
            item['status']='ACTUAL_UNCHANGED_SOURCE_PHYSICAL_NATIVE_OUTPUT_POSTIMAGE_PASS';save();print(label,item['status'],flush=True)
        assert m.sha(a.baseline)==q['baseline_sha256'];q['status']='ACTUAL_SIX_UNSELECTED_SNOW_UNDRAINED_DEPENDENCY_POSTIMAGES_PASS'
    except Exception as error:q.update(status='FAILED_OR_INCOMPLETE',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
