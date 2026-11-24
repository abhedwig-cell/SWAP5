"""Actual admitted384 plus bounded original RIA12 state and original science."""
from contextlib import ExitStack
import json
import zipfile

from analytical_hydraulic_archives import Archive, SHA
from ria12_boundary_source import R as ROOT, CORE, git
from ria12_boundary_source_custody import source, inherited_evidence
from ria12_boundary_central_science import audit, preservation, primary_preservation, short_proofs
import ria12_verify as previous

PROOF = ROOT / 'integration/f-ci/nomacro-complete01'
SEALED='2c596a91d66601b3c9fcc1d7188b9dc8e49d0e91'
ADMISSION_SHA = '19c966e0d3173d844ce434151b21252c4ceb5c04495f515f92c8388a18a505c3'
RAW_NAMES = ('RIA12_BOUNDARY_WINDOWS_RAW_V1', 'RIA12_BOUNDARY_INPUTS_V1', 'RIA12_BOUNDARY_WET8_INPUTS_V1', 'RIA12_BOUNDARY_NATIVE_ORIGINS_V1', 'RIA12_BOUNDARY_UBUNTU_O0_ORIGINAL_V1', 'RIA12_BOUNDARY_UBUNTU_O2_ORIGINAL_V1')


def frozen(name):
    path = 'integration/f-ci/nomacro-complete01/' + name + '.json'
    raw = (ROOT / path).read_bytes().replace(b'\r\n', b'\n')
    assert raw == git('show', SEALED + ':' + path), 'Changed RIA scientific declaration ' + name
    return json.loads(raw)


def parent_admission():
    with ExitStack() as stack:
        store = Archive(PROOF, 'RIA12_ADMISSION_RAW_V1', stack)
        assert store.record['sha256'] == ADMISSION_SHA
        for member in store.names:
            store.get(member)
        label = 'RIA12_ACTUAL_CANONICAL_PUBLIC_V1'
        receipt = json.loads(store.get(label + '.json'))
        old = json.loads(store.get(label + '.stdout.txt'))
        assert receipt['before'] == receipt['after'] and receipt['before']['head'] == CORE and receipt['returncode'] == 0
        assert not store.get(label + '.stderr.txt')
        assert len(receipt['before']['sparse']) == 14 and len(receipt['before']['original_project_files']) == 56
        label = 'RIA12_ACTUAL_CANONICAL_PUBLICATION_V1'
        scope = json.loads(store.get(label + '.json'))
        assert scope['before'] == scope['after'] and scope['before']['head'] == CORE and scope['returncode'] == 0
        assert b'PUBLICATION_REPLAY_SELECTED=false' in store.get(label + '.stdout.txt')
        stats = old['coadmission']
        assert stats['contexts'] == 392 and stats['native_calendar_samples'] == 2750 and stats['exact_cold_windows'] == 1180 and stats['compiled_initialization_postimages'] == 335
    receipt = json.loads((PROOF / 'RIA12_MERGE_RECEIPT_V1.json').read_text())
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
                assert name in ('RIA12_BOUNDARY_INPUTS_V1', 'RIA12_BOUNDARY_WET8_INPUTS_V1')
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
    # Fresh original RIA parent evidence is read at explicit immutable locations.
    # No old owner is given a simulated source tree, HEAD or namespace.
    previous.raw_custody()
    prior_science = {}
    for platform in ('Windows', 'Ubuntu'):
        for opt in ('O0', 'O2'):
            value = previous.audit(platform, opt)
            assert value == previous.frozen('RIA12_' + platform.upper() + '_' + opt + '_CENTRAL_V1')
            prior_science[platform + '-' + opt] = value
    for opt in ('O0', 'O2'):
        assert previous.preservation(opt) == previous.frozen('RIA12_' + opt + '_MODEL1_PRESERVATION_CENTRAL_V1')
    science = {}
    for platform in ('Windows', 'Ubuntu'):
        for opt in ('O0', 'O2'):
            name = 'RIA12_BOUNDARY_' + platform.upper() + '_' + opt + '_CENTRAL_V1'
            value = audit(platform, opt)
            assert value == frozen(name)
            science[name] = value
    unchanged = {}
    for opt in ('O0', 'O2'):
        value = preservation(opt)
        assert value == frozen('RIA12_BOUNDARY_' + opt + '_MODEL1_PRESERVATION_CENTRAL_V1')
        unchanged[opt] = value
    primary = {}
    for kind, opt in (('water', 'O0'), ('cde', 'O2')):
        value = primary_preservation(kind, opt)
        assert value == frozen('RIA12_BOUNDARY_' + kind.upper() + '_' + opt + '_PRIMARY_PRESERVATION_CENTRAL_V1')
        primary[kind + '-' + opt] = value
    short = short_proofs()
    assert short == frozen('RIA12_BOUNDARY_SHORT_ALL12_CENTRAL_V1')
    contexts = [item for record in science.values() for item in record['contexts']]
    assert len(contexts) == 8 and sum(item['native'] for item in contexts) == 56 and sum(item['cold'] for item in contexts) == 24
    assert sum(item['native_controls']['native_refusals'] for item in contexts) == 328
    assert sum(item['native_controls']['private_input_refusals'] for item in contexts) == 24
    assert sum(item['external'] is not None for item in contexts) == 6
    return dict(status='BOUNDED_ORIGINAL_RIA_BOUNDARY_PARENT392_NEW8_REAL_SOURCE_GLOBAL_ORIGINAL_NATIVE_COLD_COMPILED_EXTERNAL_PASS',
                actual_current_source=current, fresh_parent392_evidence=inherited, parent_actual_admission=parent,
                inherited392_original_science=old, inherited_primary_ria_science=prior_science, all12_original_short_science=short,
                new8_original_science=science, unchanged_model1_compiled=unchanged, unchanged_primary_ria_compiled=primary, actual_new_raw_custody=raw,
                coadmission=dict(contexts=400, short35_contexts=398, year367_contexts=2, new_ria_boundary_contexts=8,
                                 native_calendar_samples=2806, exact_cold_windows=1204, compiled_initialization_postimages=343, previous_canonical=CORE),
                compiler_executions=0, model_executions=0, canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',
                functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED', global_family_and_gap_counts='UNKNOWN', RC3_changed=False)


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
