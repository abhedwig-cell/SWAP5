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


def validate_inherited_review(name, record, canonical_head):
    """Accept only an explicitly reviewed and hash-bound dependency delta."""
    inheritance = json.loads((AUDIT / 'evidence/SWAP431_B19_MASTER_RECONCILIATION.json').read_text())
    assert inheritance['canonical_head'] == canonical_head, 'stale inheritance baseline'
    assert record['baseline'] == inheritance['old_baseline'], 'wrong historical review baseline'
    review = inheritance['inherited_reviews'][name]
    raw = (AUDIT / 'evidence' / name).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == review['record_sha256'], 'historical review changed'
    for path, expected in record['source_files_sha256'].items():
        if path in review['changed_dependencies']:
            delta = review['changed_dependencies'][path]
            assert delta['old_sha256'] == expected, 'inheritance preimage mismatch'
            expected = delta['current_sha256']
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == expected, f'stale inherited dependency: {path}'


def validate(require_closed=False):
    ledger = json.loads((AUDIT / 'SWAP431_FUNCTIONAL_COVERAGE_MASTER.json').read_text())
    census = json.loads((AUDIT / 'evidence/SWAP431_SOURCE_CENSUS.json').read_text())
    work = json.loads((AUDIT / 'SWAP431_REMAINING_WORKUNITS.json').read_text())
    reachability = json.loads((AUDIT / 'evidence/SWAP431_IMPLEMENTATION_REACHABILITY_REVIEW.json').read_text())
    validate_inherited_review('SWAP431_IMPLEMENTATION_REACHABILITY_REVIEW.json', reachability, ledger['canonical_head'])
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
    groundwater = json.loads((AUDIT / 'evidence/SWAP431_GROUNDWATER_PROJECTION_PROBE.json').read_text())
    assert hashlib.sha256(members[groundwater['source_member']]).hexdigest() == groundwater['source_sha256']
    assert hashlib.sha256((ROOT / groundwater['production_source']).read_bytes()).hexdigest() == groundwater['production_sha256']
    import probe_swap431_groundwater_projection as groundwater_probe
    assert hashlib.sha256(groundwater_probe.DRIVER.encode()).hexdigest() == groundwater['driver_sha256']
    assert hashlib.sha256(groundwater_probe.STUBS.encode()).hexdigest() == groundwater['stubs_sha256']
    assert [r['optimization'] for r in groundwater['results']] == ['-O0', '-O2']
    assert all(r['passed'] and r['cases'] == 6 for r in groundwater['results'])
    assert groundwater['results'][0]['stdout'] == groundwater['results'][1]['stdout']
    import re
    active_gwl_source = '\n'.join(line.split('!')[0] for line in members['SWAP/calcgwl.f90'].decode('latin1').splitlines())
    assert set(re.findall(r'=\s*gwlevel\s*\(\s*(\d+)', active_gwl_source, re.I)) == {'1', '3'}
    assert by_id['SW431-GW-INACTIVE-AVERAGE']['current_disposition'] == 'NOT_APPLICABLE'
    assert by_id['SW431-GW-PROJECTION']['active_workunit'] == 'MC-LOW01'
    foundations = {f['foundation_id']: f for f in ledger.get('swap5_admitted_foundations', [])}
    assert not ids.intersection(foundations), 'foundation counted as legacy capability'
    for foundation in foundations.values():
        assert foundation['current_disposition'] == 'ADMITTED', 'non-admitted foundation'
        for path in foundation['implementation_authority'] + foundation['evidence']:
            assert (ROOT / path).is_file(), f'missing foundation authority: {path}'
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
        for anchor in entry.get('closed_foundation_authorities', []):
            assert anchor in foundations or (anchor in by_id and by_id[anchor]['current_disposition'] in {'ADMITTED', 'SUPERSEDED'}), f'{cap}: unresolved/unknown foundation {anchor}'
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
    # A source-derived label can be wrong even while its JSON shape is valid.
    # Bind the resumed drainage decisions to the reviewed source postimage and
    # protect the concrete selector mix-up found during this census.
    assert by_id['SW431-DRAIN-TAB']['legacy_selector'] == 'DRAMET=1', 'wrong tabulated drainage selector'
    assert 'DRAMET=3' in by_id['SW431-DRAIN-LINEAR']['legacy_selector'], 'wrong linear contribution selector'
    for cap in ['SW431-DRAIN-DIV-SIGNED', 'SW431-DRAIN-DIV-MULTI',
                'SW431-DRAIN-DIV-TOPINTERFLOW', 'SW431-DRAIN-DISLAYER', 'SW431-DRAIN-INF-SPLIT']:
        assert by_id[cap]['legacy_source_authority']['member'] == 'SWAP/divdra.f90', 'wrong DIVDRA source member'
    admission = json.loads((AUDIT / 'PPA_WU05B19_CANONICAL_ADMISSION.json').read_text())
    assert admission['runtime_admitted'] and by_id['SW431-FROST-DIVDRA']['current_disposition'] == 'ADMITTED'
    assert 'SW431-FROST-DIVDRA' not in by_id['SW431-FROST-DIV-MULTI']['remaining_dependency']
    crop = json.loads((AUDIT / 'evidence/SWAP431_CROP_RESOLUTION_REVIEW.json').read_text())
    assert crop['baseline'] == ledger['canonical_head'] and not crop['new_admission_created']
    for path, expected in crop['source_files_sha256'].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == expected, f'stale crop review: {path}'
    replay = crop['test']
    assert replay['exit_code'] == 0
    assert hashlib.sha256(replay['stdout_stderr'].encode()).hexdigest() == replay['stdout_stderr_sha256']
    assert 'F_WOF_PP03_FWO38_FWO39_CURRENT_CONTRACT_PRESERVATION_GATE PASS' in replay['stdout_stderr']
    for name in ['SWAP431_OWNER_GAPS_RECONCILIATION.json', 'SWAP431_NFIX_REPLACEMENT_PROBE.json',
                 'SWAP431_RAIN_TYPED_MAPPING_PROBE.json',
                 'SWAP431_SURFACE_CROP_OWNER_RECONCILIATION.json']:
        record = json.loads((AUDIT / 'evidence' / name).read_text())
        assert record['baseline'] == ledger['canonical_head'], 'stale owner/input review baseline'
        for path, expected in record['source_files_sha256'].items():
            assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == expected, f'stale owner/input review: {path}'
        for path, expected in record.get('legacy_members_sha256', {}).items():
            assert hashlib.sha256(members[path]).hexdigest() == expected, f'stale legacy owner review: {path}'
        for cap, decision in record.get('decisions', {}).items():
            assert by_id[cap]['resolution_decision'] == decision, f'owner decision mismatch: {cap}'
        if 'results' in record:
            assert not record['runtime_admission_created']
            assert hashlib.sha256(members[record['source_member']]).hexdigest() == record['source_sha256']
            assert {r['optimization'] for r in record['results']} == {'-O0', '-O2'}
            assert all(r['exit_code'] == 0 for r in record['results'])
            assert len({r['stdout'] for r in record['results']}) == 1
    for cap in ['SW431-MET-RAIN2', 'SW431-MET-RAIN3']:
        assert by_id[cap]['current_disposition'] == 'SUPERSEDED'
        assert by_id[cap]['classification'] == 'LEGACY_COMPATIBILITY'
    aquifer = json.loads((AUDIT / 'evidence/SWAP431_AQUIFER_BOUNDS_PROBE.json').read_text())
    assert aquifer['baseline'] == ledger['canonical_head'] and not aquifer['runtime_admission_created']
    raw = members[aquifer['source_member']]
    assert hashlib.sha256(raw).hexdigest() == aquifer['source_sha256']
    source = raw.decode('latin1')
    start = source.index('            if (swbr == 1) then', source.index('! ---       solute balance in aquifer'))
    end = source.index('! ---       flux to surface water from aquifer', start)
    assert hashlib.sha256(source[start:end].encode()).hexdigest() == aquifer['literal_sha256']
    assert len(aquifer['results']) == 8
    assert {(r['optimization'], r['nodes'], r['qdrtot']) for r in aquifer['results']} == {
        (opt, nodes, flow) for opt in ['-O0', '-O2'] for nodes in [1, 3] for flow in ['0.1', '-0.1']}
    for result in aquifer['results']:
        assert result['exit_code'] != 0 and result['expected_bounds_failure']
        expected = f"Index '{result['nodes'] + 1}' of dimension 1 of array 'bdenskfsatporos' above upper bound of {result['nodes']}"
        assert expected in result['stderr']
    assert by_id['SW431-SALT-AQUIFER']['current_disposition'] == 'ACTIVE_MIGRATION'
    assert by_id['SW431-ICE']['classification'] == 'CORE_PHYSICS'
    for name in ['SWAP431_SEEPAGE_RUNTIME_INITIAL_PROBE.json',
                 'SWAP431_SEEPAGE_RUNTIME_ATTRIBUTION_PROBE.json',
                 'SWAP431_SEEPAGE_RUNTIME_PROBE.json']:
        probe = json.loads((AUDIT / 'evidence' / name).read_text())
        assert probe['baseline'] == ledger['canonical_head'] and not probe['runtime_admission_created']
        for path, expected in probe['source_files_sha256'].items():
            assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == expected, f'stale seepage dependency: {path}'
        fixture = (ROOT / probe['fixture']).read_text()
        assert hashlib.sha256(fixture.encode()).hexdigest() == probe['fixture_sha256']
        for old, new in probe['fixture_replacements'].items():
            assert fixture.count(old) == 1
            fixture = fixture.replace(old, new)
        assert hashlib.sha256(fixture.encode()).hexdigest() == probe['generated_fixture_sha256']
        assert len(probe['results']) == 6
        if name == 'SWAP431_SEEPAGE_RUNTIME_PROBE.json':
            assert all(r['exit_code'] == 0 for r in probe['results'])
            for selector, k in [(2, '0'), (1, '0.1'), (2, '0.1')]:
                pair = [r for r in probe['results'] if r['selector'] == selector and r['horizontal_k'] == k]
                assert {r['optimization'] for r in pair} == {'-O0', '-O2'}
                assert len({r['stdout'] for r in pair}) == 1
        else:
            assert sum(r['exit_code'] == 0 for r in probe['results']) == 2
            assert all(r['horizontal_k'] == '0' or 'positive seepage alone increases macro storage' in r['stderr']
                       for r in probe['results'])
    assert by_id['SW431-SW-MULTILEVEL']['legacy_selector'] == 'SWDRA=2;SWSEC=2;NRLEVS-NRPRI>1'
    for name in ['SWAP431_DRAIN_LOWER_RAIN_RECONCILIATION.json', 'SWAP431_DRAMET3_REPLACEMENT_PROBE.json']:
        record = json.loads((AUDIT / 'evidence' / name).read_text())
        if 'findings' in record:
            validate_inherited_review(name, record, ledger['canonical_head'])
            for finding in record['findings']:
                assert finding['capability_id'] in ids, 'unknown reviewed capability'
                assert hashlib.sha256(members[finding['legacy_member']]).hexdigest() == finding['source_sha256']
        else:
            for path, expected in record['source_files_sha256'].items():
                assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == expected, f'stale review: {path}'
            assert hashlib.sha256(members[record['source_member']]).hexdigest() == record['source_sha256']
            assert not record['runtime_admission_created']
            assert {r['optimization'] for r in record['results']} == {'-O0', '-O2'}
            assert len({r['stdout'] for r in record['results']}) == 1, 'DRAMET3 optimization mismatch'
            assert all('DRAMET3_REPLACEMENT_COUNTEREXAMPLE_PASS' in r['stdout'] for r in record['results'])
    swcf_path = AUDIT / 'evidence/SWAP431_SWCF2_ADMISSION_RECONCILIATION.json'
    if swcf_path.exists():
        swcf = json.loads(swcf_path.read_text())
        assert swcf['daily_evaluator_identical_to_admitted_commit']
        assert not swcf['new_runtime_admission_created']
        for path, expected in swcf['source_files_sha256'].items():
            assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == expected, 'stale SWCF2 postimage'
        assert {r['optimization'] for r in swcf['results']} == {'-O0', '-O2'}
        assert all(r['cases'] == 3 and 'SWCF2_PMDIRECT_DAILY_PASS' in r['stdout'] for r in swcf['results'])
    seepage_path = AUDIT / 'evidence/SWAP431_MACROPORE_SEEPAGE_PROBE.json'
    if seepage_path.exists():
        seepage = json.loads(seepage_path.read_text())
        assert hashlib.sha256(members[seepage['source_member']]).hexdigest() == seepage['source_sha256'], 'stale seepage source'
        assert hashlib.sha256((ROOT / seepage['provider']).read_bytes()).hexdigest() == seepage['provider_sha256'], 'stale seepage provider'
        assert not seepage['runtime_admission_created'], 'component probe used as runtime admission'
        assert {r['optimization'] for r in seepage['results']} == {'-O0', '-O2'}
        assert all(r['cases'] == 48 and r['max_relative_error'] <= 1e-12 for r in seepage['results'])
    probe_path = AUDIT / 'evidence/SWAP431_TILLAGE_DEFECT_PROBE.json'
    if probe_path.exists():
        probe = json.loads(probe_path.read_text())
        assert hashlib.sha256(members[probe['source_member']]).hexdigest() == probe['source_sha256'], 'stale tillage probe source'
        assert not probe['production_reachability'], 'defect probe used as admission'
        assert {r['optimization'] for r in probe['results']} == {'-O0', '-O2'}, 'missing probe optimization'
        assert len({r['stdout'] for r in probe['results']}) == 1, 'probe optimization mismatch'
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
