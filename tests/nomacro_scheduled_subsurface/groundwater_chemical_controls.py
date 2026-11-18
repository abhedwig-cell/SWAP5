"""Actual typed groundwater native refusals and active external transactions."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import zipfile
import groundwater_chemical_runtime as runtime
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical
from groundwater_native import magic,decode

m=runtime.m


def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project)
    source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    attacks=['prior-output-codec','other-groundwater-codec','truncated','trailing','truncated-carry','domain-witness']
    attacks += ['domain-'+str(i) for i in range(9)]
    attacks += ['nonfinite-'+str(i) for i in (0,project.nodes,2*project.nodes,3*project.nodes+1,4*project.nodes+2,5*project.nodes+2,5*project.nodes+3)]
    attacks += ['negative-'+str(i) for i in (project.nodes,2*project.nodes,3*project.nodes+1,4*project.nodes+2,5*project.nodes+3)]
    attacks += ['unbalanced-volume','calendar-witness','cde-output-witness','cde-native-nan']
    checks=[]
    for attack in attacks:
        target=out/attack;target.mkdir(parents=True);origin=target/'origin'
        receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        path=origin/'macro.bin';raw=bytearray(path.read_bytes());carry=decode(raw,project);offset=carry['offset'];d=offset-72
        if attack=='prior-output-codec':raw[:8]=b'S5IOC001'
        elif attack=='other-groundwater-codec':raw[:8]=b'S5GWC002'
        elif attack=='truncated':raw=raw[:-1]
        elif attack=='trailing':raw+=b'x'
        elif attack=='truncated-carry':raw=raw[:offset+8]
        elif attack.startswith('domain-'):
            i=0 if attack=='domain-witness' else int(attack.split('-')[1]);old=struct.unpack_from('<i',raw,d+4*i)[0]
            struct.pack_into('<i',raw,d+4*i,old+1)
            if attack!='domain-witness':struct.pack_into('<i',raw,d+36+4*i,old+1)
        elif attack.startswith(('nonfinite-','negative-')):
            i=int(attack.split('-')[1]);struct.pack_into('<d',raw,offset+8*i,float('nan') if attack.startswith('nonfinite') else -1.)
        elif attack=='unbalanced-volume':struct.pack_into('<d',raw,offset+8*(5*project.nodes+3),carry['volume']+1.)
        elif attack=='cde-native-nan':struct.pack_into('<d',raw,48,float('nan'))
        else:
            calendar=offset+8*(5*project.nodes+4)
            header=list(struct.unpack_from('<20i',raw,calendar));assert header[0:2]==[1,project.nodes]
            if attack=='calendar-witness':struct.pack_into('<i',raw,calendar+80,2)
            else:
                cde=calendar+160+16*header[3];assert struct.unpack_from('<i',raw,cde)[0]==1
                struct.pack_into('<i',raw,cde+12,2)
        path.write_bytes(raw)
        try:
            with contextlib.ExitStack() as stack:
                m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                    [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,
                    binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            diagnostic='\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
            assert 'ERROR STOP' in diagnostic and not list(target.glob('accepted-*.zip')),(attack,diagnostic,str(error))
            checks.append(dict(attack=attack,status='REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Corrupt prescribed groundwater native accepted: '+attack)
        assert m.sha(source)==digest
    return checks


def active(build,reference,project,full,out):
    out.mkdir();data=m.rows(full);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'groundwater-cde',origin=source,day=4,adopt_native=True)
    trial=column.prepare();assert physical(trial)==m.physical([data[4]])
    assert trial.budget['solute_ledger_mg_cm2'][3]>0
    column.discard(trial);assert column.day==4
    replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'groundwater-cde',origin=column.checkpoint,day=5)
    endpoint=recovered.prepare();assert physical(endpoint)==m.physical([data[5]]);recovered.discard(endpoint)
    checks=[]
    for field,index in (('groundwater',0),('pressure-head',2)):
        altered=CoupledDailyColumn(build,reference,out/('reported-'+field),project,'groundwater-cde',origin=source,day=4,adopt_native=True)
        receive=m.h.receive;changed=[False]
        def corrupt(process,*args,**kwargs):
            disposition,response=receive(process,*args,**kwargs)
            if not changed[0] and 'HYBRID_DAY_RETURN' in response and 'HYBRID_HYDRAULIC' in response:
                values=response['HYBRID_HYDRAULIC'].copy();values[index]=str(float(values[index])+1.)
                response['HYBRID_HYDRAULIC']=values;changed[0]=True
            return disposition,response
        try:
            m.h.receive=corrupt
            try:altered.prepare()
            except (ValueError,RuntimeError) as error:
                assert changed[0] and 'native carry differs from candidate receipt' in str(error),str(error)
                checks.append(dict(field=field,status='REFUSED_BEFORE_PREPARE',error=str(error)))
            else:raise AssertionError('Fabricated prescribed groundwater native receipt accepted')
        finally:m.h.receive=receive
        assert altered.day==4
    assert m.sha(source)==digest
    return dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,
                origin_unchanged=True,actual_active_source_mg_cm2=trial.budget['solute_ledger_mg_cm2'][3],reported_refusals=checks)


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):parser.add_argument('--'+key,type=Path,required=True)
    args=parser.parse_args();args.output.mkdir()
    project=m.e.load(args.profile_root/'input',original_output=True);build=args.profile_root/'build';full=args.profile_root/'trajectory'
    record=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'))
    def save():(args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    save()
    try:
        record['native_refusals']=native(build,args.reference_work,project,full,args.output/'native');save()
        record['transactions']=active(build,args.reference_work,project,full,args.output/'active')
        record['status']='PRESCRIBED_GROUNDWATER_ACTUAL_NATIVE_ACTIVE_AND_REPORTED_REFUSALS_PASS'
        print(record['status'],len(record['native_refusals']),flush=True)
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
