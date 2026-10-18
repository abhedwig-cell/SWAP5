#!/usr/bin/env python3
"""Incremental evidence after the two pinned project archives; no full PDFs."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('archive', type=Path)
    parser.add_argument('manifest', type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    results = root / 'results'
    context = json.loads((results / 'swap431_site_context/site_context.json').read_text())
    audit = json.loads((results / 'swap431_groundwater_audit/groundwater_audit.json').read_text())
    batch = json.loads((results / 'swap431_grid_soil_scenarios/batch_results.json').read_text())
    assert context['status_counts'] == {'OK': 536}
    assert context['grid_cells'] == audit['grid_cells'] == 1024
    assert len(batch['runs']) == 42 and all(r['native_success'] and r['reused_verified_native_output'] for r in batch['runs'])
    files = [p for directory in ['swap431_site_context', 'swap431_groundwater_audit']
             for p in (results / directory).iterdir() if p.is_file() and p.suffix in ['.xml', '.json', '.csv']]
    files += [results / ('local_studies/' + name) for name in ['study_manifest.json', 'historical_retention_fits.json',
               'dtm_capabilities.xml', 'dtm_describe.xml', 'dtm_request.json']]
    files += [results / name for name in ['symphonica_context_resume.log', 'symphonica_pipeline_status.json']]
    model = results / 'swap431_grid_soil_scenarios'
    files += [model / 'profile_catalog.json', model / 'batch_results.json']
    files += [model / run['case'] / 'case_manifest.json' for run in batch['runs']]
    entries = []
    args.archive.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(args.archive, 'w:xz') as archive:
        for path in sorted(files):
            raw = path.read_bytes()
            name = str(path.relative_to(root))
            entries.append({'path': name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
            archive.add(path, arcname=name, recursive=False)
    manifest = {'archive_sha256': hashlib.sha256(args.archive.read_bytes()).hexdigest(),
                'archive_bytes': args.archive.stat().st_size, 'files': entries,
                'scope': 'Dated field context, observation coverage, retention fits, metadata-only SWAP431 resume',
                'base_archives_sha256': ['785b262bc94e723c4a53144fb4b5e4796a48835d501c8e0e01059ae726e7e748',
                                        '592611a32c0c0a771b56d33dff244119da54d3153244b6787ec37b160d43f776']}
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({k: v for k, v in manifest.items() if k != 'files'}))


if __name__ == '__main__':
    main()
