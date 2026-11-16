"""Private trace/counterfactual experiment; never a production build rebind."""
from pathlib import Path
import contextlib, copy, importlib.util, json, re, shutil, subprocess, sys, zipfile
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
sys.path.insert(0,str(ROOT/'tools/solute'))
import daily_host as h
import experimental_project as e
from daily_coupling import validate_bundle
from check_hupsel51_repair import bounded,physical,rows,check


def main():
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=False)
    base=Path(r'C:\SWAP5-testing\nomacro-mixtures01')
    reference=Path(r'C:\SWAP5-RC2\provider')
    original=base/'water-surface-history-O0-build';project=e.load(base/'water-surface-history')
    meta,case=validate_bundle(original,reference,project)
    build=out/'private-trace-build';shutil.copytree(original,build)
    path=build/'macropore.f90';source=path.read_text(encoding='cp1252')
    a=source.index('    subroutine hybrid_macro_checkpoint(');b=source.index('    end subroutine hybrid_macro_checkpoint',a)
    body=source[a:b]
    body=body.replace('use variables, only: t, iyear','use variables, only: pondmx, t, iyear',1)
    body=body.replace('      integer :: unit,ios,nodes','      logical :: probe_seed_exists\n      integer :: probe_seed_unit\n      integer :: unit,ios,nodes',1)
    anchor='      close(unit)'
    assert body.count(anchor)==1
    body=body.replace(anchor,anchor+'''
      if(restoring)then
        inquire(file='probe-pondmx.txt',exist=probe_seed_exists)
        if(probe_seed_exists)then
          open(newunit=probe_seed_unit,file='probe-pondmx.txt',status='old')
          read(probe_seed_unit,*)pondmx
          close(probe_seed_unit)
        end if
      end if
      write(*,'(a,l1,1x,2(es24.16,1x))')'PONDMX_PROBE ',restoring,clock,pondmx
''')
    path.write_text(source[:a]+body+source[b:],encoding='cp1252')
    flags=meta['identity']['donor_flags'];objects=reference/'build/swap-obj';ttutil=reference/'build/ttutil-obj'
    commands=[['gfortran',*flags,'-I',str(objects),'-I',str(ttutil),'-c',str(path)],
      ['gfortran','-o',str(build/'trace-donor.exe'),*[str(build/p.name if (build/p.name).exists() else p) for p in sorted(objects.glob('*.o'))],str(build/'hybrid_step_budget.o'),str(ttutil/'libttutil.a')]]
    events=[]
    for command in commands:
        r=subprocess.run(command,cwd=build,capture_output=True,text=True,timeout=60)
        events.append(dict(command=command,returncode=r.returncode,stdout=r.stdout,stderr=r.stderr));assert r.returncode==0,r.stderr
    donor=build/'trace-donor.exe';kernel=h.executable(build,'day_kernel')
    binding=copy.deepcopy(meta['binding'])
    binding['build']['diagnostic_pondmx_probe']=dict(source_sha256=h.sha(path),executable_sha256=h.sha(donor),scope='Trace and explicit optional single-variable counterfactual; not production qualification')
    warm=out/'warm';warm.mkdir()
    def warm_run():
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,donor,kernel,case,warm,[h.ColumnStart('original',0,None,None)],runtime=True,checkpoint_enabled=True,binding=binding,model=project.model,project=project)
            with (warm/'daily.jsonl').open('w') as journal:
                for day in range(1,202):
                    row=host.step(1,checkpoint=day in (199,201));assert row['committed'];journal.write(json.dumps(row)+'\n')
            host.close()
    bounded(30,warm_run);check(rows(warm))
    trace=[line.split() for line in (warm/'original/donor.stdout').read_text().splitlines() if line.startswith('PONDMX_PROBE')]
    assert len(trace)==2,trace
    value=float(trace[0][-1]);results={}
    for name,seed in [('unseeded',None),('actual-warm-pondmx-only',value)]:
        origin=out/(name+'-origin');receipt=h.verify_checkpoint(warm/'accepted-column-1-day-199.zip',199,binding,origin)
        cold=out/name;cold.mkdir();start_process=h.start_process
        def launch(stack,command,directory,kind):
            if seed is not None and kind=='donor':(directory/'probe-pondmx.txt').write_text(format(seed,'.17g')+'\n')
            return start_process(stack,command,directory,kind)
        h.start_process=launch
        try: bounded(30,lambda:h.run(donor,kernel,case,cold,201,checkpoint_day=199,origin=origin,origin_receipt=receipt,runtime=True,publish_day=201,checkpoint_binding=binding,model=project.model,project=project))
        finally:h.start_process=start_process
        with zipfile.ZipFile(warm/'accepted-column-1-day-201.zip') as x,zipfile.ZipFile(cold/'accepted-column-1-day-201.zip') as y:
            native={field:x.read(field)==y.read(field) for field in ('result.end','macro.bin')}
        results[name]=dict(seed=seed,physical_exact=physical(rows(cold))==physical(rows(warm)[199:201]),native=native,
                          actual_trace=[line for line in (cold/'original/donor.stdout').read_text().splitlines() if line.startswith('PONDMX_PROBE')])
    assert results['unseeded']['physical_exact'] and not results['unseeded']['native']['macro.bin']
    assert results['actual-warm-pondmx-only']['physical_exact'] and all(results['actual-warm-pondmx-only']['native'].values())
    (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_PONDMX_CAUSAL_HYPOTHESIS_CONFIRMED',warm_trace=trace,results=results,private_binding=binding,compilation=events),indent=2))
    print(json.dumps(dict(warm_trace=trace,results=results),indent=2))


if __name__=='__main__':main()
