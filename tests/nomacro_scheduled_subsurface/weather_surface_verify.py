"""Bounded H weather source/raw owner; prior scientific bodies remain literal."""
from pathlib import Path
from functools import lru_cache
import importlib.util
import io
import json
import math
import re
import struct
import subprocess
import tarfile
import zipfile

import weather_surface_forensics as f
import groundwater_water_verify as gw
import groundwater_water_composition_verify as composition
from perstep_domain_verify import build_files

ROOT = Path(__file__).resolve().parents[2]
PROOF = 'integration/f-ci/nomacro-complete01/'
BASE = '1fc0b19e23a32385e159ec653a42f2e60c009891'
RUNTIME = '2cf36f12d0608f681d69716c01644a2307401c76'
SEALED = 'cd0b6140f8568fac9b1b1220a5d521e3d4e8d1c5'
FORENSICS = '5148797bc7b2f496b359182105ef21de67ebfabd'
ENTRY = 'tests/nomacro_scheduled_subsurface/age_groundwater_verify.py'
TYPED = 'tests/saltfarm_newton/typed_admission07.py'
COMPOSED = 'tests/nomacro_scheduled_subsurface/groundwater_water_composition_verify.py'
SELF = 'tests/nomacro_scheduled_subsurface/weather_surface_verify.py'
FORENSIC_PATH = 'tests/nomacro_scheduled_subsurface/weather_surface_forensics.py'
WEATHER_CHECKOUT = '            /integration/f-ci/nomacro-complete01/WEATHER_*\n'
HOOK = """    import importlib.util
    spec=importlib.util.spec_from_file_location('weather_terminal_admission',ROOT/'tests/nomacro_scheduled_subsurface/weather_surface_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
GUARD_HOOK = """    import importlib.util
    spec=importlib.util.spec_from_file_location('weather_terminal_preservation',ROOT/'tests/nomacro_scheduled_subsurface/weather_surface_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.preservation()
"""
STRIP_HOOK = ' from weather_surface_verify import strip_current_evidence\n text=strip_current_evidence(text)\n'
require, digest = f.require, f.digest


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


@lru_cache(maxsize=None)
def blob(ref, path):
    return git('show', ref+':'+path)


@lru_cache(maxsize=None)
def tree(ref, path):
    return {line.split('\t', 1)[1]:line.split('\t', 1)[0] for line in git('ls-tree', '-r', ref, '--', path).decode().splitlines()}


def normalized(raw):
    return raw.replace(b'\r\n', b'\n')


def strip_current_evidence(text):
    if WEATHER_CHECKOUT in text:
        require(text.count(WEATHER_CHECKOUT) == 1, 'Ambiguous weather scientific checkout')
        text = text.replace(WEATHER_CHECKOUT, '', 1)
    return text


def validate(q):
    expected = dict(status='NEUTRAL_WEATHER_SOURCE_RAW_QUALIFICATION_RECORD_ADMISSION_PENDING',
                    work_unit='SWAP5-NOMACRO-COMPLETE01', predecessor=BASE, runtime=RUNTIME,
                    forensics_ref=FORENSICS, daily_water_guard_cm=1e-10, daily_cde_guard_mg_cm2=1e-10,
                    integrated_cde_guard_mg_cm2=1e-10, integrated_water_1e10_claim=False,
                    whole_scientific_equivalence='NOT_QUALIFIED', functional_completion='PARTIAL', RC3_changed=False,
                    global_family_and_remaining_gap_counts='UNKNOWN', actual_full_periods=12,
                    actual_days_per_full_period=1096, actual_primary_complete_native_cold_windows=60,
                    actual_public_native_refusals=88, actual_compiled_native_refusals=80,
                    actual_public_cli_contexts=4, actual_transaction_contexts=4,
                    actual_current_named_two_day_contexts=4, actual_windows_hourly_five_day_composition_contexts=2,
                    actual_windows_pulsed_five_day_preservation_contexts=2, fresh_unaffected_full_periods=0)
    require(all(q.get(k) == v and type(q.get(k)) is type(v) for k, v in expected.items()), 'Weather scope/source/guards/counts changed')
    require(set(q['locations']) == {p+'-'+o+'-'+c for p in ('Windows', 'Ubuntu') for o in ('O0', 'O2') for c in ('pulsed', 'hourly', 'uniform')}, 'Weather primary denominator changed')
    require(len(q['archives']) == len(q['source_capsules']) == 7 and q['archive_bytes'] == sum(r['bytes'] for r in q['archives'].values()), 'Weather source/raw denominator changed')
    for key, run, carrier, parent, ids in [
        ('portable_main', 44536610211, 'eb8492ed818ca6779c64239f904df4de6bad6af6', 'e4161c6a76b4601d68e25313e3f37c2544357121', [14537165591,14536222151]),
        ('portable_uniform', 44538768368, '05d9a40eb8c3ca4db064cfc7c452c42399eedcec', '758378f2f318bfe70603fde949f377d87102534a', [14535814629,14537029396])]:
        require(q[key] == dict(run=run, carrier=carrier, parent=parent, conclusion='success', artifact_ids=ids), 'Weather portable producer rebound')


def source(q):
    validate(q)
    require(not git('status', '--porcelain', '--', 'app', 'src', 'reference', 'tools', 'tests', '.github', 'integration'), 'Dirty weather admission surface')
    for ref in (BASE, RUNTIME, SEALED, FORENSICS):git('merge-base', '--is-ancestor', ref, 'HEAD')
    require(not git('diff', RUNTIME, 'HEAD', '--', 'app', 'src', 'reference', 'tools'), 'Unqualified weather production source change')
    require(set(git('diff', '--name-only', BASE, RUNTIME, '--', 'app', 'src', 'reference', 'tools').decode().splitlines()) == {
        'app/hybrid_water/daily_host.py', 'app/hybrid_water/daily_coupling.py', 'app/hybrid_water/experimental_project.py',
        'app/hybrid_water/weather_terminal_receipt.py', 'app/hybrid_water/weather_root_state.py'}, 'Weather production scope broadened')
    require(q == json.loads(blob(SEALED, PROOF+'WEATHER_TERMINAL_QUALIFICATION.json')), 'Neutral weather raw authority rewritten')
    require(normalized((ROOT/FORENSIC_PATH).read_bytes()) == blob(FORENSICS, FORENSIC_PATH), 'Independent weather forensic reader changed')
    entry = (ROOT/ENTRY).read_text(encoding='utf8')
    require(entry.count(HOOK) == 1 and entry.replace(HOOK, '', 1).encode() == blob(BASE, ENTRY), 'Literal preceding registered owner changed')
    typed = (ROOT/TYPED).read_text(encoding='utf8')
    require(typed.count(GUARD_HOOK) == 3 and typed.replace(GUARD_HOOK, '').encode() == blob(BASE, TYPED), 'Literal canonical typed owner changed')
    for name in ('projection', 'source_guard', 'operational_guards'):
        require('def '+name+'():\n'+GUARD_HOOK in typed, 'Weather current-source delegation moved')
    old = (ROOT/COMPOSED).read_text(encoding='utf8')
    require(old.count(STRIP_HOOK) == 1 and old.replace(STRIP_HOOK, '', 1).encode() == blob(BASE, COMPOSED), 'Literal preceding groundwater body changed')
    for path in ('.github/workflows/mc-sol01-column-input.yml', '.github/workflows/mc-sol01-swp-reader.yml'):
        current = (ROOT/path).read_text(encoding='utf8')
        require(current.count(WEATHER_CHECKOUT) == 1 and strip_current_evidence(current).encode() == blob(BASE, path), 'MC scientific commands or limits changed')
    # Every prior scientific/operational body is retained, except the explicit
    # current-owner delegates above. No ROOT mutation, copied model or fallback.
    exceptions = {ENTRY, TYPED, COMPOSED}
    for path, info in tree(BASE, 'tests').items():
        if path not in exceptions:require(tree('HEAD', 'tests').get(path) == info, 'Historical test/validator rewritten: '+path)
    mutable = {PROOF+'STATUS.json', PROOF+'GAP_MATRIX.json'}
    current = tree('HEAD', 'integration')
    for path, info in tree(BASE, 'integration').items():
        if path not in mutable:require(current.get(path) == info, 'Historical evidence rewritten: '+path)
    for path, info in tree(SEALED, PROOF).items():
        if Path(path).name.startswith('WEATHER_'):require(current.get(path) == info, 'Sealed weather evidence rewritten: '+path)
    for path in mutable:
        meta = json.loads((ROOT/path).read_text(encoding='utf8'))
        require(meta['functional_completeness'] == 'PARTIAL' and meta['scientific_equivalence'] == 'NOT_QUALIFIED'
                and meta['release_readiness'] == 'RC3_QUALIFIED_FIXED_NAMED_PROFILES_ONLY', 'Historical closure or fixed RC3 scope inflated')
    for name in ('portable_main', 'portable_uniform'):
        record = q[name]
        require(git('rev-list', '--parents', '-n', '1', record['carrier']).decode().split()[1:] == [record['parent']]
                and git('diff', '--name-only', record['parent'], record['carrier']).decode().splitlines() == ['.github/workflows/nomacro-coverage-prescribed-head.yml'], 'Qualification carrier crossed production authority')
    return True


def preservation():
    source(json.loads((ROOT/PROOF/'WEATHER_TERMINAL_QUALIFICATION.json').read_text(encoding='utf8')))
    return 'LITERAL_NONSELECTED_HOST_COUPLER_CLI_AND_OLD_SCIENTIFIC_CHECKS_PRESERVED'


def archives(q):
    result = {}
    for name, record in q['archives'].items():
        path = ROOT/PROOF/record['archive'];raw = path.read_bytes()
        require(len(raw) == record['bytes'] and digest(raw) == record['sha256'], 'Actual weather raw archive changed')
        meta_raw = (ROOT/PROOF/record['record']).read_bytes()
        require(digest(normalized(meta_raw)) == record['record_lf_sha256'], 'Actual weather raw inventory changed')
        meta = json.loads(meta_raw);require(len(meta['members']) == record['members'], 'Weather raw member denominator changed')
        z = zipfile.ZipFile(io.BytesIO(raw))
        require(len(z.namelist()) == len(set(z.namelist())) == len(meta['members']) and set(z.namelist()) == set(meta['members']), 'Weather raw inventory incomplete/duplicated')
        for member, value in meta['members'].items():
            data = z.read(member);require(len(data) == value['bytes'] and digest(data) == value['sha256'], 'Weather actual raw member changed: '+member)
        if 'origin_artifact' in record:
            a = record['origin_artifact']
            require(a == meta['artifact'] and a['digest'] == 'sha256:'+digest(raw) and a['size_in_bytes'] == len(raw)
                    and record['actual_artifact_bytes_preserved'] is True and meta['repacked'] is False, 'Original weather CI artifact repacked/rebound')
        result[name] = z
    return result


def capsules(q, data):
    result = {}
    for name, loc in q['source_capsules'].items():
        record = gw.capsule(data[loc['archive']], loc['prefix'])
        require(record['producer_head'] == loc['head'], 'Actual weather source snapshot rebound')
        result[name] = record
    return result


def build(z, prefix, record, cap, source_ref, opt):
    b = json.loads(z.read(prefix+'BUILD.json'));build_files(z, prefix, b)
    require(b['project']['water_tolerance'] == 1e-10 and b['binding']['budget_retry'] is True
            and b['binding']['shared_pond_transfer'] is b['binding']['refresh_macro_final'] is False, 'Weather physical/transactional scope changed')
    for flags in ('donor_flags', 'kernel_flags'):
        require({'-'+opt, '-ffp-contract=off', '-march=x86-64', '-mtune=generic'} <= set(b['identity'][flags]), 'Weather actual arithmetic changed')
    for key, path in [('host','app/hybrid_water/daily_host.py'), ('adapter','app/hybrid_water/donor_adapter.f90'),
                      ('driver','app/hybrid_water/main.f90'), ('experimental_input_adapter','app/hybrid_water/experimental_project.py'),
                      ('budget_source','app/hybrid_water/hybrid_step_budget.f90')]:
        require(b['identity'][key] == cap['members'][path]['sha256'], 'Actual weather producer source differs from compiler binding: '+path)
        require(cap['members'][path]['git_blob'] == tree(source_ref, path)[path].split()[2], 'Weather earlier/later source lookup differs: '+path)
    for path, value in b['identity']['kernel_sources']:
        require(cap['members'][path]['sha256'] == value, 'Actual weather kernel compiler input differs')
    terminal = b['identity']['weather_terminal_receipt']
    require(terminal['source_sha256'] == cap['members']['app/hybrid_water/weather_terminal_receipt.py']['sha256']
            and terminal['water_guard_cm'] == 1e-10 and terminal['physical_equations_changed'] is False, 'Actual weather terminal provider/policy changed')
    for field, path in [('template_sha256','terminal_water_receipt.f90'),('retry_template_sha256','implicit_conductivity_retry.py')]:
        require(terminal[field] == cap['members']['app/hybrid_water/'+path]['sha256']
                and blob(source_ref,'app/hybrid_water/'+path) == blob(BASE,'app/hybrid_water/'+path), 'Literal inherited terminal/retry provider changed')
    if record['hourly_root_carry']:
        native = b['identity']['weather_root_state']
        require(native['codec'] == 'S5WRH001' and native['bytes'] == 108
                and native['source_sha256'] == cap['members']['app/hybrid_water/weather_root_state.py']['sha256'], 'Actual hourly root native producer changed')
    else:require('weather_root_state' not in b['identity'], 'Hourly root carry selected in rainfall-only case')
    return b


def primary(q, data, caps):
    results = {};cold_count = 0
    for name, loc in q['locations'].items():
        z = data[loc['archive']];prefix = loc['prefix'];report = json.loads(z.read(prefix+'RESULT.json'))
        require(report['source_commit'] == loc['producer'] and report['case'] == loc['case']
                and report['optimization'] == loc['optimization'] and report['requested_days'] == 1096, 'Actual weather primary producer/configuration changed')
        cap = caps[loc['source_capsule']]
        b = build(z, loc['build_prefix'], loc, cap, loc['producer'], loc['optimization'])
        require(json.loads(z.read(prefix+'trajectory/BUILD.json')) == b and b['project']['nodes'] == 34
                and b['project']['start_date'] == '2002-01-01' and b['project']['model'] == 'HYBRID_NOMACRO_WATER', 'Actual H primary geometry or build differs')
        for file, value in b['inputs'].items():require(digest(z.read(prefix+'input/'+file)) == value, 'Actual original weather input changed')
        require(b['inputs'] == report['input_provenance']['exact_original_input_sha256'], 'Actual weather input provenance changed')
        metrics, rows = f.trajectory(z, prefix+'trajectory/', b, 1096, loc['hourly_root_carry'])
        windows = report['cold'];require([(w['start'], w['end']) for w in windows] == [(2,4),(363,364),(364,367),(530,532),(1094,1096)], 'Actual weather cold coverage changed')
        for w in windows:f.cold(z, prefix+'trajectory/', prefix+f"cold-{w['start']}/", b, rows, w['start'], w['end'], loc['hourly_root_carry']);cold_count += 1
        require(report['status'] == 'ACTUAL_EXACT_H_INPUT_CURRENT_WARM_COLD_PASS'
                and all(w[k] is True for w in windows for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')), 'Actual full/native weather execution failed')
        results[name] = dict(metrics=metrics, build=b, rows=rows)
    require(cold_count == 60 and len(results) == 12, 'Actual weather full/native denominator changed')
    return results


def package(raw):
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        require(len(z.namelist()) == 3 and set(z.namelist()) == {'result.end','macro.bin','checkpoint.json'}, 'Actual weather package inventory changed')
        meta = json.loads(z.read('checkpoint.json'));files = {n:z.read(n) for n in ('result.end','macro.bin')}
        require(meta['files'] == {n:digest(v) for n,v in files.items()}, 'Actual weather package content hashes differ')
        return meta, files


def original_inputs(q, data, results, caps):
    path = ROOT/q['historical_h_input_archive']
    require(digest(path.read_bytes()) == q['historical_h_input_sha256'] == '6e39750da47c069dc35983dbe8f8b1d8f47253a3b4ddd00575d279e75b783b29', 'Original H input authority changed')
    with tarfile.open(path) as original:
        members = original.getmembers();expected = {}
        for case, directory, label in [('pulsed','rain-detailed','PULSED_RAIN'),('hourly','weather-hourly','HOURLY'),('uniform','rain-detailed-uniform',None)]:
            if label:
                old = json.loads(blob(BASE,'integration/nomacro-coverage01/BLOCK_H_'+label+'364_FAILURE.json'))
                expected[case] = old['input_sha256']
                require(old['committed_days'] == 363 and old['first_refusal']['day'] == 364 and old['first_refusal']['committed'] is False, 'Original H failure censored')
            else:
                builds = [m for m in members if m.name.endswith('/rain-detailed-uniform-O0-build/BUILD.json')]
                require(len(builds) == 1,'Ambiguous original uniform input authority')
                expected[case] = json.loads(original.extractfile(builds[0]).read())['inputs']
            for file, value in expected[case].items():
                require(Path(file).name == file,'Unsafe original H input member')
                found = [m for m in members if m.name.endswith('/input-'+directory+'/'+file)]
                require(len(found) <= 1,'Ambiguous original H input')
                raw = original.extractfile(found[0]).read() if found else blob(BASE,'reference/swap-4.3.1/projects/1.hupselbrook/'+file)
                require(digest(raw) == value,'Original H input bytes differ from historical authority')
        for name, loc in q['locations'].items():
            require(results[name]['build']['inputs'] == expected[loc['case']], 'Current weather case substituted for original H physical inputs')
    controller = 'tests/nomacro_scheduled_subsurface/weather_surface_runtime.py'
    override = data['WEATHER_TERMINAL_WINDOWS_O0_RAW_ARCHIVE'].read('uniform-controller/weather_surface_runtime.py')
    require(normalized(override) == blob('758378f2f318bfe70603fde949f377d87102534a',controller), 'Actual uniform controller override differs from producer Git')
    for loc in q['locations'].values():
        cap = caps[loc['source_capsule']]
        if loc['uniform_windows_controller_override']:
            require(loc['platform'] == 'Windows' and loc['case'] == 'uniform','Unexpected weather controller override')
            require(not git('diff',cap['producer_head'],loc['producer'],'--','app','src','reference','tools'), 'Uniform compiler source differs from actual captured provider')
        else:
            require(cap['members'][controller]['git_blob'] == tree(loc['producer'],controller)[controller].split()[2], 'Actual weather controller not bound to producer')
    return True


def retained(q, data, results):
    z = data[q['retained_failures']]
    # Read the actual failed trajectories, rather than promoting their warm
    # prefixes or trusting a later summary of the reproduced defects.
    for case in ('pulsed','hourly'):
        for attempt in ('weather-current-'+case+'-O0-v2/','weather-terminal-'+case+'-O0-v1/'):
            r = json.loads(z.read(attempt+'RESULT.json'));rows = f.rows(z,attempt+'trajectory/')
            require(r['status'] == 'FAILED' and r['error'] == "ValueError('Rejected day 364')"
                    and len(rows) == 364 and all(x['committed'] for x in rows[:363])
                    and rows[-1]['day'] == 364 and rows[-1]['committed'] is False, 'Original day364 failure erased or promoted')
            require(json.loads(z.read(attempt+'trajectory/BUILD.json'))['inputs'] == results['Windows-O0-'+case]['build']['inputs'], 'Actual failure uses different physical input')
            f.ledger(rows[:363]);row=rows[-1]
            terms=[*row['external_flux_cm'][:7], *(-v for v in row['external_flux_cm'][7:]), *row['stock_start_cm'], *(-v for v in row['stock_end_cm'])]
            require(math.fsum(terms) == row['independent_residual_cm'] and abs(math.fsum(terms)) > 1e-10
                    and abs(row['integrated_guard_residual_cm']) <= 1e-10, 'Actual daily-versus-soil failure no longer demonstrated')
            if attempt.startswith('weather-terminal-'):
                diagnostics=[list(map(float,line.split()[1:])) for line in z.read(attempt+'trajectory/original/donor.stdout').decode().splitlines() if line.startswith('WEATHER_TERMINAL_WATER ')]
                # The first terminal-only source predates this diagnostic;
                # the next retained diagnostic producer supplies it below.
                if diagnostics:require(diagnostics[-1][1:] == terms and diagnostics[-1][0] == math.fsum(terms), 'Actual original terminal projection differs')
            else:
                require(not git('diff','ef5010a83e83f879254af534bf0dd9cfcdbf3a85',r['source_commit'],'--','app','src','reference','tools'), 'Actual baseline reproduction changed production source')
        if case=='pulsed':
            prefix='weather-terminal-pulsed-O0-v2/trajectory/'
            row=f.rows(z,prefix)[-1]
            terms=[*row['external_flux_cm'][:7], *(-v for v in row['external_flux_cm'][7:]), *row['stock_start_cm'], *(-v for v in row['stock_end_cm'])]
            witness=[list(map(float,s.split()[1:])) for s in z.read(prefix+'original/donor.stdout').decode().splitlines() if s.startswith('WEATHER_TERMINAL_WATER ')][-1]
            require(witness[1:]==terms and witness[0]==math.fsum(terms),'Actual original28-term diagnostic projection differs from refused day')
        prefix='weather-terminal-'+case+'-O0-v3/'
        r=json.loads(z.read(prefix+'RESULT.json'));rows=f.rows(z,prefix+'trajectory/')
        require(r['status']=='FAILED' and len(rows)==363 and all(v['committed'] for v in rows), 'Strict terminal-only floor failure promoted')
        stderr=z.read(prefix+'trajectory/original/donor.stderr').decode()
        require('ERROR STOP Detailed-weather original retry reached clock resolution' in stderr, 'Original strict numerical floor refusal missing')
    # Read-only root-extension witness: same day531 inputs/rates, but four
    # zero-demand hours lose exactly one sixth of each integrated stress.
    prefix='weather-root-native-hourly-O0-v5/'
    def root(p):
        return [list(map(float,s.split()[1:])) for s in z.read(p+'original/donor.stdout').decode().splitlines() if s.startswith('WEATHER_ROOT_EXTENSION ')]
    warm=root(prefix+'trajectory/');cold=root(prefix+'cold-530/')
    b=cold[0];matches=[row for row in warm if row[0]==b[0]]
    require(len(matches)==1,'Ambiguous original root-extension date');a=matches[0]
    memory=results['Windows-O0-hourly']['rows'][529]['weather_root_memory']
    require(a[:7] == b[:7] and a[9:] == b[9:] and all(abs(a[7+i]-b[7+i]-memory[i]/6) <= 2e-15 for i in range(2)), 'Actual hourly root-carry defect no longer independently demonstrated')
    before=f.rows(z,'weather-terminal-hourly-O0-full-v4/trajectory/')
    new=f.rows(z,'weather-root-native-hourly-O0-v7/trajectory/')
    require(len(before)==1096 and len(new)==532
            and [{k:v for k,v in row.items() if k!='weather_root_memory'} for row in new] == before[:532], 'Root state carry changed previous warm physics')
    require([{k:v for k,v in row.items() if k!='weather_root_memory'} for row in results['Windows-O0-hourly']['rows']] == before, 'Final debug-free complete warm physics differs')
    return dict(retained_day364_refusals=4,retained_terminal_only_floor_refusals=2,actual_missing_hourly_root_stress='1/6 of each original previous-day factor',previous_complete_warm_physics_preserved=True)


def controls(q, data, results, caps):
    public_count = native_count = cli_count = tx_count = 0
    expected = {'domain-'+str(i) for i in range(8)} | {'domain-copy','trailer','clock','old-codec','truncated','trailing'}
    expected |= {k+'-'+str(i) for k in ('nan','negative','above-one','receipt') for i in range(2)}
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            name = platform+'-'+opt+'-hourly';loc=q['locations'][name];z=data[loc['archive']]
            b=results[name]['build'];warm=results[name]['rows'];r=json.loads(z.read('controls/RESULT.json'))
            require(r['source_commit']==loc['producer'] and r['status']=='ACTUAL_WEATHER_ROOT_NATIVE_PUBLIC_TRANSACTION_CONTROLS_PASS'
                    and r['origin_unchanged'] is True, 'Actual weather control producer failed/rebound')
            require(set(v['label'] for v in r['public_refusals'])==expected and len(r['public_refusals'])==22, 'Weather public refusal denominator changed')
            require(set(v['label'] for v in r['native_refusals'])==expected-{'receipt-0','receipt-1'} and len(r['native_refusals'])==20, 'Weather compiled refusal denominator changed')
            original=z.read('hourly/trajectory/accepted-column-1-day-531.zip');mf,files=package(original)
            require(mf['receipt']==warm[530], 'Actual weather control original receipt differs')
            positive=r['positive_native'];stdout=z.read('controls/native-positive/column/actual.stdout').decode('utf8')
            require(positive['returncode']==100 and 'HYBRID_READY' in stdout and 'HYBRID_DAY_RETURN' not in stdout, 'Actual compiled positive native control missing')
            for item in r['public_refusals']:
                label=item['label'];prefix='controls/'+label+'/'
                forged,parts=package(z.read(prefix+'deliberately-forged.zip'))
                require(forged['binding']==mf['binding'] and forged['receipt']==mf['receipt'] and parts['result.end']==files['result.end']
                        and parts['macro.bin']!=files['macro.bin'], 'Weather negative control not actual original-bound forged native')
                try:f.root_native(parts['macro.bin'],forged['receipt'],b['project']['nodes'],b['project']['start_date'])
                except ValueError:pass
                else:raise ValueError('Independent reader accepted actual public native forgery: '+label)
                require(item['before_physical_worker'] is item['no_publication'] is True and 'root stress' in item['error'].lower()
                        and not any(n.startswith(prefix+'public/') and (n.endswith('donor.stdout') or '/accepted-' in n) for n in z.namelist()), 'Weather forgery reached physical worker/publication')
                public_count+=1
            for item in r['native_refusals']:
                prefix='controls/'+item['label']+'/';diagnostic=z.read(prefix+'native/column/actual.stderr').decode('utf8')
                stdout=z.read(prefix+'native/column/actual.stdout').decode('utf8')
                forged,_parts=package(z.read(prefix+'deliberately-forged.zip'))
                require(item['returncode']!=100 and item['no_day_return'] is True and 'HYBRID_DAY_RETURN' not in stdout
                        and 'ERROR STOP' in diagnostic and any(v in diagnostic.lower() for v in ('root stress','nonmacro checkpoint')),
                        'Actual compiled native loader did not refuse forged context')
                require(z.read(prefix+'native/column/macro-origin.bin')==_parts['macro.bin'], 'Compiled native refusal used another payload')
                native_count+=1
            # Actual public CLI continues the active day531 origin to532.
            require(r['public_cli']['returncode']==0 and r['public_cli']['exact_physical'] is r['public_cli']['exact_complete_native'] is True, 'Actual weather public CLI failed')
            _metrics,cold=f.trajectory(z,'controls/public-cli/',b,1,True)
            require(f.physical(cold)==f.physical(warm[531:532]), 'Actual public weather continuation differs')
            a=z.read('controls/public-cli/accepted-column-1-day-532.zip');f.checkpoint(a,b,cold[-1],True)
            _ma,pa=package(a);_mb,pb=package(z.read('hourly/trajectory/accepted-column-1-day-532.zip'))
            require(pa==pb, 'Actual public weather complete native differs');cli_count+=1
            # Actual discard/replay/accept/recovery, independently reading the
            # private native frames and the published external binding.
            require(r['transactions']==dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True), 'Actual weather transaction assertions incomplete')
            trials=[]
            for prefix,day in [('controls/transactions/external/trial-1/',5),('controls/transactions/external/trial-2/',5),('controls/transactions/recovered/trial-1/',6)]:
                raw=z.read(prefix+f'accepted-column-1-day-{day}.zip');meta,parts=package(raw);row=meta['receipt']
                require(f.physical([row])==f.physical([warm[day-1]]), 'Actual weather transactional day differs')
                f.ledger([row]);f.original_observations(z.read(prefix+'original/donor.stdout'),[row],b['project']['start_date'])
                f.root_observations(z.read(prefix+'original/donor.stdout'),[row],b['project']['start_date']);f.checkpoint(raw,b,row,True)
                trials.append((meta,parts))
            require(trials[0]==trials[1], 'Actual discarded weather proposal did not replay exactly')
            published,parts=package(z.read('controls/transactions/external/accepted-column-1-day-5.zip'))
            cap=caps[loc['source_capsule']]
            external={'version':1,'source_sha256':cap['members']['app/hybrid_water/daily_coupling.py']['sha256'],'coupling_id':'original-output','forcing':'original-project'}
            require(published['binding']=={**b['binding'],'external_daily':external} and parts==trials[1][1], 'Published weather coupling/native context differs')
            base=(__import__('datetime').date.fromisoformat(b['project']['start_date'])-__import__('datetime').date(1900,1,1)).days+1
            coupling=dict(id='original-output',revision=1,origin_revision=0,origin_sha256=digest(z.read('hourly/trajectory/accepted-column-1-day-4.zip')),origin_day=4,window_day1900=[base+4,base+5],forcing='original-project')
            require(published['receipt']=={**trials[1][0]['receipt'],'coupling':coupling}
                    and 'controls/transactions/recovered/accepted-column-1-day-6.zip' not in z.namelist(), 'Weather external ownership or discard publication changed')
            tx_count+=1
    require((public_count,native_count,cli_count,tx_count)==(88,80,4,4), 'Actual weather public/native/transaction denominator changed')
    return dict(actual_public_native_refusals=public_count,actual_compiled_native_refusals=native_count,actual_public_cli_contexts=cli_count,actual_transaction_contexts=tx_count)


def projections(q,data,caps,results):
    z=data['WEATHER_TERMINAL_WINDOWS_O0_RAW_ARCHIVE'];record=json.loads(z.read(q['source_preservation']))
    require(record['status']=='LITERAL_PRIOR_SOURCE_PRESERVED_WITH_ONLY_SELECTED_WEATHER_INSERTIONS'
            and record['baseline']==BASE and record['runtime']==RUNTIME, 'Weather literal source projection rebound')
    for path,part in record['files'].items():
        old=blob(BASE,path).decode();new=blob(RUNTIME,path).decode();lines=new.splitlines(keepends=True)
        require(digest(old.encode())==part['baseline_lf_sha256'] and digest(new.encode())==part['runtime_lf_sha256'], 'Weather source insertion proof changed')
        for item in reversed(part['insertions']):
            at=item['new_line'];require(lines[at:at+len(item['lines'])]==item['lines'], 'Weather source inserted body changed')
            del lines[at:at+len(item['lines'])]
        require(''.join(lines)==old and part['original_lines_preserved'] is True, 'Original canonical physical/transaction body changed')
    transport=record['windows_transport_composition'];new=blob(RUNTIME,'app/hybrid_water/daily_host.py').decode()
    require(new.count(transport['typed_reply_helper'])==1, 'Canonical typed transport helper changed')
    folded=new.replace(transport['typed_reply_helper'],'',1).replace('        send_reply(self.host, reply)','        send(self.host, " ".join(map(str, reply)))')
    require(folded.encode()==blob('30cfaf4f5f9f693bc26d96b81ceeda0e1fb3884a','app/hybrid_water/daily_host.py')
            and blob(RUNTIME,'app/hybrid_water/direct_day_kernel.py')==blob(BASE,'app/hybrid_water/direct_day_kernel.py'), 'Explicit/nonselected canonical transport projection changed')
    authority=json.loads(z.read(q['acceptance_authority']))
    require(authority['historical_source']=='bc1adba5cfc123f69eb98010026e15ca9bee70ac'
            and authority['historical_assertion'] in blob(authority['historical_source'],authority['historical_path']).decode()
            and authority['daily_water_guard_cm']==authority['additional_integrated_cde_guard_mg_cm2']==1e-10, 'Owning historical weather acceptance changed')
    incoming=json.loads(z.read(q['incoming_actual_owner']))
    require(incoming['head']==BASE and incoming['returncode']==0 and json.loads(incoming['stdout'])['status']=='BOUNDED_SALTFARM_TYPED_REPLY_SOURCE_RAW_ADMISSION_PASS', 'Actual incoming canonical current owner missing')
    count=0
    for opt in ('O0','O2'):
        zz=data['WEATHER_TERMINAL_WINDOWS_'+opt+'_RAW_ARCHIVE']
        for case,prefix,bp,capname,producer in [
            ('pulsed','pulsed-preservation/','pulsed-preservation-build/','windows-primary','30cfaf4f5f9f693bc26d96b81ceeda0e1fb3884a'),
            ('hourly','composed-hourly/','composed-hourly-build/','windows-composed','e4161c6a76b4601d68e25313e3f37c2544357121')]:
            loc=q['locations']['Windows-'+opt+'-'+case];old=results['Windows-'+opt+'-'+case];report=json.loads(zz.read(prefix+'RESULT.json'))
            require(report['source_commit']==producer and report['status']=='ACTUAL_EXACT_H_INPUT_CURRENT_WARM_COLD_PASS', 'Actual current weather projection failed')
            b=build(zz,bp,loc,caps[capname],producer,opt);_,rows=f.trajectory(zz,prefix+'trajectory/',b,5,case=='hourly')
            require(rows==old['rows'][:5] and b['inputs']==old['build']['inputs']
                    and b['identity']['donor_generated']==old['build']['identity']['donor_generated']
                    and b['identity']['kernel_sources']==old['build']['identity']['kernel_sources'], 'Current actual weather provider/input/physical projection differs')
            f.cold(zz,prefix+'trajectory/',prefix+'cold-2/',b,rows,2,4,case=='hourly')
            _,a=package(zz.read(prefix+'trajectory/accepted-column-1-day-4.zip'))
            _,bodies=package(zz.read(case+'/trajectory/accepted-column-1-day-4.zip'));require(a==bodies, 'Current weather full-producer native differs')
            count+=1
    require(count==4,'Actual current weather projection denominator changed')
    return count


def named(q,data,caps):
    count=0
    oldq=json.loads(blob(BASE,'integration/f-ci/saltfarm-guard-cost05/COMPOSITION_QUALIFICATION.json'))
    for platform in ('Windows','Ubuntu'):
        old=oldq['archives'][platform];raw=(ROOT/'integration/f-ci/saltfarm-guard-cost05'/old['archive']).read_bytes()
        require(digest(raw)==old['sha256'], 'Inherited named physical baseline changed')
        with zipfile.ZipFile(io.BytesIO(raw)) as gold:
            for opt in ('O0','O2'):
                z=data['WEATHER_TERMINAL_'+platform.upper()+'_'+opt+'_RAW_ARCHIVE'];r=json.loads(z.read('named-seam/RESULT.json'))
                producer='e4161c6a76b4601d68e25313e3f37c2544357121' if platform=='Windows' else 'eb8492ed818ca6779c64239f904df4de6bad6af6'
                require(r['source_commit']==producer and r['status']=='ACTUAL_NAMED_SHARED_TRANSPORT_PHYSICAL_COMPLETE_NATIVE_SEAM_PASS'
                        and all(v['returncode']==0 for v in r['calls'].values()), 'Current named transport seam failed/rebound')
                bp='named-build/';b=json.loads(z.read(bp+'BUILD.json'));build_files(z,bp,b)
                oldbuild=json.loads(gold.read('qualified-'+opt+'/BUILD.json'))
                require(b['inputs']==oldbuild['inputs'] and b['identity']['kernel_sources']==oldbuild['identity']['kernel_sources']
                        and b['identity']['direct_day_kernel']['protocol']=='swap5-direct-day-kernel-1', 'Current named input/kernel/transport authority changed')
                for file in b['identity']['donor_generated']:require(z.read(bp+file)==gold.read('qualified-'+opt+'/'+file), 'Current named original Fortran changed')
                _,warm=f.trajectory(z,'named-seam/warm/',b,2,False);_,endpoint=f.trajectory(z,'named-seam/warm-endpoint/',b,2,False)
                _,cold=f.trajectory(z,'named-seam/cold/',b,1,False)
                priorrows=[json.loads(v) for v in gold.read('accept-'+opt+'/full/daily.jsonl').splitlines()]
                require(f.physical(warm)==f.physical(endpoint)==f.physical(priorrows[:2]) and f.physical(cold)==f.physical(warm[1:]), 'Actual named shared transport physical replay differs')
                _,a=package(z.read('named-seam/cold/accepted-column-1-day-2.zip'));_,bodies=package(z.read('named-seam/warm-endpoint/accepted-column-1-day-2.zip'))
                require(a==bodies,'Actual named shared transport complete native replay differs');count+=1
    require(count==4,'Current named seam denominator changed');return count


def inherited():
    # Only literal scientific readers and raw authorities are reused. Their
    # obsolete current-source barriers are not called or rebound to this ROOT.
    path=ROOT/TYPED;spec=importlib.util.spec_from_file_location('literal_typed_weather_predecessor',path)
    typed=importlib.util.module_from_spec(spec);spec.loader.exec_module(typed)
    q=json.loads((ROOT/typed.PROOF/'QUALIFICATION.json').read_bytes());typed.validate(q);typed.raw_verify(q);typed.composed_verify(q,typed.decoder())
    old=json.loads(blob(BASE,PROOF+'GROUNDWATER_WATER_COMPOSITION_QUALIFICATION.json'))
    original=json.loads(blob(BASE,PROOF+'GROUNDWATER_WATER_QUALIFICATION.json'))
    composition.scientific(old,original);result=gw.scientific(original)
    return result


def scientific(q):
    data = archives(q);caps = capsules(q, data)
    try:
        result = primary(q, data, caps);original_inputs(q,data,result,caps)
        failures=retained(q,data,result);control=controls(q,data,result,caps)
        projection_count=projections(q,data,caps,result);named_count=named(q,data,caps)
        return dict(actual_full_periods=len(result), actual_primary_complete_native_cold_windows=60,
                    actual_windows_source_physical_native_projection_contexts=projection_count,
                    actual_current_named_two_day_contexts=named_count,
                    **control,retained_failure_findings=failures,metrics={k:v['metrics'] for k,v in result.items()})
    finally:
        for z in data.values():z.close()


def verify():
    q = json.loads((ROOT/PROOF/'WEATHER_TERMINAL_QUALIFICATION.json').read_text(encoding='utf8'))
    source(q);result = scientific(q);previous=inherited()
    return dict(status='BOUNDED_ORIGINAL_CDE_WEATHER_COMPLETE_ROOT_STATE_SOURCE_RAW_ADMISSION_PASS', runtime=RUNTIME, **result,
                inherited_groundwater=previous, inherited_canonical_typed_transport_raw='PASS_WITHOUT_NEW_PERFORMANCE_OR_MODEL_RUNS',
                functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED', RC3_changed=False)


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
