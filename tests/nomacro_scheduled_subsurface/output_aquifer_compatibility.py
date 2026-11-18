"""Actual canonical baseline and current default aquifer source/state comparison."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import output_aquifer_runtime as probe
from output_aquifer_controls import fabricated_receipts,transactions

m=probe.m;ROOT=probe.ROOT
BASE='76c6251a2f3f6345428b26b1a9e03cf7e0bf917a'
RUNNER='''from pathlib import Path
import importlib.util,json,sys,subprocess,zipfile
root,build,reference,inputs,out=map(Path,sys.argv[1:])
spec=importlib.util.spec_from_file_location('actual_source_mixtures',root/'tests/nomacro_mixtures/run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
p=m.e.load(inputs)
if out.exists():
    data=m.rows(out);assert len(data)==10;meta,_=m.validate_bundle(build,reference,p);assert json.loads((out/'BUILD.json').read_text())==meta
    report=dict(status='ACTUAL_COMPLETED_TRAJECTORY_REVALIDATED',days=10,budgets=m.check(data),build_sha256=m.sha(build/'BUILD.json'))
else:report,data=m.trajectory(build,reference,p,out,10,{2,4,8,10},60)
own=[]
for s,e in ((2,4),(4,8),(8,10)):
    cold=out.parent/('own-'+str(s))
    if cold.exists():
        actual=m.rows(cold);m.check(actual);assert len(actual)==e-s and m.physical(actual)==m.physical(data[s:e])
        assert m.csvlines(cold/'original/result_output.csv')[-(e-s):]==m.csvlines(out/'original/result_output.csv')[s+2:e+2]
        with zipfile.ZipFile(cold/f'accepted-column-1-day-{e}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{e}.zip') as b:
            for name in ('result.end','macro.bin'):assert a.read(name)==b.read(name)
        own.append(dict(start=s,end=e,exact_physical=True,exact_csv=True,exact_native=True,actual_completed_cold_revalidated=True))
    else:own.append(m.own(build,reference,p,out,data,s,e,cold))
(out.parent/'RUN.json').write_text(json.dumps(dict(status='ACTUAL_DEFAULT_AQUIFER_SOURCE_NATIVE_PREFIX_PASS',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),trajectory=report,own=own),indent=2)+'\\n')
'''


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','baseline-root','output'):ap.add_argument('--'+key,type=Path,required=True)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True);ap.add_argument('--resume',action='store_true');a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=a.baseline_root,text=True).strip()==BASE
    assert not subprocess.check_output(['git','status','--porcelain'],cwd=a.baseline_root,text=True).strip()
    runner=a.output/'actual-source-runner.py';runner.write_text(RUNNER)
    q=dict(status='RUNNING',baseline=BASE,optimization=a.optimization,profiles={})
    if a.resume:q['retained_previous_report']=json.loads((a.output/'RESULT.json').read_text())
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for kind in ('soil-transfer','box-release','sorption-decay','stiff-loss'):
            out=a.output/kind;out.mkdir(exist_ok=a.resume);inputs=out/'input'
            if not inputs.exists():probe.fixture(inputs,kind,1,0)
            p=m.e.load(inputs);images={}
            for label,root in [('baseline',a.baseline_root),('current',ROOT)]:
                build=out/(label+'-build');run=out/label;run.mkdir(exist_ok=a.resume)
                command=[sys.executable,'-B',str(root/'tools/solute/run_water.py'),'--model',p.model,'--experimental-project',inputs,'--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
                if not (a.resume and (build/'BUILD.json').exists()):
                    r=subprocess.run(list(map(str,command)),cwd=root,capture_output=True,text=True,timeout=180);(run/'build.stdout').write_text(r.stdout);(run/'build.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
                r=subprocess.run([sys.executable,'-B',str(runner),str(root),str(build),str(a.reference_work),str(inputs),str(run/'trajectory')],cwd=root,capture_output=True,text=True,timeout=120);(run/'run.stdout').write_text(r.stdout);(run/'run.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
                images[label]=json.loads((build/'BUILD.json').read_text())
            actual,old=images['current'],images['baseline'];assert actual['project']==old['project'] and actual['inputs']==old['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_aquifer_solute'):assert actual['identity'].get(field)==old['identity'].get(field),(kind,field)
            assert old['identity'].get('aquifer_native_receipt') is None and actual['identity']['aquifer_native_receipt']['policy']=='original-aquifer-native-receipt-consistency-v1'
            assert m.physical(m.rows(out/'baseline/trajectory'))==m.physical(m.rows(out/'current/trajectory'))
            for day in (2,4,8,10):
                with zipfile.ZipFile(out/f'baseline/trajectory/accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(out/f'current/trajectory/accepted-column-1-day-{day}.zip') as y:
                    for name in ('result.end','macro.bin'):assert x.read(name)==y.read(name),(kind,day,name)
            active=transactions(out/'current-build',a.reference_work,p,out/'current/trajectory',out/'external')
            fraudulent=fabricated_receipts(out/'current-build',a.reference_work,p,out/'current/trajectory',out/'fabricated')
            q['profiles'][kind]=dict(actual_build=actual,baseline_build_sha256=m.sha(out/'baseline-build/BUILD.json'),baseline_run=json.loads((out/'baseline/RUN.json').read_text()),current_run=json.loads((out/'current/RUN.json').read_text()),source_provider_inputs_exact=True,ten_physical_days_exact=True,four_complete_native_endpoints_exact=True,actual_default_aquifer_native_guard=True,transactions=active,fabricated_receipt_refusals=fraudulent);save();print(kind,a.optimization,'ACTUAL_BASELINE_DEFAULT_AQUIFER_SOURCE_NATIVE_EXACT_AND_RECEIPT_GUARD_PASS',flush=True)
        assert not subprocess.check_output(['git','status','--porcelain'],cwd=a.baseline_root,text=True).strip()
        q['status']='FOUR_ACTUAL_CANONICAL_DEFAULT_AQUIFER_SOURCE_NATIVE_AND_GUARDED_RECEIPT_CONTEXTS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
