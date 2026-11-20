"""Separately qualified zero-pond reference correction for ordinary implicit flow.

The existing positive-pond equation applies at every positive pond head. The
legacy 1e-6 cm deadband leaves a discontinuous soil residual. No equation,
convergence criterion, rollback owner or conservation limit is changed here.
"""
import hashlib
from pathlib import Path

from extended_implicit_pond_switch import source

POLICY = 'ordinary-original-continuous-pond-exact-root-chain-rule-v2'
ORIGINAL_TOP = {
    False: '683dbd0b1d9a760523cf54dfb7633fd63d30cb00881765ef9f42b58472e594f1',
    True: 'e82dbca07c8676b7b2a1f29d57ddb320dbdf5187baeb7c3a0254431e57315664',
}


def selected(project):
    if not project.input_directory or project.macro or not project.original_output:
        return None
    from experimental_project import inspect
    selectors = inspect(project.input_directory)['selectors']
    if selectors['SWKIMPL'] != 1 or selectors['SWDRA'] == 2:
        return None
    return selectors


def metadata(project):
    selectors = selected(project)
    if selectors is None:
        return None
    return dict(policy=POLICY, source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                renderer_sha256=hashlib.sha256(Path(__file__).with_name('extended_implicit_pond_switch.py').read_bytes()).hexdigest(),
                pond_tangent_renderer_sha256=hashlib.sha256(Path(__file__).with_name('ordinary_implicit_pond_tangent.py').read_bytes()).hexdigest(),
                inherited_chain_rule_renderer_sha256=hashlib.sha256(Path(__file__).with_name('extended_implicit_pond.py').read_bytes()).hexdigest(),
                original_top_lf_sha256=ORIGINAL_TOP[bool(selectors['SWHYST'])],
                original_positive_head_deadband_preserved=False, original_pond_equation_preserved=True,
                original_nonlinear_approximate_root_preserved=False, root_iteration_bound=128,
                derivative='Actual soil conductivity partial composed once with original pond/runoff response',
                convergence_clock_mass_rollback_limits_changed=False, new_physical_state=False)


def actual_source(raw, history):
    from ordinary_implicit_pond_tangent import BODY, ROOT_BODY, ROOT_CALL, NAME
    text = raw.decode('cp1252').replace('\r\n', '\n')
    public = 'public :: pondrunoff, q0, FlRunoff, ftoph, hsurf'
    if any(text.count(part) != 1 for part in (BODY, ROOT_BODY, ROOT_CALL, public+', '+NAME)):
        raise ValueError('Foreign actual ordinary implicit pond root/derivative provider')
    text = text.replace(BODY, '', 1).replace(ROOT_BODY, '', 1).replace(ROOT_CALL, '', 1)
    text = text.replace(public+', '+NAME, public, 1)
    old, new = '      if (h0 <= 1.0d-6) then', '      if (h0 <= 0.0d0) then'
    if text.count(new) != 1 or old in text:
        raise ValueError('Foreign actual ordinary implicit positive-pond switch')
    restored = text.replace(new, old, 1).encode('cp1252')
    if hashlib.sha256(restored).hexdigest() != ORIGINAL_TOP[bool(history)]:
        raise ValueError('Foreign complete original ordinary implicit top source')


def validate(bundle, project):
    selectors = selected(project)
    if selectors is not None:
        actual_source((Path(bundle)/'boundtop.f90').read_bytes(), selectors['SWHYST'])


def apply_build(output, project, patched):
    selectors = selected(project)
    if selectors is None:
        return patched
    path = output/'boundtop.f90'
    text = path.read_text(encoding='cp1252')
    if hashlib.sha256(text.encode('cp1252')).hexdigest() != ORIGINAL_TOP[bool(selectors['SWHYST'])]:
        raise ValueError('Changed original ordinary implicit top before correction')
    from ordinary_implicit_pond_tangent import top,headcalc
    path.write_text(top(source(text)), encoding='cp1252')
    head = output/'headcalc.f90'
    head.write_text(headcalc(head.read_text(encoding='cp1252')), encoding='cp1252')
    return patched
