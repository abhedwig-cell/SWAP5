"""Target actual unaffected ordinary and admitted implicit-Frost compiled postimages."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import original_output_matrix as thermal
from implicit_conductivity_forensics import output_records
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
from water_snow_groundwater_period import cold as cold_continuation
from model7_search_science import Store,SHA
m=thermal.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output','evidence'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--recover-existing',type=Path);a=p.parse_args();a.output.mkdir();a.build_root.mkdir(exist_ok=True)
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,profiles={},unaffected_full_periods_replayed=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    recovered={}
    if a.recover_existing:
        previous=json.loads((a.recover_existing/'RESULT.json').read_text());assert previous['status']=='FAILED'
        assert not subprocess.check_output(['git','diff',previous['source'],'HEAD','--','app','src','tools/solute','tools/vq','reference'],cwd=ROOT)
        recovered=previous['profiles'];q['original_failed_observer']=dict(path=str(a.recover_existing/'RESULT.json'),sha256=SHA((a.recover_existing/'RESULT.json').read_bytes()))
    try:
        with ExitStack() as stack:
            proof=ROOT/'integration/f-ci/nomacro-complete01';support=Store(proof,'FROST_IMPLICIT_WINDOWS_SUPPORT_RAW_ARCHIVE',stack)
            old=Store(proof,'FROST_IMPLICIT_WINDOWS_UNSELECTED_'+a.optimization+'_RAW_ARCHIVE',stack)
            selected=[]
            manifest=json.loads((a.evidence/f'implicit-frost-unselected-postimages-{a.optimization}-v1/RESULT.json').read_text())
            for name in ('water-groundwater-explicit-daily','ordinary-snow-cde-implicit-head-clock-positive'):
                b=manifest['profiles'][name];selected.append((name,b,b['baseline']['time_policy'],old,'UNSELECTED_COMPILED_PROJECTION_V1.json'))
            for kind in ('water','cde'):
                folder=a.evidence/f'frost-implicit-root-daily-{kind}-short-{a.optimization}-v1';b=json.loads((folder/'RESULT.json').read_text());b['trajectory_root']=str(folder/'trajectory')
                selected.append(('implicit-frost-'+kind,b,'original-adaptive-event-closure-v1',support,'COMPILED_PROJECTION_V1.json'))
            for name,b,policy,archive,projection_name in selected:
                inputs=Path(b['input_root']);old_trajectory=Path(b['trajectory_root']);project=m.e.load(inputs,original_output=True,time_step_policy=policy)
                out=a.output/name;out.mkdir();build=a.build_root/name/'bundle'
                item=q['profiles'][name]=dict(status='RUNNING',baseline=b,time_policy=policy,input_root=str(inputs),build_root=str(build));save()
                command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output',
                    '--experimental-time-step-policy',policy,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
                if (build/'BUILD.json').exists():
                    item['retained_actual_compilation']=recovered[name].get('build',recovered[name].get('retained_actual_compilation'));assert item['retained_actual_compilation']['returncode']==0
                else:
                    r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
                    (out/'build.stdout').write_text(r.stdout);(out/'build.stderr').write_text(r.stderr);item['build']=dict(command=command,returncode=r.returncode);save();r.check_returncode()
                meta,_=m.validate_bundle(build,a.reference_work,project);assert not meta['identity'].get('model7_capacity') and not meta['identity'].get('model7_terminal_water')
                projection=json.loads(archive.get(projection_name))[b['build_root']];prefix=projection['prefix'];base=archive.view(prefix)
                assert SHA((base/'BUILD.json').read_bytes())==projection['actual_BUILD_sha256']
                before={path.name:path.read_bytes() for path in base.glob('*.f90')};after={path.name:path.read_bytes() for path in build.glob('*.f90')}
                assert before==after,'Unselected complete compiled Fortran changed: '+name
                oldmeta=json.loads((base/'BUILD.json').read_text());delta=differences(oldmeta['identity'],meta['identity'])
                assert set(delta)<={'host','original_output.composition_build_sha256','restart_publisher.library_sha256'},delta
                if 'restart_publisher.library_sha256' in delta:
                    original_dll=out/'original-restart_publish.dll';original_dll.write_bytes((base/'restart_publish.dll').read_bytes())
                    item['publisher_equivalence']=publisher_equivalence(original_dll,build/'restart_publish.dll')
                item['identity_changes']=delta;item['unchanged_complete_Fortran']={key:SHA(value) for key,value in after.items()}
                if recovered.get(name,{}).get('trajectory',{}).get('days')==35:
                    trajectory=Path(recovered[name].get('trajectory_root',str(a.recover_existing/name/'trajectory')));data=m.rows(trajectory);assert len(data)==35;m.check(data)
                    item['trajectory']=recovered[name]['trajectory'];item['retained_actual_35day_postimage']=True
                else:
                    trajectory=out/'trajectory';item['trajectory'],data=m.trajectory(build,a.reference_work,project,trajectory,35,{2,4,30,34,35},180)
                item['trajectory_root']=str(trajectory);save()
                assert m.physical(data)==m.physical(m.rows(old_trajectory)[:35])
                for day in (2,4,30,34,35):
                    with zipfile.ZipFile(old_trajectory/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(trajectory/f'accepted-column-1-day-{day}.zip') as y:
                        assert all(x.read(key)==y.read(key) for key in ('macro.bin','result.end'))
                for filename in ('result_output.csv','result_output.bin'):
                    actual=trajectory/'original'/filename;prior=old_trajectory/'original'/filename
                    assert actual.exists()==prior.exists()
                    if actual.exists():
                        rows=output_records(actual.read_bytes(),filename);assert rows==output_records(prior.read_bytes(),filename)[:len(rows)]
                item['cold']=cold_continuation(build,a.reference_work,project,trajectory,data,30,34,out/'own-30')
                item['status']='UNSELECTED_COMPLETE_COMPILED_FORTRAN_35DAY_NATIVE_REAL4_COLD_EXACT_PASS';save();print(name,item['status'],flush=True)
            q['status']='ACTUAL_FOUR_TARGETED_UNSELECTED_MODEL7_DEPENDENCY_POSTIMAGES_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
