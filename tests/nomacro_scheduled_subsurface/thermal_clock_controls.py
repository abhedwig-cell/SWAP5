"""Actual Snow totals, calendar/domain refusals and transactional ownership."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import shutil
import zipfile
import thermal_clock_runtime as matrix
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical
from thermal_output_clock import magic,metadata,selection

m=matrix.m


def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    attacks=['old002','old003','old004','old005','foreign-kind','truncated','trailing','header-witness','shape','policy','negative-day','foreign-day','negative-counter','changed-counter','print-counter','zero-pointer','overflow-pointer','future-pointer','flag-domain','short-flag','step-flag','nonfinite','value-witness','negative-period','ordinary-water','ordinary-cde','ordinary-age','domain-version','domain-shape','domain-macro','domain-mode','domain-kind','domain-witness','domain-snow','domain-frost','domain-drainage','domain-heat','domain-calculation','aquifer-codec']
    assert not project.solute and not project.age
    attacks+=['snow-version','snow-shape','snow-kind','snow-count','snow-witness','prototype001','preceding-snow-calendar']
    attacks += [f'snow-nan-{i}' for i in range(7)]+[f'snow-negative-{i}' for i in range(7)]
    checks=[]
    for attack in attacks:
        target=out/attack;target.mkdir(parents=True);origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        path=origin/'macro.bin';raw=bytearray(path.read_bytes());assert raw[:8]==magic(project)
        starts=[];prefix=struct.pack('<2i',1,project.nodes);pos=raw.find(prefix)
        while pos>=0:
            if pos+160<=len(raw):
                header=list(struct.unpack_from('<20i',raw,pos));nreal=header[3]
                if nreal>100 and pos+160+16*nreal<=len(raw) and header==list(struct.unpack_from('<20i',raw,pos+80)):starts.append(pos)
            pos=raw.find(prefix,pos+1)
        assert len(starts)==1,starts
        pos=starts[0];header=list(struct.unpack_from('<20i',raw,pos));nreal=header[3]
        def integer(index,value,witness=True):
            struct.pack_into('<i',raw,pos+4*index,value)
            if witness:struct.pack_into('<i',raw,pos+80+4*index,value)
        def value(index,v,witness=True):
            struct.pack_into('<d',raw,pos+160+8*index,v)
            if witness:struct.pack_into('<d',raw,pos+160+8*nreal+8*index,v)
        if attack=='preceding-snow-calendar':raw[:8]=b'S5CTW002'
        elif attack.startswith('snow-'):
            snow_header=struct.pack('<4i',1,project.nodes,0,7);assert raw.count(snow_header+snow_header)==1
            d=raw.index(snow_header+snow_header)
            if attack.startswith(('snow-nan-','snow-negative-')):
                index=int(attack.rsplit('-',1)[1]);struct.pack_into('<d',raw,d+32+8*index,float('nan') if 'nan' in attack else -1.)
            else:
                index={'snow-version':0,'snow-shape':1,'snow-kind':2,'snow-count':3,'snow-witness':0}[attack]
                value=struct.unpack_from('<i',raw,d+4*index)[0]+1;struct.pack_into('<i',raw,d+4*index,value)
                if attack!='snow-witness':struct.pack_into('<i',raw,d+16+4*index,value)
        elif attack=='prototype001':raw[:8]=b'S5CTW001'
        elif attack.startswith('domain-'):
            selected=selection(project);domain=struct.pack('<10i',1,project.nodes,0,int(project.solute),selected['swhyst'],1,selected['swfrost'],selected['swdra'],1,2)
            assert raw.count(domain+domain)==1;d=raw.index(domain+domain)
            index={'domain-version':0,'domain-shape':1,'domain-macro':2,'domain-mode':4,'domain-kind':3,'domain-witness':0,'domain-snow':5,'domain-frost':6,'domain-drainage':7,'domain-heat':8,'domain-calculation':9}[attack]
            previous=struct.unpack_from('<i',raw,d+4*index)[0];changed=previous+1
            struct.pack_into('<i',raw,d+4*index,changed)
            if attack!='domain-witness':struct.pack_into('<i',raw,d+40+4*index,changed)
        elif attack=='aquifer-codec':raw[:8]=b'S5IOQ001'
        elif attack.startswith('ordinary-'):raw[:8]={'ordinary-water':b'S5IOW001','ordinary-cde':b'S5IOC001','ordinary-age':b'S5IOA001'}[attack]
        elif attack.startswith('old'):raw[:8]=('S5AGE'+attack[-3:]).encode()
        elif attack=='foreign-kind':raw[:8]=b'S5IHW001' if project.solute or project.age else b'S5IHC001'
        elif attack=='truncated':raw=raw[:-1]
        elif attack=='trailing':raw+=b'x'
        elif attack=='header-witness':integer(7,header[7]+1,False)
        elif attack=='shape':integer(1,project.nodes+1)
        elif attack=='policy':integer(4,header[4]+1)
        elif attack=='negative-day':integer(6,-1)
        elif attack=='foreign-day':integer(6,5)
        elif attack=='negative-counter':integer(7,-1)
        elif attack=='changed-counter':integer(7,header[7]+1 if header[4]==0 or header[19] else header[4])
        elif attack=='print-counter':integer(8,header[8]+1)
        elif attack=='zero-pointer':integer(9,0)
        elif attack=='overflow-pointer':integer(10,2147483647)
        elif attack=='future-pointer':integer(10,100)
        elif attack=='flag-domain':integer(12,2)
        elif attack=='short-flag':integer(18,1-header[18])
        elif attack=='step-flag':integer(19,1-header[19])
        elif attack=='nonfinite':value(0,float('nan'))
        elif attack=='value-witness':value(0,123.,False)
        elif attack=='negative-period':value(nreal-1,-1.)
        elif attack.startswith('cde-'):
            c=pos+160+16*nreal;n=18+project.nodes
            assert struct.unpack_from('<3i',raw,c)==(1,project.nodes,n) and c+24+16*n==len(raw)
            if attack=='cde-header-witness':struct.pack_into('<i',raw,c+12,2)
            if attack=='cde-shape':
                for offset in (4,16):struct.pack_into('<i',raw,c+offset,project.nodes+1)
            if attack=='cde-value-witness':struct.pack_into('<d',raw,c+24+8,123.)
            if attack in ('cde-nonfinite','cde-negative-initial'):
                for offset in (24,24+8*n):struct.pack_into('<d',raw,c+offset,float('nan') if attack=='cde-nonfinite' else -1.)
        path.write_bytes(raw)
        try:
            with contextlib.ExitStack() as stack:
                m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,[m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            diagnostic='\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
            assert 'ERROR STOP' in diagnostic and not list(target.glob('accepted-*.zip')),(attack,diagnostic,str(error))
            checks.append(dict(attack=attack,status='REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Corrupt original-output native accepted: '+attack)
        assert m.sha(source)==digest
    return checks


def transactions(build,reference,project,full,out):
    out.mkdir();data=m.rows(full);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'original-output',origin=source,day=4,adopt_native=True)
    trial=column.prepare();assert physical(trial)==m.physical([data[4]])
    assert max(trial.budget['stock_start_cm'][2],trial.budget['stock_end_cm'][2])>0
    column.discard(trial);assert column.day==4
    replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'original-output',origin=column.checkpoint,day=5)
    endpoint=recovered.prepare();assert physical(endpoint)==m.physical([data[5]]);recovered.discard(endpoint)
    assert m.sha(source)==digest
    return dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--resume',action='store_true');a=p.parse_args();a.output.mkdir(exist_ok=a.resume)
    cohort=json.loads((a.profile_root/'RESULT.json').read_text());project=m.e.load(Path(cohort['input_root']),original_output=True)
    build=Path(cohort['build_root']);full=a.profile_root/'trajectory'
    q=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'),native_refusals=[],policy_refusals=[])
    if a.resume:
        old=json.loads((a.output/'RESULT.json').read_text());assert old['build_sha256']==q['build_sha256'];q['retained_previous_report']=old;q['native_refusals']=old.get('native_refusals',[]);q['transactions']=old.get('transactions',{})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        if not q['native_refusals']:q['native_refusals']=native(build,a.reference_work,project,full,a.output/('native-resumed' if a.resume else 'native'));save()
        assert len(q['native_refusals'])==60 and all(r['status']=='REFUSED' for r in q['native_refusals'])
        if not q.get('transactions'):q['transactions']=transactions(build,a.reference_work,project,full,a.output/'active')
        assert all(v is True for v in q['transactions'].values())
        for field in ('policy','native_codec','source_sha256','domain_source_sha256','original_hysteresis_sha256','ordinary_owner_sha256','vector_catalog_correction_sha256','cde_output_state_sha256','snow_stock','snow_increment_slots','physical_equations_changed','native_domain_bytes','snow_output_source_sha256','snow_output_fields','snow_output_domain_bytes','snow_output_value_bytes','clock_owner_sha256','soil_trial_control_volume','soil_trial_bottom','soil_trial_guard_cm','requested_period','nprintday'):
            target=a.output/(('policy-resumed-' if a.resume else 'policy-')+field);target.mkdir();bad=json.loads((build/'BUILD.json').read_text());bad['identity']['original_output'][field]='foreign';(target/'BUILD.json').write_text(json.dumps(bad))
            for helper in ('mod_subsurface_solute_source.f90','mod_aquifer_solute_reservoir.f90','frozencond.f90','timecontrol.f90','terminal_water_receipt.f90'):
                if (build/helper).exists():shutil.copyfile(build/helper,target/helper)
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:assert 'Foreign original output policy' in str(error),str(error)
            else:raise AssertionError('Foreign original thermal output policy accepted')
            q['policy_refusals'].append(dict(field=field,status='REFUSED'))
        target=a.output/'actual-snow-state-provider';target.mkdir();shutil.copyfile(build/'BUILD.json',target/'BUILD.json')
        helper='thermal_output_snow_calendar_state.f90';(target/helper).write_bytes((build/helper).read_bytes()+b'\n! deliberately foreign actual copied provider\n')
        try:m.validate_bundle(target,a.reference_work,project)
        except ValueError as error:
            assert 'Foreign actual original Snow output calendar state provider' in str(error),str(error)
            q['actual_provider_refusal']=dict(status='REFUSED',error=str(error),actual_original_metadata_unchanged=True)
        else:raise AssertionError('Foreign actual Snow state provider accepted')
        q['status']='WATER_SNOW_SUBDAILY_SIXTY_NATIVE_ACTIVE_AND_POLICY_REFUSALS_PASS';print(q['status'],len(q['native_refusals']),flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
