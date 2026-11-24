"""Actual admitted384 plus bounded original RIA12 state and original science."""
from contextlib import ExitStack
import json
import zipfile

from analytical_hydraulic_archives import Archive, SHA
from ria12_source import R as ROOT, CORE, git
from ria12_source_custody import source, inherited_evidence
from ria12_central_science import audit, preservation
import snow58_analytical_verify as previous

PROOF = ROOT / 'integration/f-ci/nomacro-complete01'
SEALED='863a0e14c0986142ee3d10b65462590e0c058f39'
ADMISSION_SHA = 'c17670492b81699c1de02f33a129a3d7651506084cc7121673054b59d325e135'
RAW_NAMES = ('RIA12_WINDOWS_RAW_V1', 'RIA12_INPUTS_V1', 'RIA12_NATIVE_CONTROL_ORIGINS_V1') + tuple(
    'RIA12_UBUNTU_' + opt + '_' + suffix + '_V1' for opt in ('O0', 'O2') for suffix in ('ORIGINAL', 'CONTROLS_ORIGINAL'))


def frozen(name):
    path = 'integration/f-ci/nomacro-complete01/' + name + '.json'
    raw = (ROOT / path).read_bytes().replace(b'\r\n', b'\n')
    assert raw == git('show', SEALED + ':' + path), 'Changed RIA scientific declaration ' + name
    return json.loads(raw)


def parent_admission():
    with ExitStack() as stack:
        store = Archive(PROOF, 'SNOW58_ANALYTICAL_ADMISSION_RAW_V1', stack)
        assert store.record['sha256'] == ADMISSION_SHA
        for member in store.names:
            store.get(member)
        label = 'SNOW58_ANALYTICAL_ACTUAL_CANONICAL_PUBLIC_V1'
        receipt = json.loads(store.get(label + '.json'))
        old = json.loads(store.get(label + '.stdout.txt'))
        assert receipt['before'] == receipt['after'] and receipt['before']['head'] == CORE and receipt['returncode'] == 0
        assert not store.get(label + '.stderr.txt')
        assert len(receipt['before']['sparse']) == 14 and len(receipt['before']['original_project_files']) == 56
        label = 'SNOW58_ANALYTICAL_ACTUAL_CANONICAL_PUBLICATION_V1'
        scope = json.loads(store.get(label + '.json'))
        assert scope['before'] == scope['after'] and scope['before']['head'] == CORE and scope['returncode'] == 0
        assert b'PUBLICATION_REPLAY_SELECTED=false' in store.get(label + '.stdout.txt')
        stats = old['coadmission']
        assert stats['contexts'] == 384 and stats['native_calendar_samples'] == 2694 and stats['exact_cold_windows'] == 1156 and stats['compiled_initialization_postimages'] == 327
    receipt = json.loads((PROOF / 'SNOW58_ANALYTICAL_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge'] == CORE and receipt['canonical_admission'] and receipt['admission_archive_sha256'] == ADMISSION_SHA
    assert git('rev-parse', CORE + '^{tree}').decode().strip() == receipt['whole_qualified_tree']
    assert git('show', '-s', '--format=%P', CORE).decode().split() == receipt['ordered_parents']
    return receipt, old


def raw_custody():
    observed = []
    with ExitStack() as stack:
        for name in RAW_NAMES:
            declaration = frozen(name)
            if 'parts' in declaration:
                store = Archive(PROOF, name, stack)
                for member in store.names:
                    store.get(member)
            else:
                assert name == 'RIA12_INPUTS_V1'
                path = PROOF / declaration['archive']
                assert path.stat().st_size == declaration['bytes'] and SHA(path.read_bytes()) == declaration['sha256']
                z = stack.enter_context(zipfile.ZipFile(path))
                assert len(z.namelist()) == len(set(z.namelist())) == len(declaration['members']) and set(z.namelist()) == set(declaration['members'])
                for member, item in declaration['members'].items():
                    raw = z.read(member)
                    assert len(raw) == item['bytes'] and SHA(raw) == item['sha256']
            observed.append(dict(archive=name, sha256=declaration['sha256'], bytes=declaration['bytes'], members=len(declaration['members'])))
    return observed


def guard_previous_source():
    source(SEALED)
    inherited_evidence()
    parent_admission()
    raw_custody()
    return True


def strip_current_evidence(text):
    return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source()
    return True


def verify():
    current = source(SEALED)
    inherited = inherited_evidence()
    parent, old = parent_admission()
    raw = raw_custody()
    # Original scientific readers operate on their immutable archived locations.
    # They do not receive a simulated old HEAD or filesystem.
    previous.raw_custody()
    prior_science = {}
    for platform in ('Windows', 'Ubuntu'):
        for opt in ('O0', 'O2'):
            value = previous.audit(platform, opt)
            assert value == previous.frozen('SNOW58_ANALYTICAL_' + platform.upper() + '_' + opt + '_CENTRAL_V1')
            prior_science[platform + '-' + opt] = value
    for opt in ('O0', 'O2'):
        assert previous.preservation(opt) == previous.frozen('SNOW58_ANALYTICAL_' + opt + '_PRESERVATION_CENTRAL_V1')
    science = {}
    for platform in ('Windows', 'Ubuntu'):
        for opt in ('O0', 'O2'):
            name = 'RIA12_' + platform.upper() + '_' + opt + '_CENTRAL_V1'
            value = audit(platform, opt)
            assert value == frozen(name)
            science[name] = value
    unchanged = {}
    for opt in ('O0', 'O2'):
        value = preservation(opt)
        assert value == frozen('RIA12_' + opt + '_MODEL1_PRESERVATION_CENTRAL_V1')
        unchanged[opt] = value
    contexts = [item for record in science.values() for item in record['contexts']]
    assert len(contexts) == 8 and sum(item['native'] for item in contexts) == 56 and sum(item['cold'] for item in contexts) == 24
    assert sum(item['native_controls']['native_refusals'] for item in contexts) == 312
    assert sum(item['native_controls']['private_input_refusals'] for item in contexts) == 24
    return dict(status='BOUNDED_ORIGINAL_RIA12_PARENT384_NEW8_REAL_SOURCE_GLOBAL_ORIGINAL_NATIVE_COLD_COMPILED_EXTERNAL_PASS',
                actual_current_source=current, fresh_parent384_evidence=inherited, parent_actual_admission=parent,
                inherited384_original_science=old, inherited_analytical_snow58_science=prior_science,
                new8_original_science=science, unchanged_model1_compiled=unchanged, actual_new_raw_custody=raw,
                coadmission=dict(contexts=392, short35_contexts=390, year367_contexts=2, new_ria12_contexts=8,
                                 native_calendar_samples=2750, exact_cold_windows=1180, compiled_initialization_postimages=335, previous_canonical=CORE),
                compiler_executions=0, model_executions=0, canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',
                functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED', global_family_and_gap_counts='UNKNOWN', RC3_changed=False)


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
