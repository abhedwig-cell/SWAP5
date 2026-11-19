"""Independent receipt and binary evidence checks for implicit conductivity."""
from datetime import date,timedelta
import hashlib,io,json,math,struct,zipfile


def require(ok,message):
    if not ok:raise ValueError(message)


def finite(values):return all(type(v) in (int,float) and math.isfinite(v) for v in values)


def water(data):
    require(bool(data),'Empty actual implicit trajectory')
    first=data[0]['day'];previous=None
    for index,row in enumerate(data):
        require(row['committed'] is True and row['day']==first+index,'Censored actual implicit day sequence')
        start=row['stock_start_cm'];end=row['stock_end_cm'];flow=row['external_flux_cm']
        require(len(start)==len(end)==6 and len(flow)==16 and finite([*start,*end,*flow,*row['pressure_head_cm']]),'Malformed actual implicit physical receipt')
        if previous is not None:require(start==previous,'Discontinuous actual implicit accepted stocks')
        residual=math.fsum([*flow[:7],*(-v for v in flow[7:]),*start,*(-v for v in end)])
        values=[residual,*(row[k] for k in ('independent_residual_cm','kernel_residual_cm','integrated_guard_residual_cm'))]
        require(finite(values) and max(map(abs,values))<=1e-10,'Actual implicit water guard exceeded')
        previous=end
    total=math.fsum([*data[0]['stock_start_cm'],*(-v for v in data[-1]['stock_end_cm']),*(v for row in data for v in row['external_flux_cm'][:7]),*(-v for row in data for v in row['external_flux_cm'][7:])])
    require(abs(total)<=1e-10,'Whole actual implicit water inventory does not close')
    return dict(days=len(data),whole_water_residual_cm=total)


def original_observations(raw,data,epoch):
    stocks=flows=hydraulic=None;observed=[];initial=None
    for line in raw.decode('utf8').splitlines():
        if line.startswith('HYBRID_READY '):
            require(initial is None,'Duplicated actual original ready clock');initial=float(line.split()[1])
        elif line.startswith('HYBRID_STOCK_FLUX '):stocks=list(map(float,line.split()[1:]))
        elif line.startswith('HYBRID_EXTERNAL_FLUX '):flows=list(map(float,line.split()[1:]))
        elif line.startswith('HYBRID_HYDRAULIC '):hydraulic=list(map(float,line.split()[1:]))
        elif line.startswith('HYBRID_DAY_RETURN '):
            require(len(observed)<len(data),'Extra actual original day return');row=data[len(observed)];parts=line.split()
            require(stocks==row['stock_end_cm']+row['stock_start_cm'] and flows==row['external_flux_cm'],'Actual original stock/flux witness differs from report')
            require(hydraulic is not None and hydraulic[0]==row['groundwater_cm'] and hydraulic[2:]==row['pressure_head_cm'],'Actual original hydraulic witness differs from report')
            require(int(parts[1])==row['day'] and float(parts[2])==initial+len(observed)+1,'Actual original accepted day/clock differs')
            observed.append(row['day']);stocks=flows=hydraulic=None
    clock=(date.fromisoformat(epoch)-date(1900,1,1)).days+1
    require(initial==clock+data[0]['day']-1 and len(observed)==len(data),'Actual original initial epoch or complete day observations differ')
    return dict(actual_original_days=len(observed),initial_clock=initial)


def sequential_records(raw):
    at=0;lengths=[]
    while at<len(raw):
        require(at+8<=len(raw),'Truncated actual original sequential record')
        count=struct.unpack_from('<i',raw,at)[0]
        require(count>0 and at+count+8<=len(raw),'Foreign actual original sequential record length')
        require(struct.unpack_from('<i',raw,at+count+4)[0]==count,'Actual original sequential record witness differs')
        lengths.append(count);at+=count+8
    require(at==len(raw) and bool(lengths),'Empty or trailing actual original sequential state')
    return lengths


def implicit_water_native(raw,row,n,selected,dz,epoch):
    require(raw[:8]==b'S5IGW001','Foreign actual implicit water native magic')
    require(len(raw)>=36,'Incomplete actual implicit water header')
    nodes,stored,step,canopy=struct.unpack_from('<i3d',raw,8)
    clock=(date.fromisoformat(epoch)-date(1900,1,1)).days+1;day=row['day']
    require(nodes==n and stored==clock+day and finite([stored,step,canopy]) and 0<step<=1 and canopy>=0,'Foreign actual implicit native clock/domain')
    domain=[4,n,0,0,1,selected['swhyst'],0,0,1,2,selected['swdra'],selected['et'],1]
    header=struct.pack('<13i',*domain)
    require(raw.count(header+header)==1,'Actual implicit hydraulic domain/witness differs')
    pos=raw.index(header+header);offset=pos+104;end=offset+8*(5*n+4)
    require(end<=len(raw),'Truncated actual implicit hydraulic state')
    state=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    require(finite(state) and min(state[n:5*n+2])>=0 and state[-1]>=0,'Nonfinite/negative actual implicit hydraulic state')
    require(list(state[:n])==row['pressure_head_cm'] and state[-2]==row['groundwater_cm'] and state[-1]==row['stock_end_cm'][0],'Actual implicit native hydraulic receipt differs')
    require(len(dz)==n and abs(math.fsum(a*b for a,b in zip(state[n:2*n],dz))-state[-1])<=1e-10,'Actual implicit hydraulic water inventory differs')
    if selected['swhyst']:
        h=struct.pack('<5i',1,n,0,selected['swhyst'],0)
        require(raw.count(h+h)==1 and raw[pos-40:pos]==h+h,'Actual implicit hysteresis domain differs')
    # The unchanged original calendar follows the new typed carry and owns EOF.
    require(end+160<=len(raw),'Truncated actual implicit output calendar')
    h=struct.unpack_from('<20i',raw,end);nr=h[3]
    # Count unchanged original fields: 2*3000 dates, 10*n nodal values,
    # three nodal drainage profiles plus three level totals, 68 scalar slots.
    require(h==struct.unpack_from('<20i',raw,end+80) and h[:2]==(1,n) and 0<=h[2]<=5 and nr==6068+10*n+(3*n+3)*h[2] and end+160+16*nr==len(raw),'Actual implicit calendar shape/witness/EOF differs')
    effective=selected['period'];completed=date.fromisoformat(epoch)+timedelta(days=day-1)
    counter=min(day,completed.timetuple().tm_yday) if selected['swres'] and effective else day
    if effective:counter%=effective
    require(selected['nprintday']==1 and selected['flprintdt'] is False,'Unqualified implicit water subdaily calendar')
    require((h[4],h[5],h[6],h[7],h[8],h[11],h[18],h[19])==(effective,1,day,counter,1,selected['swres'],0,0) and all(v in (0,1) for v in h[12:20]) and all(1<=v<=3000 for v in h[9:11]),'Actual implicit calendar day/policy/counters differ')
    first=raw[end+160:end+160+8*nr];require(first==raw[end+160+8*nr:],'Actual implicit calendar value witness differs')
    values=struct.unpack('<'+str(nr)+'d',first);require(finite(values) and values[-1]>=0,'Nonfinite/negative actual implicit calendar values')
    balance=values[-6008:-3008];interval=values[-3008:-8]
    require(h[9]==1+sum(0<v<clock+day-1e-8 for v in balance) and h[10]==1+sum(0<v<clock+day-1e-8 for v in interval),'Actual implicit original date pointers differ')
    return dict(domain_offset=pos,hydraulic_offset=offset,calendar_offset=end,calendar_header=list(h),hydraulic_values=list(state))


def checkpoint(raw,build,row,selected,dz):
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        require(set(z.namelist())=={'checkpoint.json','result.end','macro.bin'},'Foreign actual implicit native members')
        meta=json.loads(z.read('checkpoint.json'))
        require(meta['schema']=='swap5-hybrid-water-checkpoint-3' and meta['binding']==build['binding'] and meta['receipt']==row,'Actual implicit checkpoint origin/receipt differs')
        require(set(meta['files'])=={'result.end','macro.bin'},'Actual implicit native hash inventory differs')
        for name,digest in meta['files'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'Actual implicit native member hash differs')
        result=sequential_records(z.read('result.end'));native=implicit_water_native(z.read('macro.bin'),row,build['project']['nodes'],selected,dz,build['project']['start_date'])
        return dict(sequential_record_lengths=result,water=native)


def output_calendar(raw,n,row,selected,epoch,chemical):
    """Read actual paired original calendar independently of transport codec."""
    marker=struct.pack('<2i',1,n);positions=[];at=raw.find(marker)
    while at>=0:
        if at+160<=len(raw):
            h=struct.unpack_from('<20i',raw,at)
            if raw[at:at+80]==raw[at+80:at+160] and 0<=h[2]<=5 and h[3]==6068+10*n+(3*n+3)*h[2]:positions.append((at,h))
        at=raw.find(marker,at+1)
    require(len(positions)==1,'Actual original paired calendar missing or ambiguous');at,h=positions[0];nr=h[3];end=at+160+16*nr
    require(end<=len(raw),'Truncated actual original calendar values')
    day=row['day'];period=selected['period'];step=selected['flprintdt'];npd=selected['nprintday'];short=step or npd>1
    completed=date.fromisoformat(epoch)+timedelta(days=day-1);counter=min(day,completed.timetuple().tm_yday) if selected['swres'] and period else day
    if period and not step:counter%=period
    require((h[4],h[5],h[6],h[7],h[8],h[11],h[18],h[19])==(period,npd,day,counter,1 if step or not short else day*npd+1,selected['swres'],int(short),int(step)),'Actual original calendar numerical policy/day/counters differ')
    require(all(v in (0,1) for v in h[12:20]) and all(1<=v<=3000 for v in h[9:11]),'Actual original calendar flags/pointers differ')
    first=raw[at+160:at+160+8*nr];require(first==raw[at+160+8*nr:end],'Actual original calendar value witness differs');values=struct.unpack('<'+str(nr)+'d',first)
    require(finite(values) and values[-1]>=0,'Nonfinite/negative actual original calendar values');clock=(date.fromisoformat(epoch)-date(1900,1,1)).days+1
    balance=values[-6008:-3008];interval=values[-3008:-8];require(h[9]==1+sum(0<v<clock+day-1e-8 for v in balance),'Actual original balance date pointer differs')
    past=0<interval[0]<clock-1e-8;expected=1 if past else 1+sum(0<v<clock+day-1e-8 for v in interval)
    require(h[10]==1 if past else h[10]<=expected if step else h[10]==expected,'Actual original interval date pointer differs')
    if chemical:
        require(end+24<=len(raw),'Missing actual original chemical private state');head=struct.unpack_from('<3i',raw,end);version,nn,size=head
        require(nn==n and version in (1,2) and size==n+(18 if version==1 else 20) and head==struct.unpack_from('<3i',raw,end+12) and end+24+16*size==len(raw),'Actual original chemical private domain/witness/EOF differs')
        private=raw[end+24:end+24+8*size];require(private==raw[end+24+8*size:],'Actual original chemical private value witness differs');state=struct.unpack('<'+str(size)+'d',private);require(finite(state),'Nonfinite actual original chemical private state')
        stock=struct.unpack_from('<'+str(n+2)+'d',raw,48);require(finite(stock) and min(stock)>=0 and stock[-1]==row['solute_end_mg_cm2'],'Actual native conserved chemical stock differs')
        if version==2:require(state[0]>=0 and state[-2]>=0 and stock[-1]-state[-2]==state[14],'Actual original chemical private anchor differs')
    else:require(end==len(raw),'Trailing actual original water native bytes')
    return dict(calendar_offset=at,calendar_header=list(h),calendar_end=end)


def general_checkpoint(raw,build,row,selected,dz):
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        require(set(z.namelist())=={'checkpoint.json','result.end','macro.bin'},'Foreign actual original checkpoint members');meta=json.loads(z.read('checkpoint.json'))
        require(meta['schema']=='swap5-hybrid-water-checkpoint-3' and meta['binding']==build['binding'] and meta['receipt']==row and set(meta['files'])=={'result.end','macro.bin'},'Actual original checkpoint origin/receipt/inventory differs')
        for name,digest in meta['files'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'Actual original checkpoint member hash differs')
        result=general_native(z.read('macro.bin'),build,row,selected,dz)
        result['sequential_record_lengths']=sequential_records(z.read('result.end'))
        return result


def general_native(wire,build,row,selected,dz):
    magic=wire[:8].decode('ascii');allowed={'S5IOW001','S5IGW001','S5OPH001','S5CCC001','S5CIH001','S5GHC003'}
    require(magic in allowed,'Unqualified actual implicit water/CDE native codec');require(struct.unpack_from('<i',wire,8)[0]==build['project']['nodes'],'Actual original checkpoint node domain differs')
    n=build['project']['nodes'];stored,step,canopy=struct.unpack_from('<3d',wire,12);clock=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
    require(stored==clock+row['day'] and finite([stored,step,canopy]) and 0<step<=1 and canopy>=0,'Actual original native clock/step/canopy differs')
    chemical=magic in {'S5CCC001','S5CIH001','S5GHC003'};result=dict(magic=magic,calendar=output_calendar(wire,n,row,selected,build['project']['start_date'],chemical))
    if magic=='S5IGW001':result['water']=implicit_water_native(wire,row,n,selected,dz,build['project']['start_date'])
    if magic=='S5GHC003':
        from groundwater_history_verify import native
        native(wire,row,build['identity']['groundwater_native_state'])
    if selected['swhyst']:
        header=struct.pack('<5i',1,n,0,selected['swhyst'],int(chemical));require(wire.count(header+header)==1,'Actual original implicit hysteresis domain differs')
    return result
