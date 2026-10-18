#!/usr/bin/env python3
"""Cache primary site studies with explicit identity; do not redistribute scans."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import requests

SOURCES = [
    {'id': 'ugent_soil_1981', 'url': 'https://biblio.ugent.be/publication/8505121/file/8527107.pdf',
     'landing': 'https://biblio.ugent.be/publication/8505121',
     'sha256': 'f0f177961cffcbe884a883fcb6f37529e03e321a12c8c6b0db2ad21cb3091d55',
     'expected_pages': 98, 'year': 1981, 'use': 'historical measured soil physics; not current vegetation'},
    {'id': 'ugent_ecology_1981', 'url': 'https://biblio.ugent.be/publication/8505122/file/8527108.pdf',
     'landing': 'https://biblio.ugent.be/publication/8505122', 'expected_pages': 81,
     'sha256': '906ecd5810501fb2227c20f815d7b283c2ba5018588c3d9bb8a85e1dbafae9bc',
     'year': 1981, 'use': 'historical ecology; no automatic contemporary canopy parameters'},
    {'id': 'inbo_pas_2018',
     'url': 'https://purews.inbo.be/ws/portalfiles/portal/14518810/DeBlust_2018_PASgebiedsanalyseBE2100015KalmthoutseHeide.pdf',
     'sha256': '73b2d4f869203a3bbad375eefe5513c4ca82c585d63393c19d363f245491f10b', 'expected_pages': 77,
     'year': 2018, 'use': 'site hydrology and habitat context; assess perched water and soil horizons'},
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    with requests.Session() as client:
        for source in SOURCES:
            path = args.output / (source['id'] + '.pdf')
            if not path.exists():
                response = client.get(source['url'], timeout=60)
                response.raise_for_status()
                assert response.content.startswith(b'%PDF'), source['id']
                path.write_bytes(response.content)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if 'sha256' in source:
                assert digest == source['sha256'], 'Source revision requires review: ' + source['id']
            info = subprocess.check_output(['pdfinfo', str(path)], text=True)
            pages = int(next(line.split(':')[1] for line in info.splitlines() if line.startswith('Pages:')))
            if 'expected_pages' in source:
                assert pages == source['expected_pages']
            text_path = path.with_suffix('.txt')
            subprocess.run(['pdftotext', '-layout', str(path), str(text_path)], check=True)
            records.append(dict(source, sha256=digest, bytes=path.stat().st_size, pages=pages,
                                text_sha256=hashlib.sha256(text_path.read_bytes()).hexdigest()))
    manifest = {'sources': records, 'redistribution': 'Original PDFs and extracted full text remain a local cache; persist URLs, hashes and derived factual data only.'}
    (args.output / 'study_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'collected': len(records), 'pages': sum(r['pages'] for r in records)}))


if __name__ == '__main__':
    main()
