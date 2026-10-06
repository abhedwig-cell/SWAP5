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


def uncomment(line):
    """Remove free-form comments while respecting doubled Fortran quotes."""
    quote, i = None, 0
    while i < len(line):
        char = line[i]
        if quote:
            if char == quote:
                if i + 1 < len(line) and line[i + 1] == quote:
                    i += 2
                    continue
                quote = None
        elif char in "'\"":
            quote = char
        elif char == '!':
            return line[:i]
        i += 1
    return line


def split_statements(code):
    quote, start, i = None, 0, 0
    while i < len(code):
        char = code[i]
        if quote:
            if char == quote:
                if i + 1 < len(code) and code[i + 1] == quote:
                    i += 2
                    continue
                quote = None
        elif char in "'\"":
            quote = char
        elif char == ';':
            yield code[start:i].strip()
            start = i + 1
        i += 1
    yield code[start:].strip()


def logical_statements(text):
    parts, start = [], None
    for number, line in enumerate(text.splitlines(), 1):
        code = uncomment(line).strip()
        if not code:
            continue
        if start is None:
            start = number
        elif code.startswith('&'):
            code = code[1:].lstrip()
        continued = code.endswith('&')
        parts.append(code[:-1].rstrip() if continued else code)
        if not continued:
            for statement in split_statements(' '.join(parts)):
                if statement:
                    yield start, number, statement
            parts, start = [], None
    assert not parts, 'unterminated source continuation'


def is_control_branch(code):
    # END IF/END SELECT are terminators, not new execution paths.
    return bool(re.match(r'^(?:\w+\s*:\s*)?(?:\d+\s+)?(?:if\s*\(|else\s*if\s*\(|elseif\s*\(|select\s+case\s*\(|case\s*(?:\(|default\b))', code, re.I))


def inventory():
    previous = json.loads(PATH.read_text())
    compressed = base64.b64decode((ROOT / previous['authority_bundle']).read_bytes())
    assert hashlib.sha256(compressed).hexdigest() == previous['bundle_gzip_sha256']
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(compressed))) as archive:
        source = {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
    calls, branches, routines, all_branches = [], [], [], []
    for member, raw in sorted(source.items()):
        for line_number, line_end, code in logical_statements(raw.decode('latin1')):
            for match in re.finditer(r'\bcall\s+(rd(?:s|f|a)[a-z0-9_]+)\s*\(', code, re.I):
                reader = match.group(1).lower()
                if reader in {'rdsets', 'rdfrom'}:
                    continue
                remainder = code[match.end():]
                name = re.match(r"\s*['\"]([^'\"]+)['\"]", remainder)
                calls.append({'member': member, 'line': line_number, 'reader': reader,
                              'line_end': line_end,
                              'literal_name': name.group(1).strip() if name else None,
                              'source': code, 'computed_name': name is None})
            if is_control_branch(code):
                all_branches.append({'member': member, 'line': line_number, 'line_end': line_end, 'source': code})
            if is_control_branch(code) and re.search(r'\bsw[a-z0-9_]+|\b(tcs|dcs|ihwckmodel|imicro|ipos|dramet)\b', code, re.I):
                branches.append({'member': member, 'line': line_number, 'line_end': line_end, 'source': code})
            name = re.match(r'(?:[a-z0-9_()*,]+\s+)*(?:subroutine|function)\s+(\w+)(?:\s*\(|\s*$)', code, re.I)
            if name and not code.lower().startswith('end'):
                routines.append({'member': member, 'line': line_number, 'name': name.group(1)})
    ledger = json.loads((ROOT / 'integration/audits/SWAP431_FUNCTIONAL_COVERAGE_MASTER.json').read_text())
    aliases = collections.defaultdict(set)
    for entry in ledger['capabilities']:
        for token in re.findall(r'[A-Za-z_][A-Za-z_0-9]*', entry['legacy_selector']) + entry.get('source_input_names', []):
            aliases[token.lower()].add(entry['capability_id'])
    integer = [c for c in calls if c['reader'].endswith(('int', 'inr', 'log'))]
    for call in integer:
        call['capability_navigation'] = sorted(aliases[(call['literal_name'] or '').lower()])
        if call['computed_name'] and call['member'] == 'SWAP/drainage.f90':
            # The same source statement builds per-level selector names.
            if re.search(r'\b(?:swallo|swdtyp)\s*\(', call['source'], re.I):
                call['capability_navigation'] = ['SW431-DRAIN-ALLOCATION']
        if call['computed_name'] and call['member'] == 'SWAP/swapoutput.f90':
            call['capability_navigation'] = ['SW431-IO-RESTART']
        call['navigation_is_disposition_proof'] = False
    result = dict(previous)
    result.update(schema_version='1.2', canonical_head=ledger['canonical_head'],
                  census_complete=False, input_reader_calls=calls,
                  integer_input_calls=integer, selector_branch_navigation=branches,
                  routine_navigation=routines, full_control_branch_navigation=all_branches,
                  inventory_summary={'input_reader_calls': len(calls),
                                     'integer_boolean_calls': len(integer),
                                     'selector_branch_locators': len(branches),
                                     'routine_locators': len(routines), 'all_control_branch_locators': len(all_branches),
                                     'unmapped_integer_boolean_calls': sum(not c['capability_navigation'] for c in integer)})
    result['limits'] = ['Navigation scan is reproducible, not a Fortran call-graph or physical-equivalence proof.',
                        'Free-form continuations, quoted comments and semicolon statements are joined lexically; this is not a complete Fortran parser.',
                        'Computed names, real/logical controls, constant guards and cross-option reachability require source review.',
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
