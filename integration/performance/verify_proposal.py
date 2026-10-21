"""Exact optional-policy successor: fresh impacted science plus frozen predecessor.

This admits only the bounded opt-in Reference route. Default OFF, old physical
source authority, mass/rollback/restart assertions and reference bytes remain
binding. No retrospective relaxation of old evidence/provider hashes.
"""
import base64
import csv
import hashlib
import io
import json
import math
import re
from pathlib import Path
import runpy
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASE = 'e61d8e107121bc31fa1d9b0eac73439af29eb76f'
STATUS = ROOT/'integration/performance/SWAP5-PERF01_PROPOSAL_STATUS.json'
SCIENCE = ['src', 'tests', 'tools', 'reference', '.github', 'app', 'examples',
           'integration/performance/authority.py', 'integration/audits']
PINS = {
    'src/runtime/mod_canonical_interval_runtime.f90': ('M', 'b1f8bcfd672e6bc88fc439b8634614950e1a0802'),
    'app/solute_column/main.f90': ('M', '25fcc400f7ef89520917c5f1e2fb7b7f2eab3ee6'),
    'tests/performance/test_perf01_proposal.f90': ('A', '2ce37c3bc9b78e78fc93c04b46122333d66f33e4'),
    'integration/performance/authority.py': ('M', '2dd8710e4a301ad308b10853bd10eb6ae2081ce4'),
    'integration/audits/verify_matrix_thermal.py': ('M', '4e716d5fa42ef368180e1aeae72e87724d43883e')}
PHYSICAL = ['state.csv', 'endpoint.csv', 'restart.bin', 'budget.csv']


def require(ok, why):
    if not ok:
        raise ValueError(why)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def source(reader=lambda p: (ROOT/p).read_bytes(), changed=None):
    pond_status=ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
    if pond_status.exists() and 'evidence' in json.loads(pond_status.read_text()).get('nonlinear_pond_successor', {}):
        return runpy.run_path(str(ROOT/'integration/audits/verify_nonlinear_pond.py'),run_name='registered_nonlinear_pond')['source'](reader,changed)
    status = json.loads(STATUS.read_text())
    require(status['baseline'] == BASE and status['default_enabled'] is False, 'policy baseline/default')
    git('merge-base', '--is-ancestor', BASE, 'HEAD')
    require(not git('status', '--porcelain', '--', *SCIENCE), 'dirty science')
    if changed is None:
        changed = dict((r.split('\t')[1], r.split('\t')[0]) for r in
                       git('diff', '--name-status', BASE, 'HEAD', '--', *SCIENCE).splitlines())
    require(changed == {p: v[0] for p, v in PINS.items()}, 'foreign policy science delta')
    for p, (_, expected) in PINS.items():
        raw = reader(p)
        blob = hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
        require(blob == expected, 'policy source drift '+p)
    for p, digest in status['source_sha256'].items():
        require(sha(reader(p)) == digest, 'qualification source drift '+p)
    path = 'src/runtime/mod_canonical_contracts.f90'
    require(reader(path) == subprocess.check_output(['git', 'show', BASE+':'+path], cwd=ROOT), 'changed default/interface')
    return status


def capsule():
    e = json.loads(STATUS.read_text())['evidence']
    path = ROOT/e['index']
    index = json.loads(path.read_text())
    raw = base64.b64decode(b''.join((path.parent/p).read_bytes() for p in index['parts']), validate=True)
    require(sha(raw) == e['sha256'] == index['decoded_sha256'], 'policy capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        members = archive.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members), 'unsafe evidence')
        require(len(members) == len({m.name for m in members}), 'duplicate evidence')
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest = files.pop('MEMBERS.json')
    require(sha(manifest) == index['members_sha256'], 'member manifest')
    inventory = json.loads(manifest)
    require(files.keys() == inventory.keys() and len(files) == index['members'], 'evidence inventory')
    require(all(sha(files[p]) == h for p, h in inventory.items()), 'raw member hash')
    return files


def validate(files, reader=lambda p: (ROOT/p).read_bytes()):
    load = lambda p: json.loads(files[p])
    rows = lambda p: list(csv.DictReader(io.StringIO(files[p].decode())))

    def inputs(values):
        for p, digest in values.items():
            require(sha(reader(p)) == digest, 'stale executed input '+p)

    build = load('BUILD.json')
    require(build['status'] == 'DIRECT_O0_O2_AND_COLUMN_BUILDS_PASS', 'direct contracts incomplete')
    inputs(build['inputs'])
    require(len(build['direct']) == 4 and all('PASS' in r['stdout'] and r['provider_count'] == 8
                                            for r in build['direct'].values()), 'direct actual-runtime contracts')
    for opt in ['O0', 'O2']:
        b = load('build-'+opt+'/build-complete.json')
        inputs(b['input_sha256'])
        require(b['provider_count'] == 178 and b['status'] == 'BUILT', 'column build closure')
        require('-ffpe-trap=invalid,zero,overflow' in b['flags'], 'column FPE guards')
        if opt == 'O0':
            require('-fcheck=all' in b['flags'], 'checked O0')
    controls = {}
    failures = []
    for name in ['temporal-pilot-O2', 'temporal-long-O2', 'temporal-short-O0', 'temporal-short-O2',
                 'temporal-day64-O0', 'temporal-day64-O2', 'temporal-day64-inflow-O2']:
        r = load(name+'/CONTROL.json')
        controls[name] = r
        inputs(r['build']['input_sha256'])
        require(sha(files[name+'/driver.py']) == r['controller_sha256'], 'executed controller identity')
        require(sha(files[name+'/observer/main.f90']) == r['generated']['main_sha256'], 'executed observer')
        require(r['generated']['runtime_sha256'] is None, 'shadow runtime prohibited')
        for run in r['runs']:
            prefix = name+'/'+run['directory']+'/'
            if run['exit'] != 0:
                require((name, run['directory']) in [('temporal-long-O2', 'pond4/1e-08-off-0'),
                        ('temporal-day64-inflow-O2', 'dry_infiltration32/1e-06-off-0')]
                        and run['exit'] == 1 and r['status'] == 'NATIVE_FAILED_OR_CENSORED_NOT_QUALIFIED',
                        'unexpected failure/censoring')
                stdout = files[prefix+'stdout'].decode()
                water = re.search(r'FAILED_REQUEST\s+(\S+)\s+(\S+)\s+COMMITTED_WATER_CLOCK\s+(\S+)', stdout)
                chemical = re.search(r'COMMITTED_CHEMICAL_CLOCK\s+(\S+)', stdout)
                require(water and chemical and float(water[1]) == float(water[3]) == float(chemical[1])
                        and 'CHEMICAL_STEPS           0' in stdout, 'failed external atomicity')
                failures.append(run['directory'])
                continue
            require(all(sha(files[prefix+f]) == run['files'][f] for f in PHYSICAL), 'physical observation digest')
            budget = rows(prefix+'budget.csv')
            require(all(math.isfinite(float(x[k])) and abs(float(x[k])) <= 1e-10 for x in budget
                        for k in ['water_residual_cm', 'solute_residual_mg_cm2']), 'native hard balances')
            if 'work' in run:
                work = rows(prefix+'work.csv')
                require(all(sum(int(x[k]) for x in work) == v for k, v in run['work'].items()), 'numeric work')
                require(run['work']['mass_rejections'] == 0, 'candidate mass acceptance')
                trajectory = rows(prefix+'trajectory.csv')
                require(len(trajectory) == len(work)*len(rows(prefix+'state.csv')), 'trajectory inventory')
                require(all(math.isfinite(float(x[k])) for x in trajectory for k in ['head', 'theta', 'concentration']),
                        'nonfinite state')
            if name.startswith('temporal-day64'):
                expected_t1 = .5 if run['directory'].endswith('-prefix') else 1.0
                require(float(rows(prefix+'endpoint.csv')[0]['time_day']) == expected_t1, 'fixed one-day/split horizon')
        if name in ['temporal-long-O2', 'temporal-pilot-O2', 'temporal-day64-inflow-O2']:
            continue
        require(r['status'] == 'PHYSICAL_ERROR_COST_RESTART_PASS_NOT_ADMITTED', 'selected physical completion')
        expected_cases = ['pond4', 'pond32', 'pond256', 'dry32', 'pulse4'] if 'short' in name else ['pond4', 'dry32', 'pulse4']
        require([s['case'] for s in r['summary']] == expected_cases, 'selected physical case inventory')
        for summary in r['summary']:
            require(summary['default_off_exact'] and summary['restarts_exact'], 'default/restart assertions')
            case = name+'/'+summary['case']+'/'
            for f in PHYSICAL:
                require(files[case+'original/'+f] == files[case+'incumbent/'+f] == files[case+'1e-06-off-0/'+f],
                        'incumbent default OFF preservation')
            for policy in ['off', 'on']:
                full, resumed = case+'1e-06-'+policy+'-0/', case+policy+'-restart/'
                require(all(files[full+f] == files[resumed+f] for f in PHYSICAL[:3]), 'fresh restart bytes')
                for f in ['budget.csv', 'trajectory.csv']:
                    require([x for x in rows(full+f) if int(x['window']) > r['report_windows']//2] == rows(resumed+f),
                            'fresh restarted reporting trajectory')
    require(len(failures) == 2, 'failure disposition')
    for kind in ['short', 'day64']:
        a, b = controls['temporal-'+kind+'-O0'], controls['temporal-'+kind+'-O2']
        records = {r['directory']: r for r in b['runs']}
        for r in a['runs']:
            require(r['files'] == records[r['directory']]['files'] and
                    r.get('work') == records[r['directory']].get('work'), 'O0/O2 physical/work equality')
    old_study = runpy.run_path(str(ROOT/'integration/performance/verify_solver_study.py'), run_name='old_proposal_capsule')
    old_status = json.loads((ROOT/'integration/performance/SWAP5-PERF01_SOLVER_STUDY_STATUS.json').read_text())
    old = old_status['evidence']['candidate']
    prior = old_study['capsule'](ROOT/old['index'], old['sha256'])
    for case in ['pond4', 'pond32', 'pond256', 'dry32', 'pulse4']:
        for tol in ['1e-06', '2.5e-07', '6.25e-08', '1e-09']:
            for f in PHYSICAL+['trajectory.csv']:
                suffix = case+'/'+tol+'-on-0/'+f
                require(files['temporal-short-O2/'+suffix] == prior['temporal-O2/'+suffix],
                        'production versus diagnostic candidate drift')
    original = load('column-qualification/result.json')
    require(original['status'] == 'PASS' and len(original['events']) == 86, 'original real column assertions')
    for key, p in [('test_sha256', 'tests/nut-sol/test_column_input.py'),
                   ('runner_sha256', 'tools/solute/run_column.py'),
                   ('input_sha256', 'examples/solute_column/positive_pond.nml')]:
        require(sha(reader(p)) == original[key], 'original column assertion/input drift')
    runtime = load('preservation/PRESERVATION.json')
    inputs(runtime['inputs'])
    require(runtime['status'] == 'INCUMBENT_EIGHT_RUNTIME_OBSERVATIONS_EXACT_PASS' and len(runtime['runs']) == 8,
            'original runtime preservation')
    thermal = runpy.run_path(str(ROOT/'integration/audits/verify_matrix_thermal_nonlinear.py'), run_name='fresh_optional_thermal')
    thermal_files = {p.removeprefix('composition/thermal/'): raw for p, raw in files.items()
                     if p.startswith('composition/thermal/')}
    thermal['validate'](thermal_files, reader)
    prior_thermal = thermal['capsule']()
    for exponent in ['1', '0.5', '0.8', '1.0005', '1.5', '2']:
        p = exponent+'/physical/result.json'
        require(json.loads(thermal_files[p])['results'] == json.loads(prior_thermal[p])['results'],
                'incumbent nonlinear thermal physical drift')
    predecessor = load('composition/PREDECESSOR.json')
    require(predecessor['baseline'] == BASE and predecessor['owner']['qualified'], 'predecessor owner not qualified')
    for prefix, group, count in [('matched', 'temporal-day64-O2', 3)]:
        matched = load(prefix+'/MATCHED.json')
        require(matched['status'] == 'STATE_ERROR_DOMINANCE_PAIRED_COST_PASS_NOT_ADMITTED', 'matched error/cost completion')
        require(matched['study_sha256'] == sha(files[group+'/CONTROL.json']), 'matched study binding')
        require(len(matched['cases']) == count and len(matched['runs']) == 6*count, 'paired observation inventory')
        for c in matched['cases']:
            study = next(s for s in controls[group]['summary'] if s['case'] == c['case'])
            require(c['default_errors'] == study['errors']['1e-06-off'] and
                    c['proposal_errors'] == study['errors'][str(c['proposal_tolerance'])+'-on'], 'paired error source binding')
            require(all(c['proposal_errors'][ref][k] <= c['default_errors'][ref][k] for ref in ['off', 'on']
                        for k in ['head', 'theta', 'concentration']), 'state error dominance')
        for r in matched['runs']:
            require(r['exit'] == 0, 'matched native failure')
            case, policy, _ = r['directory'].rsplit('-', 2)
            choice = next(c for c in matched['cases'] if c['case'] == case)
            tol = choice['proposal_tolerance'] if policy == 'on' else 1e-6
            expected = group+'/'+case+'/'+str(tol)+'-'+policy+'-0/'
            for f in PHYSICAL+['trajectory.csv']:
                require(files[prefix+'/'+r['directory']+'/'+f] == files[expected+f], 'matched physical replay')
    probe = load('probe-inflow/PROBE.json')
    require(probe['status'] == 'EXCLUDED_REGIME_PROBE_NOT_QUALIFIED', 'excluded probe relabelled')
    inflow = controls['temporal-day64-inflow-O2']
    require(probe['executable_sha256'] == inflow['generated']['executable_sha256'] and
            probe['input_sha256'] == sha(files['temporal-day64-inflow-O2/dry_infiltration32/1e-06-on.nml']), 'probe binding')
    if probe['exit'] == 0:
        require(float(rows('probe-inflow/endpoint.csv')[0]['time_day']) == 1.0, 'probe endpoint')
    elif probe['exit'] == 1:
        failed = 'temporal-day64-inflow-O2/dry_infiltration32/1e-06-off-0/'
        require(files['probe-inflow/stdout'] == files[failed+'stdout'] and
                files['probe-inflow/budget.csv'] == files[failed+'budget.csv'], 'excluded shared failure/partial budgets')
    return dict(native_column_observations=sum(len(r['runs']) for r in controls.values()),
                retained_column_failures=2, excluded_dry_infiltration_probe_exit=probe['exit'],
                default_off_exact=True, physical_restart_exact=True,
                optimization_physical_work_exact=True, fresh_thermal_preserved=True,
                fresh_runtime_preservation_observations=8, paired_state_error_cost_cases=3,
                predecessor_qualified=True, predecessor_owner=predecessor['owner'])


def verify_qualification():
    pond_status=ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
    if pond_status.exists() and 'evidence' in json.loads(pond_status.read_text()).get('nonlinear_pond_successor', {}):
        return runpy.run_path(str(ROOT/'integration/audits/verify_nonlinear_pond.py'),run_name='registered_nonlinear_pond')['verify_qualification']()
    source()
    result = validate(capsule())
    old = result.pop('predecessor_owner')
    return {**old, **result, 'qualified': True, 'full_capability': False,
            'status': 'PERF01_OPTIONAL_POLICY_BOUNDED_QUALIFIED_DEFAULT_OFF',
            'predecessor_status': old['status'], 'predecessor_source_tree': old['source_tree'],
            'incumbent_production_unchanged': False, 'current_grid_providers_unchanged': False,
            'concurrent_solver_diagnostic_178_current_providers': False,
            'prior_diagnostic_physical_observations_exact': 20,
            'production_delta': 'Optional canonical endpoint/fallback and column input; composed physical equations unchanged',
            'independent_ci_compile_logs': 0,
            'predecessor_independent_ci_compile_logs': old.get('independent_ci_compile_logs', 0),
            'inherited_native_counts_are_predecessor_only': True,
            'production_policy': 'OPT_IN_REFERENCE_EXTERNAL_FULL_HALF_BOUNDED_ONE_DAY',
            'current_source_tree': git('rev-parse', 'HEAD:src'), 'source_tree': git('rev-parse', 'HEAD:src'),
            'mastercoverage_promotion': False, 'full_migration_qualified': False,
            'full_fci': 'OWNER_SELECTED_TARGETED_RUNTIME_PRESERVATION',
            'preservation': 'FROZEN_PREDECESSOR_PLUS_FRESH_CHANGED_RUNTIME_DEFAULT_OFF_AND_OPTIONAL_EVIDENCE'}


def self_test():
    pond_status=ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
    if pond_status.exists() and 'evidence' in json.loads(pond_status.read_text()).get('nonlinear_pond_successor', {}):
        return runpy.run_path(str(ROOT/'integration/audits/verify_nonlinear_pond.py'),run_name='registered_nonlinear_pond')['self_test']()
    source()
    files = capsule()
    validate(files)
    passed = []
    def reject(name, action):
        try:
            action()
        except (ValueError, KeyError):
            passed.append(name)
        else:
            raise ValueError('accepted corruption '+name)
    for p in PINS:
        reject('changed '+p, lambda p=p: source(lambda q: (ROOT/q).read_bytes()+(b'!' if q == p else b'')))
    reject('foreign production', lambda: source(changed={**{p: v[0] for p, v in PINS.items()},
                                                        'src/runtime/foreign.f90': 'A'}))
    for p in ['temporal-day64-O2/pond4/1e-06-on-0/state.csv',
              'temporal-short-O0/dry32/on-restart/restart.bin',
              'composition/thermal/0.5/qualification/O2/128/fresh.bin',
              'composition/PREDECESSOR.json', 'matched/MATCHED.json']:
        broken = dict(files)
        broken.pop(p)
        reject('missing '+p, lambda broken=broken: validate(broken))
    reject('changed runtime execution input', lambda: validate(files, lambda p: (ROOT/p).read_bytes()+
           (b'!' if p == 'src/runtime/mod_canonical_interval_runtime.f90' else b'')))
    broken = dict(files)
    p = 'temporal-day64-inflow-O2/CONTROL.json'
    r = json.loads(broken[p])
    r['status'] = 'PHYSICAL_ERROR_COST_RESTART_PASS_NOT_ADMITTED'
    broken[p] = json.dumps(r).encode()
    reject('native failure relabelled', lambda: validate(broken))
    return {'count': len(passed), 'negative_controls': passed}


if __name__ == '__main__':
    print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(), indent=2))
