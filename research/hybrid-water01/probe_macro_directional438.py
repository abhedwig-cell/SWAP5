"""Bounded fixed-live-state directional derivative observation on original438.

No checkpoint is rebound or published by the instrumented executable. Both
executions import the verified original native files; diagnostic execution
identity is recorded separately. Only a fork child reevaluates the residual.
"""
import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
import traceback
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle
from donor_sources import replace

C_SOURCE=r'''
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <errno.h>
int s5_shadow_begin(void) {
    pid_t p=fork(); int status=0;
    if(p==0) {alarm(3); return 0;}
    if(p<0) return -1;
    while(waitpid(p,&status,0)<0) {if(errno!=EINTR) return -2;}
    return WIFEXITED(status) && WEXITSTATUS(status)==0 ? 1 : -3;
}
void s5_shadow_end(void) {_exit(0);}
'''

OBSERVER=Path(__file__).with_name('macro_directional438_observer.f90').read_text()


def physical(row):return {k:v for k,v in row.items() if k!='revision'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--provider',type=Path,required=True)
    p.add_argument('--proof',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    report={'status':'RUNNING','new_full_runs':0,'window':[432,438],
        'hypothesis':'The original coupled residual is repeatable on identical live state but has nonlocal pressure derivatives absent from the original tridiagonal Jacobian',
        'acceptance':'Observed parent433to438 and entire raw native438 repeat frozen PR1655 control; two same-state fresh samples exactly repeat; eight nodal directions at two central-difference scales are child-only',
        'cap_each_seconds':20,'child_cap_seconds':3,'runs':[]}
    def persist():(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    persist()
    try:
        assert sys.platform=='linux'
        qualified=a.proof/'qualified/artifact.zip';segment=a.proof/'segments/4/artifact.zip'
        assert h.sha(qualified)=='b4840cb7afd435afe7b31c42e7370c70f130e6e70607d9e28aaf7c97ec228cbe'
        assert h.sha(segment)=='be43cb0fe9992fc3518ce5167c9f1b3adabd1ec4bed7f156760854375674d46a'
        with zipfile.ZipFile(qualified) as z:
            for n in z.namelist():
                if n.startswith('O2/build/') and not n.endswith('/'):
                    dest=a.output/n;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(n))
        bundle=a.output/'O2/build'
        index=json.loads((a.provider/'PROOF_INDEX.json').read_text())
        reference=a.provider/index['reference']
        meta,case=validate_bundle(bundle,reference,h.ANDELST)
        assert meta['identity']['compiler_sha256']==h.sha(Path(shutil.which('gfortran')))
        for n in ('day_donor','day_kernel'):h.executable(bundle,n).chmod(0o755)
        with zipfile.ZipFile(segment) as z:
            checkpoint=a.output/'original-native432.zip'
            checkpoint.write_bytes(z.read('resume-304-to-481/accepted-column-1-day-432.zip'))
            expected={x['day']:x for x in map(json.loads,z.read('resume-304-to-481/daily.jsonl').decode().splitlines())}
        receipt=h.verify_checkpoint(checkpoint,432,meta['binding'],a.output/'origin')
        report['original_build']=meta
        report['origin_package_sha256']=h.sha(checkpoint)
        observed=a.output/'observed-build';shutil.copytree(bundle,observed)
        source=(observed/'headcalc.f90').read_text(encoding='cp1252')
        source=replace(source,'!        special case for macropores','         call shadow438(1)\n!        special case for macropores')
        source=replace(source,'!     continue without convergence !!!','      call shadow438(2)\n!     continue without convergence !!!')
        source=replace(source,'\ncontains\n','\ncontains\n'+OBSERVER+'\n')
        (observed/'headcalc.f90').write_text(source,encoding='cp1252')
        (observed/'shadow.c').write_text(C_SOURCE)
        objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
        replacements={Path(n).with_suffix('.o').name:observed/Path(n).with_suffix('.o').name for n in meta['identity']['donor_generated']}
        commands=[['gcc','-O2','-c','shadow.c','-o','shadow.o'],
            ['gfortran',*meta['identity']['donor_flags'],'-I',str(objects),'-I',str(ttutil),'-c','headcalc.f90'],
            ['gfortran','-o',str(h.executable(observed,'day_donor')),
                *(str(replacements.get(f.name,f)) for f in sorted(objects.glob('*.o'))),
                str(observed/'hybrid_step_budget.o'),str(observed/'shadow.o'),str(ttutil/'libttutil.a')]]
        logs=[]
        for cmd in commands:
            start=time.perf_counter();r=subprocess.run(cmd,cwd=observed,capture_output=True,text=True,timeout=30)
            logs.append({'command':cmd,'seconds':time.perf_counter()-start,'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
            (a.output/'BUILD_LOG.json').write_text(json.dumps(logs,indent=2))
            assert r.returncode==0,r.stderr
        report['observation_identity']={
            'purpose':'Research-only observation, NOT the original source-bound build and NOT a rebound checkpoint',
            'script_sha256':h.sha(Path(__file__)),'headcalc_sha256':h.sha(observed/'headcalc.f90'),
            'c_sha256':h.sha(observed/'shadow.c'),'executable_sha256':h.sha(h.executable(observed,'day_donor'))}
        old_control=ROOT/'research/hybrid-water01/original-macro-day438-evidence.zip'
        assert h.sha(old_control)=='d66b55a4368a3d6b519590557fc4feae8ab8be3271912d8ed68e9320f43a7f63'
        with zipfile.ZipFile(old_control) as z:
            for name in ['control/daily.jsonl','control/original/result.end','control/original/macro.bin']:
                target=a.output/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(name))
        report['control_reuse']={'artifact_sha256':h.sha(old_control),'actual_original_source':'fe11b65305189d10f210c59da6622ace5648c4df','new_control_run':False}
        report['observation_identity']['observer_template_sha256']=h.sha(Path(__file__).with_name('macro_directional438_observer.f90'))
        original_start=h.start_process;original_send=h.send
        for label,donor in [('observation',observed)]:
            out=a.output/label;out.mkdir();workers=[];expired=threading.Event();checkpoint_requests=[]
            def start(*args,**kwargs):
                x=original_start(*args,**kwargs);workers.append(x[0]);return x
            def send(worker,message):
                # Request only raw donor files; no new source-bound package or binding is fabricated.
                if message=='438 -1':
                    checkpoint_requests.append(message);message='438 36233'
                return original_send(worker,message)
            def timeout():
                expired.set()
                for w in workers:
                    if w.poll() is None:w.kill()
            h.start_process=start;h.send=send
            started=time.perf_counter();timer=threading.Timer(20,timeout);timer.start();rows=[]
            try:
                with contextlib.ExitStack() as stack:
                    host=h.DailyHost(stack,h.executable(donor,'day_donor'),h.executable(bundle,'day_kernel'),case,out,
                        [h.ColumnStart(day=432,origin=a.output/'origin',receipt=receipt,name='original')],
                        runtime=True,checkpoint_enabled=True,binding=None)
                    for day in range(433,439):
                        row=host.step(1);rows.append(row)
                        (out/'daily.jsonl').write_text(''.join(json.dumps(x)+'\n' for x in rows))
                        assert physical(row)==physical(expected[day]),('Parent trajectory changed',label,day)
                    host.close()
            finally:
                timer.cancel();h.start_process=original_start;h.send=original_send
                for w in workers:
                    if w.poll() is None:w.kill()
                    w.wait(timeout=5)
                report['runs'].append({'label':label,'seconds':time.perf_counter()-started,
                    'expired':expired.is_set(),'verified_days':[x['day'] for x in rows]});persist()
            assert not expired.is_set() and len(checkpoint_requests)==1
        report['complete_raw_endpoint_hashes']={n:h.sha(a.output/'control/original'/n) for n in h.CHECKPOINT_FILES}
        assert all(h.sha(a.output/'observation/original'/n)==v for n,v in report['complete_raw_endpoint_hashes'].items())
        log=a.output/'observation/original/day438-shadow.txt'
        assert log.is_file(),'No last-step diagnostic sample'
        report['shadow_records']=log.read_text().splitlines()
        report['directional_samples']={p.name:p.read_text().splitlines() for p in sorted(log.parent.glob('directional-*.txt'))}
        assert len(report['directional_samples'])==34
        report['status']='PARENT_AND_NATIVE_EXACT_FIXED_STATE_DIRECTIONAL_SAMPLES_RECORDED'
    except Exception:
        report['status']='FAILED';report['error']=traceback.format_exc()
    persist();print(json.dumps({k:report[k] for k in ('status','runs')}))
    return 0 if report['status']=='PARENT_AND_NATIVE_EXACT_FIXED_STATE_DIRECTIONAL_SAMPLES_RECORDED' else 2


if __name__=='__main__':raise SystemExit(main())
