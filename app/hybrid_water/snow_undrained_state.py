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
    return text


def native_build(output,project,patched,selected):
    provider=source(selected);(output/(STATE+'.f90')).write_text(provider,encoding='cp1252')
    path=output/'macropore.f90';path.write_text(macro(path.read_text(encoding='cp1252'),selected),encoding='cp1252')
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
