#!/usr/bin/env python3
"""Fresh production O0/O2 research; no production admission or rate policy."""
import argparse, base64, hashlib, io, json, os, pathlib, re, shlex, subprocess, tarfile, time
import numpy as np
from scipy.optimize import brentq

ROOT = pathlib.Path(__file__).resolve().parents[3]
UNIT = pathlib.Path(__file__).resolve().parent
BASE = '43ee311ae4b525afd191a8e38c66a17d9c8b3a17'
sha = lambda b: hashlib.sha256(b).hexdigest()

def validate(raw):
    rows = [line.split() for line in raw.decode().splitlines()]
    sweep = np.array([[float(v) for v in row[2:]] for row in rows if row[0] == 'SWEEP'])
    assert sweep.shape == (2001, 6)
    a = np.linspace(0, 1, 2001)
    f, b = np.exp(-10*a), np.exp(-5*a)-np.exp(-10*a)
    gain = .001*f + .08*b - .001
    expected = np.column_stack([a, f, b, np.zeros_like(a), gain, .45*(1-f-b)])
    error = float(np.max(abs(sweep-expected)))
    assert error < 2e-13, error
    demand = lambda x: .08*np.exp(-5*x)-.079*np.exp(-10*x)-.001
    roots = np.array([[float(v) for v in row[2:]] for row in rows if row[0] == 'ROOT'])
    root_values = [brentq(lambda x: demand(x)-.005, 0, .13),
                   brentq(lambda x: demand(x)-.005, .14, 1)]
    assert roots.shape == (2, 5) and np.max(abs(roots[:, 0]-root_values)) < 2e-13
    assert np.max(abs(roots[:, 4])) < 1e-12
    for r in roots:
        f, b = np.exp(-10*r[0]), np.exp(-5*r[0])-np.exp(-10*r[0])
        assert np.max(abs(r[1:4]-[f, b, .45*(1-f-b)])) < 2e-13
    assert gain[-1] < 0 and max(gain) > .005 and roots[1, 3]-roots[0, 3] > .2
    clipped = [row for row in rows if row[0] == 'CLIPPED']
    assert len(clipped) == 1 and int(clipped[0][1]) == 3
    assert abs(float(clipped[0][2])-(demand(.13)-.005)) < 2e-13
    candidates = [row for row in rows if row[0] == 'CANDIDATE']
    assert len(candidates) == 6
    for row in candidates:
        mode, stock, status, exchange = map(int, row[1:5])
        n, mineral, residual = map(float, row[5:])
        assert abs(n + .039*(1-np.exp(-.1))) < 2e-13
        if stock == 1 and mode < 2:
            assert status == exchange == 0 and abs(mineral-(.02+n)) < 2e-13
        else:
            assert status != 0 and mineral == (.02 if stock else .00001)
        assert abs(residual) < 1e-12
    return dict(max_analytic_error=error, root_activity=roots[:, 0].tolist(),
                root_carbon_kg_m2=roots[:, 3].tolist(),
                maximum_organic_n_gain_kg_m2=float(max(gain)),
                full_activity_organic_n_gain_kg_m2=float(gain[-1]),
                clipped_n_excess_kg_m2=float(clipped[0][2]), candidate_cases=6)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True, type=pathlib.Path)
    parser.add_argument('--seal', action='store_true')
    args = parser.parse_args(); out = args.out.resolve(); out.mkdir()
    events = []
    def command(command, cwd, category):
        start = time.perf_counter()
        r = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True)
        index = len(events)
        names = [f'{index:04d}.stdout', f'{index:04d}.stderr']
        for name, data in zip(names, [r.stdout, r.stderr]): (out/name).write_bytes(data)
        events.append(dict(command=list(map(str, command)), category=category,
            seconds=time.perf_counter()-start, returncode=r.returncode,
            stdout=names[0], stderr=names[1], stdout_sha256=sha(r.stdout), stderr_sha256=sha(r.stderr)))
        (out/'events.json').write_text(json.dumps(events, indent=2)+'\n')
        if r.returncode: raise RuntimeError(f'{category} failed: {r.stderr.decode()} {r.stdout.decode()}')
        return r.stdout
    fc = shlex.split(os.environ.get('FC', 'gfortran'))
    compiler = command(fc+['--version'], out, 'compiler').decode()
    providers = {}
    for p in (ROOT/'src').rglob('*.f90'):
        for name in re.findall(r'^\s*module\s+(\w+)\s*$', p.read_text(), re.M|re.I): providers[name.lower()] = p
    ordered, seen = [], set()
    def visit(p):
        if p in seen: return
        seen.add(p)
        for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)', p.read_text(), re.M|re.I):
            if name.lower() not in ['iso_fortran_env', 'ieee_arithmetic']: visit(providers[name.lower()])
        ordered.append(p)
    visit(UNIT/'test_organic_constraint.f90')
    results = {}
    for opt in ['O0', 'O2']:
        build = out/opt; build.mkdir()
        flags = ['-'+opt, '-std=f2008', '-ffree-line-length-none', '-fcheck=all', '-ffpe-trap=invalid,zero,overflow', '-J'+str(build), '-I'+str(build)]
        objects = []
        for i, p in enumerate(ordered):
            obj = build/f'{i}.o'; objects.append(obj)
            command(fc+flags+['-c', p, '-o', obj], build, 'compile')
        exe = build/'research'
        command(fc+flags+objects+['-o', exe], build, 'link')
        raw = command([exe], build, 'native'); (out/(opt+'.txt')).write_bytes(raw)
        results[opt] = validate(raw)
    a = np.loadtxt(io.StringIO('\n'.join(x[6:] for x in (out/'O0.txt').read_text().splitlines() if x.startswith('SWEEP'))))
    b = np.loadtxt(io.StringIO('\n'.join(x[6:] for x in (out/'O2.txt').read_text().splitlines() if x.startswith('SWEEP'))))
    assert np.max(abs(a-b)) < 2e-13
    authority = ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(authority.read_bytes()))) as t:
        historical = {name: sha(t.extractfile(name).read()) for name in ['SWAP/management_soil.f90', 'SWAP/wofost_soil_orgmatn.f90']}
    inputs = ordered+[pathlib.Path(__file__), UNIT/'ORGANIC_CONSTRAINT_CONTRACT.md', authority]
    result = dict(status='RESEARCH_PASS_PHYSICAL_LIMITATION_POLICY_UNRESOLVED', baseline=BASE,
        tested_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        production_changed=False, production_admitted=False, compiler=compiler,
        production_provider_count=len(ordered)-1, sweep_points_per_optimization=2001,
        input_sha256={str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in inputs},
        historical_sha256=historical, results=results,
        cost_seconds={c:sum(e['seconds'] for e in events if e['category']==c) for c in ['compile','link','native']})
    (out/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    if args.seal:
        members = [p for p in out.iterdir() if p.is_file()]
        manifest = {p.name:sha(p.read_bytes()) for p in members}
        (out/'MEMBERS.json').write_text(json.dumps(manifest, indent=2)+'\n')
        buf = io.BytesIO()
        with tarfile.open(fileobj=buf, mode='w:xz') as t:
            for p in members+[out/'MEMBERS.json']: t.add(p, arcname=p.name)
        capsule = UNIT/'ORGANIC_CONSTRAINT_EVIDENCE.tar.xz.b64'
        capsule.write_bytes(base64.encodebytes(buf.getvalue()))
        result['evidence_sha256'] = sha(capsule.read_bytes())
        (UNIT/'ORGANIC_CONSTRAINT_RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))

if __name__ == '__main__': main()
