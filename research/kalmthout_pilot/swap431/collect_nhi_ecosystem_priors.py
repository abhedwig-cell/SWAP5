#!/usr/bin/env python3
"""Cache the NHI source package and inspect its natural-vegetation inputs.

This is an external parameter prior, never a Kalmthout measurement.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

import requests

URL = 'https://nhipackages.blob.core.windows.net/packages/gewasweerstanden-tools-en-rapportage.zip'
NESTED = 'kalibratietool_niet-landbouwgewassen_inclusief_uurlijks_def.zip'
PACKAGE_SHA256 = '0e176069c2df49ac7388e0fd928904e6255a56196e005fb0306d7d6f2cc2430d'
SELECTED = ['Basisdata/metaswap_parameters_dag.csv', 'Basisdata/metaswap_parameters_uur.csv',
            'Basisdata/msw_templates/fact_svat.inp', 'Basisdata/msw_templates/luse_svat.inp',
            'Basisdata/msw_templates/para_sim.inp'] + [
            f'Resultaten/{period}/MetaSWAP/heidevegetatie/opt_feddes_metaswap.csv'
            for period in ['1961-1990','1961-1990_uur','1991-2020','1991-2020_uur']]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    old_manifest = out / 'nhi_source_manifest.json'
    if old_manifest.exists():
        previous = json.loads(old_manifest.read_text())
        selected = previous.get('selected_files', [])
        if previous['package_sha256'] == PACKAGE_SHA256 and {r['path'] for r in selected} == {'selected/'+name for name in SELECTED} and all(
                (out/r['path']).exists() and hashlib.sha256((out/r['path']).read_bytes()).hexdigest()==r['sha256'] for r in selected):
            print(json.dumps({'selected_source_files_verified':len(selected),'source_package_downloaded':False}))
            return
    package = out / 'nhi_gewasweerstanden.zip'
    if not package.exists():
        temporary = package.with_suffix('.zip.tmp')
        with requests.get(URL, stream=True, timeout=60) as response:
            response.raise_for_status()
            size = int(response.headers['Content-Length'])
            received = 0
            with temporary.open('wb') as handle:
                for block in response.iter_content(1024 * 1024):
                    handle.write(block)
                    received += len(block)
                    if received % (64 * 1024 * 1024) == 0:
                        print('Downloaded source bytes', received, 'of', size, flush=True)
            assert received == size
        temporary.replace(package)
    assert hashlib.sha256(package.read_bytes()).hexdigest() == PACKAGE_SHA256, 'NHI source revision requires review'
    with zipfile.ZipFile(package) as outer:
        # Explicit member names avoid arbitrary archive path extraction.
        if not (out / NESTED).exists():
            (out / NESTED).write_bytes(outer.read(NESTED))
        for info in outer.infolist():
            if info.filename.endswith('.pdf'):
                (out / Path(info.filename).name.replace(' ', '_')).write_bytes(outer.read(info))
    with zipfile.ZipFile(out / NESTED) as inner:
        index = [{'path': i.filename, 'bytes': i.file_size, 'compressed_bytes': i.compress_size}
                 for i in inner.infolist()]
        selected = []
        for name in SELECTED:
            target = out / 'selected' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            raw = inner.read(name)
            target.write_bytes(raw)
            selected.append({'path': str(target.relative_to(out)), 'bytes': len(raw),
                             'sha256': hashlib.sha256(raw).hexdigest()})
    manifest = {'source_url': URL, 'landing_url': 'https://nhi.nu/tooling/gewasweerstanden-tool/',
                'package_bytes': package.stat().st_size,
                'package_sha256': hashlib.sha256(package.read_bytes()).hexdigest(),
                'nested_sha256': hashlib.sha256((out / NESTED).read_bytes()).hexdigest(),
                'members': index, 'selected_files': selected,
                'contract': 'External NHI natural vegetation prior, not local calibration.'}
    (out / 'nhi_source_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'members': len(index), 'package_sha256': manifest['package_sha256']}))


if __name__ == '__main__':
    main()
