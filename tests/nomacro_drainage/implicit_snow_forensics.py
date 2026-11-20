"""Independently decode actual implicit Snow physical/native/output observations.

No model imports, source generation, producer mutation or model execution.
The older numerical and calendar readers remain literal dependencies.
"""
import argparse
from datetime import date
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import zipfile

from ordinary_pond_evidence import read,digest,rows,physical,require
import groundwater_snow_forensics as snow
from groundwater_snow_forensics import original,clock

ROOT_CODECS={'S5IRW001':'S5ITW001','S5IRW002':'S5CTW002','S5IRW003':'S5STW001',
             'S5IRW004':'S5SRW001','S5IRW005':'S5SPW001','S5IRC001':'S5CIS001','S5IRC002':'S5CCS001'}


def scalar(text,key):
    values=re.findall(r'(?im)^\s*'+key+r'\s*=\s*([+\-0-9.eEdD]+)',text)
    require(len(values)==1,'Missing/ambiguous actual implicit Snow selector: '+key)
    return int(float(values[0].lower().replace('d','e')))


def native(raw,row,build,selected,selectors):
    n=build['project']['nodes'];codec=raw[:8].decode('ascii')
    epoch=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
    nodes,stored,step,canopy=struct.unpack_from('<i3d',raw,8)
    require(codec==selected['native_codec'] and nodes==n and stored==epoch+row['day'] and
        original.finite([stored,step,canopy]) and 0<step<=1 and canopy==row['stock_end_cm'][3]>=0,
        'Actual implicit Snow native prefix differs')
    rates=None
    if 'implicit_snow_root_carry' in selected:
        policy=selected['implicit_snow_root_carry']
        require(codec in ROOT_CODECS and policy['parent_codec']==ROOT_CODECS[codec] and policy['bytes']==96 and
            policy['fields']==['alpwetnoddrz','alpdrynodrtz'],'Actual implicit Snow root layout differs')
        require(len(raw)>96,'Truncated implicit Snow root carry')
        a,b=struct.unpack_from('<8i',raw,len(raw)-96),struct.unpack_from('<8i',raw,len(raw)-64)
        expected=(1,n,selectors['SWSOLU'],1,selectors['SWHYST'],selectors['SWBOTB'],1,0)
        require(a==b==expected,'Actual implicit Snow root domain/witness differs')
        rates=struct.unpack_from('<2d',raw,len(raw)-32)
        require(rates==struct.unpack_from('<2d',raw,len(raw)-16) and original.finite(rates),
                'Actual implicit Snow root values/witness differ')
        # Read-only projection into the unchanged parent decoder. Producer
        # payloads, bindings, receipts and original bytes are never rewritten.
        raw=ROOT_CODECS[codec].encode()+raw[8:-96]
    if selected.get('groundwater_snow_cde_output'):
        snow.native(raw,row,build,selected)
    else:
        domain=struct.pack('<10i',1,n,0,selectors['SWSOLU'],selectors['SWHYST'],1,0,selectors['SWDRA'],1,2)
        require(raw.count(domain+domain)==1,'Actual implicit Snow thermal domain differs')
        calendar=original.output_calendar(raw,n,row,selected,build['project']['start_date'],bool(selectors['SWSOLU']))
        offset=raw.index(domain+domain)+80
        if selected.get('thermal_calendar'):
            header=struct.pack('<4i',1,n,selectors['SWSOLU'],7)
            require(raw.count(header+header)==1 and raw.index(header+header)==offset,'Actual implicit Snow totals domain differs')
            values=struct.unpack_from('<7d',raw,offset+32)
            require(original.finite(values) and min(values)>=0,'Actual implicit Snow totals invalid')
            offset+=88
        require(offset==calendar['calendar_offset'],'Actual implicit Snow calendar placement differs')
    return rates


def audit(root):
    root=Path(root);q=read(root/'RESULT.json');buildpath=Path(q['build_root']);inputs=Path(q['input_root'])
    build=read(buildpath/'BUILD.json');selected=build['identity']['original_output'];full=q['parameters'].get('phase')=='full'
    require(q['status']==('ACTUAL_IMPLICIT_SNOW_FULL_PHYSICAL_NATIVE_OUTPUT_PASS' if full else
        'ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'),'Actual implicit Snow period incomplete')
    swp=(inputs/'swap.swp').read_text(encoding='cp1252')
    selectors={k:scalar(swp,k) for k in ('SWKIMPL','SWSNOW','SWSOLU','SWHYST','SWBOTB','SWDRA','SWKMEAN','NPRINTDAY')}
    require(selectors['SWKIMPL']==selectors['SWSNOW']==1 and selectors['SWSOLU'] in (0,1) and
        build['identity']['implicit_conductivity']['implicit_snow_composition'] is True,'Actual implicit Snow physical domain differs')
    for field,key in (('solute','SWSOLU'),('hysteresis','SWHYST'),('bottom','SWBOTB'),('kmean','SWKMEAN'),('nprintday','NPRINTDAY')):
        require(q['parameters'][field]==selectors[key],'Actual implicit Snow claimed context differs: '+field)
    require(selected['swsnow']==1 and selected['swhyst']==selectors['SWHYST'] and
        selected['swdra']==selectors['SWDRA'] and selected['nprintday']==selectors['NPRINTDAY'],
        'Actual implicit Snow output selection differs')
    for name,sha in build['inputs'].items():require(digest(inputs/name)==sha,'Actual implicit Snow input changed')
    for name,sha in build['identity']['donor_generated'].items():require(digest(buildpath/name)==sha,'Actual implicit Snow compiler source changed')
    for role,stem in (('donor','day_donor'),('kernel','day_kernel')):
        exe=next((buildpath/(stem+s) for s in ('','.exe') if (buildpath/(stem+s)).exists()),None)
        require(exe and digest(exe)==build['executable_sha256'][role],'Actual implicit Snow executable changed')
        require({'-'+q['parameters']['optimization'],'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][role+'_flags']),
                'Actual implicit Snow compiler arithmetic changed')
    warm=root/'trajectory';data=rows(warm);days=1096 if full else 35
    require(len(data)==days and data[0]['day']==1 and data[-1]['day']==days and
        digest(buildpath/'BUILD.json')==q['trajectory']['build_sha256'],'Actual implicit Snow period censored/rebound')
    stats=original.water(data);original.original_observations((warm/'original/donor.stdout').read_bytes(),data,build['project']['start_date'])
    require(max(r['stock_end_cm'][2] for r in data)>0,'Actual implicit Snow stock was never positive')
    if selectors['SWSOLU']:
        clock.ledger(data,days)
        class Files:
            def read(self,name):return (warm/name).read_bytes()
        clock.daily(Files(),'',data,build['project']['nodes'])
    soil=bool(selected.get('thermal_clock') or (selected.get('groundwater_cde_interval') and
        build['identity'].get('implicit_groundwater_trial',{}).get('control_volume')))
    if soil:snow.soil(warm,days)
    windows=[(2,4),(7,9),(30,34)]
    if full:windows += [(163,165),(199,201),(364,367),(530,532),(633,635),(1094,1096)]
    require([(r['start'],r['end']) for r in q['cold']]==windows,'Actual implicit Snow cold denominator differs')

    def checkpoints(path,observations):
        byday={r['day']:r for r in observations};found=set()
        witnesses={}
        for line in (path/'original/donor.stdout').read_text().splitlines():
            if line.startswith('HYBRID_SNOW_ROOT_NATIVE '):
                values=list(map(float,line.split()[1:]));require(len(values)==3 and original.finite(values),'Malformed actual root native witness')
                witnesses.setdefault(values[0],[]).append(tuple(values[1:]))
        epoch=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1
        for f in path.glob('accepted-column-1-day-*.zip'):
            day=int(f.stem.rsplit('-',1)[1]);require(day in byday,'Actual native outside implicit Snow period')
            with zipfile.ZipFile(f) as z:
                require(set(z.namelist())=={'checkpoint.json','macro.bin','result.end'},'Actual implicit Snow native inventory differs')
                meta=json.loads(z.read('checkpoint.json'))
                require(meta['binding']==build['binding'] and meta['receipt']==byday[day] and set(meta['files'])=={'macro.bin','result.end'},
                        'Actual implicit Snow checkpoint binding differs')
                for name,sha in meta['files'].items():require(hashlib.sha256(z.read(name)).hexdigest()==sha,'Actual implicit Snow native bytes changed')
                rates=native(z.read('macro.bin'),byday[day],build,selected,selectors)
                if rates is not None:require(rates in witnesses.get(epoch+day,[]),'Actual root native rates differ from original write witness')
                original.sequential_records(z.read('result.end'))
            found.add(day)
        return found

    require(checkpoints(warm,data)=={days,*(d for pair in windows for d in pair)},'Actual implicit Snow warm checkpoint denominator differs')
    def outputs(path):return {f.name:original.output_records(f.read_bytes(),f.name) for f in path.glob('result_output.*') if f.suffix in ('.csv','.bin')}
    for item in q['cold']:
        low,high=item['start'],item['end'];cold=root/f'own-{low}';actual=rows(cold)
        require(physical(actual)==physical(data[low:high]) and checkpoints(cold,actual)=={high},'Actual implicit Snow cold physical/native differs')
        original.water(actual)
        if selectors['SWSOLU']:clock.ledger(actual,len(actual))
        if soil:snow.soil(cold,len(actual))
        with zipfile.ZipFile(warm/f'accepted-column-1-day-{high}.zip') as a,zipfile.ZipFile(cold/f'accepted-column-1-day-{high}.zip') as b:
            require(all(a.read(n)==b.read(n) for n in ('macro.bin','result.end')),'Actual implicit Snow complete cold bytes differ')
        require(original.output_continuation(outputs(warm/'original'),outputs(cold/'original'),selected,low,high,build['project']['start_date'])==item['exact_original_output'],
                'Actual implicit Snow cold user records differ')
    return dict(status='INDEPENDENT_IMPLICIT_SNOW_PHYSICAL_NATIVE_OUTPUT_PASS',actual_days=days,actual_cold_windows=len(windows),
        water=stats,codec=selected['native_codec'],root_diagnostic_carry='implicit_snow_root_carry' in selected,
        maximum_snow_cm=max(r['stock_end_cm'][2] for r in data),functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('root',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    q=audit(a.root)
    with a.output.open('x',encoding='utf-8') as f:json.dump(q,f,indent=2);f.write('\n')
    print(q['status'],q['actual_days'],q['actual_cold_windows'])
