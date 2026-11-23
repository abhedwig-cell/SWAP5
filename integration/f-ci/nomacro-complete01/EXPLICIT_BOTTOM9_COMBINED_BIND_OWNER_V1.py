"""Install the prepared 280-context owner only after genuine parent admission.

This does not commit, qualify, merge, or assign a source anchor. The subsequent
committed source snapshot must be frozen and exercised by the public commands.
"""
import argparse, hashlib, json, re, subprocess, zipfile
from pathlib import Path

CANONICAL = '4d39e97d2f257f70b6fc108c62eb5efce9967a42'
CANDIDATE = '67d2636672921505ecb47f1c9f4c6ea27a451889'
PUBLIC_STATUS = 'BOUNDED_ORIGINAL_EXPLICIT9_WATER_CDE_AGE_CALENDAR_DRAINAGE_SOURCE_RAW_NATIVE_PASS'
SHA = lambda raw: hashlib.sha256(raw).hexdigest()


def bind(root):
    proof = root / 'integration/f-ci/nomacro-complete01'
    git = lambda *args: subprocess.check_output(['git', *args], cwd=root).decode().strip()
    assert not git('status', '--porcelain', '--untracked-files=all')
    actual_head = git('rev-parse', 'HEAD')
    manifest = json.loads((proof / 'EXPLICIT_BOTTOM9_ADMISSION_RAW_V1.json').read_text())
    archive = proof / manifest['archive']
    raw = archive.read_bytes()
    assert len(raw) == manifest['bytes'] and SHA(raw) == manifest['sha256']
    assert manifest['canonical'] == CANONICAL and manifest['candidate'] == CANDIDATE
    assert manifest['canonical_admission'] is True
    receipt = json.loads((proof / 'EXPLICIT_BOTTOM9_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge'] == CANONICAL and receipt['qualified_head'] == CANDIDATE
    assert receipt['admission_archive_sha256'] == manifest['sha256']
    assert receipt['canonical_admission'] is True and receipt['contexts'] == 216
    with zipfile.ZipFile(archive) as store:
        assert set(store.namelist()) == set(manifest['members'])
        assert len(store.namelist()) == len(set(store.namelist()))
        for name, item in manifest['members'].items():
            member = store.read(name)
            assert len(member) == item['bytes'] and SHA(member) == item['sha256']
        observation = json.loads(store.read('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
        result = json.loads(store.read('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
        assert observation['before'] == observation['after']
        assert observation['before']['head'] == CANONICAL and not observation['before']['status']
        assert observation['returncode'] == 0 and observation['status'] == 'ACTUAL_PUBLIC_COMMAND_RETURNED'
        assert not store.read('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stderr.txt')
        assert result['status'] == PUBLIC_STATUS and result['coadmission']['contexts'] == 216
    contract = dict(
        status='COHERENT_ANALYTICAL_SNOW_HISTORY_PAIRED9_AND_ACTUAL_PARENT216_CONTRACT_NOT_YET_ADMITTED',
        previous_actual_canonical=CANONICAL, parent_qualified_head=CANDIDATE,
        parent_admission_sha256=manifest['sha256'], parent_contexts=216, new_contexts=64,
        combined_contexts=280, short35_contexts=278, year367_contexts=2,
        exact_cold_windows=844, native_calendar_samples=1966,
        compiled_initialization_postimages=223, integrated_compiler_preservation_postimages=88,
        new_qualification_contexts=dict(analytical=24, snow=8, history=32),
        actual_current_clean_sparse_patterns=14, actual_original_reference_fixtures=56,
        required_committed_pushed_nevermerge_negative_roles=['SOURCE','RAW','INHERITED','PUBLICATION'],
        whole_source_inverse_required=True, complete_fresh_inherited_evidence_required=True,
        all_current_archive_bytes_required=True, all_latest_exact_head_PR_checks_terminal_required=True,
        actual_canonical_clean_public_and_publication_required=True,
        original_producer_input_binding_and_raw_receipts_rewritten=False,
        physical_equations_changed=False, mass_or_convergence_limits_changed=False,
        standalone_parent_AGE110_admission_claimed=False, whole_historical_family_closed=False,
        canonical_admission=False, functional_completion='PARTIAL',
        whole_scientific_equivalence='NOT_QUALIFIED', global_family_and_gap_counts='UNKNOWN',
        RC3_changed=False)
    contract_raw = (json.dumps(contract, indent=2) + '\n').encode()
    proposal = (proof / 'EXPLICIT_BOTTOM9_COMBINED_PUBLIC_OWNER_PROPOSAL_V1.py').read_text()
    replacements = {
        'PENDING_ACTUAL_SOURCE_ANCHOR': '0' * 40,
        'PENDING_ACTUAL_PARENT216_ADMISSION_SHA': manifest['sha256'],
        'PENDING_ACTUAL_COHERENT280_CONTRACT_SHA': SHA(contract_raw),
    }
    for old, new in replacements.items():
        assert proposal.count(old) == 1
        proposal = proposal.replace(old, new)
    assert re.search(r"(?m)^SEALED='0{40}'$", proposal)
    joint_path = root / 'tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
    joint = joint_path.read_text()
    for name in ('guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged'):
        argument = 'text' if name == 'strip_current_evidence' else ''
        old = ' import explicit_bottom9_verify as explicit_owner\n return explicit_owner.' + name + '(' + argument + ')\n'
        new = ' import explicit_bottom9_combined_verify as combined_owner\n return combined_owner.' + name + '(' + argument + ')\n'
        assert joint.count(old) == 1
        joint = joint.replace(old, new, 1)
    owner_path = root / 'tests/nomacro_drainage/explicit_bottom9_combined_verify.py'
    contract_path = proof / 'EXPLICIT_BOTTOM9_COMBINED_COADMISSION_CONTRACT_V1.json'
    assert not owner_path.exists() and not contract_path.exists()
    assert git('rev-parse', 'HEAD') == actual_head
    contract_path.write_bytes(contract_raw)
    owner_path.write_text(proposal, encoding='utf8', newline='\n')
    joint_path.write_text(joint, encoding='utf8', newline='\n')
    print(json.dumps(dict(status='OWNER_BOUND_TO_ACTUAL_PARENT_ADMISSION_SOURCE_ANCHOR_AND_PUBLIC_GATES_PENDING',
        actual_preparation_head=actual_head, parent_admission_sha256=manifest['sha256'],
        contract_sha256=SHA(contract_raw), canonical_admission=False), indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--repository', type=Path, required=True)
    bind(parser.parse_args().repository.resolve())
