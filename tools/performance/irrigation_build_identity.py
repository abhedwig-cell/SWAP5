#!/usr/bin/env python3
"""Fail-closed discovery and identity for the bounded root/sensor shared build.

No test results or objects are inherited across invocations.
"""
import hashlib
import json
from pathlib import Path
import re
import sys

EXTRAS = [Path('tests/f-app07/mc_irr01_realistic_headcalc_stubs.f90'),
          Path('tests/fmr/mod_fmr04_fixed_top_provider.f90')]
DRIVERS = [Path('tests/f-app07/test_mc_irr01_allocated_' + c + '_restart.f90')
           for c in ('root', 'sensor')]
USE = re.compile(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)', re.I | re.M)
MODULE = re.compile(r'^\s*module\s+(?!procedure\b)(\w+)', re.I | re.M)


def discover(files, drivers):
    providers = {}
    texts = {p: p.read_text() for p in files}
    for p, source in texts.items():
        for name in MODULE.findall(source):
            name = name.lower()
            if name in providers:
                raise ValueError('duplicate module provider: ' + name)
            providers[name] = p
    seen, active, ordered = set(), set(), []
    def visit(name):
        name = name.lower()
        if name == 'iso_fortran_env':
            return
        if name not in providers:
            raise ValueError('unresolved module: ' + name)
        p = providers[name]
        if p in seen:
            return
        if p in active:
            raise ValueError('module dependency cycle: ' + name)
        active.add(p)
        for dependency in USE.findall(texts[p]):
            # A source file may define several mutually using modules.
            if providers.get(dependency.lower()) != p:
                visit(dependency)
        active.remove(p)
        seen.add(p)
        ordered.append(p)
    for driver in drivers:
        for name in USE.findall(driver.read_text()):
            visit(name)
    return ordered


def snapshot():
    files = sorted(Path('src').rglob('*.f90')) + EXTRAS
    ordered = discover(files, DRIVERS)
    # Preserve the incumbent selection and order as an independent contract.
    # Each fixture currently has the identical complete production closure.
    closures = [discover(files, [d]) for d in DRIVERS]
    if any(c != ordered for c in closures):
        raise ValueError('root/sensor closures differ; shared link not qualified')
    inputs = files + DRIVERS + [Path('tests/f-app07/run_mc_irr01_allocated_' + c + '_restart.sh')
                              for c in ('root', 'sensor')]
    inputs += [Path(__file__), Path('tests/performance/run_mc_irr01_shared_build_experiment.sh')]
    hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    return {'discovery_count': len(files), 'ordered_sources': list(map(str, ordered)),
            'input_sha256': hashes,
            'identity_sha256': hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()}


if __name__ == '__main__':
    try:
        value = snapshot()
        target = Path(sys.argv[1])
        if len(sys.argv) > 2 and sys.argv[2] == '--verify':
            if json.loads(target.read_text()) != value:
                raise ValueError('build inputs changed during gate')
        else:
            target.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')
            print('\n'.join(value['ordered_sources']))
    except (ValueError, OSError) as exc:
        sys.exit('SHARED_IRR_IDENTITY_FAIL ' + str(exc))
