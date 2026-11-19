"""Independent reconstruction of actual original counter reset segments."""
import argparse
import json
import hashlib
import io
import re
import struct
import sys
import zipfile
from datetime import date,timedelta
import math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
from implicit_conductivity_forensics import finite,sequential_records,output_calendar
from extended_forensics import inventory,observed,geometry,bounded
from original_output_files import compare
from age_groundwater_verify import audit as age_observations,tolerance as age_tolerance


def require(ok,message):
    if not ok:raise ValueError(message)


def audit(directory,levels):
    directory=Path(directory)
    rows=[json.loads(line) for line in (directory/'daily.jsonl').read_text().splitlines() if line.strip()]
    frames=[];active=None
    for line in (directory/'original/donor.stdout').read_text().splitlines():
        words=line.split()
        if not words:continue
        tag=words[0]
        if tag=='HYBRID_EXTENDED_OUTPUT_COUNTER_BEGIN':
            values=list(map(float,words[1:]));require(len(values)==3+levels,'Foreign original day counter shape')
            require(active is None,'Original counter day overlaps')
            active=dict(clock=values[0],origins=[values[1:3],values[3:]],terms=[[[] for _ in range(2)],[[] for _ in range(levels)]],resets=[0,0])
        elif tag=='HYBRID_EXTENDED_OUTPUT_COUNTER_RESET':
            require(active is not None,'Original reset has no day origin')
            kind=int(words[1]);values=list(map(float,words[2:]));slot=1 if kind==1 else 0
            require(kind in (1,2),'Foreign reset kind');n=levels if slot else 2
            require(len(values)==1+2*n and active['clock']<=values[0]<=active['clock']+1,'Foreign reset clock/shape')
            current,origin=values[1:1+n],values[1+n:]
            require(origin==active['origins'][slot],'Reset observer changed its actual origin')
            for terms,a,b in zip(active['terms'][slot],current,origin):terms.extend([a,-b])
            active['origins'][slot]=[0.0]*n;active['resets'][slot]+=1
        elif tag=='HYBRID_EXTENDED_OUTPUT_INTERVAL_COUNTERS':
            require(active is not None,'Original final counters have no day origin')
            values=list(map(float,words[1:]));require(len(values)==5+2*levels,'Foreign final original counter shape')
            require(values[0]==active['clock']+1,'Incomplete original day counter clock')
            current=[values[1:3],values[3:3+levels]]
            reported=[values[3+levels:5+levels],values[5+levels:]]
            actual=[]
            for slot in (0,1):
                actual.append([math.fsum([*terms,a,-b]) for terms,a,b in zip(active['terms'][slot],current[slot],active['origins'][slot])])
                require(actual[slot]==reported[slot],'Actual original reset reconstruction differs')
            active.update(actual=actual);frames.append(active);active=None
    require(active is None and len(frames)==len(rows)>0,'Missing actual original daily counter evidence')
    maximum=0.0
    base_clock=frames[0]['clock']-rows[0]['day']+1
    for frame,row in zip(frames,rows):
        require(frame['clock']+1==base_clock+row['day'],'Original counter/physical receipt clock differs')
        actual,per_level=frame['actual'];flow=row['external_flux_cm']
        errors=[actual[0]-flow[13],actual[1]-flow[8],math.fsum([*per_level,-flow[13]])]
        errors.extend(a-b for a,b in zip(per_level,row['surfacewater']['independent_level_exchange_cm']))
        maximum=max(maximum,*map(abs,errors));require(max(map(abs,errors))<=1e-10,'Original reset segments violate soil/surface transfer')
    return dict(status='ACTUAL_ORIGINAL_COUNTER_RESET_RECONSTRUCTION_PASS',actual_days=len(rows),
                reset_segments=sum(sum(frame['resets']) for frame in frames),maximum_transfer_difference_cm=maximum,
                water_guard_cm=1e-10,physical_equations_changed=False,whole_scientific_equivalence='NOT_QUALIFIED')


def checkpoint(path,build,row,selected,dz):
    domain=build['identity']['extended_drainage']['domain'];n,r=domain[1:3];nv=11+3*r+r*n;length=92+16*nv
    clock=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1+row['day']
    with zipfile.ZipFile(io.BytesIO(path) if isinstance(path,bytes) else path) as z:
        require(set(z.namelist())=={'checkpoint.json','result.end','macro.bin'},'Foreign checkpoint members')
        meta=json.loads(z.read('checkpoint.json'));wire=z.read('macro.bin')
        require(meta['schema']=='swap5-hybrid-water-checkpoint-3' and meta['binding']==build['binding'] and meta['receipt']==row and set(meta['files'])=={'result.end','macro.bin'},'Checkpoint receipt/source/inventory differs')
        for name,digest in meta['files'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'Checkpoint member hash differs')
        sequential_records(z.read('result.end'))
        require(wire[:8]==b'S5EDO001' and len(wire)>length+48 and struct.unpack_from('<i',wire,8)[0]==n,'Foreign extended native header')
        stored,step,canopy=struct.unpack_from('<3d',wire,12)
        require(stored==clock and finite([step,canopy]) and 0<step<=1 and canopy>=0 and canopy==row['stock_end_cm'][3],'Foreign native clock/step/canopy')
        seasonal,year=struct.unpack_from('<di',wire,36)
        require(math.isfinite(seasonal) and year==(date.fromisoformat(build['project']['start_date'])+timedelta(days=row['day']-1)).year,'Foreign actual seasonal clock/year')
        at=len(wire)-length;header=struct.pack('<8i',*domain)
        require(wire[at:at+64]==header+header and struct.unpack_from('<i',wire,len(wire)-4)[0]==length,'Foreign extended native domain/trailer')
        c1,c2,a1,a2=struct.unpack_from('<2d2i',wire,at+64)
        values=list(struct.unpack_from('<'+str(nv)+'d',wire,at+88))
        require(c1==c2==clock and a1==a2 and a1>=0 and finite(values) and min(values[2],values[4])>=0,'Invalid extended native values/clock/counter')
        require(wire[at+88:at+88+8*nv]==wire[at+88+8*nv:-4] and dict(adjustments=a1,values=values)==row['extended_drainage_state'],'Extended native duplicate/receipt differs')
        calendar_native(wire[:at],build,row,selected,dz)
        if 'solute_end_mg_cm2' in row:
            chemical=struct.unpack_from('<'+str(n+2)+'d',wire,48)
            require(finite(chemical) and min(chemical)>=0 and chemical[-1]==row['solute_end_mg_cm2'],'Actual conserved CDE native stock differs')
            require(dz is not None and len(dz)==n,'Missing original conserved CDE geometry')
            bounded([math.fsum([*(v*thickness for v,thickness in zip(chemical[:n],dz)),chemical[-2],-chemical[-1]])],'Actual original nodal/surface CDE inventory differs')
        return {name:z.read(name) for name in ('result.end','macro.bin')}

def calendar_native(prefix,build,row,selected,dz):
    n=build['project']['nodes'];r=build['identity']['extended_drainage']['domain'][2]
    age='age_state_cm_day' in row
    if age:
        tail=8*(3*n+25+r+16)+20
        require(len(prefix)>tail,'Incomplete original AGE private section')
        section=prefix[:-tail]
    else:section=prefix
    # Decode the actual calendar substream, without changing any input byte.
    cal=output_calendar(section,n,row,selected,build['project']['start_date'],'solute_end_mg_cm2' in row)
    h=cal['calendar_header'];require(h[2]==r,'Calendar/drainage level domain differs')
    if age:
        start=len(section);body=struct.unpack_from('<'+str(3*n+25+r+16)+'d',prefix,start)
        require(finite(body),'Nonfinite original AGE native section')
        bulk,means,output=body[:n],body[n:2*n],body[2*n:3*n]
        require(min(*bulk,*means,*output,*body[3*n:3*n+3])>=0 and means==output,'Invalid original AGE vectors/output alias')
        require(body[3*n+3:3*n+6]==(0.,0.,0.) and list(body[3*n+6:3*n+14])==row['age_state_cm_day'][3:],'Original AGE forcing/cumulative native differs')
        totals=struct.unpack_from('<3d',prefix,len(prefix)-44)
        require(list(totals)==row['age_state_cm_day'][:3] and body[3*n]==totals[1],'Original AGE native total/receipt differs')
        limit=age_tolerance(*totals)
        require(abs(math.fsum([totals[0],totals[1],-totals[2]]))<=limit and abs(row['stock_end_cm'][1]*body[3*n+2]-body[3*n])<=limit,'Original AGE pond/total native differs')
        require(all(b<=1e12/d for b,d in zip(bulk,dz)) and abs(math.fsum(b*d for b,d in zip(bulk,dz))-totals[0])<=limit,'Original AGE weighted native soil inventory differs')
        exports=struct.unpack_from('<16d',prefix,len(prefix)-172)
        require(min(exports)>=0 and list(exports)==row['age_effluent'][:16],'Original AGE private effluent differs')
        day=struct.unpack_from('<i',prefix,len(prefix)-20)[0];period=struct.unpack_from('<d',prefix,len(prefix)-16)[0]
        flags=struct.unpack_from('<2i',prefix,len(prefix)-8)
        values=struct.unpack_from('<'+str(h[3])+'d',prefix,cal['calendar_offset']+160)
        require(day==row['day'] and period==values[-1] and flags==tuple(h[12:14]),'Original AGE private calendar clock/flags differ')
    return cal


def selected_input(path):
    text=Path(path).read_text(encoding='cp1252')
    def one(key,pattern=r'[+-]?\d+'):
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        require(len(values)==1,'Missing/ambiguous actual original output '+key);return values[0]
    fmt=int(one('SWCSV'));npd=int(one('NPRINTDAY'));monthly=int(one('SWMONTH'));solute=int(one('SWSOLU'))
    step=one('FLPRINTDT',r'\.(?:TRUE|FALSE)\.').upper()=='.TRUE.'
    requested=0 if monthly else int(one('PERIOD'));reset=0 if monthly else int(one('SWRES'));dates=0 if monthly else int(one('SWODAT'))
    return dict(kind={0:'water',1:'cde',2:'age'}[solute],swcsv=fmt,nprintday=npd,swmonth=monthly,swodat=dates,swres=reset,
                requested_period=requested,period=1 if npd>1 or step else requested,flprintdt=step,
                groups=one('INLIST_CSV',r"'[^']*'")[1:-1] if fmt else None,num_decimals=int(one('NUM_DECIMALS')) if fmt else None)


class ActualFiles:
    def __init__(self,root):self.root=Path(root)
    def read(self,name):return (self.root/name).read_bytes()


def audit_root(root,compiled_root=None):
    root=Path(root);q=json.loads((root/'RESULT.json').read_text());full=root/'trajectory'
    require(q['status']=='ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS','Incomplete actual calendar campaign')
    data=[json.loads(line) for line in (full/'daily.jsonl').read_text().splitlines()]
    build=json.loads((full/'BUILD.json').read_text());selected=selected_input(root/'input/swap.swp')
    require(q['output_selection']==selected and all(build['identity']['original_output'][key]==value for key,value in selected.items()),'Actual input/output policy differs')
    compiled=Path(compiled_root or q['build_root'])
    actual_build=(compiled/'BUILD.json').read_bytes()
    require(len(data)==q['parameters']['days'] and q['trajectory']['build_sha256']==hashlib.sha256(actual_build).hexdigest() and json.loads(actual_build)==build,'Censored or rebound actual calendar period')
    dz=geometry((root/'input/swap.swp').read_text(encoding='cp1252'));require(len(dz)==build['project']['nodes'],'Original calendar soil geometry differs')
    for name,digest in build['inputs'].items():
        require(Path(name).name==name and hashlib.sha256((root/'input'/name).read_bytes()).hexdigest()==digest,'Actual final original input/build bytes differ')
    levels=build['identity']['extended_drainage']['domain'][2]
    def check_directory(directory,rows):
        result=inventory(rows);observed((directory/'original/donor.stdout').read_bytes(),rows,build)
        result['original_counter_segments']=audit(directory,levels)
        if 'age_state_cm_day' in rows[0]:age_observations(ActualFiles(directory),'',rows,build['project']['start_date'])
        return result
    result=check_directory(full,data);natives={}
    for path in full.glob('accepted-column-1-day-*.zip'):
        day=int(path.stem.rsplit('-',1)[1]);natives[day]=checkpoint(path,build,data[day-1],selected,dz)
    cold=[]
    for window in q['cold']:
        low,high=window['start'],window['end'];directory=root/f'cold-{low}'
        rows=[json.loads(line) for line in (directory/'daily.jsonl').read_text().splitlines()]
        physical=lambda items:[{key:value for key,value in row.items() if key not in ('column','revision')} for row in items]
        require(physical(rows)==physical(data[low:high]),'Actual cold physical receipt differs')
        checks=check_directory(directory,rows)
        native=checkpoint(directory/f'accepted-column-1-day-{high}.zip',build,rows[-1],selected,dz)
        require(native==natives[high],'Actual complete cold native differs')
        checks['original_output']=compare(full/'original',directory/'original',selected,low,high,build['project']['start_date']);cold.append(checks)
    require(len(cold)==(6 if len(data)==1096 else 3 if len(data)>=35 else 2 if q['parameters'].get('end_date') is not None and len(data)==5 else 1),'Missing actual calendar cold window')
    return dict(status='INDEPENDENT_EXTENDED_ORIGINAL_CALENDAR_SOURCE_OBSERVATIONS_NATIVE_OUTPUT_PASS',actual_days=len(data),
                warm=result,cold=cold,actual_complete_native_packages=len(natives),functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);p.add_argument('--levels',type=int)
    p.add_argument('--complete',action='store_true');p.add_argument('--output',type=Path)
    a=p.parse_args();result=audit_root(a.directory) if a.complete else audit(a.directory,a.levels)
    if a.output:a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
