"""Reuse one actual canonical observation only at unchanged evidence bytes.

This is scoped to canonical21fce9bc6 and its registered public verification.
The caller must separately establish unchanged admitted numerical dependencies,
literal old owners/readers and current affected postimages. No cached result
authorizes a changed process, input, source or scientific domain.
"""
import hashlib
import json
from pathlib import Path

from calendar_evidence import extracted
from extended_forensics import require

CANONICAL = '21fce9bc6275d998d3936e035c39ed4204efa70b'
TREE = '4e9a19d002a456051ceeb8c5ab757bc494589d63'
ARCHIVE = 'EXTENDED_DRAINAGE_SECONDARY_POND_INHERITED_RAW_ARCHIVE.zip'
MANIFEST = 'SECONDARY_INHERITED_CANONICAL_OBSERVATION_V1.json'


def verify(root, proof):
    import secondary_pond_verify as owner
    owner.guard_previous_source()
    root, proof = Path(root), Path(proof)
    with extracted(proof/ARCHIVE) as (directory, _):
        manifest = json.loads((directory/MANIFEST).read_text())
        receipt = json.loads((directory/'IMPLICIT_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json').read_text())
        stdout = (directory/'IMPLICIT_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt').read_bytes()
        require(manifest['canonical'] == CANONICAL and manifest['tree'] == TREE and
                manifest['actual_owner_receipt'] == receipt,
                'Foreign inherited canonical observation')
        require(receipt['returncode'] == 0 and receipt['before'] == receipt['after'] and
                receipt['before']['head'] == CANONICAL and receipt['before']['tree'] == TREE and
                receipt['before']['status'] == '' and len(receipt['before']['sparse']) == 22 and
                receipt['command'][-1] == 'tests/hupsel51/verify_successor.py' and
                receipt['model_executions'] == 0 and receipt['stderr_bytes'] == 0,
                'Actual prior canonical owner did not pass on its clean source fixture')
        require(not (directory/'IMPLICIT_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stderr.txt').read_bytes() and
                len(stdout) == receipt['stdout_bytes'] == manifest['actual_owner_stdout']['bytes'] and
                hashlib.sha256(stdout).hexdigest() == manifest['actual_owner_stdout']['sha256'],
                'Actual inherited registered owner output changed')
        result = json.loads(stdout)
        require(result['status'] == 'BOUNDED_PRIMARY_EXTENDED_IMPLICIT_SOURCE_RAW_ADMISSION_PASS' and
                result['runtime'] == '9f472848850af09ecfd8221bb59e66357f7b7f7c' and
                result['functional_completion'] == 'PARTIAL' and
                result['whole_scientific_equivalence'] == 'NOT_QUALIFIED' and
                result['global_family_and_gap_counts'] == 'UNKNOWN' and result['RC3_changed'] is False,
                'Inherited observation promoted scope or belongs to another owner')
        excluded = {'integration/f-ci/nomacro-complete01/STATUS.json',
                    'integration/f-ci/nomacro-complete01/GAP_MATRIX.json'}
        require(set(manifest['excluded_recovery_metadata']) == excluded and
                len(manifest['members']) == 1751,
                'Inherited evidence inventory changed')
        total = 0
        for name, item in manifest['members'].items():
            require(name.startswith('integration/') and '..' not in name.split('/') and
                    '\\' not in name and ':' not in name and name not in excluded,
                    'Unsafe inherited evidence path')
            path = root/name
            require(path.is_file() and not path.is_symlink(),
                    'Missing inherited actual canonical evidence: '+name)
            body = path.read_bytes()
            if item['comparison'] == 'LF_NORMALIZED_TEXT':
                require(path.suffix.lower() in ('.json', '.md', '.yaml', '.yml', '.py', '.txt', '.log'),
                        'Inherited binary proof must retain exact bytes')
                body = body.replace(b'\r\n', b'\n')
            else:
                require(item['comparison'] == 'EXACT_RAW_BYTES', 'Foreign evidence comparison')
            require(len(body) == item['bytes'] and hashlib.sha256(body).hexdigest() == item['sha256'],
                    'Changed inherited actual canonical evidence: '+name)
            total += len(body)
    return dict(status='UNCHANGED_ACTUAL_CANONICAL_SCIENTIFIC_OBSERVATION_REUSED',
                actual_canonical=CANONICAL, actual_public_owner_seconds=receipt['elapsed_seconds'],
                evidence_files_verified=1751, evidence_bytes_verified=total,
                fresh_inherited_scientific_replays=0, fresh_inherited_models=0,
                original_scientific_bodies_retained=True,
                authority='Actual prior clean canonical registered owner plus unchanged evidence bytes; '
                          'fresh source/dependency and affected postimage gates are required separately',
                functional_completion='PARTIAL', whole_scientific_equivalence='NOT_QUALIFIED')
