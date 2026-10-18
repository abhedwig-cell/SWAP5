#!/usr/bin/env python3
"""Closed terminal owner evidence for the exact joint successor.

Passing this prerequisite permits moving F-CI to execute its existing science.
It never establishes that F-CI passed or that the successor was admitted.
"""
from pathlib import Path
import argparse
import base64
import copy
import hashlib
import io
import json
import math
import re
import subprocess
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
            directory = Path(flags[flags.index('-J') + 1]).name
            check(directory in ['o0', 'o2'] and '-O' + directory[1:] in flags,
                  'highest actual optimization flag changed')
        ordered = data[f'highest/{name}/sources'].decode().splitlines()
        check(len(ordered) == len(set(ordered)), 'duplicate highest provider')
        for opt in (0, 2):
            compiled = [e['command'][e['command'].index('-c') + 1] for e in build
                        if Path(e['command'][e['command'].index('-J') + 1]).name == f'o{opt}']
            check(compiled == ordered, 'highest compile coverage/order mismatch')
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
    compiles = [e['command'] for e in events if '-c' in e['command']]
    links = [e['command'] for e in events if '-c' not in e['command'] and '-o' in e['command']]
    check(len(compiles) == 466 and len(links) == 8, 'weather controlled build coverage')
    owning_flags = ['-std=f2008', '-ffree-line-length-none', '-w', '-fopenmp', '-fcheck=all',
                    '-fbacktrace', '-ffpe-trap=invalid,zero,overflow']
    for command in compiles + links:
        check(command[1:1+len(owning_flags)] == owning_flags, 'weather actual numerical flags changed')
    for opt in (0, 2):
        compiled = [c[c.index('-c')+1] for c in compiles if f'-O{opt}' in c]
        check(len(compiled) == len(set(compiled)) == 233, 'weather missing/repeated compilation')
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
        for row in rows:
            common = ['-std=f2008', '-ffree-line-length-none', '-Wall', '-Wextra', '-fopenmp',
                      '-fcheck=all', '-fbacktrace', '-ffpe-trap=invalid,zero,overflow']
            check(row['flags'] == [*common, f"-O{row['optimization']}"], 'direct actual flags changed')
    prior = manifest['default_off_reference_equivalence']
    raw = base64.b64decode((ROOT / prior['path']).read_bytes())
    check(hashlib.sha256(raw).hexdigest() == prior['decoded_sha256'], 'historical owner capsule drift')
    with tarfile.open(fileobj=io.BytesIO(raw)) as original:
        for route, name in [('normal', 'normal-off'), ('low-air', 'low-air-off')]:
            for opt in (0, 2):
                check(data[f'highest/{name}/o{opt}/output.txt'] ==
                      original.extractfile(f'highest/{route}/o{opt}/output.txt').read(),
                      'default OFF independently retained historical owner drift')
    return manifest


def read_evidence(record, raw=None):
    if raw is None:
        raw = base64.b64decode((ROOT / record['path']).read_bytes())
    check(hashlib.sha256(raw).hexdigest() == record['decoded_sha256'], 'joint capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        manifest = json.load(archive.extractfile('MANIFEST.json')); data = {}
        for name, digest in manifest['member_sha256'].items():
            check(not Path(name).is_absolute() and '..' not in Path(name).parts, 'unsafe evidence path')
            data[name] = archive.extractfile(name).read()
            check(hashlib.sha256(data[name]).hexdigest() == digest, 'joint raw member corruption')
    return data, manifest


def verify_qualification():
    source = verify_source()
    if source.get('historical_native_successor'):
        # The current exact HIST successor owns the source/evidence chain.
        # Do not misroute its metadata to the retired all-source highest capsule.
        import sys
        sys.path.insert(0, str(ROOT / 'tests/nut-crop'))
        from verify_hist_native_successor import verify_qualification as verify_hist
        return verify_hist()
    if source.get('co2_successor'):

        import sys
        sys.path.insert(0, str(ROOT / 'tests/crop-co2'))
        from verify_co2_successor import verify_qualification as verify_co2
        return verify_co2()
    if source.get('oxygen_cycle_successor'):
        import sys
        sys.path.insert(0, str(ROOT / 'tests/crop-cycle'))
        from verify_oxygen_successor import verify_qualification as verify_crop_cycle
        return verify_crop_cycle()
    status = json.loads((ROOT / 'integration/audits/MC_MET01_LOW_AIR_JOINT_ADMISSION_20261014.json').read_text())
    record = status['owner_evidence']  # No missing/progress evidence can pass.
    data, manifest = read_evidence(record)
    return validate(data, manifest, source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--negative-controls', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    source = verify_source()
    if source.get('historical_native_successor'):
        result = verify_qualification()
        if args.negative_controls:
            subprocess.run(['python3', '-B', str(ROOT/'tests/nut-crop/verify_hist_native_successor.py'), '--self-test'], check=True)
        if args.output:
            args.output.write_text(json.dumps(result, indent=2)+'\n')
        print('CURRENT_HIST_EXACT_OWNER_PREREQUISITE_NOT_FCI_ADMISSION=PASS')
        return
    if source.get('co2_successor'):

        result = verify_qualification()
        if args.negative_controls:
            subprocess.run(['python3', '-B', str(ROOT / 'tests/crop-co2/test_co2_successor_controls.py')], check=True)
        if args.output:
            args.output.write_text(json.dumps(result, indent=2) + '\n')
        print('CO2_COMPLETE_OWNER_PREREQUISITE_NOT_ADMISSION=PASS')
        return
    if source.get('oxygen_cycle_successor'):
        result = verify_qualification()
        if args.negative_controls:
            subprocess.run(['python3', '-B', str(ROOT / 'tests/crop-cycle/test_oxygen_successor_controls.py')], check=True)
        if args.output:
            args.output.write_text(json.dumps(result, indent=2) + '\n')
        print('OXYGEN_CYCLE_COMPLETE_OWNER_PREREQUISITE_NOT_ADMISSION=PASS')
        return
    status = json.loads((ROOT / 'integration/audits/MC_MET01_LOW_AIR_JOINT_ADMISSION_20261014.json').read_text())
    record = status['owner_evidence']
    data, manifest = read_evidence(record)
    validate(data, manifest, source)
    receipt = {'claim': 'COMPLETE_JOINT_OWNER_PREREQUISITE_NOT_FCI_OR_ADMISSION',
               'source_tree': source['source_tree'], 'capsule_sha256': record['decoded_sha256'],
               'highest_configurations': 36, 'fine_comparisons': 216, 'weather_programs': 28,
               'qualified': False, 'admitted': False}
    if args.negative_controls:
        results_path = 'highest/low-air-on/RESULTS.json'
        specimens = {}
        for name in ['partial', 'duplicate', 'failed', 'optimization-flag']:
            specimen = dict(data); result = json.loads(specimen[results_path])
            indices = [i for i, e in enumerate(result['events']) if e['kind'] == 'native']
            if name == 'partial': result['events'].pop(indices[-1])
            elif name == 'duplicate': result['events'][indices[-1]] = copy.deepcopy(result['events'][indices[0]])
            elif name == 'failed': result['events'][indices[0]]['exit'] = 1
            else:
                event = next(e for e in result['events'] if e['kind'] == 'compile' and '-O2' in e['command'])
                event['command'].remove('-O2')
            specimen[results_path] = json.dumps(result).encode(); specimens[name] = (specimen, manifest)
        specimen = dict(data); specimen.pop(results_path); specimens['missing-highest'] = (specimen, manifest)
        specimen = dict(data); specimen['highest/low-air-on/o0/configuration-1.txt'] += b'\n'
        specimens['raw-log-corruption'] = (specimen, manifest)
        altered = copy.deepcopy(manifest)
        altered['dependency_blobs']['src/adapter/mod_swap_daily_weather_file_adapter.f90'] = '0' * 40
        specimens['stale-source-binding'] = (data, altered)
        specimen = dict(data); weather = json.loads(specimen['weather/RESULTS.json']); weather['results'].pop()
        specimen['weather/RESULTS.json'] = json.dumps(weather).encode(); specimens['partial-weather'] = (specimen, manifest)
        specimen = dict(data); specimen['highest/low-air-off/o0/output.txt'] += b'\n'
        specimens['historical-reference-drift'] = (specimen, manifest)
        receipt['negative_controls'] = {}
        for name, (specimen, metadata) in specimens.items():
            try:
                validate(specimen, metadata, source)
            except (ValueError, KeyError) as error:
                receipt['negative_controls'][name] = str(error)
            else:
                raise ValueError('invalid owner evidence accepted: ' + name)
        try:
            read_evidence(record, b'corrupt capsule')
        except ValueError as error:
            receipt['negative_controls']['capsule-corruption'] = str(error)
        else:
            raise ValueError('corrupt capsule accepted')
    if args.output:
        args.output.write_text(json.dumps(receipt, indent=2) + '\n')
    print('JOINT_EXACT_SOURCE_COMPLETE_OWNER_AND_COUPLING_PREREQUISITE=PASS')
    print(json.dumps(receipt))


if __name__ == '__main__':
    main()
