#!/usr/bin/env python3
"""Frozen P4 numerical qualification, not hydrological application admission."""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import platform
import resource
import statistics
import subprocess
import sys
import time
import numpy as np

MATERIALS = ('B02', 'B05', 'B11', 'B16')
PURPOSES = ('SURF_P', 'GW_LB')
REPEATS = 5
PARAM_KEYS = dict(tr='theta_r', ts='theta_s', alpha='alpha_per_cm', nvg='n', ks='Ksat_cm_per_day', **{'lambda': 'lambda'})

def load(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module

def write_json(path: Path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, sort_keys=True, allow_nan=False) + '\n')

def fields(line: str) -> dict[str, str]:
    return dict(x.split('=', 1) for x in line.strip().split('|') if '=' in x)

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def bind(base, p3, purpose: str, mat: dict):
    p3.configure_material(base, mat)
    if purpose == 'SURF_P':
        base.HISTORY_SE = dict(p3.SURF_SE)
        base.symbol, base.qtop_downward, base.boundary_psi = p3.surf_symbol, p3.surf_q, p3.surf_bottom
    else:
        base.HISTORY_SE = dict(p3.GW_SE)
        base.symbol, base.qtop_downward, base.boundary_psi = p3.gw_symbol, p3.gw_q, p3.gw_bottom

def conform(exe, purpose, material, namelist, base, member):
    """Compare independent language implementations on fixed, response-free probes."""
    maxima = dict(PSI=0.0, K=0.0, DTH=0.0, QT=0.0, QB=0.0)
    count = 0
    for ih, hist in enumerate(base.HISTORY_SE, 1):
        dz, y0, k0, psi0 = base.initial(hist, member)
        n = len(dz)
        for day in (1, 15, 16, 20, 21, 30, 31, 40, 41, 45, 46, 50, 51, 60):
            for se in (np.full(n, base.HISTORY_SE[hist]), np.linspace(0.55, 0.90, n)):
                theta = base.THETA_R + se * (base.THETA_S - base.THETA_R)
                y = np.r_[theta * dz, 0.0, 0.0]
                derivative = base.rhs(y, dz, k0, psi0, hist, base.symbol(hist, day), 'CURRENT_LAYER_FACE')
                psi, k = base.psi_k(theta)
                stdin = f'{ih} {day}\n' + ' '.join(format(float(v), '.17g') for v in theta) + '\n'
                r = subprocess.run([str(exe), purpose, material, str(namelist), '0.01', 'probe'],
                                   input=stdin, capture_output=True, text=True, timeout=20, check=True)
                layers = [fields(x) for x in r.stdout.splitlines() if x.startswith('P4_PROBE|')]
                boundary = [fields(x) for x in r.stdout.splitlines() if x.startswith('P4_PROBE_BOUNDARY|')]
                if len(layers) != n or len(boundary) != 1:
                    raise RuntimeError('incomplete equation probe')
                pairs = []
                for j, row in enumerate(layers):
                    if int(row['LAYER']) != j + 1:
                        raise RuntimeError('probe layer identity')
                    pairs.extend((key, float(row[key]), float(expected)) for key, expected in
                                 (('PSI', psi[j]), ('K', k[j]), ('DTH', derivative[j] / dz[j])))
                pairs += [('QT', float(boundary[0]['QT']), float(derivative[-2])),
                          ('QB', float(boundary[0]['QB']), float(derivative[-1]))]
                for key, actual, expected in pairs:
                    err = abs(actual - expected) / (1.0 + abs(expected))
                    if not math.isfinite(err) or err > 5e-12:
                        raise RuntimeError(f'equation conformance failed {material} {hist} {day} {key}: {err}')
                    maxima[key] = max(maxima[key], err)
                count += 1
    # Endpoint rejection is a contract test, not a candidate response.
    theta = np.full(len(base.PARTITIONS[member]), base.THETA_R)
    stdin = '1 1\n' + ' '.join(format(float(v), '.17g') for v in theta) + '\n'
    r = subprocess.run([str(exe), purpose, material, str(namelist), '0.01', 'probe'],
                       input=stdin, capture_output=True, text=True, timeout=20)
    if r.returncode == 0 or 'P4_FAILURE|REASON=PROBE_DOMAIN' not in r.stdout:
        raise RuntimeError('compiled endpoint rejection failed')
    return {'status': 'PASS', 'probe_count': count, 'max_scaled_errors': maxima, 'endpoint_rejection': True}

def linear_diagnostics(base, member):
    """Post-hoc local explanation only; not a timestep selector or global proof."""
    out = {}
    for hist in base.HISTORY_SE:
        dz, y0, k0, psi0 = base.initial(hist, member)
        theta0 = y0[:-2] / dz
        def f(theta):
            y = np.r_[theta * dz, 0.0, 0.0]
            return base.rhs(y, dz, k0, psi0, hist, base.symbol(hist, 1), 'CURRENT_LAYER_FACE')[:-2] / dz
        rows = []
        for eps in (1e-6, 5e-7):
            jac = np.empty((len(dz), len(dz)))
            for j in range(len(dz)):
                delta = np.zeros(len(dz)); delta[j] = eps
                jac[:, j] = (f(theta0 + delta) - f(theta0 - delta)) / (2 * eps)
            eig = np.linalg.eigvals(jac)
            row = {'epsilon_theta': eps, 'eigenvalues_per_day': [[float(v.real), float(v.imag)] for v in eig]}
            for dt in (0.01, 0.005):
                z = dt * eig
                row[f'dt_{dt}'] = {'heun_fixed_point_spectral_radius': float(np.max(abs(z) / 2)),
                                  'rk4_stability_polynomial_max_modulus': float(np.max(abs(1+z+z*z/2+z**3/6+z**4/24)))}
            rows.append(row)
        out[hist] = rows
    return {'status': 'POST_HOC_INITIAL_STATE_LINEARIZATION_NOT_GLOBAL_PROOF', 'histories': out}

def invoke(command, logfile: Path):
    before = resource.getrusage(resource.RUSAGE_CHILDREN)
    t0 = time.perf_counter()
    with logfile.open('w') as stream:
        p = subprocess.run([str(x) for x in command], stdout=stream, stderr=subprocess.STDOUT, timeout=180)
    wall = time.perf_counter() - t0
    after = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu = (after.ru_utime - before.ru_utime) + (after.ru_stime - before.ru_stime)
    return {'exit_status': p.returncode, 'wall_s': wall, 'cpu_s': cpu}

def process_summary(samples):
    out = {'samples': samples}
    for key in ('wall_s', 'cpu_s'):
        vals = [s[key] for s in samples]
        out[key] = {'min': min(vals), 'median': statistics.median(vals), 'max': max(vals)}
    return out

def parse_compiled(path, purpose, dt, base, p3, member, exit_status):
    text = path.read_text()
    failure = [fields(line) for line in text.splitlines() if line.startswith('P4_FAILURE|')]
    if exit_status:
        if len(failure) != 1:
            raise RuntimeError('unclassified compiled infrastructure failure: ' + text[-2000:])
        return {'status': 'NUMERICAL_BLOCKED', 'failure': failure[0], 'histories': None}
    if failure or text.count('P4_EXECUTION_COMPLETE=PASS') != 1:
        raise RuntimeError('missing compiled completion authority')
    bounds = p3.PARTITIONS[member]; dz = np.diff(bounds)
    states = {}; layers = {}; passes = {}; internal_time = {}
    for line in text.splitlines():
        row = fields(line)
        if line.startswith('P4_STATE|'):
            key = (row['HISTORY'], int(row['DAY']))
            if key in states:
                raise RuntimeError('duplicate state')
            states[key] = row
        elif line.startswith('P4_LAYER|'):
            key = (row['HISTORY'], int(row['DAY']), int(row['LAYER']))
            if key in layers:
                raise RuntimeError('duplicate layer')
            layers[key] = float(row['THETA'])
        elif line.startswith('P4_HISTORY_PASS|'):
            if row['HISTORY'] in passes:
                raise RuntimeError('duplicate history certificate')
            passes[row['HISTORY']] = row
        elif line.startswith('P4_TIMING|'):
            internal_time = {k: float(v) for k, v in row.items()}
    histories = list(base.HISTORY_SE)
    if len(states) != 120 or len(layers) != 120 * len(dz) or set(passes) != set(histories):
        raise RuntimeError('history cardinality failed')
    output = {}
    for h in histories:
        if not (0.0 <= float(passes[h]['MAX_LEDGER']) <= 1e-8):
            raise RuntimeError('ledger certificate failed')
        if int(passes[h]['RHS_EVALS']) != round(4 * 60 / dt):
            raise RuntimeError('RHS work accounting failed')
        series = {key: [] for key in ('total_storage_cm', 'surface_0_20_storage_cm', 'root_zone_0_40_storage_cm',
                   'upper_0_80_storage_cm', 'theta_10cm', 'cumulative_bottom_downward_cm', 'interval_average_bottom_downward_flux_cm_per_day')}
        names = {'total_storage_cm': 'TOTAL', 'surface_0_20_storage_cm': 'S20', 'root_zone_0_40_storage_cm': 'S40',
                 'upper_0_80_storage_cm': 'S80', 'cumulative_bottom_downward_cm': 'CUMBOT',
                 'interval_average_bottom_downward_flux_cm_per_day': 'QBOT'}
        for d in range(1, 61):
            theta = np.array([layers[(h, d, j)] for j in range(1, len(dz) + 1)])
            base.psi_k(theta)
            row = states[(h, d)]
            for key, field in names.items():
                value = float(row[field])
                if not math.isfinite(value):
                    raise RuntimeError('nonfinite output')
                series[key].append(value)
            series['theta_10cm'].append(p3.mapped(theta * dz, bounds))
            if abs(sum(theta * dz) - float(row['TOTAL'])) > 1e-11:
                raise RuntimeError('layer storage mapping failed')
        output[h] = series
    return {'status': 'QUALIFIED', 'max_water_ledger_cm': max(float(r['MAX_LEDGER']) for r in passes.values()),
            'rhs_evaluations': sum(int(r['RHS_EVALS']) for r in passes.values()),
            'internal_timing': internal_time, 'histories': output, 'failure': None}

def canon(histories):
    names = {'total': 'total_storage_cm', 'surface': 'surface_0_20_storage_cm', 'root': 'root_zone_0_40_storage_cm',
             'upper': 'upper_0_80_storage_cm', 'theta': 'theta_10cm', 'cum': 'cumulative_bottom_downward_cm',
             'q': 'interval_average_bottom_downward_flux_cm_per_day'}
    return {h: {key: np.asarray(row[name]) for key, name in names.items()} for h, row in histories.items()}

def per_history(candidate, reference, purpose, analyzer):
    a = canon(candidate); out = {}
    keys = ('surface', 'root', 'upper', 'theta', 'total') if purpose == 'SURF_P' else ('cum', 'q', 'total')
    for h, row in a.items():
        ref = reference[h]
        m = {key + '_rmse': analyzer.rmse(row[key] - ref[key]) for key in keys}
        m['final_total_signed_bias_cm'] = float(row['total'][-1] - ref['total'][-1])
        if purpose == 'SURF_P':
            m['extremum_timing_days'] = {k: {'minimum': abs(int(np.argmin(row[k]))-int(np.argmin(ref[k]))),
                                           'maximum': abs(int(np.argmax(row[k]))-int(np.argmax(ref[k])))} for k in ('root', 'upper')}
        else:
            ca, ra = analyzer.reversals(row['q']), analyzer.reversals(ref['q'])
            m.update(candidate_reversal_days=ca, reference_reversal_days=ra,
                     sign_mismatch_days=int(np.count_nonzero(np.sign(row['q']) != np.sign(ref['q']))),
                     final_exchange_signed_bias_cm=float(row['cum'][-1]-ref['cum'][-1]))
        out[h] = m
    return out

def case(args):
    outdir = args.outdir.resolve(); outdir.mkdir(parents=True, exist_ok=True)
    p3 = load(args.p3_runner.resolve(), 'p4_p3_adapter')
    analyzer = load(args.p3_analyzer.resolve(), 'p4_p3_analyzer')
    base = p3.load_module(args.base.resolve())
    mat = json.loads(args.materials.read_text())['materials'][args.material]
    bind(base, p3, args.purpose, mat)
    member = 'S4' if args.purpose == 'SURF_P' else 'G8'
    nml = outdir / 'material.nml'
    nml.write_text('&material_parameters\n' + ',\n'.join(f'{k}={float(mat[v]):.17g}' for k,v in PARAM_KEYS.items()) + '\n/\n')
    eq = conform(args.exe, args.purpose, args.material, nml, base, member)
    write_json(outdir/'equation_conformance.json', eq)
    diagnostic = linear_diagnostics(base, member)
    commands = {'RK4_FIXED': [args.exe, args.purpose, args.material, nml, '0.01'],
                'RK4_HALF': [args.exe, args.purpose, args.material, nml, '0.005'],
                'R128': [args.reference128]}
    samples = {key: [] for key in commands}
    hashes = {key: [] for key in commands}
    for iteration in range(REPEATS + 1):
        order = list(commands) if iteration % 2 == 0 else list(reversed(commands))
        for key in order:
            path = outdir / (key + '.txt')
            result = invoke(commands[key], path)
            stable_lines = [x for x in path.read_text().splitlines() if x.startswith(('P4_STATE|', 'P4_LAYER|', 'P4_FAILURE|', 'LARE'))]
            hashes[key].append(hashlib.sha256('\n'.join(stable_lines).encode()).hexdigest())
            if iteration:
                samples[key].append(result)
    for key in commands:
        if len(set(hashes[key])) != 1 or len(set(s['exit_status'] for s in samples[key])) != 1:
            raise RuntimeError('nonrepeatable trajectory/status ' + key)
    ref64_result = invoke([args.reference64], outdir/'R64.txt')
    if ref64_result['exit_status'] or any(s['exit_status'] for s in samples['R128']):
        raise RuntimeError('Reference route did not complete')
    for key in ('R64', 'R128'):
        text = (outdir/(key+'.txt')).read_text()
        prefix = 'LAREDYN0R_STATE|' if args.purpose == 'SURF_P' else 'LAREGW1_STATE|'
        if sum(x.startswith(prefix) for x in text.splitlines()) != 3840:
            raise RuntimeError('Reference state cardinality')
    parser = analyzer.parse_surface if args.purpose == 'SURF_P' else analyzer.parse_gw
    metric = analyzer.surf_metrics if args.purpose == 'SURF_P' else analyzer.gw_metrics
    pseudo = analyzer.pseudo_surface if args.purpose == 'SURF_P' else analyzer.pseudo_gw
    ref = parser(outdir/'R128.txt'); ref64 = parser(outdir/'R64.txt')
    ref_comp = metric(pseudo(ref64), ref)
    routes = {}
    trajectories = {}
    for key, dt in (('RK4_FIXED', 0.01), ('RK4_HALF', 0.005)):
        c = parse_compiled(outdir/(key+'.txt'), args.purpose, dt, base, p3, member, samples[key][0]['exit_status'])
        trajectories[key] = c.pop('histories')
        c['dt_day'] = dt; c['process_timing'] = process_summary(samples[key])
        c['metrics_vs_R128'] = metric(trajectories[key], ref) if trajectories[key] else None
        c['per_history_vs_R128'] = per_history(trajectories[key], ref, args.purpose, analyzer) if trajectories[key] else None
        c['wall_ratio_vs_same_job_R128'] = c['process_timing']['wall_s']['median']/statistics.median(s['wall_s'] for s in samples['R128']) if trajectories[key] else None
        routes[key] = c
    refinement = None
    if all(trajectories.values()):
        delta = metric(trajectories['RK4_FIXED'], canon(trajectories['RK4_HALF']))
        hyd = routes['RK4_FIXED']['metrics_vs_R128']
        refinement = {'full_vs_half': delta,
                      'numerical_to_hydrological_error_ratio': {k: delta[k]/hyd[k] if hyd[k] != 0 else None for k in delta},
                      'per_history': per_history(trajectories['RK4_FIXED'], canon(trajectories['RK4_HALF']), args.purpose, analyzer)}
    ht = []; hc = []; heun = None; heun_failure = None
    t0 = time.perf_counter()
    try:
        for repeat in range(3):
            t1 = time.perf_counter(); c1 = time.process_time()
            heun, ledger, maxit = p3.run_once(base, args.purpose, member)
            ht.append(time.perf_counter()-t1); hc.append(time.process_time()-c1)
        heun_result = {'status': 'QUALIFIED', 'wall_s_median': statistics.median(ht), 'cpu_s_median': statistics.median(hc),
                      'max_water_ledger_cm': ledger, 'max_corrector_iterations': maxit,
                      'metrics_vs_R128': metric(heun, ref)}
    except (RuntimeError, ValueError, FloatingPointError) as exc:
        heun_failure = str(exc)
        heun_result = {'status': 'NUMERICAL_BLOCKED', 'failure': heun_failure, 'failed_elapsed_s': time.perf_counter()-t0}
    for key in routes:
        routes[key]['compiled_process_to_python_run_once_wall_ratio'] = (routes[key]['process_timing']['wall_s']['median']/statistics.median(ht)
            if routes[key]['status']=='QUALIFIED' and heun_failure is None else None)
    result = {'schema': 'swap5.rom-practical.p4.qualified-case.v1', 'purpose': args.purpose, 'material': args.material,
              'member': member, 'split': 'development' if args.material in ('B02','B11') else 'validation',
              'equation_conformance': eq, 'routes': routes, 'refinement': refinement, 'python_heun': heun_result,
              'reference_comparator': ref_comp, 'R128_process_timing': process_summary(samples['R128']),
              'post_hoc_linear_diagnostics': diagnostic,
              'provenance': {'github_sha': os.environ.get('GITHUB_SHA'), 'run_id': os.environ.get('GITHUB_RUN_ID'),
                  'runner': os.environ.get('RUNNER_NAME'), 'platform': platform.platform(), 'python': sys.version,
                  'numpy': np.__version__, 'base_sha256': sha(args.base), 'materials_sha256': sha(args.materials),
                  'compiler': subprocess.run(['gfortran','--version'],capture_output=True,text=True,check=True).stdout.splitlines()[0]},
              'application_acceptance_adjudicated': False, 'production_rom_authorized': False}
    write_json(outdir/'trajectories.json', trajectories)
    write_json(outdir/'result.json', result)
    print(json.dumps({'purpose': args.purpose, 'material': args.material, 'fixed': routes['RK4_FIXED']['status'],
                      'half': routes['RK4_HALF']['status'], 'wall_ratio': routes['RK4_FIXED']['wall_ratio_vs_same_job_R128']}, allow_nan=False))

def aggregate(args):
    rows = [json.loads(p.read_text()) for p in sorted(args.input_dir.rglob('result.json'))]
    expected = {(p,m) for p in PURPOSES for m in MATERIALS}
    if len(rows) != 8 or {(r['purpose'],r['material']) for r in rows} != expected:
        raise RuntimeError('aggregate must contain 8 unique purpose/material identities')
    if any(r['schema'] != 'swap5.rom-practical.p4.qualified-case.v1' or r['equation_conformance']['status']!='PASS' for r in rows):
        raise RuntimeError('case authority failed')
    summary = {}
    for route in ('RK4_FIXED','RK4_HALF'):
        complete = [r for r in rows if r['routes'][route]['status']=='QUALIFIED']
        failed = [dict(purpose=r['purpose'],material=r['material'],failure=r['routes'][route]['failure']) for r in rows if r not in complete]
        summary[route] = {'completed_cases': len(complete), 'total_cases': 8, 'failed_cases': failed,
             'purpose_cost': {p: [r['routes'][route]['wall_ratio_vs_same_job_R128'] for r in complete if r['purpose']==p] for p in PURPOSES}}
    full_success = summary['RK4_FIXED']['completed_cases']==8
    speed = full_success and all(r['routes']['RK4_FIXED']['wall_ratio_vs_same_job_R128']<1 for r in rows if r['split']=='validation')
    result = {'schema':'swap5.rom-practical.p4.result.v1','workstream':'ROM-PRACTICAL','work_unit':'ROM-PRACTICAL-P4',
              'status':'P4_NUMERICAL_CHARACTERIZATION_COMPLETE','summary':summary,'cases':rows,
              'primary_robustness_gate_passed':full_success,'primary_practical_speed_gate_passed':speed,
              'decision':'PRIMARY_FIXED_STEP_SUPPORTED_WITH_REFINEMENT_LIMITS' if speed else 'PRIMARY_P4_TARGET_NOT_QUALIFIED',
              'half_step_role':'Preregistered numerical comparator only; not a retrospective replacement for failed RK4_FIXED.',
              'limitations':['Same frozen and previously exposed P3 forcing, not new blind hydrological validation.',
                 'Process timing includes different harness output/orchestration; not a pure solver or portable speedup.',
                 'Python Heun versus Fortran RK4 changes language and integrator simultaneously.',
                 'Local initial Jacobian diagnostics explain tendencies but do not prove global stability.',
                 'R128 is a controlled Richards harness, not an end-to-end Full SWAP workflow.'],
              'production_rom_authorized':False,'application_acceptance_adjudicated':False,'P_ROM_ET_opened':False}
    write_json(args.output,result)
    print(json.dumps({'status':result['status'],'summary':summary,'decision':result['decision']},allow_nan=False))

def main():
    ap=argparse.ArgumentParser()
    sp=ap.add_subparsers(dest='mode',required=True)
    cp=sp.add_parser('case')
    for name in ('exe','reference64','reference128','materials','base','p3-runner','p3-analyzer','outdir'):
        cp.add_argument('--'+name,required=True,type=Path)
    cp.add_argument('--purpose',required=True,choices=PURPOSES)
    cp.add_argument('--material',required=True,choices=MATERIALS)
    ag=sp.add_parser('aggregate')
    ag.add_argument('--input-dir',required=True,type=Path);ag.add_argument('--output',required=True,type=Path)
    a=ap.parse_args()
    if a.mode=='case':case(a)
    else:aggregate(a)
if __name__=='__main__':
    main()
