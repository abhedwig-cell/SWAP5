"""Actual original CDE clock native, private, policy and transaction workers."""
import argparse,contextlib,json,shutil,struct
from pathlib import Path
import cde_clock_runtime as matrix
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical
from cde_clock_output import magic,metadata,selection

m=matrix.m



def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source);selected=selection(project)
    attacks=['old002','old003','old004','old005','foreign-kind','truncated','trailing','header-witness','shape','policy','negative-day','foreign-day','negative-counter','changed-counter','print-counter','zero-pointer','overflow-pointer','future-pointer','flag-domain','short-flag','step-flag','nonfinite','value-witness','negative-period','ordinary-water','ordinary-cde','ordinary-age','ordinary-history','aquifer-codec','preceding-snow-subdaily','preceding-snow-step','preceding-snow-reset','reset-policy']
    if not selected['swsnow'] and selected['swhyst']:attacks+=['domain-version','domain-shape','domain-macro','domain-mode','domain-kind','domain-witness']
    attacks+=['nprint-count','old-ordinary-reset','old-ordinary-reset-history','foreign-perstep-family','cde-version','cde-shape','cde-header-witness','cde-value-witness','cde-nonfinite','cde-negative-initial','cde-private-anchor','cde-private-negative','cde-private-rounderr-nonfinite','cde-private-witness']
    if selected['swsnow']:
        attacks+=['domain-version','domain-shape','domain-macro','domain-mode','domain-kind','domain-witness','domain-snow','domain-frost','domain-drainage','domain-heat','domain-calculation']
        attacks+=['snow-version','snow-shape','snow-kind','snow-count','snow-witness']+[f'snow-nan-{i}' for i in range(7)]+[f'snow-negative-{i}' for i in range(7)]
    attacks+=['preceding-cde-interval-ordinary','preceding-cde-interval-history','preceding-cde-interval-snow']
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
        markers.update({'preceding-cde-interval-ordinary':b'S5CIC001','preceding-cde-interval-history':b'S5CIH001','preceding-cde-interval-snow':b'S5CIS001'})
        if attack in markers:raw[:8]=markers[attack]
        elif attack=='nprint-count':integer(5,header[5]+1)
        elif attack.startswith('cde-'):
            cp=pos+160+16*nreal;n=20+project.nodes
            assert struct.unpack_from('<3i',raw,cp)==struct.unpack_from('<3i',raw,cp+12)==(2,project.nodes,n)
            def cde_value(index,v,witness=True):
                struct.pack_into('<d',raw,cp+24+8*index,v)
                if witness:struct.pack_into('<d',raw,cp+24+8*n+8*index,v)
            if attack=='cde-version':
                for offset in (0,12):struct.pack_into('<i',raw,cp+offset,1)
            elif attack=='cde-shape':
                for offset in (8,20):struct.pack_into('<i',raw,cp+offset,n+1)
            elif attack=='cde-header-witness':struct.pack_into('<i',raw,cp+12,1)
            elif attack=='cde-value-witness':cde_value(0,123.,False)
            elif attack=='cde-nonfinite':cde_value(1,float('nan'))
            elif attack=='cde-negative-initial':cde_value(0,-1.)
            elif attack=='cde-private-anchor':cde_value(n-2,struct.unpack_from('<d',raw,cp+24+8*(n-2))[0]+1.)
            elif attack=='cde-private-negative':cde_value(n-2,-1.)
            elif attack=='cde-private-rounderr-nonfinite':cde_value(n-1,float('nan'))
            elif attack=='cde-private-witness':cde_value(n-2,123.,False)
            else:raise AssertionError(attack)
        elif attack.startswith('snow-'):
            snow_header=struct.pack('<4i',1,project.nodes,1,7);assert raw.count(snow_header+snow_header)==1;d=raw.index(snow_header+snow_header)
            if attack.startswith(('snow-nan-','snow-negative-')):
                index=int(attack.rsplit('-',1)[1]);struct.pack_into('<d',raw,d+32+8*index,float('nan') if 'nan' in attack else -1.)
            else:
                index={'snow-version':0,'snow-shape':1,'snow-kind':2,'snow-count':3,'snow-witness':0}[attack]
                changed=struct.unpack_from('<i',raw,d+4*index)[0]+1;struct.pack_into('<i',raw,d+4*index,changed)
                if attack!='snow-witness':struct.pack_into('<i',raw,d+16+4*index,changed)
        elif attack.startswith('domain-') and selected['swsnow']:
            domain=struct.pack('<10i',1,project.nodes,0,1,selected['swhyst'],1,0,1,1,2);assert raw.count(domain+domain)==1;d=raw.index(domain+domain)
            index={'domain-version':0,'domain-shape':1,'domain-macro':2,'domain-mode':4,'domain-kind':3,'domain-witness':0,'domain-snow':5,'domain-frost':6,'domain-drainage':7,'domain-heat':8,'domain-calculation':9}[attack]
            changed=struct.unpack_from('<i',raw,d+4*index)[0]+1;struct.pack_into('<i',raw,d+4*index,changed)
            if attack!='domain-witness':struct.pack_into('<i',raw,d+40+4*index,changed)
        elif attack.startswith('domain-'):
            domain=struct.pack('<5i',1,project.nodes,0,selected['swhyst'],1);assert raw.count(domain+domain)==1;d=raw.index(domain+domain)
            index={'domain-version':0,'domain-shape':1,'domain-macro':2,'domain-mode':3,'domain-kind':4,'domain-witness':0}[attack]
            changed=struct.unpack_from('<i',raw,d+4*index)[0]+1;struct.pack_into('<i',raw,d+4*index,changed)
            if attack!='domain-witness':struct.pack_into('<i',raw,d+20+4*index,changed)
        elif attack.startswith('old'):raw[:8]=('S5AGE'+attack[-3:]).encode()
        elif attack=='foreign-kind':raw[:8]=b'S5CIC001' if selected['swsnow'] or selected['swhyst'] else b'S5CIH001'
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
    p.add_argument('--skip-provider-poison',action='store_true');a=p.parse_args();a.output.mkdir();cohort=json.loads((a.profile_root/'RESULT.json').read_text(encoding='utf8'));project=m.e.load(Path(cohort['input_root']),original_output=True)
    build=Path(cohort['build_root']);full=a.profile_root/'trajectory';selected=metadata(project)
    q=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'),native_refusals=[],policy_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        q['native_refusals']=native(build,a.reference_work,project,full,a.output/'native');save()
        assert len(q['native_refusals'])==(80 if selected['swsnow'] else 56 if selected['swhyst'] else 50)
        q['transactions']=transactions(build,a.reference_work,project,full,a.output/'active');assert all(v is True for v in q['transactions'].values());save()
        for field in selected:
            target=a.output/('policy-'+field);target.mkdir();bad=json.loads((build/'BUILD.json').read_text(encoding='utf8'));bad['identity']['original_output'][field]='foreign';(target/'BUILD.json').write_text(json.dumps(bad),encoding='utf8')
            for helper in ('mod_subsurface_solute_source.f90','mod_aquifer_solute_reservoir.f90','frozencond.f90','timecontrol.f90','terminal_water_receipt.f90'):
                if (build/helper).exists():shutil.copyfile(build/helper,target/helper)
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:assert 'Foreign original output policy' in str(error),str(error)
            else:raise AssertionError('Foreign ordinary output policy accepted')
            q['policy_refusals'].append(dict(field=field,status='REFUSED'));save()
        q['actual_provider_refusals']=[]
        q['provider_poison_selection']='NOT_SELECTED_IDENTICAL_CDE_RECEIPT_STATE_VALIDATOR' if a.skip_provider_poison else 'SELECTED_ACTUAL_COMPILED_CDE_CLOCK_PRIVATE_TIME_INTEGRAL_PROVIDER_POISON'
        helpers=[] if a.skip_provider_poison else (['original_cde_output_state.f90','cde_interval_receipt.f90','solute.f90','timecontrol.f90','integral.f90','cde_clock_events.f90']+(['thermal_output_snow_calendar_state.f90'] if selected['swsnow'] else []))
        for helper in helpers:
            target=a.output/('actual-provider-'+helper);shutil.copytree(build,target);m.validate_bundle(target,a.reference_work,project)
            path=target/helper;path.write_bytes(path.read_bytes()+b'\n! deliberately foreign actual CDE interval provider\n')
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:
                expected='Foreign actual original Snow output calendar state provider' if helper=='thermal_output_snow_calendar_state.f90' else 'Generated donor differs: '+helper
                assert str(error)==expected,str(error)
                q['actual_provider_refusals'].append(dict(status='REFUSED',provider=helper,error=str(error),actual_original_metadata_unchanged=True));save()
            else:raise AssertionError('Foreign actual CDE interval provider accepted')
        q['daily_chemical_receipts']=matrix.audit_daily(full,35,project.nodes)
        q['status']='CDE_CLOCK_NATIVE_ACTIVE_POLICY_PROVIDER_PASS';print(q['status'],len(q['native_refusals']),len(q['policy_refusals']),flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
