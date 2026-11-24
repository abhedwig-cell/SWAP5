"""Decode analytical Snow model identities and original physical native fields."""
from datetime import date
import struct

from ordinary_pond_evidence import require
from implicit_snow_forensics import original


def native(raw,row,build,s,dz):
    n=build['project']['nodes'];selected=build['identity']['original_output']
    models=selected['analytical_snow_models']
    require(models and any(value!=1 for value in models) and
        all(value in (1,3,4,5,6,7,8,9,10,11) for value in models),'Foreign analytical Snow models')
    require(s['SWBOTB'] in (5,8) and s['SWKIMPL']==s['SWHYST']==s['SWDRA']==0,
        'Foreign analytical Snow composition')
    kind='R' if selected['flprintdt'] and s['SWRES'] else 'P' if selected['flprintdt'] else 'C' if s['NPRINTDAY']>1 else 'I'
    expected=('S5A'+('C' if s['SWSOLU'] else 'W')+kind+'000').encode()
    require(raw[:8]==expected and selected['native_codec']==expected.decode(),'Foreign analytical Snow codec')
    epoch=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
    nodes,clock,step,canopy=struct.unpack_from('<i3d',raw,8)
    require(nodes==n and original.finite([clock,step,canopy]) and clock==epoch+row['day'] and
        0<step<=1 and canopy==row['stock_end_cm'][3]>=0,'Foreign analytical Snow physical prefix')
    domain=(1,n,len(models),s['SWSOLU'],*models);size=8*len(domain)
    require(len(raw)>96+size,'Truncated analytical Snow model witness')
    at=len(raw)-96-size
    require(struct.unpack_from('<'+str(2*len(domain))+'i',raw,at)==domain+domain,
        'Foreign analytical Snow layer model witness')
    root=(3,n,s['SWSOLU'],1,0,s['SWBOTB'],0,0)
    require(struct.unpack_from('<8i',raw,len(raw)-96)==struct.unpack_from('<8i',raw,len(raw)-64)==root,
        'Foreign analytical Snow root witness')
    rates=struct.unpack_from('<2d',raw,len(raw)-32)
    require(original.finite(rates) and rates==struct.unpack_from('<2d',raw,len(raw)-16),
        'Foreign analytical Snow root diagnostic rates')
    calendar=original.output_calendar(raw[:at],n,row,selected,build['project']['start_date'],bool(s['SWSOLU']))
    thermal=struct.pack('<10i',1,n,0,s['SWSOLU'],0,1,0,0,1,2)
    snow=struct.pack('<4i',1,n,s['SWSOLU'],7)
    require(raw.count(thermal+thermal)==raw.count(snow+snow)==1,'Foreign analytical Snow thermal state')
    thermal_at=raw.index(thermal+thermal);snow_at=raw.index(snow+snow)
    require(thermal_at+80==snow_at and snow_at+88==calendar['calendar_offset'],
        'Foreign analytical Snow thermal/calendar ordering')
    totals=struct.unpack_from('<7d',raw,snow_at+32)
    require(original.finite(totals) and min(totals)>=0,'Invalid analytical Snow totals')
    return dict(layer_models=models,domain_offset=at,domain_bytes=size,root_rates=rates)
