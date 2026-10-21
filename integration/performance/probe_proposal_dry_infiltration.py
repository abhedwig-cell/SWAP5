"""Observe the optional route on the exact long input whose incumbent failed.

An excluded-regime observation, never a qualified error/cost comparison.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--study', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    study, out = args.study.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    source = study/'dry_infiltration32/1e-06-on.nml'
    exe = study/'observer/column'
    command = [str(exe), str(source), '-', '128']
    report = dict(status='EXCLUDED_REGIME_PROBE_NOT_QUALIFIED', command=command,
                  executable_sha256=hashlib.sha256(exe.read_bytes()).hexdigest(),
                  input_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
    start = time.monotonic()
    with (out/'stdout').open('wb') as so, (out/'stderr').open('wb') as se:
        try:
            p = subprocess.run(command, cwd=out, stdout=so, stderr=se, timeout=120)
            report['exit'] = p.returncode
        except subprocess.TimeoutExpired:
            report['exit'] = 'TIMEOUT'
    report['wall_seconds'] = time.monotonic()-start
    (out/'PROBE.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()
