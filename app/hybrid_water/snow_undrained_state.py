"""Literal existing root diagnostic carry for actual ordinary undrained Snow."""
import math
from pathlib import Path
import re
import struct

from snow_water_groundwater_state import replace
from snow_undrained import codec

STATE='snow_undrained_root_state'


def source(selected):
    text=Path(__file__).with_name('implicit_snow_root_state.f90').read_text(encoding='cp1252')
    for old,new in (
        ('hybrid_implicit_snow_root_state','hybrid_snow_undrained_root_state'),
        ('implicit_snow_root_checkpoint','snow_undrained_root_checkpoint'),
        ('swsolu/=0','swsolu/='+str(int(selected['kind']=='cde'))),
        ('swkimpl/=1','swkimpl/='+str(selected['swkimpl'])),
        ('expected=[1,numnod','expected=[3,numnod'),
        ('HYBRID_SNOW_ROOT_NATIVE','HYBRID_UNDRAINED_SNOW_ROOT_NATIVE')):
        count=text.count(old)
        if count<1:raise ValueError('Changed literal original Snow diagnostic provider')
        text=replace(text,old,new,count)
    if selected['swbotb']==6:
        text=replace(text,'(swbotb/=5.and.swbotb/=8)','swbotb/=6')
    elif selected['swbotb']==9:
        text=replace(text,'(swbotb/=5.and.swbotb/=8)','swbotb/=9')
    if selected.get('analytical_snow_models'):
        extra=Path(__file__).with_name('snow_analytical_native.f90').read_text(encoding='cp1252')
        if 2 in selected['analytical_snow_models']:
            before='       any(iHWCKmodel(1:numlay)==2).or.all(iHWCKmodel(1:numlay)==1)) &'
            after='       all(iHWCKmodel(1:numlay)==1)) &'
            extra=replace(extra,before,after)
            extra=replace(extra,'    integer::n,ios','    integer::n,ios,i')
            before_vapor=('    if(any((iHWCKmodel(1:numlay)>=8).and.(.not.NoVap(1:numlay)))) &\n'
                          "       error stop 'Active vapor cannot use analytical Snow native'")
            after_vapor=('    do i=1,numlay\n'
                         '      if(iHWCKmodel(i)>=8)then\n'
                         "        if(.not.NoVap(i))error stop 'Active vapor cannot use analytical Snow native'\n"
                         '      end if\n    end do')
            extra=replace(extra,before_vapor,after_vapor)
        if selected['swbotb'] in (5,8):
            extra=replace(extra,'swbotb/=9','swbotb/='+str(selected['swbotb']))
        text=replace(text,'  implicit none',
            '  use hybrid_snow_analytical_native,only:snow_analytical_domain_checkpoint\n  implicit none')
        text=replace(text,'    expected=[3,numnod',
            '    call snow_analytical_domain_checkpoint(unit,restoring)\n    expected=[3,numnod')
        text=extra+'\n'+text
    return text


def native_build(output,project,patched,selected):
    provider=source(selected);(output/(STATE+'.f90')).write_text(provider,encoding='cp1252')
    path=output/'macropore.f90';text=path.read_text(encoding='cp1252')
    if selected['swkimpl'] and not project.solute and selected['swbotb']!=6:
        # The earlier unchanged dispatcher installs the old implicit water
        # carry. Replace that exact provider for this new domain, rather than
        # serializing the same two diagnostic rates twice.
        import implicit_snow_root_carry as old
        from snow_undrained_build import owner
        parent=owner(selected).MAGIC.decode();child=old.CODECS[parent]
        prior=Path(old.__file__).with_name(old.STATE+'.f90').read_text(encoding='cp1252')+'\n'
        if not text.startswith(prior) or text.count(prior)!=1:
            raise ValueError('Foreign original implicit root carry before undrained composition')
        text=text[len(prior):]
        for token in ('      use hybrid_implicit_snow_root_state,only:implicit_snow_root_checkpoint\n',
            '        call implicit_snow_root_checkpoint(unit,.true.,clock)\n',
            '        call implicit_snow_root_checkpoint(unit,.false.,clock)\n'):
            text=replace(text,token,'')
        text=replace(text,"'"+child+"'","'"+parent+"'",2)
    path.write_text(macro(text,selected),encoding='cp1252')
    return patched


def macro(text,selected):
    provider=source(selected)
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    if text.count(begin)!=1 or text.count(end)!=1:raise ValueError('Ambiguous undrained Snow checkpoint owner')
    low=text.index(begin);high=text.index(end,low)+len(end);body=text[low:high]
    codes=re.findall(r"'(S5[A-Z0-9]{6})'",body)
    if len(codes)!=2 or len(set(codes))!=1:raise ValueError('Ambiguous undrained Snow native codec')
    body=replace(body,codes[0],codec(selected).decode(),2)
    anchor='      use MOD_grid, only: numnod'
    body=replace(body,anchor,'      use hybrid_snow_undrained_root_state,only:snow_undrained_root_checkpoint\n'+anchor)
    for restoring in ('.true.','.false.'):
        anchor='        read(unit,iostat=ios) trailing' if restoring=='.true.' else '      end if\n      close(unit)'
        body=replace(body,anchor,f'        call snow_undrained_root_checkpoint(unit,{restoring},clock)\n'+anchor)
    return provider+'\n'+text[:low]+body+text[high:]


def validate_native(raw,selected,nodes):
    if len(raw)<104 or raw[:8]!=codec(selected):raise ValueError('Foreign undrained Snow native payload')
    expected=[3,nodes,int(selected['kind']=='cde'),1,selected['swhyst'],selected['swbotb'],selected['swkimpl'],0]
    header=struct.unpack('<16i',raw[-96:-32]);values=struct.unpack('<4d',raw[-32:])
    if list(header[:8])!=expected or list(header[8:])!=expected:raise ValueError('Foreign undrained Snow root witness')
    if values[:2]!=values[2:] or not all(map(math.isfinite,values)):raise ValueError('Invalid undrained Snow root values')
    models=selected.get('analytical_snow_models')
    if models:
        domain=[1,nodes,len(models),int(selected['kind']=='cde'),*models];size=4*len(domain)
        if len(raw)<104+2*size:raise ValueError('Incomplete analytical Snow native model domain')
        at=len(raw)-96-2*size
        actual=struct.unpack_from('<'+str(2*len(domain))+'i',raw,at)
        if list(actual)!=domain+domain:raise ValueError('Foreign analytical Snow native model witness')
    return values[:2]


def validate_source(bundle,selected):
    bundle=Path(bundle);provider=source(selected)
    if (bundle/(STATE+'.f90')).read_text(encoding='cp1252')!=provider:raise ValueError('Foreign undrained Snow root provider')
    text=(bundle/'macropore.f90').read_text(encoding='cp1252')
    if not text.startswith(provider+'\n') or text.count(provider)!=1:raise ValueError('Foreign compiled undrained Snow root provider')
    for part in ('use hybrid_snow_undrained_root_state,only:snow_undrained_root_checkpoint',
        'call snow_undrained_root_checkpoint(unit,.true.,clock)',
        'call snow_undrained_root_checkpoint(unit,.false.,clock)'):
        if text.count(part)!=1:raise ValueError('Foreign undrained Snow root ownership')
