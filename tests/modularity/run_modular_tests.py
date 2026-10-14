#!/usr/bin/env python3
"""Local production-contract feedback. Owning admission gates remain separate."""
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
# Existing scientific drivers/oracles, exposed through one measured feedback route.
CASES.update({
 'root_oxygen': {'driver':'tests/fmig431/test_swap431_root_oxygen_emp.f90',
                 'marker':'SW431_ROOT_OXYGEN_EMP_COMPONENT=PASS',
                 'flags':['-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']},
 'root_contract': {'driver':'tests/modularity/test_root_contracts.f90',
                   'marker':'MODULAR_ROOT_NONMUTATION_INVALID_ABA=PASS',
                   'flags':['-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']},
 'drainage': {'driver':'tests/modularity/test_drainage_contract.f90',
              'marker':None,'validator':'drainage','flags':COMMON},
 'assimilation': {'driver':'tests/fwof/pp02/test_wofost81_assimilation_driver.f90',
                  'marker':None,'validator':'assimilation','flags':['-std=f2008']}})
CASES['low_air_policy']={'driver':'tests/modularity/test_low_air_step_policy.f90','marker':'LOW_AIR_STEP_POLICY_CONTRACT=PASS','flags':COMMON}
CASES['low_air_physical']={'driver':'tests/modularity/test_low_air_development.f90','marker':'PPA_WU05B15_LOW_AIR_LOW_AIR_DRAIN_RUNTIME=PASS','flags':COMMON}
DEFAULT_CASES=['boesten','root_oxygen','root_contract','drainage','assimilation']

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
    ordered,_=DEP.strict_closure(ROOT,[cfg['driver']], (['tests/modularity/low_air_consistent_grid_stubs.f90','tests/frost/mod_ppa_wu05b15_extended_fixture.f90'] if case=='low_air_physical' else [STUB]+(['tests/modularity/mod_low_air_policy_oracle.f90'] if case=='low_air_policy' else [])))
    modules=relative(ordered[:-1])
    if broad and case=='boesten': modules=original_boesten()
    external=['src/legacy/b1_10_port/headcalc.f90'] if (STUB in modules or 'tests/modularity/low_air_consistent_grid_stubs.f90' in modules) and 'src/legacy/b1_10_port/headcalc.f90' not in modules else []
    return modules+external+[cfg['driver']]

class Session:
    """Artifacts reusable only in this live transaction; no cross-run cache."""
    def __init__(self,out):
        self.out=Path(out); self.out.mkdir(parents=True,exist_ok=False)
        self.compiler=shutil.which('gfortran')
        if not self.compiler: raise RuntimeError('gfortran unavailable')
        self.identity=self.toolchain_identity()
        self.artifacts={}; self.events=[]; self.module_artifacts={}; self.share_modules=True
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
    def command(self,args,cwd,label,input_bytes=None):
        start=time.perf_counter(); cp=subprocess.run(args,cwd=cwd,capture_output=True,input=input_bytes)
        event={'command':list(map(str,args)),'wall_seconds':time.perf_counter()-start,'returncode':cp.returncode}
        index=len(self.events); prefix=self.out/f'{index:05d}-{label}'
        if input_bytes is not None:
            prefix.with_suffix('.stdin').write_bytes(input_bytes)
            event['stdin_sha256']=hashlib.sha256(input_bytes).hexdigest()
        prefix.with_suffix('.stdout').write_bytes(cp.stdout); prefix.with_suffix('.stderr').write_bytes(cp.stderr)
        event['stdout_sha256']=hashlib.sha256(cp.stdout).hexdigest(); self.events.append(event)
        if cp.returncode: write(self.out/'FAILED.json',self.events); raise RuntimeError(f'{label} failed; see {prefix}.stderr')
        return cp.stdout,event
    def execute(self,case,opt,broad=False,reuse=False):
        begin=time.perf_counter(); validation=time.perf_counter()
        sources=plan(case,broad)
        inputs={p:sha(ROOT/p) for p in sources}
        payload=None; validate=None
        if CASES[case].get('validator'):
            oracle_path=ROOT/'tests/modularity/contract_oracles.py'
            spec=importlib.util.spec_from_file_location('contract_oracles',oracle_path)
            oracle=importlib.util.module_from_spec(spec);spec.loader.exec_module(oracle)
            payload,validate,oracle_inputs=oracle.prepare(ROOT,CASES[case]['validator'])
            inputs.update({p:sha(ROOT/p) for p in oracle_inputs})
            inputs['tests/modularity/contract_oracles.py']=sha(oracle_path)
        flags=CASES[case]['flags']+[f'-O{opt}']
        key=digest({'inputs':inputs,'sources':sources,'flags':flags,'compiler':self.identity,'case':case,'stdin':hashlib.sha256(payload).hexdigest() if payload is not None else None})
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
                # Conservative prefix includes every ordered provider before this source.
                # No persistent cache; copy verified module bytes into the isolated target build.
                module_key=digest({'prefix':[(p,inputs[p]) for p in sources[:i+1]],'flags':flags,'compiler':self.identity})
                if self.share_modules and module_key in self.module_artifacts:
                    cached_obj,cached_files=self.module_artifacts[module_key]
                    check_begin=time.perf_counter()
                    if any(not p.is_file() or sha(p)!=h for p,h in cached_files.items()):
                        raise RuntimeError('shared module artifact identity changed')
                    for p in cached_files:
                        if p.suffix=='.mod':
                            target=build/p.name
                            if target.exists() and sha(target)!=sha(p): raise RuntimeError('shared module collision')
                            if not target.exists(): shutil.copyfile(p,target)
                    record['validation_seconds']+=time.perf_counter()-check_begin
                    objects.append(cached_obj);record['reused_compilations']+=1
                else:
                    _,event=self.command([self.compiler,*flags,'-J',str(build),'-I',str(build),'-c',str(ROOT/source),'-o',str(obj)],build,'compile')
                    objects.append(obj); compile_time+=event['wall_seconds'];record['compiler_requests']+=1
                    if self.share_modules:
                        files={p:sha(p) for p in build.glob('*.mod')};files[obj]=sha(obj)
                        self.module_artifacts[module_key]=(obj,files)
            exe=build/'test'
            # Match incumbent process links: large original Boesten closure
            # is compiled but its process executable links only the process.
            linked=objects
            if case=='boesten' and broad:
                linked=[objects[sources.index('src/process/mod_restricted_surface_evaporation.f90')],objects[-1]]
            _,event=self.command([self.compiler,*flags,*map(str,linked),'-o',str(exe)],build,'link')
            link_time=event['wall_seconds'];record['compiler_requests']+=1
            artifacts={p:sha(p) for p in build.iterdir() if p.suffix in ('.o','.mod') or p==exe}
            artifacts.update({p:sha(p) for p in objects})
            self.artifacts[key]=(exe,artifacts)
        if any(sha(ROOT/p)!=h for p,h in inputs.items()): raise RuntimeError('source changed during build')
        output,event=self.command([str(exe)],exe.parent,'science',input_bytes=payload) if payload is not None else self.command([str(exe)],exe.parent,'science')
        check_begin=time.perf_counter()
        if validate is not None: validate(output)
        elif CASES[case]['marker'].encode() not in output: raise RuntimeError('missing scientific marker')
        scientific_validation=time.perf_counter()-check_begin
        if any(sha(ROOT/p)!=h for p,h in inputs.items()): raise RuntimeError('input changed during science validation')
        record.update(compile_seconds=compile_time,link_seconds=link_time,execution_seconds=event['wall_seconds'],
                      scientific_validation_seconds=scientific_validation,stdin_sha256=hashlib.sha256(payload).hexdigest() if payload is not None else None,
                      total_seconds=time.perf_counter()-begin,stdout_sha256=hashlib.sha256(output).hexdigest(),
                      executable_sha256=sha(exe),artifact_sha256={str(p.relative_to(self.out)):h for p,h in self.artifacts[key][1].items()})
        return record

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output')
    ap.add_argument('--benchmark',action='store_true');ap.add_argument('--repeat',type=int,default=3)
    ap.add_argument('--audit-build',action='store_true');ap.add_argument('--audit-closures',action='store_true');ap.add_argument('--list',action='store_true');ap.add_argument('--independent-builds',action='store_true');ap.add_argument('--case',choices=list(CASES),action='append')
    args=ap.parse_args()
    if args.repeat < 1: ap.error("repeat must be positive")
    if args.list:
        print(json.dumps({'default_cases':DEFAULT_CASES,'cases':CASES,'claim':'feedback only; not admission selection'},indent=2));return
    if not args.output: ap.error('--output is required unless --list')
    out=Path(args.output).resolve(); s=Session(out)
    s.share_modules=not (args.independent_builds or args.benchmark)
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    audit={}
    for name,path in (COMPONENTS.items() if args.audit_build or args.audit_closures else []):
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
    records=[];cases=args.case or (['mvg','boesten','accepted_heat'] if args.benchmark else DEFAULT_CASES)
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
