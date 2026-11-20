"""Decode composed groundwater/CDE interval/drainage native state without model imports.

Original groundwater and clock observers remain literal dependencies. No codec
bytes, checkpoint bindings, native payloads or original receipts are rewritten.
"""
import argparse
from datetime import date, timedelta
import hashlib
import io
import math
from pathlib import Path
import struct
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import cde_clock_verify as clock
import groundwater_history_verify as history
import implicit_conductivity_forensics as original
from ordinary_pond_evidence import read,digest,rows,physical,require


def native(raw,row,build,selected):
    n=build['project']['nodes'];hys=selected['swhyst']
    is_clock=selected.get('groundwater_cde_clock') is True
    is_interval=selected.get('groundwater_cde_interval') is True
    require(is_clock != is_interval,'Foreign groundwater interval/clock owner')
    expected=(b'S5GCC001' if hys==0 else ('S5GCH'+f'{2*hys-1:03d}').encode()) if is_clock else (b'S5GIC001' if hys==0 else ('S5GIH'+f'{2*hys-1:03d}').encode())
    require(raw[:8]==expected and selected['swsnow']==0,
            'Foreign composed groundwater CDE clock codec/domain')
    nodes,stored,step,canopy=struct.unpack_from('<i3d',raw,8)
    epoch=build['project']['start_date'];epoch_clock=(date.fromisoformat(epoch)-date(1900,1,1)).days+1
    require(nodes==n and stored==epoch_clock+row['day'] and all(map(math.isfinite,(stored,step,canopy))) and
            0<step<=1 and canopy==row['stock_end_cm'][3]>=0,'Actual composed native prefix differs')
    policy=build['identity']['groundwater_native_state']
    if hys:
        domain=policy['actual_domain']
        require(domain[:11]==[2,n,0,1,1,hys,0,0,1,2,selected['swdra']] and domain[11] in (0,1) and domain[12]==1 and
                policy['magic']==expected.decode() and policy['domain_bytes']==104,'Actual groundwater history domain differs')
        history.native(raw,row,policy)
        header=struct.pack('<13i',*domain);position=raw.index(header+header);offset=position+104
        hdomain=struct.pack('<5i',1,n,0,hys,1)
        require(raw.count(hdomain+hdomain)==1 and raw[position-40:position]==hdomain+hdomain,
                'Actual history/groundwater native ordering differs')
    else:
        header=struct.pack('<9i',1,n,0,1,1,0,0,0,1)
        require(raw.count(header+header)==1 and policy['magic']==expected.decode() and policy['domain_bytes']==72,
                'Actual ordinary groundwater domain differs')
        position=raw.index(header+header);offset=position+72
    hydro=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    require(all(map(math.isfinite,hydro)) and all(v>=0 for v in hydro[n:5*n+2]) and hydro[-1]>=0 and
            list(hydro[:n])==row['pressure_head_cm'] and hydro[-2]==row['groundwater_cm'] and
            hydro[-1]==row['stock_end_cm'][0],'Actual complete groundwater hydraulic carry differs')
    c,h,nr=clock.calendar(raw,n)
    require(c==offset+8*(5*n+4),'Actual groundwater/calendar/CDE-tail placement differs')
    require(h[:2]==(1,n) and (h[4],h[5],h[6],h[8],h[11],h[18],h[19])==
            (selected['period'],selected['nprintday'],row['day'],1 if selected['flprintdt'] or is_interval else row['day']*selected['nprintday']+1,
             selected['swres'],int(is_clock),int(selected['flprintdt'])) and
            all(1<=v<=nr for v in h[9:11]) and all(v in (0,1) for v in h[12:20]),'Actual complete calendar domain differs')
    completed=date.fromisoformat(epoch)+timedelta(days=row['day']-1)
    counter=min(row['day'],completed.timetuple().tm_yday) if selected['flprintdt'] and selected['swres'] else row['day'] if selected['flprintdt'] else 0
    if is_interval:counter=row['day']%selected['period'] if selected['period']>0 else row['day']
    require(h[7]==counter,'Actual annual/period counter differs')
    first=raw[c+160:c+160+8*nr]
    require(first==raw[c+160+8*nr:c+160+16*nr] and nr>=6008,'Actual calendar value witness/shape differs')
    cal=struct.unpack('<'+str(nr)+'d',first)
    require(all(map(math.isfinite,cal)) and cal[-1]>=0 and all(1<=v<=3000 for v in h[9:11]),'Invalid actual calendar values')
    balance=cal[-6008:-3008];interval=cal[-3008:-8];time=epoch_clock+row['day']
    require(h[9]==1+sum(0<v<time-1e-8 for v in balance),'Actual balance date pointer differs')
    past=0<interval[0]<epoch_clock-1e-8;expected_pointer=1+sum(0<v<time-1e-8 for v in interval)
    require(h[10]==1 if past else h[10]<=expected_pointer if selected['flprintdt'] else h[10]==expected_pointer,
            'Actual pending interval date pointer differs')
    cp=c+160+16*nr;size=20+n
    require(struct.unpack_from('<3i',raw,cp)==struct.unpack_from('<3i',raw,cp+12)==(2,n,size),'Actual CDE interval version/domain differs')
    first=raw[cp+24:cp+24+8*size]
    require(first==raw[cp+24+8*size:] and len(first)==8*size,'Actual CDE value witness/EOF differs')
    state=struct.unpack('<'+str(size)+'d',first);conserved=struct.unpack_from('<'+str(n+2)+'d',raw,48)
    require(all(map(math.isfinite,state)) and state[0]>=0 and state[-2]>=0 and
            all(math.isfinite(v) and v>=0 for v in conserved),'Invalid actual physical/private CDE state')
    require(conserved[-1]==row['solute_end_mg_cm2'] and conserved[-1]-state[-2]==state[14],
            'Actual CDE physical stock/interval anchor differs')
    return dict(codec=expected.decode(),groundwater_domain_offset=position,calendar_offset=c,
                private_CDE_offset=cp,original_complete_hydraulic_and_CDE_native=True)


def audit(root,build_root=None,input_root=None):
    root=Path(root);q=read(root/'RESULT.json');buildpath=Path(build_root or q['build_root']);inputs=Path(input_root or q['input_root']);build=read(buildpath/'BUILD.json')
    full=q['parameters'].get('phase')=='full'
    require(q['status']==('ACTUAL_GROUNDWATER_CDE_INTERVAL_DRAINAGE_FULL_PHYSICAL_NATIVE_OUTPUT_PASS' if full else
            'ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'), 'Actual composed period incomplete')
    selected=build['identity']['original_output'];require(selected.get('groundwater_cde_clock') is True or selected.get('groundwater_cde_interval') is True,'Wrong actual composed output owner')
    for name,sha in build['inputs'].items():require(digest(inputs/name)==sha,'Actual composed input changed')
    for name,sha in build['identity']['donor_generated'].items():require(digest(buildpath/name)==sha,'Actual composed generated source changed')
    for role,stem in [('donor','day_donor'),('kernel','day_kernel')]:
        exe=next((buildpath/(stem+s) for s in ('','.exe') if (buildpath/(stem+s)).exists()),None)
        require(exe is not None and digest(exe)==build['executable_sha256'][role],'Actual composed executable changed')
    for name in ('donor_flags','kernel_flags'):
        require({'-'+q['parameters']['optimization'],'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][name]),'Actual composed arithmetic changed')
    warm=root/'trajectory';data=rows(warm)
    days=1096 if full else 35
    require(len(data)==days and data[0]['day']==1 and data[-1]['day']==days and digest(buildpath/'BUILD.json')==q['trajectory']['build_sha256'], 'Actual composed period censored/rebound')
    clock.ledger(data,days);original.water(data);original.original_observations((warm/'original/donor.stdout').read_bytes(),data,build['project']['start_date'])
    class Files:
        def read(self,name):return (warm/name).read_bytes()
    clock.daily(Files(),'',data,build['project']['nodes'])
    def checkpoints(path,data):
        found=set();byday={r['day']:r for r in data}
        for p in path.glob('accepted-column-1-day-*.zip'):
            day=int(p.stem.rsplit('-',1)[1]);require(day in byday,'Actual checkpoint outside accepted days')
            with zipfile.ZipFile(p) as z:
                require(set(z.namelist())=={'checkpoint.json','macro.bin','result.end'},'Foreign checkpoint inventory')
                meta=__import__('json').loads(z.read('checkpoint.json'))
                require(meta['binding']==build['binding'] and meta['receipt']==byday[day] and set(meta['files'])=={'macro.bin','result.end'},'Actual checkpoint binding/receipt differs')
                for name,sha in meta['files'].items():require(hashlib.sha256(z.read(name)).hexdigest()==sha,'Actual checkpoint bytes differ')
                native(z.read('macro.bin'),byday[day],build,selected);original.sequential_records(z.read('result.end'))
            found.add(day)
        return found
    windows=[(2,4),(7,9),(30,34)]+([(17,20)] if q['parameters'].get('epoch') else [])
    if full:windows += [(163,165),(199,201),(364,367),(530,532),(1094,1096)]
    require(checkpoints(warm,data)=={days,*(d for pair in windows for d in pair)},'Actual composed warm native inventory differs')
    require([(r['start'],r['end']) for r in q['cold']]==windows,'Actual composed cold denominator differs')
    def outputs(path):return {n:original.output_records((path/n).read_bytes(),n) for n in ('result_output.csv','result_output.bin') if (path/n).exists()}
    for r in q['cold']:
        low,high=r['start'],r['end'];cold=root/f'own-{low}';actual=rows(cold)
        require(physical(actual)==physical(data[low:high]) and checkpoints(cold,actual)=={high},'Actual composed cold physical/native differs')
        clock.ledger(actual,len(actual));original.water(actual)
        with zipfile.ZipFile(warm/f'accepted-column-1-day-{high}.zip') as a,zipfile.ZipFile(cold/f'accepted-column-1-day-{high}.zip') as b:
            require(all(a.read(n)==b.read(n) for n in ('macro.bin','result.end')),'Actual complete composed cold bytes differ')
        require(original.output_continuation(outputs(warm/'original'),outputs(cold/'original'),selected,low,high,build['project']['start_date'])==r['exact_original_output'],'Actual original composed user output differs')
    return dict(status='INDEPENDENT_GROUNDWATER_CDE_INTERVAL_DRAINAGE_PHYSICAL_NATIVE_OUTPUT_PASS',actual_days=days,
                actual_cold_windows=len(windows),codec=build['identity']['groundwater_native_state']['magic'],parameters=q['parameters'],
                new_physical_state=False,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    q=audit(a.root);require(not a.output.exists(),'Refuse overwriting independent actual observation')
    a.output.write_text(__import__('json').dumps(q,indent=2)+'\n');print(q['status'])
