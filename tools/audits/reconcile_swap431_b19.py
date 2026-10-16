#!/usr/bin/env python3
"""Apply the reviewed, bounded B19 admission delta to the master ledger.

This is a pinned reconciliation, not an admission inference engine. Historical
reviews remain immutable; dependency inheritance is separately hash-bound.
"""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
A = ROOT / 'integration/audits'
OLD = 'e5eab995ef04fc813dd644025fb0f32e4f5050a1'
NEW = '78acf56f931763d2e1d4924b3dea0742f231d2e8'
EVIDENCE = 'integration/audits/evidence/SWAP431_B19_MASTER_RECONCILIATION.json'


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)


def main():
    subprocess.run(['git', 'merge-base', '--is-ancestor', NEW, 'HEAD'], cwd=ROOT, check=True)
    admission = read(A / 'PPA_WU05B19_CANONICAL_ADMISSION.json')
    assert admission['runtime_admitted'] is True
    assert git('rev-parse', 'HEAD:src').decode().strip() == admission['production_source_tree']
    ledger = read(A / 'SWAP431_FUNCTIONAL_COVERAGE_MASTER.json')
    assert ledger['canonical_head'] in (OLD, NEW)
    ledger['canonical_head'] = NEW
    by_id = {e['capability_id']: e for e in ledger['capabilities']}
    cap = by_id['SW431-FROST-DIVDRA']
    cap.update(current_disposition='ADMITTED', active_workunit=None,
               coverage_gap_type=None, implementation_absence_proven=False,
               workunit_stage='CANONICALLY_ADMITTED_BOUNDED_RUNTIME',
               resolution_stage='CLOSED_WITHIN_EXPLICIT_ENVELOPE')
    cap.pop('absence_search_scope', None)
    cap['meaning'] = 'Single-level signed trial-start frost/DIVDRA redistribution'
    cap['legacy_selector'] = 'SWFROST=1;SWDIVD=1;single level;SWDIVDINF=0/1'
    cap['swap5_implementation_authority'] = [
        'src/process/mod_frost_divdra_drainage_effect.f90',
        'src/runtime/mod_fmr_serialized_reference_backend.f90',
        'src/runtime/mod_fmr_production_application_bootstrap.f90']
    cap['evidence'] = ['integration/audits/PPA_WU05B19_CANONICAL_ADMISSION.json',
                       'docs/audits/PPA_WU05B19_CANONICAL_CLOSEOUT.md', EVIDENCE]
    cap['production_reachability'] = dict(established=True,
        route='frost_divdra_active -> immutable trial-start proposal -> existing nodal/bottom owners',
        claim=admission['scope'])
    cap['restrictions'] = [
        'Rootless ordinary serialized Reference; prescribed constant bottom mode2; default MvG and restricted sensible temperature.',
        'One level; bracketed frost geometry; normal and guarded low-air routes; separate infiltration only in the qualified domain.',
        'No mixed nodal/response drainage owners, roots, salt, snow, macropores, elasticity, alternative constitutive law or surface-water coupling.',
        'Zero scalar allowed; nonzero abs(scalar)<=1e-10 rejected. No phase change, latent heat, full-winter or multilevel claim.']
    for entry in ledger['capabilities']:
        if cap['capability_id'] in entry['remaining_dependency']:
            entry['remaining_dependency'].remove(cap['capability_id'])
            entry.setdefault('closed_foundation_authorities', []).append(cap['capability_id'])
    multi = by_id['SW431-FROST-DIV-MULTI']
    claim = 'B19 admits the single-level runtime foundation. Interacting multilevel DIVDRA and its frost nodal/bottom composition remain unimplemented; scalar multilevel response is not spatial redistribution.'
    multi['production_reachability']['claim'] = claim
    multi['restrictions'] = [claim]
    multi['evidence'].append(EVIDENCE) if EVIDENCE not in multi['evidence'] else None
    for cid in ['SW431-DRAIN-DIV-SIGNED', 'SW431-DRAIN-INF-SPLIT']:
        entry = by_id[cid]
        claim = ('B19 now supplies a qualified signed/separate-infiltration runtime, but requires active frost and sensible temperature. '
                 'The ordinary no-frost runtime still binds positive-only single-level DIVDRA; the B19 configuration validator rejects frost-off. '
                 'Reuse B19 algebra/ownership contracts for the ordinary successor, without silently extending admission.')
        entry['production_reachability']['claim'] = claim
        entry['restrictions'] = [claim]
        if EVIDENCE not in entry['evidence']:
            entry['evidence'].append(EVIDENCE)
    # The previous review recorded real DIVDRA line numbers against the wrong
    # member name. Correct both authority and digest, not only the displayed label.
    div_source = dict(by_id['SW431-DRAIN-DIV']['legacy_source_authority'])
    corrected = ['SW431-DRAIN-DIV-SIGNED', 'SW431-DRAIN-DIV-MULTI',
                 'SW431-DRAIN-DIV-TOPINTERFLOW', 'SW431-DRAIN-DISLAYER',
                 'SW431-DRAIN-INF-SPLIT']
    for cid in corrected:
        source = by_id[cid]['legacy_source_authority']
        source.update(member=div_source['member'], sha256=div_source['sha256'])
    row = dict(workunit='PPA-WU05B19', status='CANONICALLY_ADMITTED_BOUNDED_RUNTIME',
               evidence='integration/audits/PPA_WU05B19_CANONICAL_ADMISSION.json',
               closes='SW431-FROST-DIVDRA', canonical_merge=admission['actual_canonical_merge'])
    ledger['canonical_reconciliations'] = [r for r in ledger['canonical_reconciliations'] if r['workunit'] != 'PPA-WU05B19'] + [row]
    ledger['pr_reconciliation']['snapshot_policy'] = 'Historical paginated inventory, supplemented by exact live delta; not a current open-PR count.'
    write(A / 'SWAP431_FUNCTIONAL_COVERAGE_MASTER.json', ledger)
    work = read(A / 'SWAP431_REMAINING_WORKUNITS.json')
    work['baseline'] = NEW
    for unit in work['new_workunits']:
        if unit['id'] == 'MC-DRAIN01':
            unit['next_action'] = 'Qualify ordinary frost-OFF signed DIVDRA using admitted B19 algebra and ownership; native DRAMET3 controls, multilevel partitions and altered discharge layers remain separate slices.'
    write(A / 'SWAP431_REMAINING_WORKUNITS.json', work)
    record = dict(schema_version='1.0', old_baseline=OLD, canonical_head=NEW,
                  admission_authority='integration/audits/PPA_WU05B19_CANONICAL_ADMISSION.json',
                  new_admission_created=False, corrected_legacy_member_ids=corrected,
                  historical_review_overrides=['SW431-FROST-DIVDRA', 'SW431-FROST-DIV-MULTI',
                                               'SW431-DRAIN-DIV-SIGNED', 'SW431-DRAIN-INF-SPLIT'],
                  inherited_reviews={})
    for name in ['SWAP431_IMPLEMENTATION_REACHABILITY_REVIEW.json', 'SWAP431_DRAIN_LOWER_RAIN_RECONCILIATION.json']:
        path = A / 'evidence' / name
        previous = read(path)
        changes = {}
        for source, old_hash in previous['source_files_sha256'].items():
            raw = (ROOT / source).read_bytes()
            assert raw == git('show', NEW + ':' + source)
            digest = hashlib.sha256(raw).hexdigest()
            if digest != old_hash:
                assert source in ['src/runtime/mod_fmr_serialized_reference_backend.f90',
                                  'src/runtime/mod_fmr_production_application_bootstrap.f90']
                assert hashlib.sha256(git('show', OLD + ':' + source)).hexdigest() == old_hash
                changes[source] = dict(old_sha256=old_hash, current_sha256=digest)
        record['inherited_reviews'][name] = dict(
            record_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), changed_dependencies=changes,
            rationale='Reviewed B19 default-OFF addition. Historical frost-DIVDRA absence conclusions are superseded explicitly; ordinary frost-off, crop, MICRO, constitutive and solute findings remain unchanged. B19 source-bound verifier checks full inherited preservation receipts.')
    write(ROOT / EVIDENCE, record)


if __name__ == '__main__':
    main()
