#!/usr/bin/env python3
"""Fresh bounded owner and coupling prerequisites; never a moving-F-CI PASS."""
import hashlib
import json
from backend_allocation_authority import (ROOT, PUBLICATION, PUBLICATION_POSTIMAGE, verify_source, git)
import subprocess
from verify_backend_owner_evidence import verify_owner, read_archive, verify_dependencies

ORACLE_SHA256 = 'de9a811ebb3a85bf14c440350fb730b0fab8f576c06683f1265757669542d9d8'
PROGRAMS = ('multiswap_commit', 'single_tile_equivalence', 'multiswap_qualification',
            'corrector_tile_fail_closed', 'permutation_determinism', 'multicell_isolation')


def verify_repairs():
    source = verify_source()
    assert source['publication_postimage'] == PUBLICATION_POSTIMAGE, 'ledger repair not applied'
    verify_owner()
    status = json.loads((ROOT / 'integration/audits/MODULAR_TESTABILITY_20261013.json').read_text())
    with read_archive(status['backend_qualification']['coupling_evidence']) as archive:
        manifest = json.load(archive.extractfile('MANIFEST.json'))
        assert manifest['source_tree'] == source['source_tree']
        assert git('rev-parse', manifest['combined_head'] + ':src') == source['source_tree']
        verify_dependencies(manifest['dependency_blobs'])
        for name, expected in manifest['member_sha256'].items():
            assert hashlib.sha256(archive.extractfile(name).read()).hexdigest() == expected, name
        log = archive.extractfile('combined-fgc25.stdout').read()
        assert b'F-GC25 MULTISWAP GROUNDWATER COMPOSITION GATE PASS' in log
        for opt in (0, 2):
            for program in PROGRAMS:
                marker = f'FGC25_test_fgc25_{program}_O{opt}=PASS'.encode()
                assert log.count(marker) == 1, marker
        control = json.load(archive.extractfile('combined-independent/CONTROL.json'))
        assert control['status'] == 'PASS' and control['source_tree'] == source['source_tree']
        assert control['driver_blob'] == '338416575b1583152acc65cd606c4322a20dd94d'
        assert control['fixture_owner'] == '1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f'
        fixture = archive.extractfile('combined-independent/fgc21_fixture.f90').read()
        assert hashlib.sha256(fixture).hexdigest() == control['fixture_sha256']
        original = subprocess.check_output(['git', 'show', control['fixture_owner'] +
            ':tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'], cwd=ROOT)
        boundary = b'\nprogram test_fgc21_restricted_predictor_corrector_window\n'
        assert original.count(boundary) == 1 and fixture == original.split(boundary)[0] + b'\n'
        assert {r['opt'] for r in control['records']} == {0, 2} and len(control['records']) == 2
        verify_dependencies(control['dependency_blobs'])
        for record in control['records']:
            assert record['compile_exit'] == record['run_exit'] == 0
            output = archive.extractfile(f"combined-independent/o{record['opt']}/output.stdout").read()
            assert hashlib.sha256(output).hexdigest() == record['stdout_sha256'] == ORACLE_SHA256
        live = json.load(archive.extractfile('CONTROL.json'))
        assert live['status'] == 'PASS' and all(s['exit'] == 0 for s in live['steps'])
        assert git('rev-parse', live['head'] + ':src') == live['source_tree']
        assert git('diff', '--name-only', live['head'], 'HEAD', '--', 'src').splitlines() == [PUBLICATION]
        assert {s['name'] for s in live['steps']} == {'live-modflow', 'independent-application'}
        assert b'F-GC49D LIVE PRODUCTION APPLICATION CONTEXT ABI GATE PASS' in archive.extractfile('live-modflow.stdout').read()
        assert b'F-VQ124 F-GC49D INDEPENDENT GATE PASS' in archive.extractfile('independent-application.stdout').read()
        assert b'F-GC24 COUPLED RESTART SPLIT-PROCESS GATE PASS' in archive.extractfile('coupled-restart.stdout').read()
        recipes = json.load(archive.extractfile('OWNER_DEPENDENCIES.json'))
        live_recipe = recipes['recipes']['live-modflow']
        assert not live_recipe['publication_compiled']
        verify_dependencies(live_recipe['source_blobs'])
    return manifest


if __name__ == '__main__':
    verify_repairs()
    print('MODULAR_EXACT_REPAIRS_FRESH_OWNER_AND_COUPLING=PASS')
