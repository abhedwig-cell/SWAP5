"""Actual fixed age-source native input identity and external transactions."""
import argparse
import contextlib
from datetime import date
import json
from pathlib import Path
import re
import shutil
import struct
import age_irrigation_source_matrix as matrix
from age_irrigation_source import metadata,magic,base_magic,LAYOUTS,MAGICS
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical

m=matrix.m


def positions(raw,build,kind):
    # The original fixed-input arrays are contiguous in the actual existing
    # private irrigation wire. Inspect that real generated wire before using
    # the source-declared 14-element tables and MAIRG100*366 shape.
    text=(build/'irrigation.f90').read_text(encoding='cp1252')
    first=text.index('   subroutine hybrid_irrigation_checkpoint(');last=text.index('   end subroutine',first)
    body=text[first:last];wire=body[body.index('read(unit,iostat=ios)'):body.index("if(ios/=0)")]
    fields=re.findall(r'hybrid_irrigation_snapshot%(\w+)',wire)
    assert fields[:21]==['nod_ssdi','irr_depth','irr_rate','dayfix','irrigevent','irtype','isua','isuas','nirri','schedule','swcirrthres','cirr','cirrs','cirrthres','dcrit','ditab','dwatab','dt_irr_event','fidtab','gird','hcritab']
    assert fields[21:26]==['irconc','irdate','irrate','irdepth','ir_z']
    needle=struct.pack('<5d',20.,60.,10.,100.,35.);assert raw.count(needle)==1
    ages=raw.index(needle);current=ages-496;types=current-20-4*36600
    assert struct.unpack_from('<5i',raw,types)==(1 if kind=='surface' else 0,)*5
    dates=ages+8*36600
    expected=[float((date.fromisoformat(s)-date(1900,1,1)).days+1) for s in ('2002-01-05','2002-01-07','2003-01-01','2003-06-15','2004-12-30')]
    assert list(struct.unpack_from('<5d',raw,dates))==expected
    return dict(ages=ages,current=current,types=types,cursor=current-12,dates=dates,rates=dates+8*36600,depths=dates+16*36600)


def native(build,reference,project,full,out,kind):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source);checks=[]
    attacks=['domain-field'+str(i) for i in range(7)]+['domain-witness','truncated','trailing','base-codec','foreign-source-codec','future-age-upper','future-age-negative','future-age-nan','future-age-foreign','current-age-upper','current-age-nan','current-age-foreign','future-date','future-kind','future-rate','future-depth','negative-cursor','future-cursor']
    for attack in attacks:
        target=out/attack;target.mkdir(parents=True);origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);p=origin/'macro.bin';raw=bytearray(p.read_bytes());assert raw[:8]==magic(project)
        table=positions(raw,build,kind);domain=len(raw)-56;header=struct.unpack_from('<7i',raw,domain);assert header==(1,34,0,2,1,m.e.switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252'))['SWHYST'],LAYOUTS[base_magic(project)]) and raw[domain:domain+28]==raw[domain+28:]
        if attack.startswith('domain-field'):
            field=int(attack[-1])
            for offset in (domain+4*field,domain+28+4*field):struct.pack_into('<i',raw,offset,header[field]+1)
        elif attack=='domain-witness':struct.pack_into('<i',raw,domain+28,2)
        elif attack=='truncated':raw=raw[:-1]
        elif attack=='trailing':raw+=b'x'
        elif attack=='base-codec':raw[:8]=base_magic(project)
        elif attack=='foreign-source-codec':raw[:8]=next(code for code in MAGICS.values() if code!=magic(project))
        elif attack.startswith('future-age'):
            value={'future-age-upper':1001.,'future-age-negative':-1.,'future-age-nan':float('nan'),'future-age-foreign':11.}[attack];struct.pack_into('<d',raw,table['ages']+16,value)
        elif attack.startswith('current-age'):
            value={'current-age-upper':1001.,'current-age-nan':float('nan'),'current-age-foreign':15.}[attack];struct.pack_into('<d',raw,table['current'],value)
        elif attack=='future-kind':struct.pack_into('<i',raw,table['types']+8,2)
        elif attack in ('negative-cursor','future-cursor'):struct.pack_into('<i',raw,table['cursor'],-1 if attack=='negative-cursor' else 6)
        else:
            field={'future-date':'dates','future-rate':'rates','future-depth':'depths'}[attack];pos=table[field]+16;old=struct.unpack_from('<d',raw,pos)[0];struct.pack_into('<d',raw,pos,old+0.1)
        p.write_bytes(raw)
        try:
            with contextlib.ExitStack() as stack:m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,[m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            diagnostic='\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'));assert 'ERROR STOP' in diagnostic and not list(target.glob('accepted-*.zip')),(attack,diagnostic,str(error));checks.append(dict(attack=attack,status='REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Malformed fixed-age native accepted: '+attack)
        assert m.sha(source)==digest
    return checks


def transactions(build,reference,project,full,out):
    out.mkdir();data=m.rows(full);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source);column=CoupledDailyColumn(build,reference,out/'external',project,'fixed-age-source',origin=source,day=4,adopt_native=True)
    trial=column.prepare();assert physical(trial)==m.physical([data[4]]) and abs(trial.budget['age_ledger_cm_day'][2]-48.)<=1e-10
    column.discard(trial);assert column.day==4;replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'fixed-age-source',origin=column.checkpoint,day=5)
    next_trial=recovered.prepare();assert physical(next_trial)==m.physical([data[5]]);recovered.accept(next_trial)
    second=recovered.prepare();assert physical(second)==m.physical([data[6]]) and abs(second.budget['age_ledger_cm_day'][2]-72.)<=1e-10;recovered.discard(second);again=recovered.prepare();assert again.budget==second.budget;recovered.discard(again)
    assert m.sha(source)==digest
    return dict(first_gift_discard_unchanged=True,replay_exact=True,accept_exact=True,recovery_exact=True,varying_second_gift_exact=True,second_gift_discard_replay_exact=True,origin_unchanged=True)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();run=json.loads((a.profile_root/'RESULT.json').read_text());assert run['status']=='AGE_IRRIGATION_SOURCE_SHORT_CURRENT_FORCING_NATIVE_OUTPUT_PASS' and run['events']=='varying'
    project=m.e.load(Path(run.get('input_root',a.profile_root/'input')),original_output=run['original_output'],age_irrigation_source=True);build=Path(run.get('build_root',a.profile_root/'build'));q=dict(status='RUNNING',profile=dict(kind=run['kind'],calendar=run['calendar'],optimization=run['optimization']),build_sha256=m.sha(build/'BUILD.json'))
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        q['native_refusals']=native(build,a.reference_work,project,a.profile_root/'trajectory',a.output/'native',run['kind']);save()
        q['transactions']=transactions(build,a.reference_work,project,a.profile_root/'trajectory',a.output/'active');q['policy_refusals']=[]
        for field in ('policy','native_codec','base_native_codec','source_sha256','domain_source_sha256','correction_sha256','source'):
            target=a.output/('policy-'+field);target.mkdir();bad=json.loads((build/'BUILD.json').read_text());bad['identity']['original_age_fixed_irrigation'][field]='foreign';(target/'BUILD.json').write_text(json.dumps(bad))
            for helper in ('mod_subsurface_solute_source.f90','mod_aquifer_solute_reservoir.f90'):
                if (build/helper).exists():shutil.copyfile(build/helper,target/helper)
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:assert 'Foreign original fixed age input policy' in str(error),str(error)
            else:raise AssertionError('Foreign fixed age source policy accepted')
            q['policy_refusals'].append(dict(field=field,status='REFUSED'))
        q['status']='FIXED_CURRENT_AGE_NATIVE_INPUT_IDENTITY_AND_VARYING_EXTERNAL_TRANSACTIONS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
