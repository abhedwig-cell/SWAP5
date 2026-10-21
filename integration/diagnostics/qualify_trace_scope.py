"""Observe actual unchanged-numerics columns and run original preservation gates."""
import argparse
import csv
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import resource
import runpy
import shlex
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def once(text,old,new):
    if text.count(old)!=1:raise ValueError('observing preimage '+old)
    return text.replace(old,new,1)


def validate_columns(out,old):
    rows=lambda raw:list(csv.DictReader(raw.splitlines()))
    strip=lambda rr:[{k:v for k,v in r.items() if k!='cpu'} for r in rr]
    for tag in ['baseline-O2-1536','current-O2-512','current-O0-512']:
        for name in ['budget.csv','trajectory.csv','stdout']:
            assert (out/tag/name).read_bytes()==old['oracle/'+name],('dry mismatch',tag,name)
        assert strip(rows((out/tag/'work.csv').read_text()))==strip(rows(old['oracle/work.csv'].decode()))
    control=json.loads((out/'baseline-O2-512/RESOURCE.json').read_text())
    assert control['exit']!=0 and control['max_rss_kib']>=480*1024
    assert (out/'baseline-O2-512/stdout').read_bytes()!=old['oracle/stdout']
    assert len(rows((out/'baseline-O2-512/work.csv').read_text()))<6
    for tag in ['current-O0-512','current-O2-512']:
        r=json.loads((out/tag/'RESOURCE.json').read_text())
        assert r['exit']==1 and r['max_rss_kib']<128*1024 and not r['timed_out']


def observer(root,build,out):
    out.mkdir()
    b=json.loads((build/'build-complete.json').read_text())
    assert all(sha(root/p)==h for p,h in b['input_sha256'].items())
    source=out/'main.f90';text=(root/'app/solute_column/main.f90').read_text()
    text=once(text,'  implicit none','  implicit none\n  integer :: perf_u,perf_v,perf_n\n  real(real64)::perf_start,perf_end')
    fields=['attempts','accepted_substeps','temporal_rejections','solver_rejections','mass_rejections','headcalc_calls','nonlinear_iterations']
    text=once(text,'  do j=first,stop_after',"  open(newunit=perf_u,file='work.csv',status='new')\n"
        "  open(newunit=perf_v,file='trajectory.csv',status='new')\n"
        "  write(perf_u,'(A)') 'window,cpu,"+','.join(fields)+"'\n"
        "  write(perf_v,'(A)') 'window,node,head,theta,concentration'\n"
        '  do j=first,stop_after\n    call cpu_time(perf_start)')
    needle="    call require(result%status==JOINT_OK,'joint interval rejected')"
    text=once(text,needle,"    call cpu_time(perf_end)\n"
        "    write(perf_u,'(I0,\",\",ES25.17E3,7(\",\",I0))') j,perf_end-perf_start, &\n      "+
        ', &\n      '.join('result%diagnostics%'+p for p in fields)+'''\n    flush(perf_u)
    if(result%status/=JOINT_OK)then
      call water%current_time(clock,ok)
      write(*,*) 'FAILED_REQUEST',t0,t1,'COMMITTED_WATER_CLOCK',clock,ok
      call solute%snapshot(clock,theta,mobile,companion,revision)
      write(*,*) 'COMMITTED_CHEMICAL_CLOCK',clock,'CHEMICAL_STEPS',result%chemical%completed_substeps
    end if
'''+needle)
    text=once(text,'    clock=t1',"""    call water%snapshot(physical,ok)
    call require(ok,'diagnostic water snapshot failed')
    call solute%snapshot(clock,theta,mobile,companion,revision)
    select type(q=>physical)
    type is(fmr_b110_physical_state_t)
      do perf_n=1,numnod
        write(perf_v,'(I0,",",I0,3(",",ES25.17E3))')j,perf_n,q%pressure_head(perf_n),theta(perf_n),mobile%concentration_mg_cm3(perf_n)
      end do
    class default
      error stop 'diagnostic nonthermal state required'
    end select
    flush(perf_v)
    flush(u)
    clock=t1""")
    source.write_text(text)
    fc=b['compiler_command'];flags=[f for f in b['flags'] if not f.startswith(('-I','-J'))]+['-J'+str(out),'-I'+str(out),'-I'+str(build)]
    objects=[e['command'][e['command'].index('-o')+1] for e in b['events'] if e['category']=='compile'
        and not e['command'][e['command'].index('-c')+1].endswith('/app/solute_column/main.f90')]
    commands=[fc+flags+['-c',str(source),'-o',str(out/'main.o')],fc+flags+objects+[str(out/'main.o'),'-o',str(out/'column')]]
    with (out/'build.log').open('w') as log:
        for command in commands:subprocess.run(command,check=True,stdout=log,stderr=log)
    return dict(build=b,main_sha256=sha(source),commands=commands,executable_sha256=sha(out/'column'),object_sha256={p:sha(Path(p)) for p in objects})


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--builds',type=Path,required=True)
    ap.add_argument('--baseline-worktree',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--phase',choices=['columns','preservation','validate-columns','nut'],required=True)
    a=ap.parse_args();builds=a.builds.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=a.phase=='validate-columns')
    if a.phase=='validate-columns':
        report=json.loads((out/'RESULT.json').read_text())
        old=runpy.run_path(str(ROOT/'integration/diagnostics/verify_perf01_dry.py'))['capsule']()
        validate_columns(out,old)
        report['status']='ORIGINAL86_AND_EXACT_DRY_FAILURE_UNDER512MIB_PASS'
        report['resource_control_disposition']='Retained failed control: SIGSEGV/ENOMEM under512MiB, never a scientific PASS'
        report['inputs']={p:sha(ROOT/p) for p in ['src/transaction/mod_transaction_reference.f90','src/runtime/mod_fmr_serialized_reference_backend.f90']}
        (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');return
    base=a.baseline_worktree.resolve();fc=json.loads((builds/'current-O2/build-complete.json').read_text())['compiler_command']
    env={**os.environ,'FC':shlex.join(fc),'PYTHONDONTWRITEBYTECODE':'1'}
    report=dict(status='RUNNING',phase=a.phase,events=[],inputs={})
    def run(command,category,cwd=ROOT):
        start=time.monotonic();p=subprocess.run(list(map(str,command)),cwd=cwd,env=env,capture_output=True)
        i=len(report['events'])
        for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
        event=dict(command=list(map(str,command)),category=category,cwd=str(cwd),returncode=p.returncode,seconds=time.monotonic()-start,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr')
        report['events'].append(event);(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
        if p.returncode:raise RuntimeError(category+' '+p.stderr.decode()[-2000:]+p.stdout.decode()[-2000:])
        print('PRESERVATION_PHASE_COMPLETE',category,flush=True)
    if a.phase=='nut':
        # Concurrent finite-donor physics is disjoint, but its shared runtime
        # consumes both changed providers. Execute its original callers freshly.
        owner=runpy.run_path(str(ROOT/'integration/audits/verify_nut_negative.py'))
        # The original large retained driver needs more than the shell's8MiB
        # stack. Preserve that native setup explicitly; physics is unchanged.
        resource.setrlimit(resource.RLIMIT_STACK,(-1,-1))
        report['stack_limit']='unlimited for original large retained driver'
        old=owner['capsule']()
        for p,raw in old.items():
            if p.startswith('reference/'):
                target=out/p;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
        import base64,io,tarfile
        with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/MC_NUT01_REPRODUCTIVE_PROCESS_SCIENCE_20261016.tar.xz.b64').read_bytes()))) as archive:
            literal=out/'literal.f90';literal.write_bytes(archive.extractfile('process/literal.f90').read())
        wrapper=out/'gfortran';wrapper.write_text('#!/bin/sh\nexec '+shlex.join(fc)+' "$@"\n');wrapper.chmod(0o755)
        env.update(FC=str(wrapper),REPRODUCTIVE_LITERAL_FILE=str(literal),REPRODUCTIVE_LITERAL_SHA256=sha(literal),
                   CROP_N_RESULT_DIR=str(out/'retained'),OMP_NUM_THREADS='1',PATH=str(out)+os.pathsep+env['PATH'])
        run(['python','-B',ROOT/'integration/audits/run_nut_negative.py','--output',out/'production','--reference-result',out/'reference'],'finite_donor_production')
        run(['python','-B',ROOT/'tests/nut-crop/run_b112_retained_joint.py'],'original_retained_joint')
        report['status']='CONCURRENT_FINITE_DONOR_AND_RETAINED_FRESH_PASS'
    elif a.phase=='columns':
        run(['python','-B',ROOT/'tests/nut-sol/test_column_input.py','--build-O0',builds/'current-O0','--build-O2',builds/'current-O2','--output',out/'qualification'],'original86')
        report['observers']={tag:observer(root,builds/tag,out/(tag+'-observer')) for tag,root in [('baseline-O2',base),('current-O2',ROOT),('current-O0',ROOT)]}
        old=runpy.run_path(str(ROOT/'integration/diagnostics/verify_perf01_dry.py'))['capsule']()
        inp=out/'dry.nml';inp.write_bytes(old['oracle/input.nml'])
        report['dry']=[]
        for tag,memory in [('baseline-O2',1536),('baseline-O2',512),('current-O2',512),('current-O0',512)]:
            directory=out/(tag+'-'+str(memory));directory.mkdir()
            source=directory/'input.nml';source.write_bytes(inp.read_bytes())
            executable=out/(tag+'-observer/column')
            command=[str(executable),str(source),'-','6']
            def limit():resource.setrlimit(resource.RLIMIT_AS,(memory*1024**2,memory*1024**2))
            start=time.monotonic()
            with (directory/'stdout').open('w') as so,(directory/'stderr').open('w') as se:
                process=subprocess.Popen(command,cwd=directory,env=env,stdout=so,stderr=se,preexec_fn=limit)
                timed_out=False
                while True:
                    pid,status,usage=os.wait4(process.pid,os.WNOHANG)
                    if pid:break
                    if time.monotonic()-start>=90:
                        timed_out=True;process.kill();pid,status,usage=os.wait4(process.pid,0);break
                    time.sleep(.02)
                process.returncode=os.waitstatus_to_exitcode(status)
                code='TIMEOUT' if timed_out else process.returncode
            (directory/'RESOURCE.json').write_text(json.dumps(dict(max_rss_kib=usage.ru_maxrss,seconds=time.monotonic()-start,
                exit=process.returncode,timed_out=timed_out))+'\n')
            record=dict(tag=tag,address_space_mib=memory,timeout=90,command=command,cwd=str(directory),returncode=code,seconds=time.monotonic()-start,
                raw_sha256={p.name:sha(p) for p in directory.iterdir() if p.is_file()})
            report['dry'].append(record);(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
            print('DRY_PROBE_COMPLETE',tag,memory,code,flush=True)
        validate_columns(out,old)
        report['status']='ORIGINAL86_AND_EXACT_DRY_FAILURE_UNDER512MIB_PASS'
    else:
        manifest=builds/'current-O2/build-complete.json'
        run(['python','-B',ROOT/'integration/performance/preserve_proposal_runtime.py','--output',out/'runtime','--compiler-manifest',manifest],'runtime_and_matrix_linear')
        for family,physical,qualifier,initial in [('matrix','tests/nut-sol/run_matrix_thermal.py','integration/audits/qualify_matrix_thermal.py',out/'runtime/thermal-physical'),('pond','tests/nut-sol/run_pond_thermal.py','integration/audits/qualify_pond_thermal.py',None)]:
            first=initial
            for exponent in (['0.5','0.8','1.0005','1.5','2'] if initial else ['1','0.5','0.8','1.0005','1.5','2']):
                directory=out/family/exponent;directory.mkdir(parents=True)
                command=['python','-B',ROOT/physical,'--output',directory/'physical','--exponent',exponent]
                if first:command+=['--reuse-build',first]
                run(command,family+'-'+exponent+'-physical')
                if first is None:first=directory/'physical'
                run(['python','-B',ROOT/qualifier,'--physical',directory/'physical','--output',directory/'qualified','--build',first,'--nonlinear-refinement'],family+'-'+exponent+'-qualified')
        for days,label in [(30,'month'),(365,'season')]:
            run(['python','-B',ROOT/'tests/nut-sol/qualify_thermal_pond_application.py','--build-O0',builds/'current-O0','--build-O2',builds/'current-O2','--output',out/label,'--days',days],label)
        report['status']='CURRENT_RUNTIME_MATRIX_POND_THERMAL_AND_MONTH_YEAR_PRESERVED'
    for path in ['src/transaction/mod_transaction_reference.f90','src/runtime/mod_fmr_serialized_reference_backend.f90']:
        report['inputs'][path]=sha(ROOT/path)
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')


if __name__=='__main__':main()
