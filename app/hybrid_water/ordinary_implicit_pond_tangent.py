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
  if(pond>pondmx)then
     if(rsro<1d-3)then
        slope=1d0
     else
        slope=step/rsro*rsroexp*(pond-pondmx)**(rsroexp-1d0)
     end if
  end if
  tangent=soil_partial*(1d0+slope)/(1d0+step*conductance+slope)
end function
'''
ORIGINAL_TOP = ('683dbd0b1d9a760523cf54dfb7633fd63d30cb00881765ef9f42b58472e594f1',
                'e82dbca07c8676b7b2a1f29d57ddb320dbdf5187baeb7c3a0254431e57315664')
ROOT_BODY = '''      subroutine ordinary_pond_root()
        real(8)::lower,upper,middle,left_value,right_value,value,constant,coefficient
        integer::iteration
        coefficient=1d0+k1max/disnod(1)*dt
        constant=pondm1+q0hlp*dt-k1max*dt+k1max/disnod(1)*dt*h(1)
        lower=0d0;upper=h0max
        pond=lower;runots=runoff();left_value=coefficient*pond+runots-constant
        pond=upper;runots=runoff();right_value=coefficient*pond+runots-constant
        if(left_value>0d0.or.right_value<0d0)error stop 'Original ordinary pond root not bracketed'
        do iteration=1,127
           middle=lower+(upper-lower)*.5d0
           if(middle==lower.or.middle==upper)exit
           pond=middle;runots=runoff();value=coefficient*pond+runots-constant
           if(value==0d0)then
              hsurf=pond
              return
           else if(value<0d0)then
              lower=middle;left_value=value
           else
              upper=middle;right_value=value
           end if
        end do
        pond=lower
        if(abs(right_value)<abs(left_value))pond=upper
        runots=runoff();hsurf=pond
      end subroutine
'''
ROOT_CALL = '''      if(swdra/=2.and.swmacro==0.and..not.(rsro>=1d-3.and.rsroexp==1d0))then
         call ordinary_pond_root()
         return
      end if
'''


def top(text):
    old, new = '      if (h0 <= 1.0d-6) then', '      if (h0 <= 0.0d0) then'
    if text.count(new) != 1 or old in text or hashlib.sha256(
            text.replace(new, old, 1).encode('cp1252')).hexdigest() not in ORIGINAL_TOP:
        raise ValueError('Foreign ordinary complete top before chain-rule composition')
    public, end = 'public :: pondrunoff, q0, FlRunoff, ftoph, hsurf', 'end module MOD_top'
    assert text.count(public) == text.count(end) == 1
    anchor = '      runots = runoff()\n      if (dabs(runots)'
    contains = '      contains\n! ----------------------------------------------------------------------\n      function runoff ()'
    assert text.count(anchor) == text.count(contains) == 1
    text = text.replace(anchor, ROOT_CALL+anchor, 1)
    text = text.replace(contains, contains.replace('      contains\n', '      contains\n'+ROOT_BODY), 1)
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
