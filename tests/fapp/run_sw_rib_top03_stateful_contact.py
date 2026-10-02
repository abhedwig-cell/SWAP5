#!/usr/bin/env python3
"""Build the pinned real Richards kernel and execute the preregistered layer matrix.

No production source rewriting. Build directory is kept for reproducible evidence.
"""
from __future__ import annotations
import argparse, hashlib, itertools, json, os, re, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--build',type=Path,required=True)
    ap.add_argument('--compiler',default='gfortran')

    args=ap.parse_args(); build=args.build.resolve();build.mkdir(parents=True,exist_ok=True)
    os.chdir(ROOT)
    stub=build/'reference_stubs.f90'
    subprocess.run(['python3','tests/qualification/fvq89/fvq89_make_reference_stubs.py',
                    'tests/fsi/fsi04_real_headcalc_stubs.f90',str(stub)],check=True)
    text=stub.read_text()
    # Only unused legacy capacity is expanded; all scientific grids are explicit request data.
    capacity=256
    block=f'''module MOD_grid
  implicit none
  integer, parameter :: numnod = {capacity}
  integer :: grid_i
  real(8), parameter :: z(numnod) = [(-0.05d0*(grid_i-0.5d0),grid_i=1,numnod)]
  real(8), parameter :: dz(numnod) = 0.05d0
  real(8), parameter :: disnod(numnod+1) = [0.025d0,(0.05d0,grid_i=2,numnod),0.025d0]
end module MOD_grid
'''
    text,n=re.subn(r'(?ms)^module MOD_grid\n.*?^end module MOD_grid\n',block,text)
    if n!=1:raise RuntimeError('expected exactly one MOD_grid')
    stub.write_text(text)
    test=ROOT/'tests/fapp/test_sw_rib_top03_stateful_contact.f90'
    probes=[ROOT/'tests/fapp/mod_top03_microrelief_top_provider.f90',
            ROOT/'tests/fapp/mod_top03_explicit_layer_provider.f90',
            ROOT/'tests/fapp/mod_top03_stateful_contact.f90']
    fixed=ROOT/'tests/fmr/mod_fmr04_fixed_top_provider.f90'
    head=ROOT/'src/legacy/b1_10_port/headcalc.f90'
    candidates=[stub,fixed,*probes]+sorted(p for p in (ROOT/'src').rglob('*.f90') if '/src/legacy/' not in p.as_posix())+[head,test]
    mr=re.compile(r'^\s*module\s+(?!procedure\b|subroutine\b|function\b)(\w+)',re.I)
    ur=re.compile(r'^\s*use(?:\s*,\s*[^:]*)?\s*(?:::\s*)?(\w+)',re.I)
    mods={};uses={}
    for p in candidates:
        lines=p.read_text().splitlines()
        mods[p]=[m[1].lower() for line in lines if (m:=mr.match(line))]
        uses[p]=[m[1].lower() for line in lines if (m:=ur.match(line))]
    providers={}
    for p in candidates:
        for name in mods[p]:providers.setdefault(name,p)
    order=[];done=set();busy=set()
    def visit(p):
        if p in done:return
        if p in busy:raise RuntimeError(f'cycle: {p}')
        busy.add(p)
        for name in sorted(uses[p]):
            if name in providers and providers[name]!=p:visit(providers[name])
            elif name not in providers and (name.startswith('mod_') or name=='variables'):
                raise RuntimeError(f'unresolved {name} in {p}')
        busy.remove(p);done.add(p);order.append(p)
    visit(test);visit(head)
    manifest={str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else 'generated/reference_stubs.f90':
              hashlib.sha256(p.read_bytes()).hexdigest() for p in order}
    manifest['generated_stub_authority']='tests/qualification/fvq89/fvq89_make_reference_stubs.py'
    (build/'source_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (build/'compile_order.txt').write_text('\n'.join(map(str,order))+'\n')
    cases=[]
    # Mandatory saturated controls and unchanged real-kernel trajectories.
    for R,m,mode in itertools.product([0.5,1.0],[8,16,32],[1,2,6]):
        cases.append(dict(mode=mode,L=0.2,R=R,m=m,ns=1,wet=0,mean=6,analytic=1))
    for R,m,ns in itertools.product([0.5,1.0],[8,16,32],[128,256,512]):
        for mode,wet in [(1,0),(1,1),(2,0),(6,0),(6,1)]:
            cases.append(dict(mode=mode,L=0.2,R=R,m=m,ns=ns,wet=wet,mean=6,analytic=0))
    for R,m,wet in itertools.product([0.5,1.0],[8,16,32],[0,1]):
        cases.append(dict(mode=6,L=0.2,R=R,m=m,ns=1,wet=wet,mean=6,analytic=2))
    (build/'cases.json').write_text(json.dumps(cases,indent=2)+'\n')
    print(f'CASES_PER_BUILD={len(cases)} COMPILE_CLOSURE={len(order)}',flush=True)
    common=['-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
    for opt in [0,2]:
        out=build/f'o{opt}';out.mkdir(exist_ok=True);objects=[]
        with (out/'build.log').open('w') as log:
            for i,p in enumerate(order):
                obj=out/f'{i}.o'
                subprocess.run([args.compiler,*common,f'-O{opt}','-J',str(out),'-I',str(out),'-c',str(p),'-o',str(obj)],
                               stdout=log,stderr=log,check=True)
                objects.append(str(obj))
            subprocess.run([args.compiler,f'-O{opt}',*objects,'-o',str(out/'test')],stdout=log,stderr=log,check=True)
        print(f'BUILD_O{opt}=PASS',flush=True)
        rows=[];timings=[]
        (out/'records.jsonl').write_text('')
        for i,c in enumerate(cases):
            argv=[str(c[k]) for k in ['mode','L','R','m','ns','wet','mean','analytic']]
            argv += ['0']
            started=time.perf_counter()
            try:
                run=subprocess.run([str(out/'test'),*argv],capture_output=True,text=True,timeout=120)
            except subprocess.TimeoutExpired as exc:
                rows.append(dict(case=c,returncode=124,stdout=(exc.stdout or b'').decode() if isinstance(exc.stdout,bytes) else (exc.stdout or ''),stderr='case exceeded explicit 120 second execution bound'))
                (out/'records.json').write_text(json.dumps(rows)+'\n')
                raise
            timings.append(dict(case=c,seconds=time.perf_counter()-started))
            record=dict(case=c,returncode=run.returncode,stdout=run.stdout,stderr=run.stderr)
            rows.append(record)
            with (out/'records.jsonl').open('a') as journal:journal.write(json.dumps(record)+'\n')
            (out/'timings.json').write_text(json.dumps(timings)+'\n')
            if run.returncode and not ('CONTACT_UNAVAILABLE' in run.stdout and 'dynamic top-boundary provider unavailable' in run.stderr):
                (out/'records.json').write_text(json.dumps(rows)+'\n')
                raise RuntimeError(f'runtime failed {c}: {run.stderr}\n{run.stdout}')
            if c['analytic']==2 and 'LIFECYCLE_PASS' not in run.stdout:raise RuntimeError('lifecycle gate incomplete: '+run.stdout)
            if c['analytic']==1 and c['mean']==6:
                line=next((x for x in run.stdout.splitlines() if x.startswith('ANALYTIC')),None)
                if line is None:raise RuntimeError(f'analytical trajectory incomplete: {c}: {run.stdout}')
                exact,head_error,flux_error=map(float,line.split()[1:])
                if head_error>1e-9 or flux_error>1e-10:
                    raise RuntimeError(f'analytical series-resistance gate failed: {c}: {line}')
            if (i+1)%50==0:print(f'O{opt}_CASES_DONE={i+1}/{len(cases)}',flush=True)
        (out/'records.json').write_text(json.dumps(rows)+'\n')
    a=json.loads((build/'o0/records.json').read_bytes());b=json.loads((build/'o2/records.json').read_bytes())
    # Preserve raw error backtraces; compare deterministic physical records, not
    # optimizer-dependent process addresses in fatal unavailable diagnostics.
    identity=lambda rows:[{k:r[k] for k in ['case','returncode','stdout']} for r in rows]
    if identity(a)!=identity(b):raise RuntimeError('O0/O2 physical numerical output mismatch')
    if any(r['returncode'] for r in a):print('O0_O2_PHYSICAL_RECORDS_EXACT=PASS (raw backtraces retained)',flush=True)
    else:print('O0_O2_RAW_RECORDS_EXACT=PASS',flush=True)

if __name__=='__main__':main()
