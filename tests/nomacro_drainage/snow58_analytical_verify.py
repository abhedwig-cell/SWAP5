"""Bound ordinary analytical Snow5/8 to actual admitted360 and original evidence."""
import json
import zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive, SHA
from snow58_analytical_source import ROOT, CORE, git
from snow58_analytical_source_custody import source, inherited_evidence
from snow58_analytical_central_science import audit, preservation

PROOF = ROOT / 'integration/f-ci/nomacro-complete01'
SEALED='58aa5693940ac61a32a9b99012a63c51f4c6c807'
PARENT_ADMISSION_SHA = '1272201c759396f7441b33676a0a08a47ae0f9ebf5b8d527f2f33fc5fcf6c7ec'
RAW_NAMES = (
    'SNOW58_ANALYTICAL_WINDOWS_RAW_V1',
    'SNOW58_ANALYTICAL_FIRST143_UBUNTU_O0_ORIGINAL_V1',
    'SNOW58_ANALYTICAL_FIRST143_UBUNTU_O2_ORIGINAL_V1',
    'SNOW58_ANALYTICAL_UBUNTU_O0_ORIGINAL264_V1',
    'SNOW58_ANALYTICAL_UBUNTU_O2_ORIGINAL264_V1',
    'SNOW58_ANALYTICAL_UBUNTU_O0_SUPPLEMENT107_V1',
    'SNOW58_ANALYTICAL_UBUNTU_O2_SUPPLEMENT107_V1',
    'SNOW58_ANALYTICAL_EXISTING9_MODEL1_PRESERVATION_RAW_V1',
    'SNOW58_ANALYTICAL_INPUTS_V1',
)


def frozen(name):
    path = 'integration/f-ci/nomacro-complete01/' + name + '.json'
    raw = (ROOT / path).read_bytes().replace(b'\r\n', b'\n')
    assert raw == git('show', SEALED + ':' + path), 'Changed scientific declaration ' + name
    return json.loads(raw)


def parent_admission():
    with ExitStack() as stack:
        store = Archive(PROOF, 'EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_ADMISSION_RAW_V1', stack)
        assert store.record['sha256'] == PARENT_ADMISSION_SHA and store.record['canonical_admission']
        for member in store.names:
            store.get(member)
        label = 'EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_ACTUAL_CANONICAL_PUBLIC_V1'
        receipt = json.loads(store.get(label + '.json'))
        old = json.loads(store.get(label + '.stdout.txt'))
        assert receipt['before'] == receipt['after'] and receipt['before']['head'] == CORE and receipt['returncode'] == 0
        assert not store.get(label + '.stderr.txt')
        assert len(receipt['before']['sparse']) == 14 and len(receipt['before']['original_project_files']) == 56
        label = 'EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_ACTUAL_CANONICAL_PUBLICATION_V1'
        scope = json.loads(store.get(label + '.json'))
        assert scope['before'] == scope['after'] and scope['before']['head'] == CORE and scope['returncode'] == 0
        assert b'PUBLICATION_REPLAY_SELECTED=false' in store.get(label + '.stdout.txt')
        stats = old['coadmission']
        assert stats['contexts'] == 360 and stats['native_calendar_samples'] == 2526 and stats['exact_cold_windows'] == 1084 and stats['compiled_initialization_postimages'] == 303
    receipt = frozen('EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_MERGE_RECEIPT_V1')
    assert receipt['actual_merge'] == CORE and receipt['canonical_admission'] and receipt['admission_archive_sha256'] == PARENT_ADMISSION_SHA
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
                assert store.record == declaration
                for member in store.names:
                    store.get(member)
                count = len(store.names)
            else:
                assert name == 'SNOW58_ANALYTICAL_INPUTS_V1'
                path = PROOF / declaration['archive']
                assert path.stat().st_size == declaration['bytes'] and SHA(path.read_bytes()) == declaration['sha256']
                z = stack.enter_context(zipfile.ZipFile(path))
                members = declaration['members']
                assert len(z.namelist()) == len(set(z.namelist())) == len(members) and set(z.namelist()) == set(members)
                for member, item in members.items():
                    raw = z.read(member)
                    assert len(raw) == item['bytes'] and SHA(raw) == item['sha256']
                count = len(members)
            observed.append(dict(archive=name, bytes=declaration['bytes'], sha256=declaration['sha256'], members=count))
    return observed


def guard_previous_source():
    source(SEALED)
    inherited_evidence()
    parent_admission()
    raw_custody()
    return True


def strip_current_evidence(text):
    from explicit_bottom9_snow_analytical_verify import strip_current_evidence as inherited
    return inherited(text)


def publication_dependencies_unchanged():
    guard_previous_source()
    return True


def verify():
    current = source(SEALED)
    inherited = inherited_evidence()
    parent, previous = parent_admission()
    raw = raw_custody()
    science = {}
    for platform in ('Windows', 'Ubuntu'):
        for opt in ('O0', 'O2'):
            name = 'SNOW58_ANALYTICAL_' + platform.upper() + '_' + opt + '_CENTRAL_V1'
            actual = audit(platform, opt)
            assert actual == frozen(name)
            science[name] = actual
    unchanged = {}
    for opt in ('O0', 'O2'):
        actual = preservation(opt)
        assert actual == frozen('SNOW58_ANALYTICAL_' + opt + '_PRESERVATION_CENTRAL_V1')
        unchanged[opt] = actual
    contexts = [item for record in science.values() for item in record['contexts']]
    assert len(contexts) == 24 and sum(item['native'] for item in contexts) == 168 and sum(item['exact_cold'] for item in contexts) == 72
    assert sum(item['model_refusals'] for item in contexts) == 432 and sum(item['root_refusals'] for item in contexts) == 200
    assert sum(item['transactions'] for item in contexts) == sum(item['vapor_refusal'] for item in contexts) == 8
    return dict(status='BOUNDED_ORIGINAL_ANALYTICAL_SNOW58_PARENT360_NEW24_SOURCE_NATIVE_COLD_COMPILED_AND_ORIGINAL_CONSTITUTIVE_PASS', actual_current_source=current, fresh_parent360_evidence=inherited, parent_actual_admission=parent, inherited360_original_science=previous, new24_original_science=science, unchanged_paired9_model1_compiled_preservation=unchanged, actual_new_raw_custody=raw, coadmission=dict(contexts=384, short35_contexts=382, year367_contexts=2, new_analytical_snow58_contexts=24, native_calendar_samples=2694, exact_cold_windows=1156, compiled_initialization_postimages=327, new_unselected_paired9_model1_compiled_postimages=12, previous_canonical=CORE), compiler_executions=0, model_executions=0, canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT', functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED', global_family_and_gap_counts='UNKNOWN', RC3_changed=False)


if __name__ == '__main__':
    print(json.dumps(verify(), indent=2))
