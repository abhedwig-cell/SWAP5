#!/usr/bin/env python3
"""Source-bound WOFOST81 harvest owner tests; no physical publication admission."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, shutil, subprocess, time

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('deps',ROOT/'tests/support/augment_bartholomeus_backend_sources.py')
DEP=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(DEP)
FIXTURE='tests/crop-harvest/mod_harvest_oracle.f90'
DRIVERS={'chemical':('tests/crop-harvest/test_harvest_chemical.f90','HARVEST_CHEMICAL_ATOMIC_PENDING_CONTINUATION=PASS'),
 'harvest':('tests/crop-harvest/test_harvest_owner.f90','WOFOST81_HARVEST_OWNER_LITERAL_ORACLE=PASS'),
 'incumbent_day':('tests/fwof/pp02/test_wofost81_one_day_candidate_integration.f90','F_WOF_PP02_REPOSITORY_INTEGRATION_PASS')}
FLAGS=['-I'+str(ROOT/'tests/crop-harvest'),'-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-fcheck=all',
       '-fbacktrace','-ffpe-trap=invalid,zero,overflow']

def plan():
    orders={}
    for name,(driver,_) in DRIVERS.items():
        order,_=DEP.strict_closure(ROOT,[driver],[FIXTURE,driver])
        orders[name]=[str(p.relative_to(ROOT)) for p in order]
    paths=sorted({'tests/nut-crop/crop_fixture.inc','tests/nut-material/material_fixture.inc'}|{p for order in orders.values() for p in order}|{str(Path(__file__).relative_to(ROOT))})
    return dict(orders=orders,inputs={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths},
                production_providers={n:sum(p.startswith('src/') for p in ps) for n,ps in orders.items()},
                flags=FLAGS,optimizations=['O0','O2'],
                source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),
                dirty_scientific_surface=bool(subprocess.check_output(
                    ['git','status','--porcelain','--','src','tests','tools','reference'],cwd=ROOT,text=True).strip()),
                compile_link_native_seconds='UNKNOWN_UNTIL_EXECUTION',canonical_admission=False)

def main():
    p=argparse.ArgumentParser();p.add_argument('--plan-only',action='store_true')
    p.add_argument('--output',type=Path);a=p.parse_args();result=plan()
    if a.plan_only:
        print(json.dumps(dict(status='DEPENDENCY_PLAN_ONLY',**result),indent=2));return 0
    if a.output is None:p.error('--output is required for execution')
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    total_start=time.perf_counter()
    events=[];result.update(status='RUNNING',events=events)
    def save(): (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    save();compiler=shutil.which('gfortran')
    if compiler is None:
        result['status']='BLOCKED_COMPILER_UNAVAILABLE';save();print(json.dumps(result,indent=2));return 2
    if result['dirty_scientific_surface']:
        result['status']='BLOCKED_UNPERSISTED_SCIENTIFIC_SURFACE';save();print(json.dumps(result,indent=2));return 2
    result['compiler']=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0]
    result['execution_commit']=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    def run(command,category,work):
        if category=='native':
            exe=Path(command[0]);assert exe.is_relative_to(out)
            exe.chmod(exe.stat().st_mode|0o111)
        start=time.perf_counter();done=subprocess.run(list(map(str,command)),cwd=work,capture_output=True)
        n=len(events)
        for stream in ['stdout','stderr']:(out/f'{n}.{stream}').write_bytes(getattr(done,stream))
        events.append(dict(command=list(map(str,command)),category=category,exit=done.returncode,
                           seconds=time.perf_counter()-start,stdout=f'{n}.stdout',stderr=f'{n}.stderr'))
        save()
        if done.returncode:raise RuntimeError('selected event failed; see raw output')
        return done.stdout
    try:
        outputs={}
        providers=list(dict.fromkeys(path for order in result['orders'].values() for path in order[:-1]))
        for opt in result['optimizations']:
            work=out/opt;work.mkdir(parents=True);objects=[]
            for i,path in enumerate(providers):
                obj=work/f'{i}.o';objects.append(obj)
                strict=['-Werror'] if path in ['src/crop/mod_wofost81_crop_owner_state.f90','src/crop/mod_wofost81_one_day_candidate.f90'] else []
                run([compiler,*FLAGS,*strict,'-'+opt,'-J'+str(work),'-I'+str(work),'-c',ROOT/path,'-o',obj],
                    'fixture_compile' if path.startswith('tests/') else 'provider_compile',work)
            for name,order in result['orders'].items():
                obj=work/(name+'.o')
                run([compiler,*FLAGS,'-'+opt,'-J'+str(work),'-I'+str(work),'-c',ROOT/order[-1],'-o',obj],
                    'driver_compile',work)
                exe=work/name
                run([compiler,'-'+opt,*objects,obj,'-o',exe],'link',work)
                raw=run([exe],'native',work)
                if DRIVERS[name][1].encode() not in raw:raise RuntimeError('native assertion marker absent')
                outputs[(opt,name)]=raw
        for name in DRIVERS:
            if outputs[('O0',name)]!=outputs[('O2',name)]:
                raise RuntimeError('O0/O2 native output differs: '+name)
        result['optimization_output_identity']='BYTE_IDENTICAL_FOR_EACH_DRIVER'
    except Exception:
        result['status']='FAILED';save();raise
    result['status']='HARVEST_OWNER_AND_INCUMBENT_CONTRACT_PASS_NOT_ADMITTED'
    result['cost_seconds']={c:sum(e['seconds'] for e in events if e['category']==c)
                            for c in {e['category'] for e in events}}
    result['total_wall_seconds']=time.perf_counter()-total_start
    save();print(json.dumps(result,indent=2));return 0

if __name__=='__main__':raise SystemExit(main())
