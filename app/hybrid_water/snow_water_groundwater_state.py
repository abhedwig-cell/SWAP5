"""Literal hydraulic and existing diagnostic carry for water Snow groundwater."""
import hashlib
import math
import struct
from pathlib import Path

STATE='snow_water_groundwater_native_state'
ROOT_STATE='snow_water_groundwater_root_state'
POLICY='original-water-snow-groundwater-hydraulic-diagnostic-carry-v1'


def replace(source,old,new,count=1):
    if source.count(old)!=count:raise ValueError('Changed original water Snow native seam: '+old)
    return source.replace(old,new)


def state_source(implicit):
    if implicit not in (0,1):raise ValueError('Foreign water Snow numerical domain')
    source=Path(__file__).with_name('groundwater_history_native_state.f90').read_text(encoding='cp1252')
    for old,new,count in (
        ('hybrid_groundwater_history_native_state','hybrid_snow_water_groundwater_native_state',1),
        ('groundwater_history_native_checkpoint','snow_water_groundwater_native_checkpoint',2),
        ('only: swbotb,swcfbs,','only: swkimpl,swbotb,swcfbs,',1),
        ('swsolu/=1','swsolu/=0.or.swkimpl/='+str(implicit),1),
        ('swsnow<0.or.swsnow>1','swsnow/=1',1),
        ('(swhyst==0.and.swsnow==0)','(swhea/=1.or.swcalt/=2)',1),
        ('expected=[2,n,','expected=['+str(14+implicit)+',n,',1),
        ('swcfbs,1]','swcfbs,swkimpl]',1)):
        source=replace(source,old,new,count)
    return source


def root_source(implicit):
    if implicit not in (0,1):raise ValueError('Foreign water Snow root numerical domain')
    source=Path(__file__).with_name('implicit_snow_root_state.f90').read_text(encoding='cp1252')
    for old,new,count in (
        ('hybrid_implicit_snow_root_state','hybrid_snow_water_groundwater_root_state',1),
        ('implicit_snow_root_checkpoint','snow_water_groundwater_root_checkpoint',2),
        ('swkimpl/=1','swkimpl/='+str(implicit),1),
        ('(swbotb/=5.and.swbotb/=8)','swbotb/=1',1),
        ('expected=[1,numnod,','expected=[2,numnod,',1),
        ('HYBRID_SNOW_ROOT_NATIVE','HYBRID_SNOW_GROUNDWATER_ROOT_NATIVE',1)):
        source=replace(source,old,new,count)
    return source


def domain(project,selected):
    return [14+selected['swkimpl'],project.nodes,0,0,1,selected['swhyst'],1,0,1,2,
        selected['swdra'],selected['et'],selected['swkimpl']]


def metadata(project,selected):
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    return dict(policy=POLICY,source_sha256=sha(Path(__file__).read_bytes().replace(b'\r\n',b'\n')),
        provider_sha256=sha(state_source(selected['swkimpl']).encode('cp1252')),
        root_provider_sha256=sha(root_source(selected['swkimpl']).encode('cp1252')),
        actual_domain=domain(project,selected),hydraulic_doubles='5*actual_nodes+4',
        diagnostic_rates='Original alpwetnoddrz,alpdrynodrtz; no physical store added',
        root_tail_bytes=96,new_physical_state=False)


def validate_candidate(raw,receipt,project,selected):
    from snow_water_groundwater import codec
    n=project.nodes;header=struct.pack('<13i',*domain(project,selected))
    if raw[:8]!=codec(selected) or raw.count(header+header)!=1:raise ValueError('Foreign water Snow groundwater native domain')
    if len(raw)<36+104+8*(5*n+4)+96:raise ValueError('Incomplete water Snow groundwater native carry')
    nodes,clock,step,canopy=struct.unpack_from('<i3d',raw,8)
    if nodes!=n or not all(map(math.isfinite,(clock,step,canopy))) or not 0<step<=1 or canopy<0 or clock!=project.start_clock+receipt.get('day',-1) or canopy!=receipt.get('stock_end_cm',[None]*4)[3]:
        raise ValueError('Actual water Snow groundwater native prefix differs')
    offset=raw.index(header+header)+104;values=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    if not all(map(math.isfinite,values)) or any(v<0 for v in values[n:5*n+2]) or values[-1]<0:
        raise ValueError('Invalid water Snow groundwater hydraulic carry')
    if list(values[:n])!=receipt.get('pressure_head_cm') or values[-2]!=receipt.get('groundwater_cm') or values[-1]!=receipt.get('stock_end_cm',[None])[0]:
        raise ValueError('Actual water Snow groundwater hydraulic receipt differs')
    root_header=(2,n,0,1,selected['swhyst'],1,selected['swkimpl'],0)
    if struct.unpack_from('<8i',raw,len(raw)-96)!=root_header or struct.unpack_from('<8i',raw,len(raw)-64)!=root_header:
        raise ValueError('Foreign water Snow groundwater root domain')
    rates=struct.unpack_from('<2d',raw,len(raw)-32)
    if not all(map(math.isfinite,rates)) or rates!=struct.unpack_from('<2d',raw,len(raw)-16):
        raise ValueError('Invalid water Snow groundwater root witness')
