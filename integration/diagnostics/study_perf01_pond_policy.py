"""Observe admitted pond cost and a private solver-capped numerical experiment."""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import resource
import runpy
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()


def once(text,old,new):
    assert text.count(old)==1,old
    return text.replace(old,new,1)


def runtime_source(text):
    old='''      solver_limited = solver_limited .or. tx%solver_rejections > 0
      if (solver_limited) proposal_active = .false.
      if (config%retain_accepted_step_proposal .and. .not. solver_limited .and. &
          (proposal_active .or. tx%temporal_rejections > 0)) then'''
    new='''      ! Diagnostic only: retain a successful duration after solver rejection.
      if (config%retain_accepted_step_proposal .and. &
          (proposal_active .or. tx%temporal_rejections > 0 .or. tx%solver_rejections > 0)) then'''
    text=once(text,old,new)
    return once(text,'        proposed_dt = tx%accepted_dt * proposal_factor',
        '        if (tx%solver_rejections > 0) proposal_factor = min(1.0_real64,proposal_factor)\n'
        '        proposed_dt = tx%accepted_dt * proposal_factor')


def main_source(text):
    observer=runpy.run_path(str(ROOT/'integration/diagnostics/qualify_trace_scope.py'))['observer_source']
    return once(observer(text),'.not.retain_accepted_step_proposal.and.freundlich_exponent==1d0)',
                'freundlich_exponent==1d0)')


def cache_counter_source(text):
    text=once(text,'  implicit none\n  private\n',
        '  implicit none\n  private\n  integer,save::perf_cache_calls=0,perf_cache_prepared=0\n  public::perf01_cache_counters\n')
    text=once(text,'contains\n\n',"contains\n\n  subroutine perf01_cache_counters()\n    print '(A,2(1X,I0))','PERF01_CACHE_CALLS_PREPARED',perf_cache_calls,perf_cache_prepared\n  end subroutine\n\n")
    text=once(text,'       prepare_origin = ws%legacy_worker%diagnostics%nonlinear_iterations >= 2',
        '       prepare_origin = ws%legacy_worker%diagnostics%nonlinear_iterations >= 2\n       perf_cache_calls=perf_cache_calls+1')
    return once(text,'          if(n>=16.and.prepare_origin)then',
        '          if(n>=16.and.prepare_origin)then\n             perf_cache_prepared=perf_cache_prepared+1')


def cache_counter_main(text):
    text=once(text,'program swap5_solute_column\n',
        'program swap5_solute_column\n  use mod_reference_richards_legacy_binding,only:perf01_cache_counters\n')
    return once(text,"  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'",
        "  call perf01_cache_counters()\n  print '(A)','SWAP5_SOLUTE_COLUMN_COMPLETED'")


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--build',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--mode',choices=['profile','cap','cache','control'],required=True)
    ap.add_argument('--source-tree',type=Path,help='Isolated complete source tree for the exact cache overlay')
    ap.add_argument('--cpu',type=int,help='Pin a paired native observation to one available CPU')
    ap.add_argument('--windows',type=int,default=64)
    ap.add_argument('--restart',type=Path)
    ap.add_argument('--tolerance',type=float,default=1e-6)
    ap.add_argument('--timeout',type=float,default=180)
    ap.add_argument('--capture-balance',action='store_true',help='Observe the exact rejected aggregate chemical budget; preserve its guard')
    ap.add_argument('--capture-cache',action='store_true',help='Observe actual prepared-cache selection; excluded from timing pairs')
    a=ap.parse_args();base=a.build.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    b=json.loads((base/'build-complete.json').read_text())
    assert b['status']=='BUILT' and sha(base/'swap5_solute_column')==b['executable_sha256']
    source_root=a.source_tree.resolve() if a.source_tree else ROOT
    assert all(sha(source_root/p)==h for p,h in b['input_sha256'].items())
    report=dict(status='BUILDING',mode=a.mode,build=b,events=[],generated_sha256={},inputs={
        'integration/diagnostics/study_perf01_pond_policy.py':sha(Path(__file__)),
        'integration/diagnostics/qualify_trace_scope.py':sha(ROOT/'integration/diagnostics/qualify_trace_scope.py')})
    def save(): (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    def run(command,category):
        command=list(map(str,command));start=time.monotonic();p=subprocess.run(command,cwd=out,capture_output=True)
        i=len(report['events'])
        for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
        report['events'].append(dict(command=command,category=category,returncode=p.returncode,seconds=time.monotonic()-start))
        save();p.check_returncode();return p.stdout
    input_text=(ROOT/'examples/solute_column/dry32_implicit_pond.nml').read_text()
    assert a.tolerance in {1e-3,1e-4,1e-5,1e-6,1e-7}
    input_text=once(input_text,'temporal_tolerance=1e-06','temporal_tolerance='+str(a.tolerance))
    if a.mode in {'cap','cache','control'}:
        assert '-pg' not in b['flags']
        if a.mode=='cap':
            input_text=once(input_text,'&column\n','&column\n retain_accepted_step_proposal=.true.\n')
        gen=out/'generated';gen.mkdir()
        main=gen/'main.f90'
        observe=runpy.run_path(str(ROOT/'integration/diagnostics/qualify_trace_scope.py'))['observer_source']
        main.write_text(main_source((ROOT/'app/solute_column/main.f90').read_text()) if a.mode=='cap'
                        else observe((ROOT/'app/solute_column/main.f90').read_text()))
        flags=[f for f in b['flags'] if not f.startswith(('-I','-J'))]+['-J'+str(gen),'-I'+str(gen),'-I'+str(base)]
        replacements={'app/solute_column/main.f90':gen/'main.o'}
        generated=[(main,gen/'main.o')]
        if a.mode=='cap':
            runtime=gen/'mod_canonical_interval_runtime.f90';runtime.write_text(runtime_source((ROOT/'src/runtime/mod_canonical_interval_runtime.f90').read_text()))
            replacements['src/runtime/mod_canonical_interval_runtime.f90']=gen/'runtime.o'
            generated.insert(0,(runtime,gen/'runtime.o'))
        if a.mode=='cache':
            assert a.source_tree
            report['source_overlay']={}
            for path in ['src/solver/mod_b110_default_mvg_provider.f90','src/adapter/mod_reference_richards_legacy_binding.f90']:
                p=gen/'source-overlay'/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((source_root/path).read_bytes())
                report['source_overlay'][path]=sha(p)
            if a.capture_cache:
                path='src/adapter/mod_reference_richards_legacy_binding.f90'
                source=gen/'cache_observer.f90';source.write_text(cache_counter_source((source_root/path).read_text()))
                replacements[path]=gen/'cache-observer.o';generated.insert(0,(source,gen/'cache-observer.o'))
                main.write_text(cache_counter_main(main.read_text()))
        if a.capture_balance:
            path='src/runtime/mod_fmr_b111_pond_solute_route.f90'
            text=once((ROOT/path).read_text(),'  if(abs(receipt%residual)>8192d0*epsilon(1d0)*scale)return',
                '''  if(abs(receipt%residual)>8192d0*epsilon(1d0)*scale)then
    write(*,*) 'POND_POLICY_AGGREGATE_BALANCE_REJECTION',receipt%residual, &
      8192d0*epsilon(1d0)*scale,receipt%completed_substeps, &
      receipt%mass_before,receipt%mass_after,receipt%external_in,receipt%external_out
    return
  end if''')
            route=gen/Path(path).name;route.write_text(text)
            replacements[path]=gen/'route.o';generated.append((route,gen/'route.o'))
        for source,obj in generated:
            run(b['compiler_command']+flags+['-c',source,'-o',obj],'compile-generated')
            report['generated_sha256'][source.name]=sha(source)
        objects=[]
        for e in b['events']:
            if e['category']!='compile':continue
            c=e['command'];source=c[c.index('-c')+1];obj=c[c.index('-o')+1]
            key=next((p for p in replacements if source.endswith('/'+p)),None)
            objects.append(str(replacements[key]) if key else obj)
        objects.append(str(base/'libttutil.a'))
        report['linked_original_sha256']={p:sha(Path(p)) for p in objects if not p.startswith(str(gen))}
        exe=gen/'column';run(b['compiler_command']+flags+objects+['-o',exe],'link-generated')
    else:
        assert '-pg' in b['flags'] and a.tolerance==1e-6 and a.restart is None
        exe=base/'swap5_solute_column'
    native=out/'native';native.mkdir();inp=native/'input.nml';inp.write_text(input_text)
    restart='-'
    if a.restart:
        restart=native/'input.restart';restart.write_bytes(a.restart.read_bytes())
        report['restart_input_sha256']=sha(restart)
    command=[str(exe),str(inp),str(restart),str(a.windows)]
    if a.cpu is not None:
        assert a.cpu in os.sched_getaffinity(0)
        command=['taskset','-c',str(a.cpu)]+command
    report.update(status='RUNNING',executable_sha256=sha(exe),native_command=command,
                  timeout=a.timeout,address_space_mib=512,tolerance=a.tolerance,capture_balance=a.capture_balance,capture_cache=a.capture_cache)
    save();start=time.monotonic()
    def limit():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    with (native/'stdout').open('wb') as so,(native/'stderr').open('wb') as se:
        p=subprocess.Popen(command,cwd=native,stdout=so,stderr=se,preexec_fn=limit)
        timed_out=False
        while True:
            pid,status,usage=os.wait4(p.pid,os.WNOHANG)
            if pid:break
            if time.monotonic()-start>=a.timeout:
                timed_out=True;p.kill();pid,status,usage=os.wait4(p.pid,0);break
            time.sleep(.02)
        p.returncode=os.waitstatus_to_exitcode(status)
    measured=dict(returncode=p.returncode,timed_out=timed_out,seconds=time.monotonic()-start,
                  user_seconds=usage.ru_utime,system_seconds=usage.ru_stime,max_rss_kib=usage.ru_maxrss)
    (native/'RESOURCE.json').write_text(json.dumps(measured,indent=2)+'\n')
    report.update(status='COMPLETE_DIAGNOSTIC_NOT_PRODUCTION_ADMISSION' if p.returncode==0 and not timed_out
                  else 'FAILED_OR_CENSORED_NOT_QUALIFIED',resource=measured)
    report['raw_sha256']={p.name:sha(p) for p in native.iterdir() if p.is_file()};save()
    if p.returncode or timed_out:return
    if a.mode=='profile':
        symbols=run(['nm','-n',exe],'symbols').decode().replace(' t ',' T ')
        (out/'symbols.txt').write_text(symbols)
        raw=run(['gprof','-S',out/'symbols.txt',exe,native/'gmon.out'],'gprof')
        (out/'gprof.txt').write_bytes(raw)
        old=runpy.run_path(str(ROOT/'integration/diagnostics/verify_perf01_empty_pond.py'))['capsule']('production_evidence')
        for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
            assert (native/name).read_bytes()==old['enabled/O2-day/'+name],name
        report['profile_physical_files_exact']=True;save()
    print(json.dumps(dict(status=report['status'],resource=measured)),flush=True)


if __name__=='__main__':main()
