"""Read-only independent audits of actual original extended-drain evidence.

No production adapter, renderer, or decoder is imported. Historical H owns
daily water1e-10, integrated CDE1e-10; integrated water is reported separately.
"""
import argparse
from datetime import date,timedelta
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
from implicit_conductivity_forensics import require,finite,original_observations,sequential_records
from cde_clock_verify import ledger as chemical_ledger

def rows(path):return [json.loads(line) for line in path.read_text(encoding='utf8').splitlines() if line.strip()]
def bounded(values,label):require(finite(values) and max(map(abs,values),default=0)<=1e-10,label)

def inventory(data):
    require(bool(data),'Empty actual extended trajectory')
    previous=None;surface=None;first=data[0]['day'];maximum=0
    for index,row in enumerate(data):
        require(row['committed'] is True and row['day']==first+index,'Censored extended day sequence')
        a,b,f=row['stock_start_cm'],row['stock_end_cm'],row['external_flux_cm']
        require(len(a)==len(b)==6 and len(f)==16 and finite([*a,*b,*f,*row['pressure_head_cm']]),'Malformed extended soil receipt')
        require(previous is None or a==previous,'Discontinuous actual soil stocks')
        soil=math.fsum([*a,*(-v for v in b),*f[:7],*(-v for v in f[7:])])
        bounded([soil,*(row[k] for k in ('independent_residual_cm','kernel_residual_cm','integrated_guard_residual_cm'))],'Actual daily H water guard exceeded')
        s=row['surfacewater'];start,end=s['stock_start_cm'],s['stock_end_cm']
        require(surface is None or start==surface,'Discontinuous actual secondary storage')
        require(min(start,end,s['supply_cm'],s['discharge_cm'])>=0,'Negative actual secondary stock or boundary flow')
        require(end==row['extended_drainage_state']['values'][2],'Secondary native/receipt stock differs')
        sf=math.fsum([start,-end,s['secondary_exchange_cm'],s['runoff_from_soil_cm'],s['supply_cm'],-s['discharge_cm'],s['prescribed_stage_reaction_cm']])
        combined=math.fsum([*a,*(-v for v in b),start,-end,*f[:7],*(-f[i] for i in range(7,16) if i not in (8,13)),-s['primary_exchange_cm'],s['supply_cm'],-s['discharge_cm'],s['prescribed_stage_reaction_cm']])
        bounded([sf,combined],'Independent secondary or combined water guard exceeded')
        require(sf==s['independent_surface_residual_cm'] and combined==s['independent_combined_residual_cm'],'Rebound independent surface/combined diagnostic')
        maximum=max(maximum,abs(soil),abs(sf),abs(combined));previous=b;surface=end
    if 'solute_ledger_mg_cm2' in data[0]:chemical_ledger(data,len(data))
    integrated=math.fsum([*data[0]['stock_start_cm'],*(-v for v in data[-1]['stock_end_cm']),*(v for r in data for v in r['external_flux_cm'][:7]),*(-v for r in data for v in r['external_flux_cm'][7:])])
    return dict(days=len(data),maximum_daily_inventory_residual_cm=maximum,reported_integrated_soil_water_residual_cm=integrated,integrated_soil_water_qualification=False)

def observed(raw,data,build):
    epoch=build['project']['start_date'];original_observations(raw,data,epoch)
    domain=build['identity']['extended_drainage']['domain'];n,r,pri=domain[1],domain[2],domain[5]
    clock=(date.fromisoformat(epoch)-date(1900,1,1)).days+1
    state=None;flux=None;count=0
    for line in raw.decode('utf8').splitlines():
        if line.startswith('HYBRID_EXTENDED_DRAIN_STATE '):
            tokens=line.split()[1:];state=dict(clock=float(tokens[0]),adjustments=int(tokens[1]),count=int(tokens[2]),values=list(map(float,tokens[3:])))
        elif line.startswith('HYBRID_EXTENDED_DRAIN_FLUX '):flux=line.split()[1:]
        elif line.startswith('HYBRID_DAY_RETURN '):
            require(count<len(data) and state is not None and flux is not None,'Missing actual extended state/flux witness')
            row=data[count];s=row['surfacewater'];v=list(map(float,flux));f=row['external_flux_cm']
            require(state['clock']==v[0]==clock+row['day'] and state['count']==len(state['values'])==11+3*r+r*n,'Actual extended clock/shape differs')
            require(dict(adjustments=state['adjustments'],values=state['values'])==row['extended_drainage_state'],'Actual extended state differs from report')
            require(len(v)==13+2*r and finite(v) and v[1]>=1 and v[2]>=0 and v[1]==s['accepted_steps'] and v[2]==s['rejected_steps'],'Malformed actual extended flux witness')
            names=['stock_start_cm','stock_end_cm','secondary_exchange_cm','primary_exchange_cm','runoff_from_soil_cm','supply_cm','discharge_cm','prescribed_stage_reaction_cm']
            require(v[3:11]==[s[k] for k in names] and v[11:13]==[f[13],f[8]] and v[13+r:]==s['independent_level_exchange_cm'],'Actual original extended flux/report differs')
            require((domain[4]==2 and v[10]==0 and s['authority']=='original simulated surfacewater') or (domain[4]==1 and v[8]==v[9]==0 and s['authority']=='original prescribed-stage volume constraint'),'Mixed original stage/flux authority')
            original=v[13:13+r];independent=v[13+r:]
            bounded([*(a-b for a,b in zip(original,independent)),math.fsum([*original,-f[13]]),math.fsum([*independent[:pri],-v[6]]),math.fsum([*independent[pri:],-v[5]]),math.fsum([v[5],v[6],-f[13]]),v[7]-f[8]],'Actual original level/soil/surface transfer differs')
            count+=1;state=flux=None
    require(count==len(data),'Censored actual extended witness')
    return count

def checkpoint(path,build,row):
    domain=build['identity']['extended_drainage']['domain'];n,r=domain[1:3];nv=11+3*r+r*n;length=92+16*nv
    clock=(date.fromisoformat(build['project']['start_date'])-date(1900,1,1)).days+1+row['day']
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())=={'checkpoint.json','result.end','macro.bin'},'Foreign checkpoint members')
        meta=json.loads(z.read('checkpoint.json'));wire=z.read('macro.bin')
        require(meta['schema']=='swap5-hybrid-water-checkpoint-3' and meta['binding']==build['binding'] and meta['receipt']==row and set(meta['files'])=={'result.end','macro.bin'},'Checkpoint receipt/source/inventory differs')
        for name,digest in meta['files'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'Checkpoint member hash differs')
        sequential_records(z.read('result.end'))
        require(wire[:8]==b'S5EDR001' and len(wire)>length+48 and struct.unpack_from('<i',wire,8)[0]==n,'Foreign extended native header')
        stored,step,canopy=struct.unpack_from('<3d',wire,12)
        require(stored==clock and finite([step,canopy]) and 0<step<=1 and canopy>=0,'Foreign native clock/step/canopy')
        seasonal,year=struct.unpack_from('<di',wire,36)
        require(math.isfinite(seasonal) and year==(date.fromisoformat(build['project']['start_date'])+timedelta(days=row['day']-1)).year,'Foreign actual seasonal clock/year')
        at=len(wire)-length;header=struct.pack('<8i',*domain)
        require(wire[at:at+64]==header+header and struct.unpack_from('<i',wire,len(wire)-4)[0]==length,'Foreign extended native domain/trailer')
        c1,c2,a1,a2=struct.unpack_from('<2d2i',wire,at+64)
        values=list(struct.unpack_from('<'+str(nv)+'d',wire,at+88))
        require(c1==c2==clock and a1==a2 and a1>=0 and finite(values) and min(values[2],values[4])>=0,'Invalid extended native values/clock/counter')
        require(wire[at+88:at+88+8*nv]==wire[at+88+8*nv:-4] and dict(adjustments=a1,values=values)==row['extended_drainage_state'],'Extended native duplicate/receipt differs')
        if 'solute_end_mg_cm2' in row:
            chemical=struct.unpack_from('<'+str(n+2)+'d',wire,48)
            require(finite(chemical) and min(chemical)>=0 and chemical[-1]==row['solute_end_mg_cm2'],'Actual conserved CDE native stock differs')
        return {name:z.read(name) for name in ('result.end','macro.bin')}

def audit(root):
    result=json.loads((root/'RESULT.json').read_text(encoding='utf8'))
    require(result['status']=='ACTUAL_EXTENDED_ORIGINAL_SOIL_SURFACE_COMBINED_NATIVE_PERIOD_PASS','Incomplete actual extended campaign')
    warm=root/'trajectory';build=json.loads((warm/'BUILD.json').read_text(encoding='utf8'));data=rows(warm/'daily.jsonl')
    require(len(data)==result['requested_days'] and data[0]['day']==1,'Actual campaign day count differs')
    report=inventory(data);observed((warm/'original/donor.stdout').read_bytes(),data,build)
    checkpoints={}
    for path in warm.glob('accepted-column-1-day-*.zip'):
        day=int(path.stem.rsplit('-',1)[1]);checkpoints[day]=checkpoint(path,build,data[day-1])
    report['actual_native_checkpoints']=len(checkpoints);report['cold_windows']=[]
    for window in result['cold']:
        low,high=window['start'],window['end'];cold=root/('cold-'+str(low));continuation=rows(cold/'daily.jsonl')
        # Revision is the local transaction count of a new host. Every other
        # accepted receipt field, including all physical diagnostics, is exact.
        physical=lambda rr:[{k:v for k,v in row.items() if k!='revision'} for row in rr]
        require(physical(continuation)==physical(data[low:high]),'Actual cold physical receipts differ')
        inventory(continuation);observed((cold/'original/donor.stdout').read_bytes(),continuation,build)
        native=checkpoint(cold/('accepted-column-1-day-'+str(high)+'.zip'),build,continuation[-1])
        require(native==checkpoints[high],'Actual cold complete original native bytes differ')
        report['cold_windows'].append([low,high])
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('evidence',type=Path);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();report=audit(a.evidence)
    with a.output.open('x',encoding='utf8') as stream:json.dump(dict(status='INDEPENDENT_ACTUAL_EXTENDED_DRAIN_FORENSICS_PASS',**report),stream,indent=2)
    print(json.dumps(report))
