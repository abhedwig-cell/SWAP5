"""Whole initialized original MOD_top context for experimental history restarts."""
import re

FIELDS=('theatm','katm','h0max','k1max','q0','hsurf','FlRunoff','ftoph')

def render(source, *, scheduled_pond=False):
    declarations=source.split('contains',1)[0]
    actual=re.findall(r'(?im)^\s*(?:real\(8\)|logical),\s*save\s*::\s*(\w+)',declarations)
    if actual!=list(FIELDS) or not re.search(r'hatm\s*=\s*-2\.75d\+05',source,re.I):
        raise ValueError('Changed original initialized top-boundary domain')
    source=source.replace('contains','''public :: hybrid_top_checkpoint,hybrid_apply_top
logical,save::hybrid_top_pending=.false.
real(8),save::hybrid_top_values(6)=0d0,hybrid_top_clock=0d0
integer,save::hybrid_top_flags(2)=0
contains''',1)
    routines='''
subroutine hybrid_top_checkpoint(unit,restoring)
use variables,only:t1900
use MOD_swap_base,only:swmacro
use ieee_arithmetic,only:ieee_is_finite
integer,intent(in)::unit
logical,intent(in)::restoring
integer::version,flags(2),trailer,ios
real(8)::clock,values(6)
if(swmacro/=0)error stop 'Top history state requires absent macropores'
if(restoring)then
  read(unit,iostat=ios)version,clock,values,flags,trailer
  if(ios/=0)error stop 'Incomplete top history state'
else
  version=1;clock=t1900;values=[theatm,katm,h0max,k1max,q0,hsurf]
  flags=[merge(1,0,FlRunoff),merge(1,0,ftoph)];trailer=72
end if
if(version/=1.or.trailer/=72)error stop 'Invalid top history format'
if(.not.ieee_is_finite(clock).or.clock/=t1900)error stop 'Foreign top history clock'
if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite top history state'
if(any(values(1:4)<0d0).or.values(1)>1d0)error stop 'Invalid top history physical domain'
if(any(flags<0).or.any(flags>1))error stop 'Invalid top history flags'
if(restoring)then
  hybrid_top_values=values;hybrid_top_flags=flags;hybrid_top_clock=clock
  hybrid_top_pending=.true.
else
  write(unit)version,clock,values,flags,trailer
end if
end subroutine

subroutine hybrid_apply_top()
use variables,only:t1900
if(.not.hybrid_top_pending)return
if(t1900/=hybrid_top_clock)error stop 'Stale top history context'
theatm=hybrid_top_values(1);katm=hybrid_top_values(2)
h0max=hybrid_top_values(3);k1max=hybrid_top_values(4)
q0=hybrid_top_values(5);hsurf=hybrid_top_values(6)
FlRunoff=hybrid_top_flags(1)==1;ftoph=hybrid_top_flags(2)==1
hybrid_top_pending=.false.
end subroutine
'''
    if scheduled_pond:
        # PondRunoff owns this live schedule carry. BoundTop consumes its last
        # value even on days when PondRunoff is never called. Restore the actual
        # value together with all MOD_top fields, after original initialization.
        if source.count('pondmx = afgen (pondmxtab,2*mairg,t1900+dt)') != 1:
            raise ValueError('Changed original scheduled pond owner')
        source=source.replace('hybrid_top_values(6)', 'hybrid_top_values(7)')
        routines=routines.replace('use variables,only:t1900', 'use variables,only:t1900,pondmx')
        routines=routines.replace('clock,values(6)', 'clock,values(7)')
        routines=routines.replace('version=1;clock=t1900;values=[theatm,katm,h0max,k1max,q0,hsurf]',
                                  'version=2;clock=t1900;values=[theatm,katm,h0max,k1max,q0,hsurf,pondmx]')
        routines=routines.replace('trailer=72', 'trailer=80').replace('version/=1.or.trailer/=72', 'version/=2.or.trailer/=80')
        routines=routines.replace("if(any(flags<0)", "if(values(7)<0d0)error stop 'Invalid top history scheduled pond domain'\nif(any(flags<0)")
        routines=routines.replace('hybrid_top_pending=.false.\nend subroutine',
                                  'pondmx=hybrid_top_values(7)\nhybrid_top_pending=.false.\nend subroutine')
    if len(re.findall(r'(?im)^end module',source))!=1:raise ValueError('Changed original top module terminator')
    return re.sub(r'(?im)^end module',routines+'\nend module',source,count=1)
