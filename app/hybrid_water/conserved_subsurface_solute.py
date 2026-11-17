"""Source-bound correction for original no-macro fixed chemical irrigation.

CIRR is existing checkpointed irrigation state. The source helper and CDE
scratch arrays are derived per transport substep and own no persistent stock.
"""
import hashlib
import importlib.util
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
POLICY='original-corrected-fixed-subsurface-solute-v1'
PATCH=ROOT/'reference/swap-4.3.1/patches/NOMACRO-SUBSURFACE-SOLUTE-01/source.py'


def enabled(project):
    if not project.input_directory or project.macro:return False
    from experimental_project import inspect
    selected=inspect(project.input_directory)['selectors']
    return selected['SWSOLU']==1 and selected['SWIRFIX']==1


def correction():
    spec=importlib.util.spec_from_file_location('corrected_original_subsurface_solute',PATCH)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def metadata():
    patch=correction()
    digest=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
    return dict(policy=POLICY,source_sha256=digest(Path(__file__)),
                correction_sha256=digest(PATCH),helper_canonical_sha256=patch.HELPER_SHA,
                original_solute_sha256=patch.ORIGINAL_SHA,
                original_irrigation_sha256=patch.IRRIGATION_SHA,
                fixed_reader_sha256=digest(ROOT/'app/hybrid_water/fixed_irrigation_file.py'))
