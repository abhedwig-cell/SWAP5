#!/usr/bin/env python3
"""Validate coverage evidence integrity; --require-closed also enforces closure."""
import argparse
import base64
import collections
import gzip
import hashlib
import io
import json
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parents[2]
AUDIT = ROOT / 'integration/audits'
DISPOSITIONS = {'ADMITTED', 'SUPERSEDED', 'REJECTED', 'NOT_APPLICABLE', 'ACTIVE_MIGRATION'}
CLASSES = {'CORE_PHYSICS', 'APPLICATION_PHYSICS', 'LEGACY_COMPATIBILITY', 'LEGACY_IO', 'OBSOLETE_CONTROL_FLOW'}


def validate(require_closed=False):
    ledger = json.loads((AUDIT / 'SWAP431_FUNCTIONAL_COVERAGE_MASTER.json').read_text())
    census = json.loads((AUDIT / 'evidence/SWAP431_SOURCE_CENSUS.json').read_text())
    work = json.loads((AUDIT / 'SWAP431_REMAINING_WORKUNITS.json').read_text())
    reachability = json.loads((AUDIT / 'evidence/SWAP431_IMPLEMENTATION_REACHABILITY_REVIEW.json').read_text())
    assert reachability['baseline'] == ledger['canonical_head'], 'reachability baseline mismatch'
    for path, digest in reachability['source_files_sha256'].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, f'stale reachability evidence: {path}'
    compressed = base64.b64decode((ROOT / census['authority_bundle']).read_bytes(), validate=False)
    assert hashlib.sha256(compressed).hexdigest() == census['bundle_gzip_sha256'], 'source bundle SHA'
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(compressed))) as archive:
        members = {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
    assert len(members) == 63, 'source member count'
    assert sum(map(len, members.values())) == 1886519, 'source byte count'
    for row in census['members']:
        raw = members[row['path']]
        assert len(raw) == row['bytes'] and hashlib.sha256(raw).hexdigest() == row['sha256'], row['path']
    manifest = ''.join(f'{hashlib.sha256(raw).hexdigest()}  {len(raw):8d}  {name}\n' for name, raw in sorted(members.items())).encode('ascii')
    assert hashlib.sha256(manifest).hexdigest() == census['b111_manifest_sha256'], 'B1.11 manifest'
    entries = ledger['capabilities']
    ids = {e['capability_id'] for e in entries}
    by_id = {e['capability_id']: e for e in entries}
    assert len(ids) == len(entries), 'duplicate capability ID'
    assert ledger['summary']['capabilities'] == len(entries), 'stale capability count'
    registered = {u['id']: u for u in work['new_workunits']}
    registered['PPA-WU05B19'] = {'capabilities': ['SW431-FROST-DIVDRA']}
    for entry in entries:
        cap = entry['capability_id']
        assert entry['current_disposition'] in DISPOSITIONS, cap
        assert entry['classification'] in CLASSES, cap
        for path in entry['evidence'] + entry['swap5_implementation_authority']:
            assert (ROOT / path).is_file(), f'{cap}: missing {path}'
        source = entry['legacy_source_authority']
        assert hashlib.sha256(members[source['member']]).hexdigest() == source['sha256'], cap
        lines = members[source['member']].decode('latin1').splitlines()
        assert source['locator_lines'] and all(1 <= n <= len(lines) for n in source['locator_lines']), cap
        assert set(entry['remaining_dependency']) <= ids, f'{cap}: dangling dependency'
        assert all(by_id[d]['current_disposition'] == 'ACTIVE_MIGRATION' for d in entry['remaining_dependency']), f'{cap}: closed dependency treated as blocker'
        if entry['current_disposition'] == 'ACTIVE_MIGRATION':
            assert entry['active_workunit'] in registered, f'{cap}: unregistered workunit'
            assert cap in registered[entry['active_workunit']]['capabilities'], cap
            assert not entry['production_reachability']['established'], cap
        else:
            assert entry['active_workunit'] is None, cap
            assert not entry['remaining_dependency'], f'{cap}: final disposition still has unresolved dependency'
        if entry['current_disposition'] in {'ADMITTED', 'SUPERSEDED'}:
            assert entry['swap5_implementation_authority'] and entry['evidence'], cap
            assert entry['production_reachability']['established'], cap
    graph = {e['capability_id']: e['remaining_dependency'] for e in entries}
    visiting, done = set(), set()
    def visit(cap):
        assert cap not in visiting, f'dependency cycle: {cap}'
        if cap in done:
            return
        visiting.add(cap)
        for dep in graph[cap]:
            visit(dep)
        visiting.remove(cap)
        done.add(cap)
    for cap in graph:
        visit(cap)
    depths = {}
    def depth(cap):
        if cap not in depths:
            depths[cap] = max((depth(dep) + 1 for dep in graph[cap]), default=0)
        return depths[cap]
    for entry in entries:
        assert entry['migration_priority']['dependency_depth'] == depth(entry['capability_id']), 'stale dependency depth'
    counts = dict(collections.Counter(e['current_disposition'] for e in entries))
    active = [e for e in entries if e['current_disposition'] == 'ACTIVE_MIGRATION']
    assert ledger['summary']['dispositions'] == counts, 'stale summary'
    assert ledger['summary']['open_capabilities'] == len(active), 'stale open count'
    confirmed = sum(e.get('implementation_absence_proven', False) for e in active)
    assert ledger['summary']['confirmed_missing_production_entries'] == confirmed, 'stale proven-gap count'
    assert ledger['summary']['other_unresolved_source_admission_reviews'] == len(active)-confirmed, 'stale review count'
    for call in census['integer_input_calls']:
        assert set(call['capability_navigation']) <= ids, 'dangling selector navigation'
    if 'pr_reconciliation' in ledger:
        snapshot = json.loads((ROOT/ledger['pr_reconciliation']['complete_current_snapshot']).read_text())
        review = json.loads((ROOT/ledger['pr_reconciliation']['migration_reconciliation']).read_text())
        for kind in ['open', 'recent_merged']:
            pages = [p for p in snapshot['pages'] if p['kind'] == kind]
            numbers = {x['number'] for p in pages for x in p['items']}
            assert snapshot[kind]['pagination_complete'] and len(numbers) == snapshot[kind]['unique_count'], 'PR pagination'
            assert snapshot[kind]['reported_totals'] == [len(numbers)] and not snapshot[kind]['incomplete_results'], 'PR total'
        for row in review['entries']:
            assert set(row['capabilities']) <= ids, 'dangling PR capability'
            if 'authority' in row:
                assert (ROOT/row['authority']).is_file(), 'missing PR reconciliation authority'
    assert {e['capability_id'] for e in ledger['remaining_queue']} == {e['capability_id'] for e in active}, 'queue mismatch'
    for row in ledger['remaining_queue']:
        assert row['dependencies'] == by_id[row['capability_id']]['remaining_dependency'], 'stale queue dependencies'
    priority_fields = ['dependency_depth', 'functional_relevance', 'implementation_extent', 'physical_risk', 'regression_risk']
    ordered = sorted(ledger['remaining_queue'], key=lambda row: tuple(row['priority'][k] for k in priority_fields) + (row['capability_id'],))
    assert ledger['remaining_queue'] == ordered, 'queue ordering mismatch'
    if ledger['coverage_closed'] or require_closed:
        assert ledger['denominator_complete'] and census['census_complete'], 'denominator incomplete'
        assert not active, f'{len(active)} unresolved capabilities'
        assert ledger['closure_statement'] == 'SWAP431 FUNCTIONAL COVERAGE CLOSED', 'closure statement'
    return {'schema': 'swap5.coverage_integrity_result.v1', 'integrity': 'PASS', 'baseline': ledger['canonical_head'], 'source_members': len(members), 'capabilities': len(entries), 'dispositions': counts, 'denominator_complete': ledger['denominator_complete'], 'coverage_closed': ledger['coverage_closed'], 'claim': 'Evidence integrity only; not independent physics qualification or admission'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--require-closed', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(validate(args.require_closed), indent=2))
    except (AssertionError, KeyError, ValueError) as exc:
        parser.exit(1, f'SWAP431_COVERAGE_FAIL: {exc}\n')
