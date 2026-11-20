"""Bounded secondary implicit admission with exact unchanged-proof reuse."""
from functools import lru_cache
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT/'tests/nomacro_drainage'), str(ROOT/'tests/nomacro_scheduled_subsurface')]
import implicit_verify as previous
import secondary_pond_evidence as evidence
import secondary_pond_inherited as inherited
from extended_forensics import require

BASE = '21fce9bc6275d998d3936e035c39ed4204efa70b'
RUNTIME = 'aec7c3598e6407827869d3d94fa92a5f2b682512'
READERS = 'd2563d2c9dd086b628673df1a2656d6ca8ca5ee1'
SEALED = 'TO_BE_SEALED'
PROOF = ROOT/'integration/f-ci/nomacro-complete01'
QUAL = 'integration/f-ci/nomacro-complete01/EXTENDED_DRAINAGE_SECONDARY_POND_QUALIFICATION.json'
SURFACES = ('app', 'src', 'tools/solute', 'tools/vq', 'reference/swap-4.3.1')
PARSERS = ('secondary_pond_forensics.py', 'secondary_pond_evidence.py', 'secondary_pond_inherited.py')
OLD = 'tests/nomacro_drainage/implicit_verify.py'
SOURCE_LINE = " qualification();require(not git('diff',RUNTIME,'--',*SURFACES),'Actual implicit compiler source differs from qualified runtime')\n"
SOURCE_HOOK = " qualification()\n import secondary_pond_verify as secondary\n secondary.guard_previous_source()\n"
VERIFY_HOOK = " import secondary_pond_verify as secondary\n return secondary.verify()\n"


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def blob(ref, path):
    return git('show', ref+':'+path)


def norm(raw):
    return raw.replace(b'\r\n', b'\n')


def change(raw, old, new):
    require(raw.count(old) == 1, 'Ambiguous original secondary dependency guard')
    return raw.replace(old, new, 1)


@lru_cache(maxsize=1)
def guard_previous_source():
    require(not git('diff', RUNTIME, '--', *SURFACES),
            'Actual secondary implicit compiler source differs from qualified runtime')
    expected = ['app/hybrid_water/'+name for name in ('daily_coupling.py', 'extended_drainage.py',
                 'extended_implicit_pond_switch.py', 'secondary_pond_source_guard.py')]
    require(git('diff', '--name-only', BASE, RUNTIME, '--', *SURFACES).decode().splitlines() == expected,
            'Unexpected secondary numerical/compiler dependency changed')
    path = 'app/hybrid_water/daily_coupling.py'
    anchor = b"        raise ValueError('Foreign actual extended drain native state provider')\n"
    addition = b"    if (identity.get('extended_drainage') or {}).get('zero_pond_switch_renderer_sha256'):\n        from secondary_pond_source_guard import validate as validate_secondary_pond_source\n        validate_secondary_pond_source(bundle)\n"
    require(change(blob(BASE, path), anchor, anchor+addition) == blob(RUNTIME, path),
            'Daily physical/transaction body changed beyond selected read-only source guard')
    path = 'app/hybrid_water/extended_drainage.py'
    before = blob(BASE, path)
    anchor = b'        body=implicit_pond_source(body)\n'
    added = b"        if selection(project)['swsrf']==2:\n            from extended_implicit_pond_switch import source as zero_pond_source\n            body=zero_pond_source(body)\n"
    before = change(before, anchor, anchor+added)
    removed = b"    if selected.get('SWKIMPL')==1 and swsrf!=3:\n        raise ValueError('Implicit secondary-only extended drainage is not qualified: original Newton clock-resolution failure')\n"
    before = change(before, removed, b'')
    anchor = b'                strict_trial_water_guard_cm=1e-10,strict_retry_clock_floor_ulps=8,\n'
    added = b"                **({'zero_pond_switch_renderer_sha256':sha(Path(__file__).with_name('extended_implicit_pond_switch.py')),\n                    'zero_pond_reference_correction':'Original positive pond branch selected at h0>0; removes proved1e-6cm residual jump; original pond equation and all convergence/clock/balance limits unchanged',\n                    'original_positive_head_deadband_preserved':False} if implicit and selection(project)['swsrf']==2 else {}),\n"
    before = change(before, anchor, added+anchor)
    require(before == blob(RUNTIME, path),
            'Old extended physical/ledger/native/default implementation changed beyond secondary selection')
    existing = set(git('ls-tree', '-r', '--name-only', BASE, '--', 'tests').decode().splitlines())
    changed = set(git('diff', '--name-only', BASE, '--', 'tests').decode().splitlines()) & existing
    require(changed <= {'tests/nomacro_drainage/calendar_runtime.py', OLD},
            'Earlier scientific test/reader/registered owner changed')
    path = 'tests/nomacro_drainage/calendar_runtime.py'
    require(norm((ROOT/path).read_bytes()) == blob(RUNTIME, path),
            'Actual declared secondary producer differs from persisted controller')
    return True


def qualification():
    raw = (ROOT/QUAL).read_bytes()
    require(norm(raw) == blob(SEALED, QUAL), 'Neutral secondary qualification changed')
    q = json.loads(raw)
    require(q['status'] == 'NEUTRAL_SECONDARY_POND_SOURCE_RAW_SCIENCE_PASS_PENDING_ADMISSION' and
            len(q['archives']) == 9 and q['secondary_implicit_admitted'] is False and
            q['original_positive_head_deadband_preserved'] is False,
            'Neutral secondary evidence scope changed')
    require((q['runtime'], q['predecessor'], q['independent_readers']) == (RUNTIME, BASE, READERS),
            'Foreign secondary source/evidence authority')
    expected = dict(actual_full_periods=8, actual_days_per_full_period=1096,
                    actual_full_cold_windows=56, actual_Windows_short_contexts=18,
                    actual_Windows_short_cold_windows=54, actual_Ubuntu_current_secondary35_contexts=4,
                    actual_primary35_postimages=8, actual_explicit_off_postimages=2,
                    actual_ordinary_current4day_native_postimages=4,
                    actual_public_native_refusals=572, actual_compiled_native_refusals=534,
                    actual_CLI_contexts=10, actual_transaction_contexts=10,
                    actual_before_worker_source_policy_refusals=30, actual_before_compiler_scope_refusals=5,
                    actual_component_cases_per_variant_platform_optimization=18,
                    inherited_unchanged_evidence_files=1751)
    require(all(q[k] == v for k, v in expected.items()), 'Actual secondary denominator changed')
    require(q['functional_completion'] == 'PARTIAL' and q['whole_scientific_equivalence'] ==
            'NOT_QUALIFIED' and q['global_family_and_gap_counts'] == 'UNKNOWN' and
            q['RC3_changed'] is False and q['AGE_admitted'] is False and
            q['integrated_water_1e10_claim'] is False and q['fresh_unaffected_full_periods'] == 0,
            'Whole historical/scientific/release scope promoted')
    require(all(q[k] == 1e-10 for k in ('daily_soil_water_guard_cm', 'daily_secondary_water_guard_cm',
            'daily_combined_water_guard_cm', 'daily_CDE_guard_mg_cm2', 'integrated_CDE_guard_mg_cm2')),
            'Secondary scientific limits changed')
    return q


@lru_cache(maxsize=1)
def source():
    q = qualification()
    guard_previous_source()
    current = norm((ROOT/OLD).read_bytes()).decode()
    require(current.count(SOURCE_HOOK) == current.count(VERIFY_HOOK) == 1 and
            current.replace(SOURCE_HOOK, SOURCE_LINE, 1).replace(VERIFY_HOOK, '', 1).encode() == blob(BASE, OLD),
            'Earlier implicit scientific/source bodies changed')
    for name in PARSERS:
        path = 'tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes()) == blob(READERS, path),
                'Frozen independent secondary observer changed')
    for item in q['archives'].values():
        path = 'integration/f-ci/nomacro-complete01/'+item['record']
        raw = (ROOT/path).read_bytes()
        require(norm(raw) == blob(SEALED, path) and evidence.prior.prior.digest(norm(raw)) ==
                item['record_lf_sha256'], 'Neutral secondary actual provenance changed')
    previous.source()
    return True


@lru_cache(maxsize=1)
def scientific():
    qualification()
    metrics, controls = {}, []
    for opt in ('O0', 'O2'):
        win = evidence.windows(PROOF/(evidence.PREFIX+f'WINDOWS_{opt}_RAW_ARCHIVE.zip'), opt)
        full = evidence.ubuntu_full(PROOF/(evidence.PREFIX+f'FULL_UBUNTU_{opt}_RAW_ARCHIVE.zip'), opt)
        current = evidence.ubuntu_current(PROOF/(evidence.PREFIX+f'CURRENT_UBUNTU_{opt}_RAW_ARCHIVE.zip'), opt)
        metrics.update({f'Windows-{opt}': win, f'Ubuntu-full-{opt}': full, f'Ubuntu-current-{opt}': current})
        controls += [win[p]['controls'] for p in ('full-water', 'full-cde')]
        controls += [full['water']['controls'], current['water']['controls'], current['cde']['controls']]
    counts = tuple(sum(v[k] for v in controls) for k in ('actual_public_refusals',
        'actual_compiled_refusals', 'actual_cli_contexts', 'actual_transaction_contexts'))
    require(counts == (572, 534, 10, 10), 'Actual recomputed secondary control denominator differs')
    source_refusals = sum(metrics[f'Windows-{opt}'][p]['source-controls']['actual_before_worker_source_policy_refusals']
                          for opt in ('O0', 'O2') for p in ('full-water', 'full-cde'))
    source_refusals += sum(metrics[f'Ubuntu-current-{opt}']['source-controls']['actual_before_worker_source_policy_refusals']
                           for opt in ('O0', 'O2'))
    require(source_refusals == 30, 'Actual secondary source-policy refusal denominator differs')
    path = PROOF/(evidence.PREFIX+'DIAGNOSTICS_RAW_ARCHIVE.zip')
    with evidence.prior.prior.archive(path, json.loads(path.with_suffix('.json').read_text())):
        pass
    return dict(metrics=metrics, actual_full_periods=8, actual_full_cold_windows=56,
                actual_public_native_refusals=counts[0], actual_compiled_native_refusals=counts[1],
                actual_CLI_contexts=counts[2], actual_transaction_contexts=counts[3],
                actual_before_worker_source_policy_refusals=source_refusals,
                fresh_unaffected_full_periods=0)


def verify():
    source()
    retained = inherited.verify(ROOT, PROOF)
    current = scientific()
    return dict(status='BOUNDED_SECONDARY_EXTENDED_IMPLICIT_SOURCE_RAW_ADMISSION_PASS',
                runtime=RUNTIME, **current, inherited_qualified_observation=retained,
                secondary_only_implicit_source_raw_qualified=True,
                canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT', AGE_extended_admitted=False,
                functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED',
                global_family_and_gap_counts='UNKNOWN', RC3_changed=False)


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
