"""Independent actual implicit extended-drain conservation/native observations.

Preceding readers are unchanged; this separately scoped reader selects the
implicit codec and uses existing complete history and calendar decoders.
No production adapter or decoder is imported.
"""
from datetime import date,timedelta
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import zipfile
import calendar_forensics as calendar
import history_forensics as history
from calendar_forensics import require,finite,sequential_records,output_calendar,inventory,observed,geometry,bounded,audit,age_observations,ActualFiles,legacy_terminal,compare


def selected_input(path):
    selected=calendar.selected_input(path);text=Path(path).read_text(encoding='cp1252')
    def one(key):
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([+-]?\d+)[ \t]*(?:!.*)?$',text)
        require(len(values)==1,'Missing/ambiguous original implicit '+key);return int(values[0])
    require(one('SWKIMPL')==1 and one('SWBOTB')==6 and one('SWSOLU') in (0,1),'Unqualified original implicit extended domain')
    mode=one('SWHYST');require(mode in (0,1,2),'Unqualified original implicit hydraulic history')
    return dict(selected,swhyst=mode)


def calendar_native(prefix,build,row,selected,dz):
    return (history.calendar_native if selected['swhyst'] else calendar.calendar_native)(prefix,build,row,selected,dz)


def checkpoint(path,build,row,selected,dz):
    domain=build['identity']['extended_drainage']['domain'];n,r=domain[1:3];nv=11+3*r+r*n;length=92+16*nv
    clock=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1+row['day']
    with zipfile.ZipFile(io.BytesIO(path) if isinstance(path,bytes) else path) as z:
        require(set(z.namelist())=={'checkpoint.json','result.end','macro.bin'},'Foreign checkpoint members')
        meta=json.loads(z.read('checkpoint.json'));wire=z.read('macro.bin')
        require(meta['schema']=='swap5-hybrid-water-checkpoint-3' and meta['binding']==build['binding'] and meta['receipt']==row and set(meta['files'])=={'result.end','macro.bin'},'Checkpoint receipt/source/inventory differs')
        for name,digest in meta['files'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'Checkpoint member hash differs')
        sequential_records(z.read('result.end'))
        require(wire[:8]==(b'S5EHK001' if selected['swhyst'] else b'S5EDK001') and len(wire)>length+48 and struct.unpack_from('<i',wire,8)[0]==n,'Foreign extended native header')
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

def audit_root(root,compiled_root=None):
    root=Path(root);q=json.loads((root/'RESULT.json').read_text());full=root/'trajectory'
    require(q['status']=='ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS','Incomplete actual calendar campaign')
    data=[json.loads(line) for line in (full/'daily.jsonl').read_text().splitlines()]
    days=q['parameters']['days']
    expected=[(1,2)] if days==2 else [(2,4)]
    if q['parameters'].get('end_date') and days==5:expected.append((4,5))
    if days>=35:expected += [(14,17),(30,35)]
    if days==1096:expected += [(363,367),(530,532),(1094,1096)]
    require([(window['start'],window['end']) for window in q['cold']]==expected,'Actual required calendar cold windows changed')
    build=json.loads((full/'BUILD.json').read_text());selected=selected_input(root/'input/swap.swp')
    require(q['output_selection']=={key:value for key,value in selected.items() if key!='swhyst'} and q['parameters']['hysteresis']==selected['swhyst'] and all(build['identity']['original_output'][key]==value for key,value in selected.items() if key!='swhyst' or value) and q['parameters']['implicit'] is True and build['identity']['implicit_conductivity']['SWKIMPL']==1 and build['identity']['implicit_conductivity']['examined_ksat_interpolation'] is False,'Actual input/output hydraulic policy differs')
    compiled=Path(compiled_root or q['build_root'])
    actual_build=(compiled/'BUILD.json').read_bytes()
    require(len(data)==q['parameters']['days'] and q['trajectory']['build_sha256']==hashlib.sha256(actual_build).hexdigest() and json.loads(actual_build)==build,'Censored or rebound actual calendar period')
    dz=geometry((root/'input/swap.swp').read_text(encoding='cp1252'));require(len(dz)==build['project']['nodes'],'Original calendar soil geometry differs')
    for name,digest in build['inputs'].items():
        require(Path(name).name==name and hashlib.sha256((root/'input'/name).read_bytes()).hexdigest()==digest,'Actual final original input/build bytes differ')
    levels=build['identity']['extended_drainage']['domain'][2]
    def check_directory(directory,rows):
        result=inventory(rows);observed((directory/'original/donor.stdout').read_bytes(),rows,build)
        actual_hydraulic=[list(map(float,line.split()[1:])) for line in (directory/'original/donor.stdout').read_text().splitlines() if line.startswith('HYBRID_HYDRAULIC ')]
        require(len(actual_hydraulic)==len(rows)+1,'Actual original hydraulic initial/day frame count changed')
        require(all(values[1]==0 for values in actual_hydraulic),'Actual original bottom6 emitted nonzero bottom flux')
        result['actual_zero_bottom_hydraulic_initial_and_day_frames']=len(actual_hydraulic)
        result['original_counter_segments']=audit(directory,levels)
        if 'age_state_cm_day' in rows[0]:age_observations(ActualFiles(directory),'',rows,build['project']['start_date'])
        return result
    result=check_directory(full,data);natives={}
    for path in full.glob('accepted-column-1-day-*.zip'):
        day=int(path.stem.rsplit('-',1)[1]);natives[day]=checkpoint(path,build,data[day-1],selected,dz)
    require(set(natives)=={days,*(day for pair in expected for day in pair)},'Actual complete calendar checkpoint inventory differs')
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
        if high==len(data) and (len(data)==1096 or q['parameters'].get('end_date')):
            epoch=date.fromisoformat(build['project']['start_date'])
            checks['original_legacy_terminal']=legacy_terminal(full/'original',directory/'original',selected['swcsv']==0,
                start=str(epoch+timedelta(days=low)),end=str(epoch+timedelta(days=high-1)))
    require(len(cold)==(6 if len(data)==1096 else 3 if len(data)>=35 else 2 if q['parameters'].get('end_date') is not None and len(data)==5 else 1),'Missing actual calendar cold window')
    return dict(status='INDEPENDENT_EXTENDED_ORIGINAL_CALENDAR_SOURCE_OBSERVATIONS_NATIVE_OUTPUT_PASS',actual_days=len(data),
                warm=result,cold=cold,actual_complete_native_packages=len(natives),functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('directory',type=Path);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();result=audit_root(a.directory);result['status']='INDEPENDENT_EXTENDED_IMPLICIT_WATER_CDE_NATIVE_COUNTER_OUTPUT_PASS'
    with a.output.open('x') as stream:json.dump(result,stream,indent=2)
    print(result['status'],result['actual_days'])
