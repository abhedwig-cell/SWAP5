"""Bounded H weather source/raw owner; prior scientific bodies remain literal."""
from pathlib import Path
from functools import lru_cache
import importlib.util
import io
import json
import re
import struct
import subprocess
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


def scientific(q):
    data = archives(q);caps = capsules(q, data)
    try:
        result = primary(q, data, caps)
        return dict(actual_full_periods=len(result), actual_primary_complete_native_cold_windows=60,
                    metrics={k:v['metrics'] for k,v in result.items()})
    finally:
        for z in data.values():z.close()


def verify():
    q = json.loads((ROOT/PROOF/'WEATHER_TERMINAL_QUALIFICATION.json').read_text(encoding='utf8'))
    source(q);result = scientific(q)
    return dict(status='DRAFT_WEATHER_RAW_GATE_NOT_YET_COMPLETE', runtime=RUNTIME, **result,
                functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED', RC3_changed=False)


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
