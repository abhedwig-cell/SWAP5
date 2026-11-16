"""Explicit bounded original frost reference; no global B1 source promotion."""
from pathlib import Path
import hashlib
import json

POLICY = 'original-frost-geometry01-snow-hysteresis-v1'
ROOT = Path(__file__).resolve().parents[2]
ORIGINAL_SHA = 'edd16b08ff238ee41d264d1c4870726f1232fb1143c1340f2dc21f94a3b909cf'
REPORTING_SHA = '9d75dc4a552f438fa4f358f3d9e17ddaaa1d50348e549b11802617a270ca1c87'
GUARDED_SHA = 'd5dd195187d4581e09d19e6afdd4066c0fdb23eee84f8f87947251d2778724d2'


def enabled(project):
    if not project.input_directory or project.macro:
        return False
    from experimental_project import inspect
    return inspect(project.input_directory)['selectors']['SWFROST'] == 1


def source(original):
    folder = ROOT/'reference/swap-4.3.1/frost-corrections'
    drain = json.loads((folder/'FROST-DRAIN-01/manifest.json').read_text())
    geometry = json.loads((folder/'FROST-GEOMETRY-01/manifest.json').read_text())
    reporting = (folder/'FROST-DRAIN-01/frozencond.f90').read_bytes()
    guarded = (folder/'FROST-GEOMETRY-01/frozencond.f90').read_bytes()
    sha = lambda data: hashlib.sha256(data).hexdigest()
    if (drain['base_sha256'] != ORIGINAL_SHA or drain['target_sha256'] != REPORTING_SHA
            or geometry['target_sha256'] != GUARDED_SHA
            or sha(original) != drain['base_sha256'] or sha(reporting) != drain['target_sha256']
            or sha(reporting) != geometry['base_sha256'] or sha(guarded) != geometry['target_sha256']):
        raise ValueError('Foreign bounded original frost reference chain')
    return guarded


def render_witness(source):
    from donor_sources import replace
    source = replace(source, '   use MOD_grid,                 only: numnod',
                     '   use MOD_frost,only:rfcp,nodfrostbot,zfrosttop,zfrostbot,frost_geometry_valid\n'
                     '   use MOD_grid,                 only: numnod')
    return replace(source, "   write(*,'(a,12(1x,es25.17e3))') 'HYBRID_STOCK_FLUX', &",
                   "   write(*,'(a,6(1x,es25.17e3))') 'HYBRID_FROST_WITNESS', &\n"
                   '      minval(rfcp(1:numnod)),maxval(rfcp(1:numnod)),dble(nodfrostbot), &\n'
                   '      zfrosttop,zfrostbot,dble(merge(1,0,frost_geometry_valid))\n'
                   "   write(*,'(a,12(1x,es25.17e3))') 'HYBRID_STOCK_FLUX', &")
