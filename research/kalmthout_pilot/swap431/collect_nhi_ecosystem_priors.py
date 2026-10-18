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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
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
    manifest = {'source_url': URL, 'landing_url': 'https://nhi.nu/tooling/gewasweerstanden-tool/',
                'package_bytes': package.stat().st_size,
                'package_sha256': hashlib.sha256(package.read_bytes()).hexdigest(),
                'nested_sha256': hashlib.sha256((out / NESTED).read_bytes()).hexdigest(),
                'members': index, 'contract': 'External NHI natural vegetation prior, not local calibration.'}
    (out / 'nhi_source_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'members': len(index), 'package_sha256': manifest['package_sha256']}))


if __name__ == '__main__':
    main()
