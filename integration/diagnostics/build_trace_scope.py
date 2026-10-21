"""Fresh current/baseline builds, original policy gates and real private arena tests."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import time

ROOT=Path(__file__).resolve().parents[2]
BASE='969aa918f0104546ec4ca2372feccf37b0145627'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--compiler-manifest',type=Path,required=True)
    ap.add_argument('--baseline-worktree',type=Path,required=True)
    a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    base=a.baseline_worktree.resolve()
    subprocess.run(['git','worktree','add','--detach',str(base),BASE],cwd=ROOT,capture_output=True,check=True)
    fc=json.loads(a.compiler_manifest.read_text())['compiler_command']
    env={**os.environ,'FC':shlex.join(fc),'PYTHONDONTWRITEBYTECODE':'1'}
    report=dict(status='RUNNING',baseline=BASE,candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),events=[],direct=[],private=[],inputs={})
    def run(command,category,cwd=ROOT,expected=0,marker=None):
        start=time.monotonic();p=subprocess.run(list(map(str,command)),cwd=cwd,env=env,capture_output=True)
        i=len(report['events'])
        for stream in ['stdout','stderr']:(out/f'{i:04d}.{stream}').write_bytes(getattr(p,stream))
        event=dict(command=list(map(str,command)),cwd=str(cwd),category=category,returncode=p.returncode,seconds=time.monotonic()-start,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr')
        report['events'].append(event);(out/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n')
        assert (p.returncode==expected if expected==0 else p.returncode!=0),(category,p.stderr.decode()[-2000:])
        if marker:assert marker.encode() in p.stdout+p.stderr,(category,marker)
        return event
    for tag,root,opt,profile in [('baseline-O2',base,'O2','production'),('current-O2',ROOT,'O2','production'),('current-O0',ROOT,'O0','checked')]:
        run(['python','-B',root/'tools/solute/build_column.py','--optimization',opt,'--build-profile',profile,'--output',out/tag],'column_build',root)
        print('COLUMN_BUILD_COMPLETE',tag,flush=True)
    spec=importlib.util.spec_from_file_location('closure',ROOT/'tests/support/augment_bartholomeus_backend_sources.py')
    closure=importlib.util.module_from_spec(spec);spec.loader.exec_module(closure)
    fixtures=['tests/modularity/mod_low_air_policy_oracle.f90']
    for driver,marker in [('tests/modularity/test_low_air_step_policy.f90','LOW_AIR_STEP_POLICY_CONTRACT=PASS'),('tests/performance/test_perf01_proposal.f90','PROPOSAL_EXACT_FALLBACK_ATOMIC_RESET=PASS'),('tests/performance/test_perf01_scratch_lifecycle.f90','SCRATCH_SCOPE_ALL_RETURNS_AFTER_CONTEXT_DESTRUCTION=PASS')]:
        sources,_=closure.strict_closure(ROOT,[driver],extra_sources=fixtures+[driver])
        for p in sources:report['inputs'][str(p.relative_to(ROOT))]=sha(p)
        for opt in ['O0','O2']:
            target=out/(Path(driver).stem+'-'+opt);target.mkdir()
            flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(target),'-I'+str(target)]
            run(fc+flags+sources+['-o',target/'test'],'direct_compile',target)
            report['direct'].append(run([target/'test'],'direct_native',target,marker=marker))
    for opt in ['O0','O2']:
        build=out/('current-'+opt);manifest=json.loads((build/'build-complete.json').read_text())
        target=out/('private-'+opt);target.mkdir()
        source=ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90';text=source.read_text()
        needle='  implicit none\n  private\n';assert text.count(needle)==1
        shadow=target/'backend.f90';shadow.write_text(text.replace(needle,'  implicit none\n  public\n',1))
        flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(target),'-I'+str(target),'-I'+str(build)]
        run(fc+flags+['-c',shadow,'-o',target/'backend.o'],'private_compile',target)
        objects=[]
        for e in manifest['events']:
            if e['category']!='compile':continue
            cmd=e['command'];p=Path(cmd[cmd.index('-c')+1]);obj=Path(cmd[cmd.index('-o')+1])
            if p==ROOT/'app/solute_column/main.f90':continue
            objects.append(target/'backend.o' if p==source else obj)
        for driver,modes,marker in [('tests/performance/test_perf01_trace_branch.f90',['','stale','invalid'],'PERF01_TRACE_IMMUTABLE_BRANCH_RESTORE=PASS'),('tests/performance/test_perf01_trace_scope.f90',['','generation','watermark'],'TRACE_SCOPE_RECLAIM_PINNED_BRANCH_NESTED_ROLLBACK=PASS')]:
            p=ROOT/driver;report['inputs'][driver]=sha(p);exe=target/p.stem
            run(fc+flags+[p]+objects+['-o',exe],'private_link',target)
            for mode in modes:
                expected=0 if not mode else 1
                text=marker if not mode else ('stale or invalid attempt context' if 'branch' in driver else 'invalid scratch scope')
                report['private'].append(run([exe,mode],'private_native',target,expected,text))
    report['status']='FRESH_BUILDS_AND_LIFECYCLE_IMMUTABLE_SCOPE_CONTRACTS_PASS'
    (out/'BUILD.json').write_text(json.dumps(report,indent=2)+'\n')
    print(report['status'],flush=True)


if __name__=='__main__':main()
