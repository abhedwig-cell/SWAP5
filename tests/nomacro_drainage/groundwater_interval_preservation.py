"""Current postimages for unchanged clock, daily CDE and water dependencies."""
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

m=original.m;ROOT=original.ROOT


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','evidence','build-root','output'):
        parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    args=parser.parse_args();args.output.mkdir()
    read=lambda p:json.loads(p.read_text(encoding='utf-8'))
    cohort=read(args.evidence/f'groundwater-clock-cohort-{args.optimization}-v1/RESULT.json')
    old=args.evidence/f'ordinary-pond-matrix-recovered-{args.optimization}-v1'
    cases={'groundwater-clock':Path(cohort['cases']['h2-periodic']['actual_case_root']),
           'head-clock':old/'cde-head-history1/short','groundwater-daily':old/'cde-groundwater-history/short'}
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                cases={},fresh_unaffected_full_periods=0)
    def save():(args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for name,parent in cases.items():
            prior=read(parent/'RESULT.json');oldbuild=Path(prior['build_root']);oldmeta=read(oldbuild/'BUILD.json')
            target=args.output/name;target.mkdir();inputs=target/'input';shutil.copytree(Path(prior['input_root']),inputs)
            project=m.e.load(inputs,original_output=True);build=args.build_root/name/'bundle'
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,
                     '--experimental-project',str(inputs),'--original-output','--reference-work',str(args.reference_work),
                     '--build-only','--donor-opt',args.optimization,'--kernel-opt',args.optimization,'--output',str(build)]
            with (target/'build.stdout').open('x') as out,(target/'build.stderr').open('x') as err:
                subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=180,check=True)
            meta,_=m.validate_bundle(build,args.reference_work,project)
            assert {p.name:p.read_bytes() for p in oldbuild.glob('*.f90')}=={p.name:p.read_bytes() for p in build.glob('*.f90')}
            assert oldmeta['inputs']==meta['inputs'] and oldmeta['project']==meta['project']
            delta=differences(oldmeta['identity'],meta['identity'])
            assert set(delta)<={'original_output.source_sha256','original_output.predecessor_owner_sha256',
                               'groundwater_native_state.source_sha256','groundwater_native_state.predecessor_sha256',
                               'restart_publisher.library_sha256'},delta
            publisher=None
            if 'restart_publisher.library_sha256' in delta:
                publisher=publisher_equivalence(oldbuild/'restart_publish.dll',build/'restart_publish.dll')
            receipt,data=m.trajectory(build,args.reference_work,project,target/'trajectory',35,{2,4,7,9,30,34,35},180)
            assert m.physical(data)==m.physical(m.rows(parent/'trajectory'))
            for day in (2,4,7,9,30,34,35):
                with zipfile.ZipFile(parent/f'trajectory/accepted-column-1-day-{day}.zip') as a,zipfile.ZipFile(target/f'trajectory/accepted-column-1-day-{day}.zip') as b:
                    assert all(a.read(member)==b.read(member) for member in ('macro.bin','result.end'))
            cold=original.previous.own(build,args.reference_work,project,target/'trajectory',data,30,34,target/'own-30')
            result['cases'][name]=dict(status='ACTUAL_UNCHANGED_FORTRAN_INPUT_PHYSICAL_NATIVE_POSTIMAGE_PASS',
                original_profile=str(parent),original_receipt_sha256=m.sha(parent/'RESULT.json'),
                original_BUILD_sha256=m.sha(oldbuild/'BUILD.json'),current_build=str(build),
                actual_BUILD_sha256=m.sha(build/'BUILD.json'),trajectory=receipt,cold=cold,
                identity_changes=delta,publisher=publisher)
            save()
        result['status']='ACTUAL_THREE_UNCHANGED_CDE_POSTIMAGES_PASS'
    except Exception as error:
        result.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(result['status'])


if __name__=='__main__':main()
