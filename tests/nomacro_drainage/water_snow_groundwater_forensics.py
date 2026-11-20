"""Decode original water Snow groundwater evidence without model imports."""
import argparse
from datetime import date
import hashlib
import json
import math
from pathlib import Path
import struct
import zipfile

from ordinary_pond_evidence import read,digest,require,rows,physical
from implicit_snow_forensics import scalar,original
from age_groundwater_verify import geometry
from groundwater_snow_forensics import soil


def native(raw,row,build,s,dz):
    n=build['project']['nodes'];selected=build['identity']['original_output']
    kind='R' if selected['flprintdt'] and s['SWRES'] else 'P' if selected['flprintdt'] else 'C' if s['NPRINTDAY']>1 else 'I'
    expected=('S5WG'+kind+f"{s['SWKIMPL']:03d}").encode();epoch=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
    require(raw[:8]==expected and selected['native_codec']==expected.decode(),'Actual water Snow groundwater codec differs')
    nodes,clock,step,canopy=struct.unpack_from('<i3d',raw,8)
    require(nodes==n and original.finite([clock,step,canopy]) and clock==epoch+row['day'] and
        0<step<=1 and canopy==row['stock_end_cm'][3]>=0,'Actual water Snow groundwater prefix differs')
    h=struct.pack('<13i',14+s['SWKIMPL'],n,0,0,1,s['SWHYST'],1,0,1,2,s['SWDRA'],s['SWCFBS'],s['SWKIMPL'])
    require(raw.count(h+h)==1,'Actual typed water Snow groundwater domain/witness differs')
    pos=raw.index(h+h);end=pos+104+8*(5*n+4)
    require(end+96==len(raw),'Actual water Snow groundwater placement/EOF differs')
    values=struct.unpack_from('<'+str(5*n+4)+'d',raw,pos+104)
    require(original.finite(values) and min(values[n:5*n+2])>=0 and values[-1]>=0 and
        list(values[:n])==row['pressure_head_cm'] and values[-2]==row['groundwater_cm'] and values[-1]==row['stock_end_cm'][0],
        'Actual water Snow groundwater hydraulic receipt differs')
    require(abs(math.fsum(v*d for v,d in zip(values[n:2*n],dz))-values[-1])<=1e-10,'Actual hydraulic inventory differs')
    expected_root=(2,n,0,1,s['SWHYST'],1,s['SWKIMPL'],0)
    require(struct.unpack_from('<8i',raw,end)==struct.unpack_from('<8i',raw,end+32)==expected_root,
        'Actual water Snow groundwater diagnostic domain/witness differs')
    rates=struct.unpack_from('<2d',raw,end+64)
    require(original.finite(rates) and rates==struct.unpack_from('<2d',raw,end+80),'Actual root rate values/witness differ')
    # Only a read-only byte view is shortened for the unchanged calendar decoder.
    # The raw native/receipt/BUILD and their bindings remain untouched.
    calendar=original.output_calendar(raw[:pos],n,row,selected,build['project']['start_date'],False)
    thermal=struct.pack('<10i',1,n,0,0,s['SWHYST'],1,0,s['SWDRA'],1,2)
    snow=struct.pack('<4i',1,n,0,7)
    require(raw.count(thermal+thermal)==raw.count(snow+snow)==1,'Actual thermal/Snow domain differs')
    at=raw.index(thermal+thermal);snowat=raw.index(snow+snow)
    require(at+80==snowat and snowat+88==calendar['calendar_offset'],'Actual thermal/Snow/calendar ordering differs')
    totals=struct.unpack_from('<7d',raw,snowat+32)
    require(original.finite(totals) and min(totals)>=0,'Invalid actual Snow output totals')
    return rates


def audit(root,build_root=None,input_root=None):
    root=Path(root);q=read(root/'RESULT.json');bpath=Path(build_root or q['build_root']);inputs=Path(input_root or q['input_root'])
    build=read(bpath/'BUILD.json');selected=build['identity']['original_output'];days=q['days']
    require(q['status']=='ACTUAL_WATER_SNOW_GROUNDWATER_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS' and days in (35,1096),
        'Actual water Snow groundwater period incomplete')
    swp=(inputs/'swap.swp').read_text(encoding='cp1252')
    s={k:scalar(swp,k) for k in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA','SWCFBS','NPRINTDAY','SWRES')}
    require((s['SWSNOW'],s['SWSOLU'],s['SWBOTB'])==(1,0,1) and s['SWKIMPL'] in (0,1) and
        selected['groundwater_snow_water_output'] is True and selected['swhyst']==s['SWHYST'] and
        selected['swkimpl']==s['SWKIMPL'] and selected['swdra']==s['SWDRA'],'Actual selected water Snow groundwater context differs')
    require(digest(bpath/'BUILD.json')==q['actual_BUILD_sha256']==q['trajectory']['build_sha256'],'Actual water Snow build rebound')
    for name,sha in build['inputs'].items():require(digest(inputs/name)==sha,'Actual water Snow input changed')
    for name,sha in build['identity']['donor_generated'].items():require(digest(bpath/name)==sha,'Actual water Snow emitted source changed')
    for role,stem in (('donor','day_donor'),('kernel','day_kernel')):
        executable=next((bpath/(stem+suffix) for suffix in ('','.exe') if (bpath/(stem+suffix)).exists()),None)
        require(executable and digest(executable)==build['executable_sha256'][role] and
            {'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][role+'_flags']),
            'Actual water Snow compiler/executable differs')
    warm=Path(q.get('trajectory_root',root/'trajectory'));data=rows(warm)
    require(len(data)==days and data[0]['day']==1 and data[-1]['day']==days,'Actual water Snow period censored')
    water=original.water(data);original.original_observations((warm/'original/donor.stdout').read_bytes(),data,build['project']['start_date']);soil(warm,days)
    require(max(r['stock_end_cm'][2] for r in data)>0,'Actual Snow stock never positive')
    dz=geometry((inputs/'swap.swp').read_bytes(),build['project']['nodes']);epoch=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
    windows=[(2,4),(7,9),(30,34)]
    if days==1096:windows += [(163,165),(199,201),(364,367),(530,532),(633,635),(1094,1096)]
    require([(r['start'],r['end']) for r in q['cold']]==windows,'Actual water Snow cold denominator differs')
    def checkpoints(path,observed):
        byday={r['day']:r for r in observed};witnesses={};found=set()
        for line in (path/'original/donor.stdout').read_text(encoding='utf-8').splitlines():
            if line.startswith('HYBRID_SNOW_GROUNDWATER_ROOT_NATIVE '):
                v=list(map(float,line.split()[1:]));require(len(v)==3 and original.finite(v),'Actual root write witness malformed')
                witnesses.setdefault(v[0],[]).append(tuple(v[1:]))
        for p in path.glob('accepted-column-1-day-*.zip'):
            day=int(p.stem.rsplit('-',1)[1]);require(day in byday,'Actual checkpoint outside accepted period')
            with zipfile.ZipFile(p) as z:
                require(set(z.namelist())=={'checkpoint.json','macro.bin','result.end'},'Actual native file inventory differs')
                m=json.loads(z.read('checkpoint.json'));require(m['binding']==build['binding'] and m['receipt']==byday[day] and
                    set(m['files'])=={'macro.bin','result.end'},'Actual native binding/receipt differs')
                require(all(hashlib.sha256(z.read(n)).hexdigest()==v for n,v in m['files'].items()),'Actual native payload digest differs')
                rates=native(z.read('macro.bin'),byday[day],build,s,dz)
                require(rates in witnesses.get(epoch+day,[]),'Actual diagnostic native rates differ from original write witness')
                original.sequential_records(z.read('result.end'))
            found.add(day)
        return found
    require(checkpoints(warm,data)=={days,*(d for pair in windows for d in pair)},'Actual warm native denominator differs')
    def outputs(path):return {p.name:original.output_records(p.read_bytes(),p.name) for p in path.glob('result_output.*') if p.suffix in ('.csv','.bin')}
    roots=q.get('cold_actual_roots') or [str(root/f'own-{low}') for low,high in windows]
    require(len(roots)==len(windows),'Actual cold root denominator differs')
    for item,path in zip(q['cold'],roots):
        low,high=item['start'],item['end'];cold=Path(path);actual=rows(cold)
        require(physical(actual)==physical(data[low:high]) and checkpoints(cold,actual)=={high},'Actual cold physical/native differs')
        original.water(actual);soil(cold,len(actual))
        with zipfile.ZipFile(warm/f'accepted-column-1-day-{high}.zip') as a,zipfile.ZipFile(cold/f'accepted-column-1-day-{high}.zip') as b:
            require(all(a.read(n)==b.read(n) for n in ('macro.bin','result.end')),'Actual complete cold native bytes differ')
        require(original.output_continuation(outputs(warm/'original'),outputs(cold/'original'),selected,low,high,build['project']['start_date'])==item['exact_original_output'],
            'Actual cold user records differ')
    return dict(status='INDEPENDENT_WATER_SNOW_GROUNDWATER_PHYSICAL_NATIVE_OUTPUT_PASS',actual_days=days,
        actual_cold_windows=len(windows),water=water,actual_BUILD_sha256=digest(bpath/'BUILD.json'),model_executions=0,
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    q=audit(a.root)
    with a.output.open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')
    print(q['status'],q['actual_days'],q['actual_cold_windows'])
