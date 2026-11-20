"""Literal hydraulic and existing diagnostic carry for water Snow groundwater."""
import hashlib
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
