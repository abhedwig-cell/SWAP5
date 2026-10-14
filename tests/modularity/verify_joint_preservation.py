#!/usr/bin/env python3
"""Closed terminal owner evidence for the exact joint successor.

Passing this prerequisite permits moving F-CI to execute its existing science.
It never establishes that F-CI passed or that the successor was admitted.
"""
from pathlib import Path
import base64
import hashlib
import io
import json
import math
import re
import tarfile

from joint_admission_authority import ROOT, verify_source, blob, git

MARKERS = {
    'source': b'MC_MET01_LITERAL_DAILY_DEMAND_O0_O2=PASS',
    'reference': b'MC_MET01_INCUMBENT_LITERAL_REFERENCE_ET_PRESERVATION_O0_O2=PASS',
    'heat-runtime': b'MC_HEAT01_RUNTIME_O0_O2_REPEAT_DETERMINISM=PASS',
    'fkt22': b'FKT22_FMR_PRODUCTION_RUNTIME_GATE=PASS',
    'boesten': b'PPA-WU04-B BOESTEN PRESERVATION PASS',
    'macro-top': b'PPA_WU05A9_TOP_INPUT_GATE=PASS',
    'multiswap': b'F-GC25 MULTISWAP GROUNDWATER COMPOSITION GATE PASS',
    'coupled-restart': b'F-GC24 COUPLED RESTART SPLIT-PROCESS GATE PASS',
    'live-modflow': b'F-GC49D LIVE PRODUCTION APPLICATION CONTEXT ABI GATE PASS',
    'independent-application': b'F-VQ124 F-GC49D INDEPENDENT GATE PASS',
}


def check(condition, message):
    if not condition:
        raise ValueError(message)


def validate(data, manifest, source):
    check(manifest['source_tree'] == source['source_tree'], 'joint evidence source tree')
    check(manifest['highest_cases_inherited'] == 0, 'highest result inheritance forbidden')
    check(manifest['highest_configurations'] == 24 and manifest['fine_comparisons'] == 144,
          'complete default-OFF owning matrix missing')
    check(manifest['policy_on_configurations'] == 12, 'policy-ON complete matrix missing')
    check(manifest['reference_tree'] == git('rev-parse', 'HEAD:reference'), 'reference tree drift')
    tree = {line.split('\t', 1)[1]: line.split('\t', 1)[0].split()[2]
            for line in git('ls-tree', '-r', 'HEAD').splitlines()}
    sources = set(git('ls-tree', '-r', '--name-only', 'HEAD', '--', 'src').splitlines())
    check(sources <= manifest['dependency_blobs'].keys(), 'incomplete conservative production binding')
    for path, expected in manifest['dependency_blobs'].items():
        check(tree.get(path) == expected and blob((ROOT / path).read_bytes()) == expected,
              'current joint dependency drift: ' + path)
    for name in ['normal-off', 'low-air-off', 'low-air-on']:
        result = json.loads(data[f'highest/{name}/RESULTS.json'])
        check(result['status'] == 'PASS', 'highest not terminal PASS')
        check(result['identity']['source']['source_tree'] == source['source_tree'], 'highest source mismatch')
        rows = [e for e in result['events'] if e['kind'] == 'native']
        check(len(rows) == 12 and {(r['opt'], r['configuration']) for r in rows}
              == {(o, c) for o in (0, 2) for c in range(1, 7)}, 'incomplete distinct highest cases')
        route = 'normal' if name == 'normal-off' else 'low_air'
        policy = 'ON' if name.endswith('-on') else 'OFF'
        check(result['identity']['route'] == route and result['identity']['policy'] == policy,
              'highest route/policy drift')
        values = {}
        for row in rows:
            check(row['exit'] == 0, 'failed highest native')
            raw = data[f"highest/{name}/o{row['opt']}/configuration-{row['configuration']}.txt"]
            check(hashlib.sha256(raw).hexdigest() == row['stdout_sha256'], 'highest raw output mismatch')
            text = raw.decode()
            check(text.count('_RUNTIME=PASS') == 1 and text.count('FINE_COMPARISON') == 6,
                  'original full highest assertions missing')
            for marker in ['PPA_WU05B15_EXTENDED_APPLICATION=PASS', 'PPA_WU05B15_ACTUAL_CONTROL_PREFLIGHT=PASS']:
                check(marker in text, 'highest application/negative gate missing')
            comparisons = re.findall(r'FINE_COMPARISON head_cm=\s*(\S+) temperature_c=\s*(\S+)', text)
            check(len(comparisons) == 6, 'complete fine comparisons absent')
            for h, t in comparisons:
                h, t = float(h), float(t)
                check(math.isfinite(h) and math.isfinite(t) and 0 <= h <= 1.e-6 and 0 <= t <= 1.e-4,
                      'original independent comparison budget failed')
            values[(row['opt'], row['configuration'])] = raw
        for c in range(1, 7):
            check(values[(0, c)] == values[(2, c)], 'highest O0/O2 physical drift')
        build = [e for e in result['events'] if e['kind'] == 'compile']
        check(build and all(e['exit'] == 0 for e in build), 'incomplete highest build')
        for e in build:
            flags = e['command']
            check(all(x in flags for x in ['-std=f2008', '-fopenmp', '-fcheck=all', '-fbacktrace',
                                          '-ffpe-trap=invalid,zero,overflow']), 'highest numerical flags drift')
    additional = json.loads(data['additional/RESULTS.json'])
    check(additional['status'] == 'PASS', 'additional owner evidence incomplete')
    check(len(additional['steps']) == len(MARKERS) and {s['name'] for s in additional['steps']} == set(MARKERS),
          'additional owner coverage incomplete')
    for step in additional['steps']:
        raw = data['additional/' + step['name'] + '.stdout']
        check(step['exit'] == 0 and hashlib.sha256(raw).hexdigest() == step['stdout_sha256'],
              'additional owner failed/raw log drift')
        check(MARKERS[step['name']] in raw, 'original owner PASS marker absent')
    weather = json.loads(data['weather/RESULTS.json'])
    expected = {(o, n, m, mode) for o in (0, 2) for n in ['weather', 'daily_demand', 'raintb', 'legacy']
                for m in (['neutral', 'dry', 'hydraulic'] if n == 'weather' else ['typed', 'legacy'] if n == 'legacy' else ['neutral'])
                for mode in ['continuous', 'restart']}
    rows = weather['results']
    check(weather['status'] == 'PASS' and len(rows) == 28 and
          {(r['opt'], r['driver'], r['moisture'], r['mode']) for r in rows} == expected,
          'incumbent/legacy physical coverage incomplete')
    hashes = {(r['opt'], r['driver'], r['moisture'], r['mode']): r['stdout_sha256'] for r in rows}
    check(all(r['returncode'] == 0 for r in rows), 'failed weather native')
    for key, value in hashes.items():
        o, n, m, mode = key
        check(value == hashes[(2-o, n, m, mode)] == hashes[(o, n, m, 'restart' if mode == 'continuous' else 'continuous')],
              'weather optimization/restart drift')
        if n == 'legacy':
            check(value == hashes[(o, n, 'typed' if m == 'legacy' else 'legacy', mode)], 'physical representation drift')
    events = weather['events']
    for index, event in enumerate(events):
        check(event['returncode'] == 0, 'failed weather build/fixture/native')
        exe = Path(event['command'][0])
        if exe.name in ['test-weather', 'test-daily_demand', 'test-raintb', 'test-legacy']:
            name = exe.name.removeprefix('test-')
            command = event['command']
            mode = command[-3] if name == 'legacy' else command[-2]
            moisture = command[-1]
            opt = int(exe.parent.name.removeprefix('o'))
            raw = data[f"weather/{index:05d}-native-{name}-{moisture}-{mode}.stdout"]
            check(hashlib.sha256(raw).hexdigest() == event['stdout_sha256'], 'weather raw log drift')
            check(event['stdout_sha256'] == hashes[(opt, name, moisture, mode)], 'weather native evidence binding')
    modular = json.loads(data['modular/RESULTS.json'])
    check(modular['status'] == 'PASS', 'direct modular evidence incomplete')
    for case in ['raintb_legacy', 'low_air_policy', 'low_air_physical']:
        rows = [r for r in modular['records'] if r['case'] == case]
        check(len(rows) == 4 and {(r['optimization'], r['build']) for r in rows}
              == {(o, b) for o in (0, 2) for b in ['cold', 'warm_same_transaction']},
              'modular original O0/O2 cold/warm coverage')
        check(len({r['stdout_sha256'] for r in rows}) == 1, 'direct science drift')
    return manifest


def verify_qualification():
    source = verify_source()
    status = json.loads((ROOT / 'integration/audits/MC_MET01_LOW_AIR_JOINT_ADMISSION_20261014.json').read_text())
    record = status['owner_evidence']  # No missing/progress evidence can pass.
    raw = base64.b64decode((ROOT / record['path']).read_bytes())
    check(hashlib.sha256(raw).hexdigest() == record['decoded_sha256'], 'joint capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        manifest = json.load(archive.extractfile('MANIFEST.json')); data = {}
        for name, digest in manifest['member_sha256'].items():
            check(not Path(name).is_absolute() and '..' not in Path(name).parts, 'unsafe evidence path')
            data[name] = archive.extractfile(name).read()
            check(hashlib.sha256(data[name]).hexdigest() == digest, 'joint raw member corruption')
    return validate(data, manifest, source)


if __name__ == '__main__':
    verify_qualification()
    print('JOINT_EXACT_SOURCE_COMPLETE_OWNER_AND_COUPLING_PREREQUISITE=PASS')
