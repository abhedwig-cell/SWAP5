"""Four real one-file committed/pushed never-merge public refusal controls."""
import argparse, hashlib, json, subprocess, sys
from pathlib import Path

SHA = lambda raw: hashlib.sha256(raw).hexdigest()
PATHS = {
    'SOURCE': 'app/hybrid_water/prescribed_head_flux_boundary.py',
    'RAW': 'integration/f-ci/nomacro-complete01/CANONICAL_LEGACY_ORIGINAL_ORACLES_RAW_V1.zip',
    'INHERITED': 'integration/f-ci/nomacro-complete01/INITIAL_PROFILE_FROST_ADMISSION_RAW_V1.zip',
    'PUBLICATION': 'docs/publication/P2E09_REFERENCE_ONLY_THRESHOLD_FREEZE_PREREGISTRATION.json',
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repository', type=Path, required=True)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--candidate', required=True)
    args = parser.parse_args()
    root, evidence, candidate = args.repository.resolve(), args.evidence.resolve(), args.candidate
    git = lambda *a: subprocess.check_output(['git', *a], cwd=root, text=True).strip()
    assert len(candidate) == 40 and git('rev-parse', 'HEAD') == candidate
    clean = lambda: not git('status', '--porcelain=v1', '--untracked-files=all', '--ignored')
    assert clean()
    positive = json.loads((evidence/'EXPLICIT_BOTTOM9_COMBINED_CANDIDATE_PUBLIC_V4.json').read_text())
    assert positive['returncode'] == 0 and positive['before'] == positive['after']
    assert positive['before']['head'] == candidate
    result = json.loads((evidence/'EXPLICIT_BOTTOM9_COMBINED_CANDIDATE_PUBLIC_V4.stdout.txt').read_text())
    assert result['coadmission']['contexts'] == 280
    assert not (evidence/'EXPLICIT_BOTTOM9_COMBINED_CANDIDATE_PUBLIC_V4.stderr.txt').read_bytes()
    positive_pub = evidence/'EXPLICIT_BOTTOM9_COMBINED_CANDIDATE_PUBLICATION_V4'
    pub = json.loads(positive_pub.with_suffix('.json').read_text())
    assert pub['before'] == pub['after'] and pub['before']['head'] == candidate and pub['returncode'] == 0
    assert 'PUBLICATION_REPLAY_SELECTED=false' in positive_pub.with_suffix('.stdout.txt').read_text()
    assert not positive_pub.with_suffix('.stderr.txt').read_bytes()
    branch_before = git('symbolic-ref', '--short', 'HEAD')
    branches = {role:'codex/nomacro-paired9-combined-negative-'+role.lower()+'05' for role in PATHS}
    for branch in branches.values():
        assert not git('ls-remote', '--heads', 'origin', 'refs/heads/'+branch)
        assert subprocess.run(['git','show-ref','--verify','--quiet','refs/heads/'+branch], cwd=root).returncode == 1
    record_path = evidence/'EXPLICIT_BOTTOM9_COMBINED_FINAL_NEGATIVES_V5.json'
    assert not record_path.exists()
    record = dict(status='RUNNING', candidate=candidate, never_merge=True, controls=[],
                  compiler_executions=0, model_executions=0)
    save = lambda: record_path.write_text(json.dumps(record, indent=2)+'\n', encoding='utf8')
    observer = root/'tests/nomacro_drainage/explicit_bottom9_combined_public_observe.py'

    def observe(label, publication=False):
        command = [sys.executable,'-B',str(observer),'--cwd',str(root),'--output',str(evidence/label)]
        if publication:
            command.append('--publication')
        response = subprocess.run(command, cwd=root, capture_output=True, timeout=3700)
        (evidence/(label+'-observer.stdout.txt')).write_bytes(response.stdout)
        (evidence/(label+'-observer.stderr.txt')).write_bytes(response.stderr)
        response.check_returncode()
        value = json.loads((evidence/(label+'.json')).read_text())
        assert value['before'] == value['after'] and value['before']['head'] == git('rev-parse','HEAD')
        assert value['before']['original_project_files'] == positive['before']['original_project_files']
        assert value['before']['sparse'] == positive['before']['sparse']
        return value

    save()
    try:
        for role, path in PATHS.items():
            assert clean()
            subprocess.run(['git','switch','--detach',candidate], cwd=root, check=True, capture_output=True)
            subprocess.run(['git','switch','-c',branches[role]], cwd=root, check=True, capture_output=True)
            file = (root/path).resolve()
            assert file.is_relative_to(root) and file.is_file() and not file.is_symlink()
            original = file.read_bytes()
            if role == 'SOURCE':
                old = b'if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.'
                assert original.count(old) == 1
                changed = original.replace(old, old.replace(b'1d-10', b'2d-10'), 1)
                recipe = dict(original_expression=old.decode(), never_merge_test_guard='2d-10')
            elif role == 'PUBLICATION':
                changed = original+b'\n \n'
                recipe = dict(append_only_JSON_whitespace=True, original_document_values_unchanged=True)
            else:
                offset = len(original)//2
                changed = bytearray(original)
                changed[offset] ^= 1
                changed = bytes(changed)
                recipe = dict(offset=offset, xor_hex='01', old_byte=original[offset], new_byte=changed[offset])
            file.write_bytes(changed)
            subprocess.run(['git','add','--',path], cwd=root, check=True, capture_output=True)
            subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','commit','-m',
                            'NEVER MERGE paired9 combined '+role.lower()+' public negative'], cwd=root, check=True, capture_output=True)
            head = git('rev-parse','HEAD')
            item = dict(role=role, path=path, branch=branches[role], head=head,
                        exact_parent=candidate, actual_original_file_sha256=SHA(original),
                        actual_mutated_file_sha256=SHA(changed), mutation_recipe=recipe,
                        status='ACTUAL_COMMITTED_PENDING_PUSH', never_merge=True)
            record['controls'].append(item)
            save()
            push = subprocess.run(['git','-c','gc.auto=0','-c','maintenance.auto=false','-c','pack.threads=2',
                                   'push','origin','HEAD:refs/heads/'+branches[role]], cwd=root, capture_output=True, timeout=180)
            label = 'EXPLICIT_BOTTOM9_COMBINED_FINAL_'+role+'_NEGATIVE'
            (evidence/(label+'_PUSH_V5.stdout.txt')).write_bytes(push.stdout)
            (evidence/(label+'_PUSH_V5.stderr.txt')).write_bytes(push.stderr)
            push.check_returncode()
            assert git('ls-remote','origin','refs/heads/'+branches[role]).split()[0] == head
            assert git('show','-s','--format=%P',head) == candidate
            assert git('diff','--name-only',candidate,head) == path and clean()
            item['status'] = 'ACTUAL_COMMITTED_PUSHED_PENDING_PUBLIC_REFUSAL'
            save()
            observed = observe(label+'_PUBLIC_V5')
            error = (evidence/(label+'_PUBLIC_V5.stderr.txt')).read_bytes()
            assert observed['status'] == 'ACTUAL_PUBLIC_COMMAND_RETURNED'
            assert observed['returncode'] not in (None,0) and b'AssertionError' in error
            item.update(status='ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_REFUSED', actual_refusal=True,
                        actual_public_seconds=observed['seconds'], actual_public_returncode=observed['returncode'],
                        actual_public_stderr_sha256=SHA(error), actual_one_file_delta=True)
            save()
            if role == 'PUBLICATION':
                pub_label = label+'_SCOPE_V5'
                scope = observe(pub_label, publication=True)
                assert scope['returncode'] == 0
                assert 'PUBLICATION_REPLAY_SELECTED=true' in (evidence/(pub_label+'.stdout.txt')).read_text()
                assert not (evidence/(pub_label+'.stderr.txt')).read_bytes()
                item['actual_publication_replay_selected'] = True
                save()
            print('ACTUAL_COMMITTED_PUSHED_CLEAN14_NEGATIVE_REFUSED',role,head,observed['seconds'],flush=True)
        record['status'] = 'FOUR_ACTUAL_COMMITTED_PUSHED_CLEAN14_PUBLIC_NEGATIVES_REFUSED'
    except Exception as error:
        record.update(status='FAILED_ACTUAL_NEGATIVE_CAMPAIGN_NOT_QUALIFIED', error=repr(error))
        raise
    finally:
        save()
        if clean():
            subprocess.run(['git','switch',branch_before], cwd=root, check=True, capture_output=True)
    assert git('rev-parse','HEAD') == candidate and clean()
    print(record['status'], flush=True)


if __name__ == '__main__':
    main()
