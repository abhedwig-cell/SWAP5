#!/usr/bin/env python3
"""Verify actual moving preservation and the original highest workspace matrix.

This is a bounded scientific/preservation receipt, never a 10x or admission gate.
"""
import base64, hashlib, io, json, pathlib, subprocess, sys, tarfile, tempfile
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2] / 'tools/performance'))
from verify_low_air_successor import ROOT, CAPSULE as PRIOR_CAPSULE, verify_successor
from low_air_fine_worker_recipe import reuse_fine_workspace
from verify_low_air_ab import verify

CAPSULE = 'integration/audits/evidence/LOW_AIR_10X_CONTINUATION_20261014.tar.xz.b64'
CAPSULE_SHA = '0562ce36bd167854a8b59f6f7d267d24c65277bd516753ccb54ac1fce70fb5ed'
EXCLUDED = {
    'tests/modularity/test_low_air_development.f90',
    'tools/performance/run_low_air_ab.py',
    'tools/performance/run_low_air_final_candidate.py',
}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def verify_continuation():
    prerequisite = verify_successor()
    raw = base64.b64decode((ROOT / CAPSULE).read_bytes())
    if sha(raw) != CAPSULE_SHA:
        raise ValueError('continuation capsule corruption')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        read = lambda name: archive.extractfile(name).read()
        index = json.loads(read('INDEX.json'))
        if set(archive.getnames()) != set(index) | {'INDEX.json'}:
            raise ValueError('unindexed members')
        for name, expected in index.items():
            if sha(read(name)) != expected:
                raise ValueError('member corruption ' + name)
        owner = json.loads(read('OWNER.json'))
        if owner['source_tree'] != prerequisite['source']['source_tree']:
            raise ValueError('foreign production source')
        if set(owner['preservation_excluded_paths']) != EXCLUDED:
            raise ValueError('foreign preservation exclusion')
        for path, expected in owner['preserved_input_blobs'].items():
            actual = subprocess.check_output(['git', 'hash-object', '--stdin'], input=(ROOT / path).read_bytes(), cwd=ROOT).decode().strip()
            if actual != expected:
                raise ValueError('preservation input drift ' + path)
        if sha((ROOT / 'tools/performance/low_air_fine_worker_recipe.py').read_bytes()) != owner['recipe_sha256']:
            raise ValueError('fine recipe drift')
        if sha(read('LOW_AIR_10X_CONTINUATION_EXECUTED.bundle')) != owner['recovery_bundle_sha256']:
            raise ValueError('recovery bundle corruption')
        moving = json.loads(read('moving-qualified/RESULTS.json'))
        if moving['exit'] != 0 or moving['source_tree'] != owner['source_tree'] or moving['canonical_parent'] != owner['baseline'] or moving['candidate_parent'] != owner['preserved_commit']:
            raise ValueError('wrong moving preservation binding')
        if moving['command'] != ['bash', 'tests/fci/run_fci_canonical_p2e05_moving_preservation.sh']:
            raise ValueError('wrong preservation command')
        if b'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS' not in read('moving-qualified/stdout'):
            raise ValueError('incomplete moving preservation')
        expected = (ROOT / 'tests/frost/test_ppa_wu05b15_low_air_runtime.f90').read_text()
        expected = expected.replace('    config%transaction%retry_scale = 0.5_real64', '    config%retain_accepted_step_proposal = .true.\n    config%transaction%retry_scale = 0.5_real64')
        expected = expected.replace('    cfg%numerical%transaction%retry_scale=.5_real64', '    cfg%numerical%retain_accepted_step_proposal=.true.\n    cfg%numerical%transaction%retry_scale=.5_real64')
        expected = reuse_fine_workspace(expected).encode()
        science = {}
        prior_raw = base64.b64decode((ROOT / PRIOR_CAPSULE).read_bytes())
        prior_archive = tarfile.open(fileobj=io.BytesIO(prior_raw))
        for opt in [0, 2]:
            prefix = f'final-workspace-qualification/qual-o{opt}/'
            report = json.loads(read(prefix + 'RESULTS.json'))
            if not report['fine_worker_reuse'] or report['repeat'] != 1 or read(prefix + 'candidate.f90') != expected:
                raise ValueError('changed original scientific recipe')
            with tempfile.TemporaryDirectory(prefix='swap5-low-air-closeout-') as temporary:
                folder = pathlib.Path(temporary)
                (folder / 'RESULTS.json').write_text(json.dumps(report))
                for run in report['runs']:
                    name = f"{run['round']}-{run['family']}-{run['policy']}.stdout"
                    (folder / name).write_bytes(read(prefix + name))
                science[opt] = verify(folder)
            if science[opt]['trajectories'] != 6 or science[opt]['fine_comparisons'] != 36:
                raise ValueError('partial original highest matrix')
            build_prefix = f'final-workspace-qualification/build-o{opt}/'
            if sha(read(build_prefix + 'RESULTS.json')) != report['build_manifest_sha256']:
                raise ValueError('wrong compiled build manifest')
            if read(build_prefix + 'mod_canonical_interval_runtime.f90') != (ROOT / 'src/runtime/mod_canonical_interval_runtime.f90').read_bytes():
                raise ValueError('generated runtime provider drift')
            for path, expected_sha in report['sources'].items():
                if '/SWAP5/src/' in path:
                    relative = 'src/' + path.split('/SWAP5/src/', 1)[1]
                    if sha((ROOT / relative).read_bytes()) != expected_sha:
                        raise ValueError('compiled production input drift')
            control = json.loads(read(f'direct-workspace-controls-o{opt}/RESULTS.json'))
            if control['exit'] or control['full_owning_replaced'] or b'LOW_AIR_FINE_WORKSPACE_PER_STEP_AND_FAILED_REUSE=PASS' not in read(f'direct-workspace-controls-o{opt}/run.stdout'):
                raise ValueError('missing independent fine lifetime control')
            for family in range(1, 7):
                name = f'0-{family}-candidate.stdout'
                current = read(prefix + name)
                if current != read(f'direct-workspace-full-o{opt}/' + name) or current != read('final-workspace-qualification/qual-o0/' + name):
                    raise ValueError('repeat or O0/O2 science drift')
                if current != prior_archive.extractfile(f'final-current-qualification/qual-o{opt}/' + name).read():
                    raise ValueError('fresh worker owning science drift')
        prior_archive.close()
        feedback = json.loads(read('physical-workspace-feedback/RESULTS.json'))
        if feedback['status'] != 'PASS' or len(feedback['records']) != 4:
            raise ValueError('incomplete modular feedback')
        if {record['case'] for record in feedback['records']} != {'low_air_physical'} or {record['optimization'] for record in feedback['records']} != {0, 2}:
            raise ValueError('wrong modular matrix')
        for record in feedback['records']:
            for path, expected_sha in record['inputs'].items():
                if sha((ROOT / path).read_bytes()) != expected_sha:
                    raise ValueError('modular input drift ' + path)
            matches = [name for name in index if name.startswith('physical-workspace-feedback/') and name.endswith('science.stdout') and sha(read(name)) == record['stdout_sha256']]
            if not matches:
                raise ValueError('missing executed modular output')
        warm = json.loads(read('final-workspace-qualification/RESULTS.json'))
        if warm['tenfold_proved'] or not warm['fine_worker_reuse'] or warm['cold_end_to_end_ab'] != 'UNKNOWN':
            raise ValueError('false end-to-end performance authority')
    return {
        'scientific_highest_programs': 12, 'original_fine_comparisons': 72,
        'moving_preservation': 'PASS_ON_UNCHANGED_RELEVANT_INPUTS',
        'modular_feedback': 'PASS', 'warm_enclosing_wall_seconds': warm['whole_wall'],
        'warm_child_cpu_seconds': warm['whole_child_cpu'],
        'cold_end_to_end_ab': 'UNKNOWN', 'tenfold_proved': False,
        'canonical_admission': False,
    }

if __name__ == '__main__':
    print(json.dumps(verify_continuation(), indent=2))
