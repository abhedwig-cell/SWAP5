"""Actual unchanged NoSnow postimages after the selected explicit Snow correction."""
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

m=original.m;ROOT=original.ROOT


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','evidence','build-root','output'):
        parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    args=parser.parse_args();args.output.mkdir()
    read=lambda p:json.loads(p.read_text(encoding='utf-8'))
    previous=args.evidence/f'groundwater-interval-preservation-{args.optimization}-v1'
    baseline=read(previous/'RESULT.json');assert baseline['status']=='ACTUAL_THREE_UNCHANGED_CDE_POSTIMAGES_PASS'
    cases={name:dict(parent=previous/name,build=Path(baseline['cases'][name]['current_build']),
                    inputs=previous/name/'input',authority=previous/'RESULT.json')
           for name in ('groundwater-clock','head-clock')}
    interval=args.evidence/f'groundwater-interval-cohort-{args.optimization}-v1/h0-interval-monthly-off'
    receipt=read(interval/'RESULT.json')
    cases['groundwater-interval']=dict(parent=interval,build=Path(receipt['build_root']),
                                      inputs=Path(receipt['input_root']),authority=interval/'RESULT.json')
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                cases={},fresh_unaffected_full_periods=0)
    def save():(args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for name,baseline in cases.items():
            parent=baseline['parent'];oldbuild=baseline['build'];oldmeta=read(oldbuild/'BUILD.json')
            target=args.output/name;target.mkdir();inputs=target/'input';shutil.copytree(baseline['inputs'],inputs)
            project=m.e.load(inputs,original_output=True);build=args.build_root/name/'bundle'
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,
                     '--experimental-project',str(inputs),'--original-output','--reference-work',str(args.reference_work),
                     '--build-only','--donor-opt',args.optimization,'--kernel-opt',args.optimization,'--output',str(build)]
            with (target/'build.stdout').open('x') as out,(target/'build.stderr').open('x') as err:
                subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=180,check=True)
            meta,_=m.validate_bundle(build,args.reference_work,project)
            assert {p.name:p.read_bytes() for p in oldbuild.glob('*.f90')}=={p.name:p.read_bytes() for p in build.glob('*.f90')}
            assert oldmeta['inputs']==meta['inputs'] and oldmeta['project']==meta['project']
            assert not meta['identity']['original_output'].get('groundwater_snow_cde_output')
            delta=differences(oldmeta['identity'],meta['identity'])
            assert set(delta)<={'original_output.source_sha256','original_output.predecessor_owner_sha256',
                               'groundwater_native_state.source_sha256','groundwater_native_state.predecessor_sha256',
                               'restart_publisher.library_sha256'},delta
            publisher=None
            if 'restart_publisher.library_sha256' in delta:
                publisher=publisher_equivalence(oldbuild/'restart_publish.dll',build/'restart_publish.dll')
            receipt,data=m.trajectory(build,args.reference_work,project,target/'trajectory',35,{2,4,7,9,30,34,35},180)
            assert m.physical(data)==m.physical(m.rows(parent/'trajectory'))
            output_counts={}
            for filename in ('result_output.csv','result_output.bin'):
                oldpath=parent/'trajectory/original'/filename;newpath=target/'trajectory/original'/filename
                assert oldpath.exists()==newpath.exists()
                if oldpath.exists():
                    oldrecords=output_records(oldpath.read_bytes(),filename)
                    assert output_records(newpath.read_bytes(),filename)==oldrecords
                    output_counts[filename]=len(oldrecords)
            for day in (2,4,7,9,30,34,35):
                with zipfile.ZipFile(parent/f'trajectory/accepted-column-1-day-{day}.zip') as a,zipfile.ZipFile(target/f'trajectory/accepted-column-1-day-{day}.zip') as b:
                    assert all(a.read(member)==b.read(member) for member in ('macro.bin','result.end'))
            cold=original.previous.own(build,args.reference_work,project,target/'trajectory',data,30,34,target/'own-30')
            result['cases'][name]=dict(status='ACTUAL_UNCHANGED_FORTRAN_INPUT_PHYSICAL_NATIVE_POSTIMAGE_PASS',
                original_profile=str(parent),original_receipt_sha256=m.sha(baseline['authority']),original_receipt_path=str(baseline['authority']),
                original_BUILD_sha256=m.sha(oldbuild/'BUILD.json'),current_build=str(build),
                actual_BUILD_sha256=m.sha(build/'BUILD.json'),trajectory=receipt,cold=cold,
                identity_changes=delta,publisher=publisher,exact_original_user_record_counts=output_counts)
            save()
        result['status']='ACTUAL_THREE_UNCHANGED_NOSNOW_POSTIMAGES_PASS'
    except Exception as error:
        result.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(result['status'])


if __name__=='__main__':main()
