"""Independent actual water groundwater typed hydraulic/calendar evidence reader."""
from datetime import date
import math,struct
import implicit_conductivity_forensics as p
require=p.require

def native(raw,row,build,selected,dz,implicit):
 n=build['project']['nodes'];epoch=build['project']['start_date'];clock=(date.fromisoformat(epoch)-date(1900,1,1)).days+1
 require(raw[:8]==(b'S5IGW001' if implicit else b'S5EGW001') and len(raw)>=36,'Foreign groundwater water native identity');nodes,stored,step,canopy=struct.unpack_from('<i3d',raw,8)
 require(nodes==n and stored==clock+row['day'] and p.finite([stored,step,canopy]) and 0<step<=1 and canopy>=0 and canopy==row['stock_end_cm'][3],'Foreign actual groundwater native prefix/receipt')
 domain=[4 if implicit else 5,n,0,0,1,selected['swhyst'],0,0,1,2,selected['swdra'],selected['et'],implicit];header=struct.pack('<13i',*domain);require(raw.count(header+header)==1,'Foreign groundwater hydraulic domain');pos=raw.index(header+header);offset=pos+104;end=offset+8*(5*n+4);require(end<=len(raw),'Truncated hydraulic carry')
 values=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset);require(p.finite(values) and min(values[n:5*n+2])>=0 and values[-1]>=0,'Invalid hydraulic inventory');require(list(values[:n])==row['pressure_head_cm'] and values[-2]==row['groundwater_cm'] and values[-1]==row['stock_end_cm'][0],'Hydraulic receipt differs');require(abs(math.fsum(a*b for a,b in zip(values[n:2*n],dz))-values[-1])<=1e-10,'Actual hydraulic inventory is unbalanced')
 if selected['swhyst']:
  h=struct.pack('<5i',1,n,0,selected['swhyst'],0);require(raw.count(h+h)==1 and raw[pos-40:pos]==h+h,'Actual hysteresis domain differs')
 else:require(pos>=48,'Hydraulic carry overlaps original clock/physical prefix')
 calendar=p.output_calendar(raw,n,row,selected,epoch,False);require(calendar['calendar_offset']==end,'Hydraulic/calendar ownership overlap or gap');return dict(domain_offset=pos,hydraulic_offset=offset,calendar_offset=end)

