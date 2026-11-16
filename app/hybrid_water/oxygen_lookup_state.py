"""Complete original once-initialized oxygen preprocessing history context."""
import re

FIELDS=('d_soil_term1','d_soil_term2','gfp100','Capac_term','Nmin1','Mplus1')

def render(source):
    declarations=[]
    for names in ('d_soil_term1, d_soil_term2, gfp100','Capac_term, Nmin1, Mplus1'):
        pattern=r'(?m)^\s*real\(8\), dimension\(macp\)\s*:: '+re.escape(names)+r'\s*$'
        source,count=re.subn(pattern,'',source)
        if count!=1:raise ValueError('Changed original complete oxygen preprocessing arrays')
        declarations.append('real(8),dimension(macp),save::'+names)
    source,count=re.subn(r'(?m)^\s*logical\s*:: ini = \.TRUE\.\s*$','',source)
    if count!=1 or source.count('         call calc_ini_pars (numnod)')!=1:
        raise ValueError('Changed original oxygen initialization ownership')
    declarations+=['logical,save::ini=.true.,hybrid_oxygen_pending=.false.,hybrid_oxygen_initialized=.false.',
                   'real(8),save::hybrid_oxygen_clock=0d0','real(8),allocatable,save::hybrid_oxygen_values(:,:)']
    anchor='      subroutine OxygenStress(node,rwu_factor)'
    if source.count(anchor)!=1 or source.count('end module O2_pars')!=1:
        raise ValueError('Changed original oxygen component interface')
    source=source.replace(anchor,anchor+'\n      use O2_pars,only:'+','.join(FIELDS)+',ini')
    values=','.join(name+'(1:numnod)' for name in FIELDS)
    assignments='\n'.join(name+'(1:numnod)=hybrid_oxygen_values(:,'+str(i)+')' for i,name in enumerate(FIELDS,1))
    routines='''
contains
subroutine hybrid_oxygen_checkpoint(unit,restoring)
use MOD_grid,only:numnod
use variables,only:t1900
use MOD_swap_base,only:swmacro
use ieee_arithmetic,only:ieee_is_finite
integer,intent(in)::unit
logical,intent(in)::restoring
integer::version,flag,nodes,bytes,expected,ios
real(8)::clock,values(numnod,6)
if(swmacro/=0)error stop 'Oxygen history requires absent macropores'
if(restoring)then
  read(unit,iostat=ios)version,flag,nodes,clock
  if(ios/=0)error stop 'Incomplete original oxygen history header'
else
  version=1;flag=merge(0,1,ini);nodes=numnod;clock=t1900
end if
if(version/=1.or.flag<0.or.flag>1)error stop 'Invalid original oxygen history version/flag'
if(nodes/=numnod)error stop 'Foreign original oxygen history grid'
if(.not.ieee_is_finite(clock).or.clock/=t1900)error stop 'Foreign original oxygen history clock'
expected=24
if(flag==1)then
  expected=24+48*numnod
  if(restoring)then
    read(unit,iostat=ios)values
    if(ios/=0)error stop 'Incomplete original oxygen history arrays'
  else
'''+'\n'.join('    values(:,'+str(i)+')='+name+'(1:numnod)' for i,name in enumerate(FIELDS,1))+'''
  end if
  if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite original oxygen history arrays'
  if(any(values<0d0).or.any(values(:,6)<1d0))error stop 'Invalid original oxygen history domain'
end if
if(restoring)then
  read(unit,iostat=ios)bytes
  if(ios/=0)error stop 'Incomplete original oxygen history trailer'
  if(bytes/=expected)error stop 'Invalid original oxygen history size'
  if(allocated(hybrid_oxygen_values))deallocate(hybrid_oxygen_values)
  if(flag==1)then
    allocate(hybrid_oxygen_values(numnod,6));hybrid_oxygen_values=values
  end if
  hybrid_oxygen_clock=clock;hybrid_oxygen_initialized=flag==1;hybrid_oxygen_pending=.true.
else
  write(unit)version,flag,nodes,clock
  if(flag==1)write(unit)values
  write(unit)expected
end if
end subroutine

subroutine hybrid_apply_oxygen()
use MOD_grid,only:numnod
use variables,only:t1900
if(.not.hybrid_oxygen_pending)return
if(t1900/=hybrid_oxygen_clock)error stop 'Stale original oxygen history context'
if(hybrid_oxygen_initialized)then
  if(.not.allocated(hybrid_oxygen_values))error stop 'Absent original oxygen history context'
  if(any(shape(hybrid_oxygen_values)/=[numnod,6]))error stop 'Changed original oxygen history grid'
'''+assignments+'''
end if
ini=.not.hybrid_oxygen_initialized
hybrid_oxygen_pending=.false.
if(allocated(hybrid_oxygen_values))deallocate(hybrid_oxygen_values)
end subroutine
'''
    return source.replace('end module O2_pars','\n'.join(declarations)+'\n'+routines+'\nend module O2_pars')
