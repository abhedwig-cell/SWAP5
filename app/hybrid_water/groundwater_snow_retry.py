"""Compose the qualified rollback/pond-event policy with explicit Snow output.

The event provider is copied literally. Its pending value is consumed only after
the original complete rollback and must be absent at every native boundary.
No physical flux, storage, tolerance or accepted receipt is corrected here.
"""
from pathlib import Path
import difflib
import hashlib
import re

POLICY='existing-original-rollback-pond-event-explicit-snow-v1'
HEAD_TEMPLATE='''   use hybrid_step_budget, only: projected_water_residual
   use MOD_top,            only: boundtop, pondrunoff, hsurf
   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror, mass_polish_at
   mass_polish_at = 0
            deviat = pond - pondm1 + epd*dt + reva*dt - (nraidt+nird+Melt)*dt - runon*dt + runots - qtop * dt
   if (.NOT.fldtmin) then
   call boundtop(2)
'''
TIME_TEMPLATE='''   use MOD_timer
   implicit none
      if (fldecdt) then
'''
TOP_TEMPLATE='''public :: boundtop                                          ! headcalc; initialization calls from soilwater and hysteresis
      subroutine boundtop(iTask)
      integer, intent(in)  :: iTask
         epd = epond
      end subroutine boundtop
'''
TOP_PARENT_SHA='ea9d62eed9518fff6e6f46312d17885fb1a722bf108c5a02a5f30f2df87b4a15'


def head(source):
    from implicit_conductivity_retry import headcalc_source
    from implicit_pond_event import headcalc_source as pond
    from implicit_pond_availability import head_source as available
    result=available(pond(headcalc_source(source)))
    anchor='.NOT.fldtmin.or.(swmacro==0.and.swkimpl==1)'
    if result.count(anchor)!=1:raise ValueError('Changed qualified Snow retry selector')
    return result.replace(anchor,anchor.replace('swkimpl==1','swkimpl==0'),1)


def time(source):
    from implicit_conductivity_retry import time_source
    from implicit_pond_event import time_source as pond
    result=pond(time_source(source))
    anchor='if(swmacro==0.and.swkimpl==1)then'
    if result.count(anchor)!=1:raise ValueError('Changed qualified Snow time retry selector')
    return result.replace(anchor,anchor.replace('swkimpl==1','swkimpl==0'),1)


def inverse(source,transform,template):
    # Derive exact whole-line additions/replacements from the unchanged admitted
    # renderers. This is a read-only inverse, followed by the parent whole hash.
    # Keep independent anchor sites separate even when the small fixture omits
    # the intervening original declarations/procedure body.
    template=''.join('! exact transform seam '+str(i)+'\n'+line for i,line in enumerate(template.splitlines(keepends=True)))
    before=template.splitlines(keepends=True);after=transform(template).splitlines(keepends=True)
    edits=[]
    for tag,i,j,k,l in difflib.SequenceMatcher(a=before,b=after,autojunk=False).get_opcodes():
        if tag!='equal':edits.append((''.join(before[i:j]),''.join(after[k:l])))
    for old,new in reversed(edits):
        if not new or source.count(new)!=1:raise ValueError('Foreign actual Snow rollback/pond event source')
        source=source.replace(new,old,1)
    return source


def metadata():
    folder=Path(__file__).parent
    sha=lambda name:hashlib.sha256((folder/name).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(groundwater_snow_retry_policy=POLICY,
                groundwater_snow_retry_provider_sha256=sha(Path(__file__).name),
                groundwater_snow_retry_parent_sha256=sha('implicit_conductivity_retry.py'),
                groundwater_snow_pond_parent_sha256=sha('implicit_pond_event.py'),
                groundwater_snow_pond_state_sha256=sha('implicit_pond_event_state.f90'),
                groundwater_snow_availability_parent_sha256=sha('implicit_pond_availability.py'),
                groundwater_snow_availability_state_sha256=sha('implicit_pond_availability.f90'))


def apply_build(output,patched):
    from implicit_pond_event import STATE
    folder=Path(__file__).parent
    (output/(STATE+'.f90')).write_bytes((folder/(STATE+'.f90')).read_bytes())
    (output/'implicit_pond_availability.f90').write_bytes((folder/'implicit_pond_availability.f90').read_bytes())
    for name,transform in (('headcalc.f90',head),('timecontrol.f90',time)):
        path=output/name;parent=path.read_text(encoding='cp1252')
        path.write_text(transform(parent),encoding='cp1252')
    path=output/'macropore.f90';source=path.read_text(encoding='cp1252')
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    if source.count(begin)!=1 or source.count(end)!=1:raise ValueError('Changed Snow native checkpoint owner')
    first=source.index(begin);last=source.index(end,first)+len(end);body=source[first:last]
    anchor='      use MOD_grid, only: numnod'
    if body.count(anchor)!=1:raise ValueError('Changed Snow native checkpoint imports')
    body=body.replace(anchor,'      use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event\n'+anchor,1)
    matches=list(re.finditer(r'(?m)^([ \t]*)if \(restoring\) then$',body))
    if len(matches)!=1:raise ValueError('Changed Snow native checkpoint dispatch')
    anchor=matches[0].group()
    body=body.replace(anchor,matches[0][1]+'call assert_no_implicit_pond_event()\n'+anchor,1)
    path.write_text(source[:first]+body+source[last:],encoding='cp1252')
    from implicit_pond_availability import top_source
    path=output/'boundtop.f90';parent=path.read_text(encoding='cp1252')
    if hashlib.sha256(parent.encode('cp1252')).hexdigest()!=TOP_PARENT_SHA:
        raise ValueError('Changed complete original Snow top-boundary parent')
    path.write_text(top_source(parent),encoding='cp1252')
    return [STATE,'implicit_pond_availability','boundtop',*(name for name in patched if name!='boundtop')]


def validate(bundle):
    folder=Path(__file__).parent
    for name in ('implicit_pond_event_state.f90','implicit_pond_availability.f90'):
        if (bundle/name).read_bytes().replace(b'\r\n',b'\n')!=(folder/name).read_bytes().replace(b'\r\n',b'\n'):
            raise ValueError('Foreign actual Snow pond-event/availability provider')
    from implicit_pond_availability import top_source
    parent=inverse((bundle/'boundtop.f90').read_text(encoding='cp1252'),top_source,TOP_TEMPLATE)
    if hashlib.sha256(parent.encode('cp1252')).hexdigest()!=TOP_PARENT_SHA:
        raise ValueError('Foreign actual Snow top-boundary parent')
    body=(bundle/'macropore.f90').read_text(encoding='cp1252').split('    subroutine hybrid_macro_checkpoint(',1)[1].split('    end subroutine hybrid_macro_checkpoint',1)[0]
    if body.count('use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event')!=1 or body.count('call assert_no_implicit_pond_event()')!=1:
        raise ValueError('Foreign Snow pending-event native boundary')
