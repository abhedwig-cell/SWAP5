"""Extend the existing explicit-input curve without modifying production code.

Requires the retained native executable from PERF01 pond-policy research.
Native timing excludes Python, compilation and analysis. Raw failures are kept.
"""
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import resource
import runpy
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'benchmarks/performance/evidence/perf01-fast-curve-expanded-20261021'
OLD = Path('/tmp/perf01-pond-policy/curve-1e-3')
digest = lambda b: hashlib.sha256(b).hexdigest()


def rows(path):
    return list(csv.DictReader(path.open()))


def assess(folder, reference):
    b, t, w = [rows(folder / f) for f in ('budget.csv', 'trajectory.csv', 'work.csv')]
    assert len(b) == len(w) == 64 and len(t) == len(reference) == 2048
    dz = [.5, .5, 1, 1, 2, 3] + [5.] * 26
    errors = dict.fromkeys(('head_cm', 'theta', 'storage_mm', 'soil_storage_mm',
                           'pond_mm', 'infiltration_mm', 'evaporation_mm', 'runoff_mm'), 0.)
    cumulative = dict.fromkeys(('infiltration_cm', 'pond_evaporation_cm', 'runoff_cm'), 0.)
    for i, budget in enumerate(b):
        native, ref = t[i*32:(i+1)*32], reference[i*32:(i+1)*32]
        assert int(budget['window']) == i + 1
        assert all(int(x['window']) == i+1 and int(x['node']) == j+1
                   for j, x in enumerate(native))
        ns = sum(float(x['theta'])*d for x, d in zip(native, dz))
        rs = sum(float(x['theta'])*d for x, d in zip(ref, dz))
        rp = float(ref[0]['pond'])
        nt = float(budget['water_end_cm'])
        for key in cumulative:
            cumulative[key] += float(budget[key])
        diffs = {'head_cm': max(abs(float(x['head'])-float(y['head'])) for x,y in zip(native,ref)),
                 'theta': max(abs(float(x['theta'])-float(y['theta'])) for x,y in zip(native,ref)),
                 'storage_mm': 10*abs(nt-rs-rp), 'soil_storage_mm': 10*abs(ns-rs),
                 'pond_mm': 10*abs(nt-ns-rp),
                 'evaporation_mm': 10*abs(cumulative['pond_evaporation_cm']-float(ref[0]['cumulative_evaporation'])),
                 'runoff_mm': 10*abs(cumulative['runoff_cm']-float(ref[0]['cumulative_runoff'])),
                 'infiltration_mm': 10*abs(cumulative['infiltration_cm']-(float(ref[0]['time'])-
                     float(ref[0]['cumulative_evaporation'])-float(ref[0]['cumulative_runoff'])-rp))}
        for key, value in diffs.items():
            errors[key] = max(errors[key], value)
    return dict(errors=errors,
                water_residual_mm=max(abs(float(x['water_residual_cm'])) for x in b)*10,
                solute_residual_mg_cm2=max(abs(float(x['solute_residual_mg_cm2'])) for x in b),
                totals_mm={k:10*v for k,v in cumulative.items()},
                first_runoff_window=next((int(x['window']) for x in b if float(x['runoff_cm']) > 0),None),
                work={k:sum(int(x[k]) for x in w) for k in w[0] if k not in ('window','cpu')})


def main():
    OUT.mkdir(parents=True, exist_ok=False)
    prior = json.loads((OLD/'RESULT.json').read_text())
    exe = OLD/'generated/column'
    assert digest(exe.read_bytes()) == prior['executable_sha256']
    assert all(digest((ROOT/p).read_bytes()) == h for p,h in prior['build']['input_sha256'].items())
    # Only the file application's upper input bound changes in this private main.
    # All production providers and all numerical/physical acceptance guards stay exact.
    generated = OUT/'generated'
    generated.mkdir()
    source = (OLD/'generated/main.f90').read_text()
    anchor = "temporal_tolerance<=1d-3,'invalid temporal tolerance'"
    assert source.count(anchor) == 1
    (generated/'main.f90').write_text(source.replace(anchor,"temporal_tolerance<=1d0,'invalid temporal tolerance'"))
    build_events = []
    for event in prior['events']:
        if event['category'] not in ('compile-generated','link-generated'):
            continue
        command = [x.replace(str(OLD/'generated'),str(generated)) for x in event['command']]
        for x in command:
            if x.endswith(('.o','.a')) and not x.startswith(str(generated)):
                assert digest(Path(x).read_bytes()) == prior['linked_original_sha256'][x]
        start = time.monotonic()
        result = subprocess.run(command,capture_output=True)
        for stream in ('stdout','stderr'):
            (generated/(event['category']+'.'+stream)).write_bytes(getattr(result,stream))
        build_events.append(dict(command=command,returncode=result.returncode,seconds=time.monotonic()-start))
        result.check_returncode()
    exe = generated/'column'
    (OUT/'BUILD.json').write_text(json.dumps(dict(events=build_events,
        executable_sha256=digest(exe.read_bytes()),main_sha256=digest((generated/'main.f90').read_bytes()),
        scope='Private file input ceiling only; no production or acceptance guard changed'),indent=2)+'\n')
    template = (OLD/'native/input.nml').read_text()
    assert template.count('temporal_tolerance=0.001') == 1
    (OUT/'prior-build.json').write_text(json.dumps(prior,indent=2)+'\n')
    frozen = runpy.run_path(str(ROOT/'integration/diagnostics/verify_perf01_empty_pond.py'))['capsule']('experiment_evidence')
    ref_bytes = frozen['independent-water/tighter.csv']
    (OUT/'reference.csv').write_bytes(ref_bytes)
    ref = list(csv.DictReader(io.StringIO(ref_bytes.decode())))
    cpu = int(prior['native_command'][2])
    assert cpu in os.sched_getaffinity(0)
    records = []
    # Reverse the middle repetition to reduce systematic order effects.
    values = [.001,.003,.01,.03,.1,1.]
    for rep in range(3):
        for tol in (values if rep != 1 else values[::-1]):
            folder = OUT/f'tol-{tol:g}-rep-{rep}'
            folder.mkdir()
            inp = folder/'input.nml'
            inp.write_text(template.replace('temporal_tolerance=0.001',f'temporal_tolerance={tol}'))
            command = ['taskset','-c',str(cpu),str(exe),str(inp),'-','64']
            def limit():
                resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
            start = time.monotonic()
            with (folder/'stdout').open('wb') as so, (folder/'stderr').open('wb') as se:
                p = subprocess.Popen(command,cwd=folder,stdout=so,stderr=se,preexec_fn=limit)
                expired = False
                while True:
                    pid, status, usage = os.wait4(p.pid,os.WNOHANG)
                    if pid:
                        break
                    if time.monotonic()-start > 30:
                        expired = True
                        p.kill()
                        pid, status, usage = os.wait4(p.pid,0)
                        break
                    time.sleep(.01)
                p.returncode = os.waitstatus_to_exitcode(status)
            result = dict(tolerance=tol, repetition=rep, command=command,
                          returncode=p.returncode, timed_out=expired, wall_seconds=time.monotonic()-start,
                          user_seconds=usage.ru_utime, system_seconds=usage.ru_stime,
                          max_rss_kib=usage.ru_maxrss)
            if p.returncode == 0 and not expired:
                result.update(assess(folder,ref))
            result['raw_sha256'] = {x.name:digest(x.read_bytes()) for x in folder.iterdir()}
            (folder/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
            records.append(result)
            print(tol,rep,result['returncode'],result['user_seconds'],flush=True)
    summary = []
    for tol in values:
        selected = [r for r in records if r['tolerance'] == tol]
        assert len(selected) == 3
        if all(r['returncode'] == 0 and not r['timed_out'] for r in selected):
            for key in ('errors','totals_mm','work','first_runoff_window'):
                assert all(r[key] == selected[0][key] for r in selected)
            assert all(r['water_residual_mm'] < 1e-9 and r['solute_residual_mg_cm2'] < 1e-11 for r in selected)
        summary.append(dict(tolerance=tol, median_user_seconds=statistics.median(r['user_seconds'] for r in selected),
                            observations=selected))
    (OUT/'SUMMARY.json').write_text(json.dumps(dict(baseline=subprocess.check_output(
        ['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),executable_sha256=digest(exe.read_bytes()),
        reference_sha256=digest(ref_bytes), cpu=cpu, curve=summary),indent=2)+'\n')


if __name__ == '__main__':
    main()
