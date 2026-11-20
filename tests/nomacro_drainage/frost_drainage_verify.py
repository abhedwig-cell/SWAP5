"""Bounded explicit Frost drainage source, raw science and inherited authority."""
import ast
from functools import lru_cache
import json
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT/'tests/nomacro_drainage'), str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_evidence import read, digest, require
from ordinary_pond_verify import git, blob, norm, sha, SURFACES
import frost_cde_drainage_science as science

PARENT = '383526abddeb06ea61fe31fa7e342ebbd8a5c43d'
RUNTIME = '6e40385c9b871992641f7a601bbf0ec30f5f68d3'
READERS = 'b285147254b208643423adea88a4fb5f1158b464'
SEALED = 'a45960ea8cf8a13862d1dd8fd92b08e7b4bfa4d6'
PROOF = ROOT/'integration/f-ci/nomacro-complete01'
QUAL = 'integration/f-ci/nomacro-complete01/FROST_DRAINAGE_QUALIFICATION.json'
OLD = 'tests/nomacro_drainage/snow_undrained_verify.py'
GUARD_HOOK = '    import frost_drainage_verify as frost\n    return frost.guard_previous_source()\n'
VERIFY_HOOK = '    import frost_drainage_verify as frost\n    return frost.verify()\n'
PROJECTION_HOOK = '    import frost_drainage_verify as frost\n    text=frost.strip_current_evidence(text)\n'
PATTERN = '            /integration/f-ci/nomacro-complete01/FROST_DRAINAGE_*\n'
LEGACY_PATTERN = '            /integration/f-ci/nomacro-complete01/OUTPUT_THERMAL_WINDOWS_*\n'
PUBLICATION_WORKFLOWS = ('pub-me-d1-transition-authority.yml', 'pub-me-d3-origin-authority.yml',
    'pub-p2e06-reference-local-balance-scaling.yml', 'pub-p2e07-reference-cancellation-floor.yml',
    'pub-p2e08-reference-valid-calibration-domain.yml', 'pub-p2e09-reference-threshold-freeze.yml',
    'pub-p2e10-e0-broad-paired-matrix.yml')
PUBLICATION_EXCLUSIONS = ''.join("      - '!reference/swap-4.3.1/frost-corrections/FROST-DIVDRA-OVERLAP-01/" +
    name + "'\n" for name in ('README.md', 'divdra.f90', 'manifest.json'))
PUBLICATION_HELPER = "      - 'tests/nomacro_drainage/frost_publication_scope.py'\n"
PUBLICATION_SELECTION = ('      - name: Select actual publication dependency changes\n'
    '        id: publication_scope\n        run: python3 tests/nomacro_drainage/frost_publication_scope.py\n')
PUBLICATION_CONDITION = "        if: steps.publication_scope.outputs.replay == 'true'\n"
PARSERS = ('frost_cde_drainage_science.py', 'frost_cde_drainage_model_forensics.py',
    'frost_cde_drainage_component_forensics.py', 'frost_cde_drainage_sealed_components.py',
    'frost_cde_drainage_portable_forensics.py', 'frost_drainage_parent_bridge.json')
COUNTS = dict(actual_full_periods=8, actual_days_per_full_period=1096, actual_full_cold_windows=56,
    actual_short_contexts=8, actual_short_cold_windows=24, actual_compiled_refusals=332,
    actual_source_refusals=40, actual_descriptor_refusals=52, actual_transaction_contexts=8,
    actual_unselected_contexts=12, actual_unselected_cold_windows=12,
    actual_geometric_component_cases=48, actual_Frost_rate_component_cases=336,
    actual_literal_CDE_task2_component_cases=1008)


def strip_current_evidence(text):
    for pattern in (PATTERN, LEGACY_PATTERN):
        if pattern in text:
            require(text.count(pattern) == 1, 'Ambiguous Frost drainage proof checkout')
            text = text.replace(pattern, '', 1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    require(not git('diff', RUNTIME, '--', *SURFACES),
        'Actual Frost drainage compiler source differs from qualified runtime')
    bridge = read(Path(__file__).with_name('frost_drainage_parent_bridge.json'))
    require((bridge['parent'], bridge['runtime']) == (PARENT, RUNTIME), 'Foreign Frost parent source bridge')
    changes = git('diff', '--name-status', PARENT, RUNTIME, '--', *SURFACES).decode().splitlines()
    expected = {line.split('\t')[1]: line.split('\t')[0] for line in changes}
    require(set(expected) == set(bridge['changes']) | set(bridge['added']) and
        all(expected[p] == 'M' for p in bridge['changes']) and all(expected[p] == 'A' for p in bridge['added']),
        'Incomplete complete-file Frost parent source bridge')
    for path, items in bridge['changes'].items():
        lines = blob(RUNTIME, path).decode().splitlines(keepends=True)
        for item in reversed(items):
            at = item['runtime_line']-1; after = item['after'].splitlines(keepends=True)
            require(lines[at:at+len(after)] == after, 'Actual Frost source bridge differs')
            lines[at:at+len(after)] = item['before'].splitlines(keepends=True)
        require(''.join(lines).encode() == blob(PARENT, path), 'Admitted original Snow parent source changed')
    for path, value in bridge['added'].items():
        require(sha(blob(RUNTIME, path)) == value, 'Added bounded Frost source differs')
    for name in PARSERS:
        path = 'tests/nomacro_drainage/' + name
        require(norm((ROOT/path).read_bytes()) == blob(READERS, path), 'Frozen Frost observer changed: ' + name)
    old = norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK, VERIFY_HOOK, PROJECTION_HOOK):
        require(old.count(hook) == 1, 'Ambiguous Frost bounded owner delegation')
        old = old.replace(hook, '', 1)
    require(old.encode() == blob(PARENT, OLD), 'Earlier ordinary Snow scientific owner changed')
    existing = set(git('ls-tree', '-r', '--name-only', PARENT, '--', 'tests').decode().splitlines())
    changed = set(git('diff', '--name-only', PARENT, '--', 'tests').decode().splitlines()) & existing
    require(changed == {OLD}, 'Earlier actual scientific observer changed beyond Frost delegation')
    for name in ('mc-sol01-column-input.yml', 'mc-sol01-swp-reader.yml'):
        path = '.github/workflows/' + name; actual = norm((ROOT/path).read_bytes()).decode()
        require(actual.count(PATTERN) == actual.count(LEGACY_PATTERN) == 1 and
            actual.replace(PATTERN, '', 1).replace(LEGACY_PATTERN, '', 1).encode() == blob(PARENT, path),
            'Registered CI changed beyond Frost proof checkout')
    for name in PUBLICATION_WORKFLOWS:
        path = '.github/workflows/' + name; actual = norm((ROOT/path).read_bytes()).decode()
        for inserted, count in ((PUBLICATION_EXCLUSIONS, 1), (PUBLICATION_HELPER, 1),
                                (PUBLICATION_SELECTION, 1), (PUBLICATION_CONDITION, 2)):
            require(actual.count(inserted) == count, 'Ambiguous publication dependency selection')
            actual = actual.replace(inserted, '')
        require(actual.encode() == blob(PARENT, path),
            'Publication CI changed beyond explicit unchanged dependency selection')
    return True


def qualification():
    raw = (ROOT/QUAL).read_bytes()
    require(norm(raw) == blob(SEALED, QUAL), 'Neutral Frost qualification changed')
    q = json.loads(raw)
    require(q['status'] == 'NEUTRAL_FROST_DRAINAGE_RAW_SCIENCE_PASS_PENDING_ADMISSION' and
        (q['runtime'], q['predecessor'], q['independent_readers']) == (RUNTIME, PARENT, READERS),
        'Foreign bounded Frost qualification')
    require(q['functional_completion'] == 'PARTIAL' and q['whole_scientific_equivalence'] == 'NOT_QUALIFIED' and
        q['global_family_and_gap_counts'] == 'UNKNOWN', 'Whole historical authority promoted')
    for name in ('RC3_changed', 'AGE_admitted', 'frost_drainage_admitted', 'implicit_Frost_admitted',
                 'fully_frozen_front_admitted', 'new_physical_state', 'broader_calendars_admitted'):
        require(q[name] is False, 'Unqualified Frost/AGE/production authority promoted: ' + name)
    require(all(q[k] == v for k, v in COUNTS.items()) and len(q['archives']) == 12, 'Neutral Frost denominator differs')
    require(all(q[k] == 1e-10 for k in ('daily_water_guard_cm', 'integrated_water_guard_cm',
        'daily_CDE_guard_mg_cm2', 'integrated_CDE_guard_mg_cm2')), 'Scientific conservation guard changed')
    return q


@lru_cache(maxsize=1)
def source():
    guard_previous_source(); q = qualification()
    import groundwater_snow_verify as archives
    for label, item in q['archives'].items(): archives.archive_identity(item, label)
    import snow_undrained_verify as previous
    previous.source()
    return True


def inherited():
    path = PROOF/'SNOW_UNDRAINED_ADMISSION_RAW_V1.zip'; record = read(path.with_suffix('.json'))
    require(path.stat().st_size == record['bytes'] and digest(path) == record['sha256'] ==
        'd892f426579447b9fc5608e9d19ece61da3e00995c9905914854e37130c724e2',
        'Inherited ordinary Snow admission changed')
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist()) == set(record['members']), 'Inherited ordinary Snow admission inventory differs')
        for name, item in record['members'].items():
            raw = z.read(name)
            require(len(raw) == item['bytes'] and sha(raw) == item['sha256'], 'Inherited ordinary Snow evidence changed')
        receipt = json.loads(z.read('SNOW_UNDRAINED_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
        observed = json.loads(z.read('SNOW_UNDRAINED_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
        require(receipt['before'] == receipt['after'] and receipt['before']['head'] == PARENT and
            receipt['before']['status'] == '' and len(receipt['before']['sparse']) == 29 and
            receipt['returncode'] == receipt['compiler_executions'] == receipt['model_executions'] == 0 and
            observed['status'] == 'BOUNDED_SNOW_UNDRAINED_SOURCE_RAW_ADMISSION_PASS',
            'Actual inherited ordinary Snow canonical public observation differs')
    # Execute the exact accepted function body from the actual canonical parent.
    # Only the three current delegation hooks are bypassed; no original science
    # statement, reader, denominator or source/refusal body is reconstructed.
    import snow_undrained_verify as previous
    tree = ast.parse(blob(PARENT, OLD).decode())
    functions = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'verify']
    require(len(functions) == 1, 'Missing original accepted ordinary Snow scientific body')
    namespace = dict(previous.__dict__)
    exec(compile(ast.Module(body=functions, type_ignores=[]), OLD, 'exec'), namespace)
    observations = namespace['verify']()
    require(observations['status'] == 'BOUNDED_SNOW_UNDRAINED_SOURCE_RAW_ADMISSION_PASS',
        'Original accepted ordinary Snow scientific body did not pass')
    return dict(status='UNCHANGED_ACTUAL_ADMITTED_ORDINARY_SNOW_AND_EARLIER_SCIENCE_REUSED',
        prior_actual_canonical=PARENT, literal_original_verify_body_executed=True,
        actual_original_observations=observations, fresh_unaffected_full_periods=0,
        inherited_observations_counted_fresh=False)


def verify():
    source(); retained = inherited()
    win = science.windows(PROOF); portable = {o: science.ubuntu(PROOF, o) for o in ('O0', 'O2')}
    for key in ('actual_full_periods', 'actual_full_cold_windows', 'actual_short_contexts',
                'actual_short_cold_windows', 'actual_compiled_refusals', 'actual_source_refusals',
                'actual_descriptor_refusals', 'actual_transaction_contexts',
                'actual_unselected_contexts', 'actual_unselected_cold_windows'):
        require(sum(r[key] for r in [win, *portable.values()]) == COUNTS[key], 'Actual Frost denominator differs: ' + key)
    contexts = list(win['components'].values()) + [r['observations']['components'] for r in portable.values()]
    require(len(contexts) == 4, 'Missing actual platform/optimizer component context')
    for count, component, field in (
        ('actual_geometric_component_cases', 'overlap', 'corrected_geometric_cases'),
        ('actual_Frost_rate_component_cases', 'rates', 'actual_original_and_guarded_rate_cases'),
        ('actual_literal_CDE_task2_component_cases', 'cde', 'actual_literal_CDE_task2_cases')):
        require(sum(c['components'][component][field] for c in contexts) == COUNTS[count],
            'Actual independent Frost component denominator differs: ' + count)
    return dict(status='BOUNDED_FROST_DRAINAGE_SOURCE_RAW_ADMISSION_PASS', runtime=RUNTIME, **COUNTS,
        Windows=win, Ubuntu=portable, inherited_unchanged_owners=retained, model_executions=0,
        compiler_executions=0, canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',
        functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED',
        global_family_and_gap_counts='UNKNOWN', RC3_changed=False, AGE_admitted=False,
        frost_drainage_admitted=False, implicit_Frost_admitted=False, fully_frozen_front_admitted=False)


if __name__ == '__main__': print(json.dumps(verify(), indent=2))
