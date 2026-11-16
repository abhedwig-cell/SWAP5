"""Private whole original oxygen preprocessing context replay; never public state."""
import re

FIELDS=('d_soil_term1','d_soil_term2','gfp100','Capac_term','Nmin1','Mplus1')

def render(source,clock):
    declarations=[]
    for names in ('d_soil_term1, d_soil_term2, gfp100','Capac_term, Nmin1, Mplus1'):
        pattern=r'(?m)^\s*real\(8\), dimension\(macp\)\s*:: '+re.escape(names)+r'\s*$'
        source,count=re.subn(pattern,'',source);assert count==1
        declarations.append('real(8),dimension(macp),save::'+names)
    source,count=re.subn(r'(?m)^\s*logical\s*:: ini = \.TRUE\.\s*$','',source);assert count==1
    declarations.append('logical,save::ini=.true.,hybrid_oxygen_applied=.false.')
    fields=','.join(FIELDS)
    for anchor in ('      subroutine OxygenStress(node,rwu_factor)','end module O2_pars'):
        assert source.count(anchor)==1
    source=source.replace('      subroutine OxygenStress(node,rwu_factor)',
        '      subroutine OxygenStress(node,rwu_factor)\n      use O2_pars,only:'+fields+',ini,hybrid_oxygen_probe')
    anchor='         ini = .FALSE.\n      end if'
    assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n      call hybrid_oxygen_probe(.true.)')
    writes=','.join(name+'(1:numnod)' for name in FIELDS)
    assignments='\n'.join(name+'(1:numnod)=values(:,'+str(i)+')' for i,name in enumerate(FIELDS,1))
    routine=f'''
contains
subroutine hybrid_oxygen_probe(restoring)
use MOD_grid,only:numnod
use variables,only:t1900
use ieee_arithmetic,only:ieee_is_finite
logical,intent(in)::restoring
integer::unit,nodes,flag,ios
real(8)::clock,values(numnod,6)
character(8)::magic
character::trailing
logical::exists
if(t1900/={clock}d0)return
if(ini)error stop 'Absent complete original oxygen context'
if(restoring.and.hybrid_oxygen_applied)return
if(restoring)then
  open(newunit=unit,file='hybrid-oxygen-current.bin',access='stream',form='unformatted',status='replace')
else
  open(newunit=unit,file='hybrid-oxygen-capture.bin',access='stream',form='unformatted',status='replace')
end if
write(unit)'S5JOXY01',t1900,numnod,0,{writes}
close(unit)
if(.not.restoring)return
inquire(file='hybrid-oxygen-origin.bin',exist=exists)
hybrid_oxygen_applied=.true.
if(.not.exists)return
open(newunit=unit,file='hybrid-oxygen-origin.bin',access='stream',form='unformatted',status='old')
read(unit,iostat=ios)magic,clock,nodes,flag
if(ios/=0)error stop 'Incomplete oxygen probe header'
if(magic/='S5JOXY01'.or.clock/=t1900.or.nodes/=numnod.or.flag/=0)error stop 'Foreign whole oxygen context'
read(unit,iostat=ios)values
if(ios/=0)error stop 'Incomplete oxygen probe tables'
read(unit,iostat=ios)trailing
if(.not.is_iostat_end(ios))error stop 'Trailing oxygen probe tables'
close(unit)
if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite original oxygen tables'
{assignments}
open(newunit=unit,file='hybrid-oxygen-restored.bin',access='stream',form='unformatted',status='replace')
write(unit)'S5JOXY01',t1900,numnod,0,{writes}
close(unit)
end subroutine
'''
    return source.replace('end module O2_pars','\n'.join(declarations)+'\n'+routine+'\nend module O2_pars')
