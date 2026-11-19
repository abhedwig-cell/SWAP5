"""Actual AGE per-step native/private, policy and transactional controls."""
import argparse,contextlib,json,shutil,struct
from pathlib import Path
import age_groundwater_runtime as matrix
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical
from age_groundwater_output import magic,metadata,selection,domain as groundwater_domain

m=matrix.m



def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source);selected=selection(project)
    attacks=['old002','old003','old004','old005','foreign-kind','truncated','trailing','header-witness','shape','policy','negative-day','foreign-day','negative-counter','changed-counter','print-counter','zero-pointer','overflow-pointer','future-pointer','flag-domain','short-flag','step-flag','nonfinite','value-witness','negative-period','ordinary-water','ordinary-cde','ordinary-age','ordinary-history','aquifer-codec','preceding-snow-subdaily','preceding-snow-step','preceding-snow-reset','reset-policy']
    if not selected['swsnow'] and selected['swhyst']:attacks+=['domain-version','domain-shape','domain-macro','domain-mode','domain-kind','domain-witness']
    attacks+=['nprint-count','old-ordinary-reset','old-ordinary-reset-history','foreign-perstep-family']
    if selected['swsnow']:
        attacks+=['domain-version','domain-shape','domain-macro','domain-mode','domain-kind','domain-witness','domain-snow','domain-frost','domain-drainage','domain-heat','domain-calculation']
        attacks+=['snow-version','snow-shape','snow-kind','snow-count','snow-witness']+[f'snow-nan-{i}' for i in range(7)]+[f'snow-negative-{i}' for i in range(7)]
    attacks+=['age-output-day','age-output-period','age-stock-negative','age-stock-nan','age-export-negative','age-export-nan','age-total-receipt','age-cumulative-reset','age-interval-reset']
    attacks += ['ground-domain-'+str(i) for i in range(13)]+['ground-witness']
    attacks += ['ground-nan-'+str(i) for i in (0,project.nodes,2*project.nodes,3*project.nodes+1,4*project.nodes+2,5*project.nodes+2,5*project.nodes+3)]
    attacks += ['ground-negative-'+str(i) for i in (project.nodes,2*project.nodes,3*project.nodes+1,4*project.nodes+2,5*project.nodes+3)]
    attacks += ['ground-head','ground-level','ground-volume']
    checks=[]
    for attack in attacks:
        target=out/attack;target.mkdir(parents=True);origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        path=origin/'macro.bin';raw=bytearray(path.read_bytes());assert raw[:8]==magic(project);pos,header,nreal=matrix.calendar(raw,project.nodes)
        def integer(index,value,witness=True):
            struct.pack_into('<i',raw,pos+4*index,value)
            if witness:struct.pack_into('<i',raw,pos+80+4*index,value)
        def value(index,v,witness=True):
            struct.pack_into('<d',raw,pos+160+8*index,v)
            if witness:struct.pack_into('<d',raw,pos+160+8*nreal+8*index,v)
        markers={'ordinary-water':b'S5IOW001','ordinary-cde':b'S5IOC001','ordinary-age':b'S5IOA001','ordinary-history':b'S5IHW001','aquifer-codec':b'S5IOQ001',
            'preceding-snow-subdaily':b'S5STW001','preceding-snow-step':b'S5SPW001','preceding-snow-reset':b'S5SRW001'}
        markers.update({'old-ordinary-reset':b'S5ORW001','old-ordinary-reset-history':b'S5ORH001',
            'foreign-perstep-family':b'S5OPW001' if selected['swsnow'] or selected['swhyst'] else b'S5SPN001'})
        if attack.startswith('ground-'):
            header=struct.pack('<13i',*groundwater_domain(project));assert raw.count(header+header)==1;start=raw.index(header+header);offset=start+104;n=project.nodes
            if attack.startswith('ground-domain-'):
                i=int(attack.rsplit('-',1)[1]);v=groundwater_domain(project)[i]+1
                for at in (start,start+52):struct.pack_into('<i',raw,at+4*i,v)
            elif attack=='ground-witness':struct.pack_into('<i',raw,start,99)
            elif attack.startswith(('ground-nan-','ground-negative-')):
                i=int(attack.rsplit('-',1)[1]);struct.pack_into('<d',raw,offset+8*i,float('nan') if 'nan' in attack else -1.)
            else:
                i={'ground-head':0,'ground-level':5*n+2,'ground-volume':5*n+3}[attack];v=struct.unpack_from('<d',raw,offset+8*i)[0];struct.pack_into('<d',raw,offset+8*i,v+1.)
        elif attack.startswith('age-'):
            age_start=pos+160+16*nreal
            if attack=='age-output-day':struct.pack_into('<i',raw,len(raw)-20,5)
            elif attack=='age-output-period':struct.pack_into('<d',raw,len(raw)-16,1.)
            elif attack=='age-stock-negative':struct.pack_into('<d',raw,age_start,-1.)
            elif attack=='age-stock-nan':struct.pack_into('<d',raw,age_start,float('nan'))
            elif attack=='age-export-negative':struct.pack_into('<d',raw,len(raw)-172,-1.)
            elif attack=='age-export-nan':struct.pack_into('<d',raw,len(raw)-172,float('nan'))
            elif attack=='age-total-receipt':struct.pack_into('<d',raw,len(raw)-44,1.)
            else:
                offset=len(raw)-(8 if attack=='age-cumulative-reset' else 4)
                struct.pack_into('<i',raw,offset,1-struct.unpack_from('<i',raw,offset)[0])
        elif attack in markers:raw[:8]=markers[attack]
        elif attack=='nprint-count':integer(5,header[5]+1)
        elif attack.startswith('snow-'):
            snow_header=struct.pack('<4i',1,project.nodes,0,7);assert raw.count(snow_header+snow_header)==1;d=raw.index(snow_header+snow_header)
            if attack.startswith(('snow-nan-','snow-negative-')):
                index=int(attack.rsplit('-',1)[1]);struct.pack_into('<d',raw,d+32+8*index,float('nan') if 'nan' in attack else -1.)
            else:
                index={'snow-version':0,'snow-shape':1,'snow-kind':2,'snow-count':3,'snow-witness':0}[attack]
                changed=struct.unpack_from('<i',raw,d+4*index)[0]+1;struct.pack_into('<i',raw,d+4*index,changed)
                if attack!='snow-witness':struct.pack_into('<i',raw,d+16+4*index,changed)
        elif attack.startswith('domain-') and selected['swsnow']:
            domain=struct.pack('<10i',1,project.nodes,0,0,selected['swhyst'],1,0,1,1,2);assert raw.count(domain+domain)==1;d=raw.index(domain+domain)
            index={'domain-version':0,'domain-shape':1,'domain-macro':2,'domain-mode':4,'domain-kind':3,'domain-witness':0,'domain-snow':5,'domain-frost':6,'domain-drainage':7,'domain-heat':8,'domain-calculation':9}[attack]
            changed=struct.unpack_from('<i',raw,d+4*index)[0]+1;struct.pack_into('<i',raw,d+4*index,changed)
            if attack!='domain-witness':struct.pack_into('<i',raw,d+40+4*index,changed)
        elif attack.startswith('domain-'):
            domain=struct.pack('<5i',1,project.nodes,0,selected['swhyst'],2);assert raw.count(domain+domain)==1;d=raw.index(domain+domain)
            index={'domain-version':0,'domain-shape':1,'domain-macro':2,'domain-mode':3,'domain-kind':4,'domain-witness':0}[attack]
            changed=struct.unpack_from('<i',raw,d+4*index)[0]+1;struct.pack_into('<i',raw,d+4*index,changed)
            if attack!='domain-witness':struct.pack_into('<i',raw,d+20+4*index,changed)
        elif attack.startswith('old'):raw[:8]=('S5AGE'+attack[-3:]).encode()
        elif attack=='foreign-kind':raw[:8]=b'S5OPW001' if selected['swsnow'] or selected['swhyst'] else b'S5OPH001'
        elif attack=='truncated':raw=raw[:-1]
        elif attack=='trailing':raw+=b'x'
        elif attack=='header-witness':integer(7,header[7]+1,False)
        elif attack=='shape':integer(1,project.nodes+1)
        elif attack=='policy':integer(4,header[4]+1)
        elif attack=='negative-day':integer(6,-1)
        elif attack=='foreign-day':integer(6,5)
        elif attack=='negative-counter':integer(7,-1)
        elif attack=='changed-counter':integer(7,header[7]+1)
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
        elif attack=='reset-policy':integer(11,1-header[11])
        else:raise AssertionError(attack)
        path.write_bytes(raw)
        try:
            with contextlib.ExitStack() as stack:
                m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,[m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            diagnostic='\n'.join(p.read_text(encoding='utf8',errors='replace') for p in target.rglob('donor.stderr'))
            assert 'ERROR STOP' in diagnostic and not list(target.glob('accepted-*.zip')),(attack,diagnostic,str(error))
            checks.append(dict(attack=attack,status='REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Corrupt original ordinary native accepted: '+attack)
        assert m.sha(source)==digest
    return checks


def transactions(build,reference,project,full,out):
    out.mkdir();data=m.rows(full);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'original-output',origin=source,day=4,adopt_native=True)
    trial=column.prepare();assert physical(trial)==m.physical([data[4]])
    column.discard(trial);assert column.day==4
    replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'original-output',origin=column.checkpoint,day=5)
    endpoint=recovered.prepare();assert physical(endpoint)==m.physical([data[5]]);recovered.discard(endpoint)
    assert m.sha(source)==digest
    return dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)



def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();cohort=json.loads((a.profile_root/'RESULT.json').read_text(encoding='utf8'));project=m.e.load(Path(cohort.get('input_root',a.profile_root/'input')),original_output=True)
    build=Path(cohort.get('build_root',a.profile_root/'build'));full=a.profile_root/'trajectory';selected=metadata(project)
    q=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'),native_refusals=[],policy_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        q['native_refusals']=native(build,a.reference_work,project,full,a.output/'native');save()
        assert len(q['native_refusals'])==(81 if selected['swhyst'] else 75)
        q['transactions']=transactions(build,a.reference_work,project,full,a.output/'active');assert all(v is True for v in q['transactions'].values());save()
        for field in selected:
            target=a.output/('policy-'+field);target.mkdir();bad=json.loads((build/'BUILD.json').read_text(encoding='utf8'));bad['identity']['original_output'][field]='foreign';(target/'BUILD.json').write_text(json.dumps(bad),encoding='utf8')
            for helper in ('mod_subsurface_solute_source.f90','mod_aquifer_solute_reservoir.f90','frozencond.f90','timecontrol.f90','terminal_water_receipt.f90'):
                if (build/helper).exists():shutil.copyfile(build/helper,target/helper)
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:assert 'Foreign original output policy' in str(error),str(error)
            else:raise AssertionError('Foreign ordinary output policy accepted')
            q['policy_refusals'].append(dict(field=field,status='REFUSED'));save()
        target=a.output/'actual-compiled-provider';shutil.copytree(build,target);m.validate_bundle(target,a.reference_work,project)
        helper='thermal_output_snow_calendar_state.f90' if selected['swsnow'] else 'original_output_hysteresis_domain.f90' if selected['swhyst'] else 'mod_original_output_receipt.f90'
        path=target/helper;path.write_bytes(path.read_bytes()+b'\n! deliberately foreign actual copied provider\n')
        try:m.validate_bundle(target,a.reference_work,project)
        except ValueError as error:
            assert str(error)==('Foreign actual original Snow output calendar state provider' if selected['swsnow'] else 'Generated donor differs: '+helper),str(error)
            q['actual_provider_refusal']=dict(status='REFUSED',provider=helper,error=str(error),actual_original_metadata_unchanged=True)
        else:raise AssertionError('Foreign actual compiled ordinary provider accepted')
        path=target/'age_groundwater_native_state.f90';path.write_bytes(path.read_bytes()+b'\n! actual wrong typed hydraulic state provider\n')
        try:m.validate_bundle(target,a.reference_work,project)
        except ValueError as error:
            assert str(error)=='Foreign actual original AGE groundwater state provider',str(error)
            q['actual_hydraulic_provider_refusal']=dict(status='REFUSED',provider=path.name,error=str(error))
        else:raise AssertionError('Foreign compiled hydraulic provider accepted')
        q['trial_phase_witness']='SOURCE_BOUND_LITERAL_EXISTING_PRESCRIBED_GROUNDWATER_REACTION_NOT_FRESH_COMPONENT_PASS'
        q['status']='AGE_GROUNDWATER_NATIVE_PRIVATE_ACTIVE_POLICY_PROVIDER_PASS';print(q['status'],len(q['native_refusals']),len(q['policy_refusals']),flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
