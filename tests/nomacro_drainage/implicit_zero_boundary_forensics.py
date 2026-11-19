"""Independent ordinary-drainage zero-flux observations/native/output audit."""
from datetime import date,timedelta
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import zipfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
from implicit_conductivity_forensics import water,original_observations,output_calendar,sequential_records,finite,require
from cde_clock_verify import ledger as chemical_ledger
from extended_forensics import geometry
from original_output_files import compare


def rows(path):return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def checkpoint(path,build,row,selected,dz):
    n=build['project']['nodes'];kind=selected['kind'];hys=selected.get('swhyst',0)
    expected=b'S5IHC001' if kind=='cde' and hys else b'S5IOW001'
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())=={'checkpoint.json','result.end','macro.bin'},'Foreign actual zero-boundary native members')
        meta=json.loads(z.read('checkpoint.json'));wire=z.read('macro.bin')
        require(meta['binding']==build['binding'] and meta['receipt']==row and set(meta['files'])=={'result.end','macro.bin'},'Actual zero-boundary origin/receipt/hash domain differs')
        for name,digest in meta['files'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'Actual zero-boundary native member changed')
        sequential_records(z.read('result.end'))
        nodes,clock,step,canopy=struct.unpack_from('<i3d',wire,8);epoch=build['project']['start_date'];base=(date.fromisoformat(epoch)-date(1900,1,1)).days+1
        require(wire[:8]==expected and nodes==n and clock==base+row['day'] and finite([clock,step,canopy]) and 0<step<=1 and canopy==row['stock_end_cm'][3],'Actual zero-boundary native clock/step/canopy differs')
        cal=output_calendar(wire,n,row,selected,epoch,kind=='cde');at=cal['calendar_offset']
        if kind=='cde':
            end=cal['calendar_end'];require(struct.unpack_from('<3i',wire,end)==(1,n,18+n) and struct.unpack_from('<d',wire,end+24)[0]>=0,'Invalid actual original zero-boundary CDE private anchor')
            stock=struct.unpack_from('<'+str(n+2)+'d',wire,48)
            require(abs(math.fsum([*(v*d for v,d in zip(stock[:n],dz)),stock[-2],-stock[-1]]))<=1e-10,'Actual zero-boundary weighted chemical stock differs')
        if hys:
            domain=struct.pack('<5i',1,n,0,hys,int(kind=='cde'));require(wire.count(domain+domain)==1 and wire[at-40:at]==domain+domain,'Actual ordinary hydraulic-history domain differs')
            marker=struct.pack('<'+str(n)+'d',*row['pressure_head_cm']);prefix=wire[:at-40];require(prefix.count(marker)==1,'Missing/ambiguous actual ordinary hydraulic carry')
            offset=prefix.index(marker);require(offset+8*(5*n+4)<=at-40,'Truncated actual ordinary hydraulic carry')
            state=struct.unpack_from('<'+str(5*n+4)+'d',wire,offset)
            require(finite(state) and min(state[n:5*n+2])>=0 and state[-2]==row['groundwater_cm'] and state[-1]==row['stock_end_cm'][0],'Actual ordinary hydraulic carry/receipt differs')
            require(abs(math.fsum(v*d for v,d in zip(state[n:2*n],dz))-state[-1])<=1e-10,'Actual ordinary hydraulic theta inventory differs')
        return {name:z.read(name) for name in ('result.end','macro.bin')}


def audit(root,compiled_root=None):
    root=Path(root);q=json.loads((root/'RESULT.json').read_text());compiled=Path(compiled_root or q['build_root']);raw=(compiled/'BUILD.json').read_bytes();build=json.loads(raw)
    require(q['status']=='ACTUAL_ORDINARY_DRAINAGE_IMPLICIT_ZERO_BOUNDARY_NATIVE_OUTPUT_PASS' and q['trajectory']['build_sha256']==hashlib.sha256(raw).hexdigest(),'Actual zero-boundary producer/build incomplete or rebound')
    require(json.loads((root/'trajectory/BUILD.json').read_text())==build and build['identity']['implicit_conductivity']['SWKIMPL']==1,'Actual zero-boundary numerical identity differs')
    for name,digest in build['inputs'].items():require(hashlib.sha256((root/'input'/name).read_bytes()).hexdigest()==digest,'Actual zero-boundary input/build identity changed')
    selected=build['identity']['original_output'];dz=geometry((root/'input/swap.swp').read_text(encoding='cp1252'));data=rows(root/'trajectory/daily.jsonl')
    require(len(data)==35 and data[0]['day']==1 and [(v['start'],v['end']) for v in q['cold']]==[(2,4),(7,9),(30,34)],'Actual ordinary zero-boundary period/windows censored')
    def directory(path,values):
        result=water(values);original_observations((path/'original/donor.stdout').read_bytes(),values,build['project']['start_date'])
        actual=[list(map(float,line.split()[1:])) for line in (path/'original/donor.stdout').read_text().splitlines() if line.startswith('HYBRID_HYDRAULIC ')]
        require(len(actual)==len(values)+1 and all(item[1]==0 for item in actual),'Actual original ordinary bottom6 flux/count differs')
        if selected['kind']=='cde':chemical_ledger(values,len(values))
        return result
    warm=directory(root/'trajectory',data);natives={}
    for path in (root/'trajectory').glob('accepted-column-1-day-*.zip'):
        day=int(path.stem.rsplit('-',1)[1]);natives[day]=checkpoint(path,build,data[day-1],selected,dz)
    require(set(natives)=={2,4,7,9,30,34,35},'Actual ordinary zero-boundary checkpoint inventory changed')
    cold=[];physical=lambda values:[{k:v for k,v in row.items() if k not in ('column','revision')} for row in values]
    for low,high in ((2,4),(7,9),(30,34)):
        path=root/f'own-{low}';values=rows(path/'daily.jsonl');require(physical(values)==physical(data[low:high]),'Actual ordinary zero-boundary cold physical receipt differs')
        report=directory(path,values);require(checkpoint(path/f'accepted-column-1-day-{high}.zip',build,values[-1],selected,dz)==natives[high],'Actual ordinary zero-boundary complete native differs')
        report['output']=compare(root/'trajectory/original',path/'original',selected,low,high,build['project']['start_date']);cold.append(report)
    return dict(status='INDEPENDENT_ORIGINAL_ORDINARY_IMPLICIT_ZERO_BOUNDARY_WATER_CDE_NATIVE_OUTPUT_PASS',warm=warm,cold=cold,actual_days=35,whole_water_guard_cm=1e-10)


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.directory)
    with a.output.open('x') as stream:json.dump(q,stream,indent=2)
    print(q['status'],q['actual_days'])
