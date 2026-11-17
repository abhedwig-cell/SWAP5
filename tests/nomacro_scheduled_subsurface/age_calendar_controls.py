"""Actual S5AGE003 native readers, interval transactions and independent owners."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import age_calendar as c
from daily_coupling import CoupledDailyColumn

m=c.m


def physical(candidate):
    return m.physical([{k:v for k,v in candidate.budget.items() if k!='candidate_only'}|{'committed':True}])


def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project)
    source=full/'accepted-column-1-day-4.zip';digest=m.sha(source);checks=[]
    attacks=('old-codec','truncated','header-witness','shape','policy','negative-day','foreign-day',
             'negative-counter','overflow-counter','print-counter','zero-pointer','overflow-pointer',
             'foreign-pointer','flag-domain','foreign-short-flag','nonfinite-value','value-witness',
             'negative-period','foreign-age-clock')
    for attack in attacks:
        target=out/attack;target.mkdir(parents=True);origin=target/'origin'
        receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        path=origin/'macro.bin';raw=bytearray(path.read_bytes())
        # Original age payload is unchanged; selected fixture has one drain level.
        age_bytes=24*project.nodes+8*26+20+128
        prefix=struct.pack('<3i',1,project.nodes,1);start=raw.find(prefix)
        while start>=0:
            header=list(struct.unpack_from('<20i',raw,start));nreal=header[3]
            if start+160+16*nreal==len(raw)-age_bytes and header==list(struct.unpack_from('<20i',raw,start+80)):break
            start=raw.find(prefix,start+1)
        assert start>0,'No complete duplicated calendar header at exact native boundary'
        def hi(index,value,witness=True):
            struct.pack_into('<i',raw,start+4*index,value)
            if witness:struct.pack_into('<i',raw,start+80+4*index,value)
        def value(index,v,witness=True):
            struct.pack_into('<d',raw,start+160+8*index,v)
            if witness:struct.pack_into('<d',raw,start+160+8*nreal+8*index,v)
        if attack=='old-codec':raw[:8]=b'S5AGE002'
        elif attack=='truncated':raw=raw[:-1]
        elif attack=='header-witness':hi(7,1,witness=False)
        elif attack=='shape':hi(1,project.nodes+1)
        elif attack=='policy':hi(4,header[4]+1)
        elif attack=='negative-day':hi(6,-1)
        elif attack=='foreign-day':hi(6,5)
        elif attack=='negative-counter':hi(7,-1)
        elif attack=='overflow-counter':hi(7,header[4])
        elif attack=='print-counter':hi(8,2)
        elif attack=='zero-pointer':hi(9,0)
        elif attack=='overflow-pointer':hi(9,2147483647)
        elif attack=='foreign-pointer':hi(9,header[9]+1)
        elif attack=='flag-domain':hi(12,2)
        elif attack=='foreign-short-flag':hi(18,1)
        elif attack=='nonfinite-value':value(0,float('nan'))
        elif attack=='value-witness':value(0,123.,witness=False)
        elif attack=='negative-period':value(nreal-1,-1.)
        elif attack=='foreign-age-clock':struct.pack_into('<i',raw,len(raw)-20,5)
        path.write_bytes(raw)
        try:
            with contextlib.ExitStack() as stack:
                m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                    [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,
                    binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            diagnostic='\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
            assert any(word in (diagnostic+' '+str(error)).lower() for word in ('calendar','checkpoint','age')),(attack,diagnostic,str(error))
            assert not list(target.glob('accepted-*.zip'))
            checks.append(dict(attack=attack,status='REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Corrupt calendar native accepted: '+attack)
        assert m.sha(source)==digest
    return checks


def transactions(build,reference,project,full,out):
    out.mkdir();data=m.rows(full);meta,case=m.validate_bundle(build,reference,project)
    source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'calendar-age',origin=source,day=4,adopt_native=True)
    trial=column.prepare();assert physical(trial)==m.physical([data[4]])
    assert trial.budget['external_flux_cm'][3]+trial.budget['external_flux_cm'][5]>0
    column.discard(trial);assert column.day==4
    replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'calendar-age',origin=column.checkpoint,day=5)
    endpoint=recovered.prepare();assert physical(endpoint)==m.physical([data[5]]);recovered.discard(endpoint)
    checks=[]
    for attack,tag,index in [('water-receipt','HYBRID_EXTERNAL_FLUX',0),('age-production','HYBRID_AGE_CUMULATIVE',3)]:
        target=out/attack;target.mkdir();origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        with contextlib.ExitStack() as stack:
            host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
            col=host.columns[0];before=(col.day,col.stocks.copy(),col.age_state.copy(),col.age_effluent.copy());receive=m.h.receive
            def corrupt(process,*args,**kwargs):
                disposition,response=receive(process,*args,**kwargs)
                if process is col.worker and tag in response:
                    values=response[tag].copy();values[index]=str(float(values[index])+1.);response[tag]=values
                return disposition,response
            try:
                m.h.receive=corrupt
                try:
                    refused=host.step(1,checkpoint=True)
                    assert attack=='water-receipt' and not refused['committed'],'Fabricated daily calendar receipt accepted'
                    checks.append(dict(attack=attack,status='REFUSED',kernel_residual_cm=refused['kernel_residual_cm']))
                except ValueError as error:
                    assert attack=='age-production' and 'age' in str(error).lower(),str(error)
                    checks.append(dict(attack=attack,status='REFUSED',error=str(error)))
            finally:m.h.receive=receive
            assert before==(col.day,col.stocks,col.age_state,col.age_effluent)
            assert not list(target.glob('accepted-*.zip'))
    target=out/'independent';target.mkdir();starts=[1,4];origins=[]
    for i,start in enumerate(starts):
        origin=target/('origin'+str(i));receipt=m.h.verify_checkpoint(full/f'accepted-column-1-day-{start}.zip',start,meta['binding'],origin)
        origins.append(m.h.ColumnStart('original',start,origin,receipt,name='calendar'+str(i)))
    with contextlib.ExitStack() as stack:
        host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,origins,
            runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        for turn in range(3):
            for i,start in enumerate(starts,1):assert m.physical([host.step(i)])==m.physical([data[start+turn]])
        host.close()
    assert m.sha(source)==digest
    return dict(active_gift_day=5,discard_replay_exact=True,disk_recovery_exact=True,independent_steps=6,
                committed_state_unchanged=True,origin_unchanged=True,checks=checks)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','matrix','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();result=dict(status='RUNNING',profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    try:
        for kind,period,reset in [('surface',3,0),('subsurface-interval',7,0),('plain',7,1)]:
            for opt in ('O0','O2'):
                name=f'p{period}-{kind}-r{reset}-{opt}';root=a.matrix/name;project=m.e.load(root/'input');out=a.output/name;out.mkdir()
                checks=native(root/'build',a.reference_work,project,root/'short',out/'native')
                active=transactions(root/'build',a.reference_work,project,root/'short',out/'active') if kind!='plain' else None
                result['profiles'][name]=dict(native_refusals=checks,transactions=active);save();print(name,'CALENDAR_NATIVE_AND_ACTIVE_CONTROLS_PASS',flush=True)
        result['status']='CALENDAR_NATIVE_READERS_ACTIVE_TRANSACTIONS_REFUSALS_AND_ISOLATION_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
