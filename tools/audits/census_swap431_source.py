#!/usr/bin/env python3
"""Rebuild selector navigation from the pinned full B1.11 source bundle."""
import argparse
import base64
import collections
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / 'integration/audits/evidence/SWAP431_SOURCE_CENSUS.json'


def inventory():
    previous = json.loads(PATH.read_text())
    compressed = base64.b64decode((ROOT / previous['authority_bundle']).read_bytes())
    assert hashlib.sha256(compressed).hexdigest() == previous['bundle_gzip_sha256']
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(compressed))) as archive:
        source = {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
    calls, branches, routines = [], [], []
    for member, raw in sorted(source.items()):
        for line_number, line in enumerate(raw.decode('latin1').splitlines(), 1):
            code = line.split('!')[0].strip()
            if not code:
                continue
            for match in re.finditer(r'\bcall\s+(rd(?:s|f|a)[a-z0-9_]+)\s*\(', code, re.I):
                reader = match.group(1).lower()
                if reader in {'rdsets', 'rdfrom'}:
                    continue
                remainder = code[match.end():]
                name = re.match(r"\s*['\"]([^'\"]+)['\"]", remainder)
                calls.append({'member': member, 'line': line_number, 'reader': reader,
                              'literal_name': name.group(1).strip() if name else None,
                              'source': code, 'computed_name': name is None})
            if re.search(r'\b(if|else\s*if|select\s+case|case)\b', code, re.I) and re.search(r'\bsw[a-z0-9_]+|\b(tcs|dcs|ihwckmodel|imicro|ipos|dramet)\b', code, re.I):
                branches.append({'member': member, 'line': line_number, 'source': code})
            name = re.match(r'(?:[a-z0-9_()*,]+\s+)*(?:subroutine|function)\s+(\w+)\s*\(', code, re.I)
            if name and not code.lower().startswith('end'):
                routines.append({'member': member, 'line': line_number, 'name': name.group(1)})
    ledger = json.loads((ROOT / 'integration/audits/SWAP431_FUNCTIONAL_COVERAGE_MASTER.json').read_text())
    aliases = collections.defaultdict(set)
    for entry in ledger['capabilities']:
        for token in re.findall(r'[A-Za-z_][A-Za-z_0-9]*', entry['legacy_selector']):
            aliases[token.lower()].add(entry['capability_id'])
    integer = [c for c in calls if c['reader'].endswith(('int', 'inr', 'log'))]
    for call in integer:
        call['capability_navigation'] = sorted(aliases[(call['literal_name'] or '').lower()])
        call['navigation_is_disposition_proof'] = False
    result = dict(previous)
    result.update(schema_version='1.1', canonical_head=ledger['canonical_head'],
                  census_complete=False, input_reader_calls=calls,
                  integer_input_calls=integer, selector_branch_navigation=branches,
                  routine_navigation=routines,
                  inventory_summary={'input_reader_calls': len(calls),
                                     'integer_boolean_calls': len(integer),
                                     'selector_branch_locators': len(branches),
                                     'routine_locators': len(routines),
                                     'unmapped_integer_boolean_calls': sum(not c['capability_navigation'] for c in integer)})
    result['limits'] = ['Navigation scan is reproducible, not a Fortran call-graph or physical-equivalence proof.',
                        'Computed names, continuations, real/logical controls, constant guards and cross-option reachability require source review.',
                        'Mapped selector names are not proof of complete subselector or composition dispositions.',
                        'Global denominator remains incomplete until these reviews are closed.']
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    result = inventory()
    if args.write:
        PATH.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result['inventory_summary'], indent=2))
