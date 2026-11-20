"""Ordinary pond chain-rule prototype; not installed until real-interface tests.

The residual retains the original pond equation. Differentiate its response
and the selected soil conductivity once, using the existing Newton row owner.
"""
import hashlib
import importlib.util
from pathlib import Path

NAME = 'ordinary_implicit_top_jacobian'
BODY = '''real(8) function ordinary_implicit_top_jacobian(conductance,soil_partial,step) result(tangent)
  use variables,only:pond,pondmx,rsro,rsroexp
  real(8),intent(in)::conductance,soil_partial,step
  real(8)::slope
  slope=0d0
  if(pond>pondmx)slope=step/rsro*rsroexp*(pond-pondmx)**(rsroexp-1d0)
  tangent=soil_partial*(1d0+slope)/(1d0+step*conductance+slope)
end function
'''
ORIGINAL_TOP = ('683dbd0b1d9a760523cf54dfb7633fd63d30cb00881765ef9f42b58472e594f1',
                'e82dbca07c8676b7b2a1f29d57ddb320dbdf5187baeb7c3a0254431e57315664')


def top(text):
    old, new = '      if (h0 <= 1.0d-6) then', '      if (h0 <= 0.0d0) then'
    if text.count(new) != 1 or old in text or hashlib.sha256(
            text.replace(new, old, 1).encode('cp1252')).hexdigest() not in ORIGINAL_TOP:
        raise ValueError('Foreign ordinary complete top before chain-rule composition')
    public, end = 'public :: pondrunoff, q0, FlRunoff, ftoph, hsurf', 'end module MOD_top'
    assert text.count(public) == text.count(end) == 1
    return text.replace(public, public+', '+NAME, 1).replace(end, BODY+end, 1)


def headcalc(text):
    # Reuse the already qualified soil/pond composition, changing only its name.
    path = Path(__file__).with_name('extended_implicit_pond.py')
    spec = importlib.util.spec_from_file_location('qualified_extended_pond_renderer', path)
    renderer = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(renderer)
    text = renderer.headcalc(text).replace('extended_implicit_top_jacobian', NAME)
    anchor = '   use MOD_top,only:katm'
    assert text.count(anchor) == 1
    return text.replace(anchor, '   use MOD_top,only:'+NAME+'\n'+anchor, 1)
