#!/usr/bin/env python3
"""Recover admitted B12..B15 expected stdout, never partial run outputs."""
from pathlib import Path
import gzip
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
for number in (12, 13, 14, 15):
    status = json.loads((ROOT / f'integration/audits/PPA_WU05B{number}_STATUS.json').read_text())
    assert status['qualified'] and status['admitted']
    evidence = ROOT / status['evidence']['path']
    assert hashlib.sha256(evidence.read_bytes()).hexdigest() == status['evidence']['sha256']
    replay = json.loads(gzip.decompress(evidence.read_bytes()))
    for route in ('normal', 'low_air'):
        for optimization in (0, 2):
            content = replay['runtime_output_snapshots'][f'{route}_O{optimization}'].encode()
            assert content.count(b'FINE_COMPARISON') >= 6 and b'_RUNTIME=PASS' in content
            target = Path(f'/tmp/ppa-wu05b{number}-{route.replace("_", "-")}-runtime/o{optimization}/output.txt')
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists():
                assert target.read_bytes() == content, target
            else:
                with target.open('xb') as output:
                    output.write(content)
            print(f'B19_ADMITTED_EXPECTED_STDOUT_RECOVERED B{number} {route} O{optimization} SHA256={hashlib.sha256(content).hexdigest()}', flush=True)
