"""Direct-source native refusal, active external rollback and ledger attacks."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import direct_soil_age_runtime as runtime
from age_direct_soil_source import magic
from age_irrigation_source import magic as surface_magic
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical

m=runtime.m


def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source);checks=[]
    attacks=['direct-version','direct-shape','direct-witness','direct-negative','direct-nan','direct-positive-foreign','source-domain','source-witness','truncated','trailing','old-source-codec','old-base-codec','future-age','future-rate','future-date','future-kind','negative-cursor','foreign-cursor','current-age']
    for attack in attacks:
        target=out/attack;target.mkdir(parents=True);origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);path=origin/'macro.bin';raw=bytearray(path.read_bytes());assert raw[:8]==magic(project)
        # Locate only the actual active two-row fixed input table. The original
        # private wire places its other MAIRG-sized tables at fixed offsets.
        needle=struct.pack('<2d',20.,60.);assert raw.count(needle)==1
        ages=raw.index(needle);current=ages-496;types=current-20-4*36600;dates=ages+8*36600
        assert struct.unpack_from('<2i',raw,types)==(2,2)
        if attack in ('direct-version','direct-shape'):
            field=0 if attack=='direct-version' else 1
            for off in (-24+4*field,-8+4*field):struct.pack_into('<i',raw,len(raw)+off,2 if field==0 else 35)
        elif attack=='direct-witness':struct.pack_into('<i',raw,len(raw)-8,2)
        elif attack.startswith('direct-'):
            struct.pack_into('<d',raw,len(raw)-16,{'direct-negative':-1.,'direct-nan':float('nan'),'direct-positive-foreign':1.}[attack])
        elif attack=='source-domain':
            for off in (-80,-52):struct.pack_into('<i',raw,len(raw)+off,2)
        elif attack=='source-witness':struct.pack_into('<i',raw,len(raw)-52,2)
        elif attack=='truncated':raw=raw[:-1]
        elif attack=='trailing':raw+=b'x'
        elif attack=='old-source-codec':
            from age_direct_soil_source import shadow
            raw[:8]=surface_magic(shadow(project))
        elif attack=='old-base-codec':raw[:8]=b'S5AGE002'
        elif attack=='future-age':struct.pack_into('<d',raw,ages+8,1001.)
        elif attack=='future-rate':struct.pack_into('<d',raw,dates+8*36600+8,13.)
        elif attack=='future-date':struct.pack_into('<d',raw,dates+8,40000.)
        elif attack=='future-kind':struct.pack_into('<i',raw,types+4,1)
        elif attack=='negative-cursor':struct.pack_into('<i',raw,current-12,-1)
        elif attack=='foreign-cursor':struct.pack_into('<i',raw,current-12,3)
        elif attack=='current-age':struct.pack_into('<d',raw,current,1001.)
        path.write_bytes(raw)
        try:
            with contextlib.ExitStack() as stack:m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,[m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            diagnostic='\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
            assert not list(target.glob('accepted-*.zip'))
            if attack=='direct-positive-foreign':assert 'Restored original age state differs' in str(error),(attack,str(error))
            else:assert 'ERROR STOP' in diagnostic,(attack,diagnostic,str(error))
            checks.append(dict(attack=attack,status='REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Malformed direct age native accepted: '+attack)
        assert m.sha(source)==digest
    return checks


def transactions(build,reference,project,full,out):
    out.mkdir();data=m.rows(full);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'direct-soil-age',origin=source,day=4,adopt_native=True)
    first=column.prepare();assert physical(first)==m.physical([data[4]]) and abs(first.budget['age_direct_soil_input_cm_day']-48.)<1e-10
    column.discard(first);assert column.day==4
    replay=column.prepare();assert replay.budget==first.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'direct-soil-age',origin=column.checkpoint,day=5)
    sixth=recovered.prepare();assert physical(sixth)==m.physical([data[5]]);recovered.accept(sixth)
    second=recovered.prepare();assert physical(second)==m.physical([data[6]]) and abs(second.budget['age_direct_soil_input_cm_day']-72.)<1e-10
    recovered.discard(second);again=recovered.prepare();assert again.budget==second.budget;recovered.discard(again)
    meta,case=m.validate_bundle(build,reference,project);refusals=[]
    for index in (0,2,3,5,11):
        target=out/('ledger-'+str(index));target.mkdir();origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        with contextlib.ExitStack() as stack:
            host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,[m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
            col=host.columns[0];before=(col.day,col.stocks.copy(),col.age_state.copy(),col.age_effluent.copy());receive=m.h.receive
            def corrupt(process,*args,**kwargs):
                disposition,response=receive(process,*args,**kwargs)
                if process is col.worker and 'HYBRID_AGE_CUMULATIVE' in response:
                    values=response['HYBRID_AGE_CUMULATIVE'].copy();values[index]=str(float(values[index])+1.);response['HYBRID_AGE_CUMULATIVE']=values
                return disposition,response
            try:
                m.h.receive=corrupt
                try:host.step(1,checkpoint=True)
                except ValueError as error:assert 'age' in str(error).lower();refusals.append(dict(index=index,error=str(error)))
                else:raise AssertionError('Altered direct soil age ledger accepted')
            finally:m.h.receive=receive
            assert before==(col.day,col.stocks,col.age_state,col.age_effluent) and not list(target.glob('accepted-*.zip'))
    assert m.sha(source)==digest
    return dict(first_gift_discard_unchanged=True,replay_exact=True,accept_exact=True,recovery_exact=True,varying_second_gift_exact=True,second_gift_discard_replay_exact=True,origin_unchanged=True,altered_ledger_refusals=refusals)


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):ap.add_argument('--'+key,type=Path,required=True)
    a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir();project=m.e.load(a.profile_root/'input',age_direct_soil_source=True);build=a.profile_root/'build';full=a.profile_root/'trajectory'
    q=dict(status='RUNNING',native=[],transactions=None)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        q['native']=native(build,a.reference_work,project,full,a.output/'native');save()
        q['transactions']=transactions(build,a.reference_work,project,full,a.output/'transactions')
        q['status']='DIRECT_SOIL_AGE_NATIVE_EXTERNAL_ROLLBACK_AND_ALTERED_LEDGER_REFUSALS_PASS'
        print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
