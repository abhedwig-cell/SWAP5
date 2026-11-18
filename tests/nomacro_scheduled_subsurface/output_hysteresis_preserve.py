"""Exact emitted/source/native preservation at changed selection boundaries."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import original_output_matrix as ordinary
import output_hysteresis_baseline as baseline
m=ordinary.m
ROOT=ordinary.ROOT


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output','prior-prefix','hysteresis-baseline'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--resume',action='store_true')
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    q=dict(status='RUNNING',profiles={},optimization=a.optimization)
    if a.resume:
        previous=json.loads((a.output/'RESULT.json').read_text());q['retained_failure']=previous
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    contexts=[('ordinary-'+key,Path(str(a.prior_prefix)+key+'-'+a.optimization),True) for key in ('water-nprint3','cde-solbal-csv3','age-csv3','age-perstep-monthly')]
    record=json.loads((a.hysteresis_baseline/'RESULT.json').read_text())
    for kind in ('water','cde','age'):
        for mode in (1,2):
            key=kind+'-hys'+str(mode);root=a.hysteresis_baseline/key
            if not (root/'build/BUILD.json').exists():
                root=Path(record['reused_completed_profiles'][key])
            contexts.append(('compatibility-'+key,root,False))
    try:
        for key,prior,flag in contexts:
            out=a.output/key;out.mkdir(exist_ok=a.resume);project=m.e.load(prior/'input',original_output=flag);build=out/'build'
            cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',project.input_directory,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            if flag:cmd+=['--original-output']
            if not (a.resume and (build/'BUILD.json').exists()):
                r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/'build.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
            actual,_=m.validate_bundle(build,a.reference_work,project);old=json.loads((prior/'build/BUILD.json').read_text())
            assert actual['project']==old['project'] and actual['inputs']==old['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age','original_output'):
                assert actual['identity'].get(field)==old['identity'].get(field),(key,field)
            days=35 if 'monthly' in key else 10;full=out/'trajectory'
            if a.resume and full.exists():
                data=m.rows(full);assert len(data)==days;report=dict(status='ACTUAL_COMPLETED_TRAJECTORY_REVALIDATED',days=days,budgets=m.check(data),build_sha256=m.sha(build/'BUILD.json'))
            else:report,data=m.trajectory(build,a.reference_work,project,full,days,{2,4,8,days},60)
            oldfull=prior/('trajectory' if not flag else 'short')
            if not oldfull.exists():oldfull=prior/'trajectory'
            assert m.physical(data)==m.physical(m.rows(oldfull))
            for day in (2,4,8,days):
                # Ordinary predecessor short runs retain their declared cuts.
                oldzip=oldfull/f'accepted-column-1-day-{day}.zip'
                if not oldzip.exists():continue
                with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(oldzip) as oldz:
                    for member in ('result.end','macro.bin'):assert new.read(member)==oldz.read(member),(key,day,member)
            files={x.name:hashlib.sha256(x.read_bytes()).hexdigest() for x in (full/'original').glob('*') if x.is_file() and (x.suffix.lower()=='.csv' or x.name.endswith('_output.bin'))}
            for file in files:assert (full/'original'/file).read_bytes()==(oldfull/'original'/file).read_bytes(),file
            if flag:own=[ordinary.own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in ((2,4),(4,8))]
            else:own=[baseline.own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in ((2,4),(4,8))]
            q['profiles'][key]=dict(actual_build=actual,prior_build_sha256=m.sha(prior/'build/BUILD.json'),prior_root=str(prior),generated_provider_exact=True,all_physical_exact=True,user_files_exact=files,complete_native_exact=True,trajectory=report,own=own);save();print(key,'HYSTERESIS_OUTPUT_DEFAULT_PRESERVED',flush=True)
        q['status']='TEN_ORDINARY_AND_HYSTERESIS_COMPATIBILITY_CONTEXTS_EXACT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
