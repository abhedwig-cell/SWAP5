"""Explicit conserved source identity for original scheduled chemical SSDI."""
from pathlib import Path
import hashlib

POLICY='original-corrected-scheduled-subsurface-solute-v1'


def enabled(project):
    if not project.solute or project.macro or not project.input_directory:return False
    from scheduled_subsurface_irrigation import enabled as scheduled_enabled
    return scheduled_enabled(project)


def metadata():
    from conserved_subsurface_solute import metadata as shared_metadata
    result=shared_metadata()
    result['shared_generator_sha256']=result.pop('source_sha256')
    result.update(policy=POLICY,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    return result
