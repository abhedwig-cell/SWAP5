#!/usr/bin/env python3
"""Opt-in local feedback and measured process-leg comparison. No gate selection."""
from __future__ import annotations
import argparse, hashlib, importlib.util, json, os, platform, re, shutil, subprocess, time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('dependencies',ROOT/'tests/support/augment_bartholomeus_backend_sources.py')
DEP=importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(DEP)
STUB='tests/fsi/fsi04_real_headcalc_stubs.f90'
COMMON=['-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
CASES={
 'mvg': {'driver':'tests/fsi/test_fsi39_b110_ksatexm.f90','marker':'F_SI39_BELOW_THRESHOLD_NOOP=PASS',
         'flags':['-std=f2008','-pedantic-errors','-ffree-line-length-none','-Wall','-Wextra','-Werror','-Wno-error=unused-dummy-argument','-Wno-error=compare-reals','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']},
 'boesten': {'driver':'tests/fapp/test_ppa_wu04b_boesten_process.f90','marker':'PPA-WU04-B BOESTEN PROCESS TEST PASS','flags':COMMON},
 'accepted_heat': {'driver':'tests/fmig431/test_crop_accepted_soil_temperature.f90','marker':'SW431_CROP_ACCEPTED_THERMAL_FKT=PASS',
                  'flags':['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace']}}
COMPONENTS={
 'hydraulics':'src/solver/mod_b110_default_mvg_provider.f90',
 'richards':'src/adapter/mod_reference_richards_legacy_binding.f90',
 'timestep':'src/runtime/mod_timestep_controller_contract.f90',
 'transaction':'src/transaction/mod_transaction_reference.f90',
 'evaporation':'src/process/mod_restricted_surface_evaporation.f90',
 'root':'src/process/mod_root_water_uptake_process.f90',
 'drainage':'src/process/mod_drainage_hooghoudt_equivalent_depth.f90',
 'crop':'src/crop/mod_wofost81_assimilation.f90',
 'temperature':'src/process/mod_restricted_soil_temperature.f90',
 'runtime':'src/runtime/mod_fmr_crop_accepted_soil_temperature.f90'}

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def digest(value): return hashlib.sha256(json.dumps(value,sort_keys=True).encode()).hexdigest()
def write(path,value): Path(path).write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')
def relative(paths): return [str(p.relative_to(ROOT)) for p in paths]

def original_boesten():
    text=(ROOT/'tests/fapp/run_ppa_wu04b_boesten_evaporation.sh').read_text()
    sources=re.search(r'MODULE_SRC=\(\n(.*?)\n\)',text,re.S).group(1).split()
    result=subprocess.check_output(['python3',str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all',*sources],cwd=ROOT,text=True)
    return result.splitlines()

def plan(case,broad=False):
    cfg=CASES[case]
    ordered,_=DEP.strict_closure(ROOT,[cfg['driver']], [STUB])
    modules=relative(ordered[:-1])
    if broad and case=='boesten': modules=original_boesten()
    external=['src/legacy/b1_10_port/headcalc.f90'] if STUB in modules else []
    return modules+external+[cfg['driver']]

class Session:
    """Artifacts reusable only in this live transaction; no cross-run cache."""
    def __init__(self,out):
        self.out=Path(out); self.out.mkdir(parents=True,exist_ok=False)
        self.compiler=shutil.which('gfortran')
        if not self.compiler: raise RuntimeError('gfortran unavailable')
        self.identity=self.toolchain_identity()
        self.artifacts={}; self.events=[]
    def toolchain_identity(self):
        compiler=Path(self.compiler).resolve()
        result={'launcher':str(compiler),'launcher_sha256':sha(compiler),
                'version':subprocess.check_output([self.compiler,'--version'],text=True),
                'environment_sha256':digest(dict(os.environ)), 'host':platform.uname()._asdict()}
        # Actual executable and helper/library bytes behind the launcher.
        for option in ['-print-prog-name=f951','-print-file-name=libgfortran.a','-print-file-name=libgfortran.so.5','-print-libgcc-file-name']:
            path=Path(subprocess.check_output([self.compiler,option],text=True).strip())
            if not path.is_file(): raise RuntimeError(f'unresolved compiler input: {option}')
            result[option]={'path':str(path.resolve()),'sha256':sha(path)}
        return result
    def command(self,args,cwd,label):
        start=time.perf_counter(); cp=subprocess.run(args,cwd=cwd,capture_output=True)
        event={'command':list(map(str,args)),'wall_seconds':time.perf_counter()-start,'returncode':cp.returncode}
        index=len(self.events); prefix=self.out/f'{index:05d}-{label}'
        prefix.with_suffix('.stdout').write_bytes(cp.stdout); prefix.with_suffix('.stderr').write_bytes(cp.stderr)
        event['stdout_sha256']=hashlib.sha256(cp.stdout).hexdigest(); self.events.append(event)
        if cp.returncode: write(self.out/'FAILED.json',self.events); raise RuntimeError(f'{label} failed; see {prefix}.stderr')
        return cp.stdout,event
    def execute(self,case,opt,broad=False,reuse=False):
        begin=time.perf_counter(); validation=time.perf_counter()
        sources=plan(case,broad)
        inputs={p:sha(ROOT/p) for p in sources}
        flags=CASES[case]['flags']+[f'-O{opt}']
        key=digest({'inputs':inputs,'sources':sources,'flags':flags,'compiler':self.identity,'case':case})
        if self.toolchain_identity()!=self.identity: raise RuntimeError('toolchain/environment changed inside transaction')
        validated=time.perf_counter()-validation
        record={'case':case,'optimization':opt,'route':'original_process_leg' if broad else 'focused',
                'inputs':inputs,'sources':sources,'flags':flags,'compiler_identity':self.identity,
                'validation_seconds':validated,'compiler_requests':0,'reused_compilations':0}
        compile_time=link_time=0.
        if reuse and key in self.artifacts:
            exe,artifacts=self.artifacts[key]
            t=time.perf_counter()
            if any(not p.is_file() or sha(p)!=h for p,h in artifacts.items()): raise RuntimeError('artifact identity changed')
            record['validation_seconds']+=time.perf_counter()-t
            record['reused_compilations']=len(sources)
        else:
            build=self.out/f'build-{len(self.artifacts)}-{len(self.events)}-{case}-O{opt}';build.mkdir()
            objects=[]
            for i,source in enumerate(sources):
                obj=build/f'{i:03d}.o'
                _,event=self.command([self.compiler,*flags,'-J',str(build),'-I',str(build),'-c',str(ROOT/source),'-o',str(obj)],build,'compile')
                objects.append(obj); compile_time+=event['wall_seconds'];record['compiler_requests']+=1
            exe=build/'test'
            # Match incumbent process links: large original Boesten closure
            # is compiled but its process executable links only the process.
            linked=objects
            if case=='boesten' and broad:
                linked=[objects[sources.index('src/process/mod_restricted_surface_evaporation.f90')],objects[-1]]
            _,event=self.command([self.compiler,*flags,*map(str,linked),'-o',str(exe)],build,'link')
            link_time=event['wall_seconds'];record['compiler_requests']+=1
            artifacts={p:sha(p) for p in build.iterdir() if p.suffix in ('.o','.mod') or p==exe}
            self.artifacts[key]=(exe,artifacts)
        if any(sha(ROOT/p)!=h for p,h in inputs.items()): raise RuntimeError('source changed during build')
        output,event=self.command([str(exe)],exe.parent,'science')
        if CASES[case]['marker'].encode() not in output: raise RuntimeError('missing scientific marker')
        record.update(compile_seconds=compile_time,link_seconds=link_time,execution_seconds=event['wall_seconds'],
                      total_seconds=time.perf_counter()-begin,stdout_sha256=hashlib.sha256(output).hexdigest(),
                      executable_sha256=sha(exe),artifact_sha256={str(p.relative_to(self.out)):h for p,h in self.artifacts[key][1].items()})
        return record

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',required=True)
    ap.add_argument('--benchmark',action='store_true');ap.add_argument('--repeat',type=int,default=3)
    ap.add_argument('--audit-build',action='store_true');ap.add_argument('--case',choices=list(CASES),action='append')
    args=ap.parse_args(); out=Path(args.output).resolve(); s=Session(out)
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    audit={}
    for name,path in COMPONENTS.items():
        closure,direct=DEP.strict_closure(ROOT,[path],[STUB])
        audit[name]={'target':path,'sources':relative(closure),'source_count':len(closure), 'direct':direct,
                     'source_sha256':{p:sha(ROOT/p) for p in relative(closure)},'build_seconds':'UNKNOWN',
                     'science_scope':'compile/link probe only; not physical qualification'}
        if args.audit_build:
            build=out/f'audit-{name}';build.mkdir();start=time.perf_counter();events=[];objects=[]
            for i,p in enumerate(closure):
                obj=build/f'{i}.o';_,event=s.command([s.compiler,*COMMON,'-O0','-J',str(build),'-I',str(build),'-c',str(p),'-o',str(obj)],build,'audit-compile');objects.append(obj);events.append(event)
            probe=build/'probe.f90';mod=DEP.MODULE_RE.findall((ROOT/path).read_text())[0]
            probe.write_text(f'program probe\nuse {mod}\nimplicit none\nend program\n')
            externals=[ROOT/'src/legacy/b1_10_port/headcalc.f90'] if STUB in relative(closure) else []
            _,event=s.command([s.compiler,*COMMON,'-O0','-J',str(build),'-I',str(build),str(probe),*map(str,externals+objects),'-o',str(build/'probe')],build,'audit-link')
            _,execute=s.command([str(build/'probe')],build,'audit-run')
            audit[name].update(build_seconds=time.perf_counter()-start,compile_seconds=sum(e['wall_seconds'] for e in events),link_seconds=event['wall_seconds'],compiler_requests=len(closure)+1,link_probe='PASS',external_sources=list(map(str,externals)))
        write(out/'AUDIT.json',audit)
    records=[];cases=args.case or list(CASES)
    for round_index in range(args.repeat if args.benchmark else 1):
        for broad in ([True,False] if round_index%2==0 else [False,True]) if args.benchmark else [False]:
            for case in cases:
                for opt in (0,2):
                    r=s.execute(case,opt,broad=broad);r.update(round=round_index,build='cold');records.append(r)
                    write(out/'RESULTS.json',{'head':head,'audit':audit,'records':records,'events':s.events})
                    print(json.dumps({k:r[k] for k in ['case','optimization','route','total_seconds','compiler_requests']}),flush=True)
                    if not broad:
                        warm=s.execute(case,opt,reuse=True);warm.update(round=round_index,build='warm_same_transaction');records.append(warm)
                        if warm['stdout_sha256']!=r['stdout_sha256']:raise RuntimeError('warm output drift')
        for case in cases:
            group=[r for r in records if r['case']==case and r['round']==round_index]
            if len({r['stdout_sha256'] for r in group})!=1:raise RuntimeError(f'O0/O2/route output drift: {case}')
        write(out/'RESULTS.json',{'head':head,'audit':audit,'records':records,'events':s.events,'status':'PASS'})
    print('MODULAR_PRODUCTION_DRIVERS=PASS',flush=True)
if __name__=='__main__':main()
