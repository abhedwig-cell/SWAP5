"""Current real SWAP5 versus original4.3.1 on the existing matched kernels."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import time
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
CASES = {1:('bare',30),2:('prescribed_roots',30),3:('dry',1),4:('shallow_head',1),
    5:('rain_pulse',3),6:('prescribed_drainage',30),7:('long_balanced',365),8:('layered_column',30)}
DTYPE = np.dtype([('step','i4'),('dt','f8'),('nl','i4'),('retry','i4'),('mass','f8'),
    ('h','f8',(50,)),('theta','f8',(50,)),('pond','f8'),('gwl','f8'),
    ('top','f8'),('bottom','f8'),('root','f8'),('drain','f8')])
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--output',type=Path,required=True)
ap.add_argument('--stage',choices=['build','native','all'],default='all')
ap.add_argument('--reuse-legacy',type=Path)
a = ap.parse_args()
out = a.output.resolve()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
if a.stage in ['build','all']:
    out.mkdir(parents=True,exist_ok=False)
    report = dict(status='BUILDING',events=[],builds={},runs=[],summary=[],
        baseline=subprocess.check_output(['git','merge-base','HEAD','origin/integration/f-ci-canonical'],cwd=ROOT,text=True).strip(),
        source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),
        host=platform.uname()._asdict(),core=min(os.sched_getaffinity(0)),
        compiler=subprocess.check_output([os.environ.get('FC','gfortran'),'--version'],text=True),
        scope='Matched synthetic fixed-step real kernels only; excludes weather/crop/transaction orchestration')
else:
    report = json.loads((out/'RESULT.json').read_text())
def save():
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
def command(cmd,folder,label):
    start = time.monotonic()
    r = subprocess.run(list(map(str,cmd)),cwd=folder,capture_output=True)
    for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
    report['events'].append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.monotonic()-start))
    save();r.check_returncode()
if a.stage in ['build','all']:
    spec = importlib.util.spec_from_file_location('audit',ROOT/'tools/performance/run_richards_revision_audit.py')
    audit = importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
    audit.DRIVER = ROOT/'tests/performance/swap5_perf01_column.f90'
    for opt in ['O0','O2']:
        if a.reuse_legacy:
            previous=json.loads((a.reuse_legacy/'RESULT.json').read_text())
            assert previous['compiler']==report['compiler']
            legacy=(a.reuse_legacy/('legacy-'+opt)).resolve()
            meta=previous['builds']['legacy-'+opt]
            assert sha(legacy/'trajectory')==meta['executable_sha256']
            for path,digest in meta['source_sha256'].items():assert sha(legacy/path)==digest,path
            assert sha(ROOT/'tests/performance/swap431_perf01_column.f90')==meta['driver_sha256']
            (out/('legacy-'+opt)).symlink_to(legacy,target_is_directory=True)
            report.setdefault('legacy_reuse',{})[opt]=dict(source=str(legacy),all216_original_members_exact=True,
                executable_sha256=meta['executable_sha256'],compiler_exact=True)
        else:
            command([sys.executable,'-B',ROOT/'tools/performance/build_swap431_perf01.py','--output',out/('legacy-'+opt),'--opt',opt],ROOT,'build-legacy-'+opt)
        old = out/('legacy-'+opt)
        report['builds']['legacy-'+opt] = json.loads((old/'INPUTS.json').read_text())
        audit.COMMON = ['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-'+opt]
        if opt == 'O0': audit.COMMON += ['-fcheck=all','-ffpe-trap=invalid,zero,overflow']
        start = time.monotonic()
        modern = audit.build(ROOT,out/('current-'+opt))
        modern['total_build_seconds'] = time.monotonic()-start
        report['builds']['current-'+opt] = modern
        save()
    report['status'] = 'BUILT';save()
if a.stage == 'build':
    print('CURRENT_431_REAL_KERNEL_BUILDS_PASS');sys.exit(0)
assert report['status'] == 'BUILT'
for key,meta in report['builds'].items():
    assert sha(out/key/'trajectory') == meta['executable_sha256']
    if key.startswith('legacy'):
        for path,digest in meta['source_sha256'].items():assert sha(out/key/path) == digest,path
        assert sha(ROOT/'tests/performance/swap431_perf01_column.f90') == meta['driver_sha256']
    else:
        inputs = json.loads((out/key/'INPUTS.json').read_text())
        for path,digest in inputs['source_identity'].items(): assert sha(Path(path)) == digest,path
report['status'] = 'NATIVE_RUNNING';save()
for opt,repeats in [('O2',5),('O0',1)]:
    for case,(name,days) in CASES.items():
        traces = {}
        for repeat in range(repeats):
            for arm in (['legacy','current'] if repeat%2 == 0 else ['current','legacy']):
                label = f'{opt}-{case}-{repeat}-{arm}'
                folder = out/label;folder.mkdir()
                start = time.monotonic()
                cmd = ['taskset','-c',str(report['core']),str(out/(arm+'-'+opt)/'trajectory'),str(days),str(case)]
                r = subprocess.run(cmd,cwd=folder,capture_output=True,timeout=90)
                for stream in ['stdout','stderr']:(folder/stream).write_bytes(getattr(r,stream))
                record = dict(opt=opt,case=case,name=name,days=days,repeat=repeat,arm=arm,
                    command=cmd,returncode=r.returncode,wall_seconds=time.monotonic()-start)
                report['runs'].append(record);save();r.check_returncode()
                path = folder/('legacy_trajectory.bin' if arm == 'legacy' else 'trajectory.bin')
                assert path.stat().st_size%DTYPE.itemsize == 0
                trace = np.fromfile(path,dtype=DTYPE)
                assert len(trace) == days*200
                assert np.isfinite(np.column_stack([trace[k].reshape(len(trace),-1) for k in DTYPE.names])).all()
                assert np.abs(trace['mass']).max() <= 1e-12
                timing = re.search(rb'CPU=\s*(\S+) WALL=\s*(\S+)',r.stderr)
                assert timing
                record.update(core_cpu=float(timing[1]),core_wall=float(timing[2]),
                    trace_sha256=sha(path),stdout_sha256=hashlib.sha256(r.stdout).hexdigest(),
                    stderr_sha256=hashlib.sha256(r.stderr).hexdigest(),steps=len(trace),
                    nonlinear_iterations=int(trace['nl'].sum()),max_mass_cm=float(np.abs(trace['mass']).max()))
                assert record['core_cpu'] > 0
                if repeat:
                    assert np.array_equal(trace,traces[arm]),'non-deterministic physical/work trace'
                    path.unlink()  # First repetition retains the entire trace; later identities remain recorded.
                else:traces[arm] = trace
                save()
                print(label,record['core_cpu'],flush=True)
        legacy,current = traces['legacy'],traces['current']
        for key in ['step','dt','root','drain']:assert np.array_equal(legacy[key],current[key]),key
        delta = {key:float(np.abs(current[key]-legacy[key]).max()) for key in DTYPE.names}
        assert delta['h'] <= 1e-8 and delta['theta'] <= 1e-10
        assert all(delta[k] <= 1e-8 for k in ['pond','gwl','top','bottom'])
        row = dict(opt=opt,case=case,name=name,days=days,historical_max_abs=delta,arms={})
        for arm in ['legacy','current']:
            records = [r for r in report['runs'] if r['opt'] == opt and r['case'] == case and r['arm'] == arm]
            cpu = [r['core_cpu'] for r in records]
            row['arms'][arm] = dict(cpu_seconds=cpu,median_cpu_seconds=statistics.median(cpu),
                min_cpu_seconds=min(cpu),max_cpu_seconds=max(cpu),steps=records[0]['steps'],
                nonlinear_iterations=records[0]['nonlinear_iterations'],max_mass_cm=max(r['max_mass_cm'] for r in records))
        row['current_over_431_cpu'] = row['arms']['current']['median_cpu_seconds']/row['arms']['legacy']['median_cpu_seconds']
        report['summary'].append(row);save()
report['status'] = 'COMPLETE_MATCHED_REAL_KERNEL_O0_O2_PHYSICAL_SCREEN_PASS';save()
print(report['status'],flush=True)
