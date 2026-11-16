"""Complete initialized original microscopic uptake lookup restart state.

The original preprocessor owns the values; this adds no constitutive formula.
Undefined allocation tails are outside the serialized physical domain.
"""
import re

POLICY = 'original-initialized-micro-and-top-v2'
MAGICS = {
    (False,False): ('S5WML024','S5WMS025','S5WMM026'),
    (True,False): ('S5CML027','S5CMS028','S5CMM029'),
    (False,True): ('S5WEL030','S5WES031','S5WEM032'),
    (True,True): ('S5CEL033','S5CES034','S5CEM035'),
}
ALL_MAGICS = {name.encode() for values in MAGICS.values() for name in values}

def enabled(project):
    if not project.input_directory or project.macro:return False
    from experimental_project import inspect
    selected=inspect(project.input_directory)['selectors']
    return bool(selected['SWHYST'] or selected['SWSNOW'])

def render(source):
    if not re.search(r'Mcount\s*=\s*801\b',source) or not re.search(r'wiltpoint\s*=\s*-20000\.0d0',source):
        raise ValueError('Changed original microscopic preprocessing domain')
    anchor='   public :: do_RWU_micro, read_rwu_micro_input, PP, PL, UpwPot, swAlpTot, M_table, K_table'
    if source.count(anchor)!=1:raise ValueError('Changed original microscopic module interface')
    source=source.replace(anchor,anchor+'''
   public :: hybrid_micro_checkpoint,hybrid_apply_micro_lookup
   logical,save::hybrid_lookup_pending=.false.
   integer,save::hybrid_lookup_owner=0,hybrid_lookup_drought=0,hybrid_lookup_model=0
   real(8),save::hybrid_lookup_clock=0d0
   real(8),allocatable,save::hybrid_m_lookup(:,:),hybrid_k_lookup(:,:)
''')
    routines='''
subroutine hybrid_micro_checkpoint(unit,restoring)
use MOD_arrays,only:macrop
use MOD_grid,only:numlay
use MOD_swap_base,only:swmacro
use plant_interface,only:icrop,sw_drought,fl_cropemergence
use variables,only:t1900
use ieee_arithmetic,only:ieee_is_finite
implicit none
integer,intent(in)::unit
logical,intent(in)::restoring
integer::version,flag,owner,drought,micro,layers,nm,nk,bytes,expected,ios
real(8)::clock
real(8),allocatable::saved_m(:,:),saved_k(:,:)
logical::active
if(swmacro/=0)error stop 'Microscopic lookup state requires absent macropores'
active=fl_cropemergence.and.(sw_drought==2.or.sw_drought==3)
if(restoring)then
  read(unit,iostat=ios)version,flag,owner,drought,micro,layers,nm,nk,clock
  if(ios/=0)error stop 'Incomplete original microscopic lookup header'
else
  version=1;flag=merge(1,0,active);clock=t1900
  owner=0;drought=0;micro=0;layers=0;nm=0;nk=0
  if(active)then
    owner=icrop;drought=sw_drought;micro=iMicro;layers=numlay;nm=430;nk=429
  end if
end if
if(version/=1.or.flag<0.or.flag>1)error stop 'Invalid original microscopic lookup version/flag'
if(.not.ieee_is_finite(clock).or.clock/=t1900)error stop 'Foreign original microscopic lookup clock'
if(flag/=merge(1,0,active))error stop 'Missing or inactive original microscopic lookup context'
expected=44
if(flag==0)then
  if(any([owner,drought,micro,layers,nm,nk]/=0))error stop 'Nonempty inactive original microscopic lookup metadata'
else
  if(owner<1.or.owner>macrop.or.owner/=icrop)error stop 'Foreign original microscopic lookup crop'
  if(drought/=sw_drought.or.(drought/=2.and.drought/=3))error stop 'Foreign original microscopic lookup drought'
  if((drought==2.and.micro/=2).or.(drought==3.and.micro/=1))error stop 'Foreign original microscopic lookup model'
  if(layers/=numlay.or.nm/=430.or.nk/=429)error stop 'Foreign original microscopic lookup dimensions'
  expected=44+8*(nm+nk)*layers
  if(restoring)then
    allocate(saved_m(nm,layers),saved_k(nk,layers))
    read(unit,iostat=ios)saved_m,saved_k
    if(ios/=0)error stop 'Incomplete original microscopic lookup data'
  else
    if(.not.allocated(M_table).or..not.allocated(K_table))error stop 'Absent original microscopic lookup arrays'
    if(any(shape(M_table)/=[801,numlay]).or.any(shape(K_table)/=[801,numlay]))error stop 'Invalid original microscopic allocation'
    allocate(saved_m(nm,layers),saved_k(nk,layers))
    saved_m=M_table(1:nm,:);saved_k=K_table(1:nk,:)
  end if
  if(.not.all(ieee_is_finite(saved_m)).or..not.all(ieee_is_finite(saved_k)))error stop 'Nonfinite original microscopic lookup data'
  if(any(saved_m<0d0).or.any(saved_k<0d0))error stop 'Negative original microscopic lookup data'
end if
if(restoring)then
  read(unit,iostat=ios)bytes
  if(ios/=0.or.bytes/=expected)error stop 'Invalid original microscopic lookup trailer'
  if(allocated(hybrid_m_lookup))deallocate(hybrid_m_lookup)
  if(allocated(hybrid_k_lookup))deallocate(hybrid_k_lookup)
  hybrid_lookup_pending=flag==1
  hybrid_lookup_owner=owner;hybrid_lookup_drought=drought;hybrid_lookup_model=micro;hybrid_lookup_clock=clock
  if(flag==1)then
    call move_alloc(saved_m,hybrid_m_lookup)
    call move_alloc(saved_k,hybrid_k_lookup)
  end if
else
  write(unit)version,flag,owner,drought,micro,layers,nm,nk,clock
  if(flag==1)write(unit)saved_m,saved_k
  write(unit)expected
end if
end subroutine

subroutine hybrid_apply_micro_lookup()
use MOD_grid,only:numlay
use plant_interface,only:icrop,sw_drought,fl_cropemergence
use variables,only:t1900
implicit none
if(.not.hybrid_lookup_pending)return
if(.not.fl_cropemergence.or.icrop/=hybrid_lookup_owner.or.sw_drought/=hybrid_lookup_drought.or.iMicro/=hybrid_lookup_model) &
  error stop 'Changed original microscopic lookup crop context'
if(t1900/=hybrid_lookup_clock)error stop 'Stale original microscopic lookup context'
if(.not.allocated(M_table).or..not.allocated(K_table))error stop 'Uninitialized original microscopic crop'
if(any(shape(M_table)/=[801,numlay]).or.any(shape(K_table)/=[801,numlay]))error stop 'Changed original microscopic allocation'
M_table(1:430,:)=hybrid_m_lookup
K_table(1:429,:)=hybrid_k_lookup
hybrid_lookup_pending=.false.
deallocate(hybrid_m_lookup,hybrid_k_lookup)
end subroutine
'''
    anchor='end module mod_RWU_micro'
    if source.count(anchor)!=1:raise ValueError('Changed original microscopic module terminator')
    return source.replace(anchor,routines+'\n'+anchor)
