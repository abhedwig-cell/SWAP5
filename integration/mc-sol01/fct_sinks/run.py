"""Actual process and Richards composition, separate checked O0/O2 closures."""
import argparse,hashlib,importlib.util,itertools,json,os,runpy,stat,subprocess,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);ap.add_argument('--process-only',action='store_true');a=ap.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    g=runpy.run_path(str(HERE/'generate.py'));generated=g['sources']()
    for name,raw in generated.items():(out/name).write_bytes(raw)
    dependency=ROOT/'tests/support/augment_bartholomeus_backend_sources.py'
    spec=importlib.util.spec_from_file_location('deps',dependency);deps=importlib.util.module_from_spec(spec);spec.loader.exec_module(deps)
    closures={}
    with tempfile.TemporaryDirectory(dir=ROOT,prefix='.mc-sol01-sinks-') as tmp:
        temporary=Path(tmp);lookup={}
        for name,raw in generated.items():
            p=temporary/name;p.write_bytes(raw);lookup[p]=out/name
        extra=[*map(str,lookup),str(HERE.parent/'fct_reactive/mod_research_composed_fct.f90'),'app/solute_column/link_context.f90']
        closures['process'],_=deps.strict_closure(ROOT,[str(HERE/'process_driver.f90')],extra)
        closures['joint'],_=deps.strict_closure(ROOT,[str(temporary/'joint_driver.f90')],extra)
        closures['joint'].append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
        closures={k:[lookup.get(p,p) for p in v] for k,v in closures.items()}
    inputs={p for v in closures.values() for p in v if p.is_relative_to(ROOT)}
    inputs.update(ROOT/g['g'][k] for k in ['PHYSICAL','STORAGE','TRACE','JOINT'])
    inputs.update([HERE/'generate.py',HERE/'run.py',dependency,HERE.parent/'fct_reactive/generate.py',HERE.parent/'fct_joint_acceptance/run.py',HERE.parent/'fct_joint_acceptance/driver.inc',
        HERE.parent/'fct_accepted_trace/water_driver.f90',HERE.parent/'fct_accepted_trace/qualify_replay.py'])
    r=dict(status='BUILDING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        inputs={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in sorted(inputs)},generated={p:sha(b) for p,b in generated.items()},
        closures={k:list(map(str,v)) for k,v in closures.items()},events=[],process_cases=[],joint_cases=[],production_activated=False,disk_restart_qualified=False)
    def save():(out/'execution.json').write_text(json.dumps(r,indent=2)+'\n')
    def run(cmd,cwd):
        start=time.monotonic()
        executable=Path(cmd[0])
        # Workspace restoration can drop mode bits on new build artifacts.
        # Set the executable bit only on this run's own compiler outputs.
        if executable.is_relative_to(out) and executable.is_file():
            executable.chmod(executable.stat().st_mode|stat.S_IXUSR)
        try:cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=180)
        except subprocess.TimeoutExpired as e:cp=subprocess.CompletedProcess(cmd,124,e.stdout or b'',e.stderr or b'')
        except OSError as e:cp=subprocess.CompletedProcess(cmd,126,b'',repr(e).encode())
        e=dict(command=list(map(str,cmd)),returncode=cp.returncode,seconds=time.monotonic()-start)
        for s in ['stdout','stderr']:
            raw=getattr(cp,s);e[s]=f'{len(r["events"]):03d}.{s}';e[s+'_sha256']=sha(raw);(out/e[s]).write_bytes(raw)
        r['events'].append(e)
        if cp.returncode:r['status']='CENSORED' if cp.returncode==124 else 'FAILED'
        save();assert cp.returncode==0,(e['returncode'],cp.stdout[-1000:],cp.stderr[-3000:]);return e
    save();fc=os.environ.get('FC','gfortran');run([fc,'--version'],out)
    r['toolchain_files']={str(Path(p).resolve()):sha(Path(p).read_bytes()) for p in [fc,*filter(None,os.environ.get('SWAP5_FC_IDENTITY_FILES','').split(':'))] if Path(p).is_file()}
    for category in ['process']+([] if a.process_only else ['joint']):
        for opt in ['O0','O2']:
            folder=out/(category+'-'+opt);folder.mkdir();exe=folder/'driver'
            run([fc,'-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*closures[category],'-o',exe],folder)
            cases=list(itertools.product([0,1,2],[.5,1.,2.],[0.,.5,1.],[1,2,3],[4])) if category=='process' else list(itertools.product([40,80],[.8,1.2],[.5,1.,2.],[0.,1.]))
            for args in cases:
                e=run([exe,*args],folder);r[category+'_cases'].append(dict(**e,optimization=opt,arguments=list(args)));save()
    r['status']='PROCESS_EXECUTED' if a.process_only else 'EXECUTED';save()
    print(json.dumps({k:r[k] for k in ['status','baseline']},indent=2))
if __name__=='__main__':main()
