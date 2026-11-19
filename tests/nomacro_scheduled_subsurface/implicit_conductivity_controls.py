"""Real worker refusals, immutable numerical policy and active transactions."""
import argparse
import contextlib
import copy
import json
from pathlib import Path
import shutil
import struct
import re
import implicit_conductivity_runtime as runtime
from age_groundwater_controls import transactions
from daily_coupling import CoupledDailyColumn
from original_output_baseline import assignment

m=runtime.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir()
    item=json.loads((a.profile_root/'RESULT.json').read_text(encoding='utf8'))
    inputs=Path(item['input_root']);build=Path(item['build_root']);full=a.profile_root/'trajectory'
    project=m.e.load(inputs,original_output=True);meta,case=m.validate_bundle(build,a.reference_work,project)
    q=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'),policy_refusals=[],numerical_owner_refusals=[],descriptor_refusals=[],native_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        policy=meta['identity']['implicit_conductivity'];attacks=[(k,None) for k in policy]
        attacks += [('original_parameter_rows',(i,k)) for i,row in enumerate(policy['original_parameter_rows']) for k in row]
        for index,(field,nested) in enumerate(attacks):
            target=a.output/f'policy-{index}';target.mkdir();bad=copy.deepcopy(meta)
            if nested is None:bad['identity']['implicit_conductivity'][field]='foreign'
            else:i,k=nested;bad['identity']['implicit_conductivity'][field][i][k]+=1
            (target/'BUILD.json').write_text(json.dumps(bad),encoding='utf8')
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:assert 'Foreign original implicit conductivity numerical policy' in str(error)
            else:raise AssertionError('Foreign immutable numerical policy accepted')
            q['policy_refusals'].append(dict(field=field,nested=nested,status='REFUSED_BEFORE_WORKER'));save()
        for owner,expected in [
            ('implicit_groundwater_trial','Foreign original implicit groundwater daily trial receipt policy'),
            ('implicit_conductivity_retry','Foreign explicit original implicit-conductivity retry policy'),
            ('implicit_conductivity_jacobian','Foreign exact original implicit-conductivity boundary Jacobian policy'),
            ('implicit_root_finalization','Foreign original implicit microscopic root finalization policy'),
            ('implicit_pond_availability','Foreign original implicit pond availability policy'),
            ('implicit_interception_partition','Foreign original implicit exact interception partition policy'),
            ('implicit_pond_event','Foreign original implicit pond event ownership policy')]:
            policy=meta['identity'].get(owner)
            for field in [None,*(policy or {})]:
                target=a.output/('owner-'+owner+'-'+str(field));target.mkdir();bad=copy.deepcopy(meta)
                if field is None:bad['identity'][owner]='foreign'
                else:bad['identity'][owner][field]='foreign'
                (target/'BUILD.json').write_text(json.dumps(bad),encoding='utf8')
                if owner in ('implicit_root_finalization','implicit_pond_availability','implicit_interception_partition'):
                    shutil.copyfile(build/'implicit_pond_event_state.f90',target/'implicit_pond_event_state.f90')
                if owner in ('implicit_pond_availability','implicit_interception_partition'):
                    shutil.copyfile(build/'RWU_micro.f90',target/'RWU_micro.f90')
                if owner=='implicit_interception_partition':
                    shutil.copyfile(build/'implicit_pond_availability.f90',target/'implicit_pond_availability.f90')
                try:m.validate_bundle(target,a.reference_work,project)
                except ValueError as error:assert expected in str(error),(owner,field,str(error))
                else:raise AssertionError('Foreign numerical owner accepted: '+owner+' '+str(field))
                q['numerical_owner_refusals'].append(dict(owner=owner,field=field,status='REFUSED_BEFORE_WORKER'));save()
        target=a.output/'owner-actual-pond-provider';target.mkdir()
        (target/'BUILD.json').write_bytes((build/'BUILD.json').read_bytes())
        (target/'implicit_pond_event_state.f90').write_bytes((build/'implicit_pond_event_state.f90').read_bytes()+b'\n! foreign source\n')
        try:m.validate_bundle(target,a.reference_work,project)
        except ValueError as error:assert 'Foreign actual original implicit pond event provider' in str(error)
        else:raise AssertionError('Foreign compiled pond event provider accepted')
        q['numerical_owner_refusals'].append(dict(owner='implicit_pond_event',field='actual_provider_bytes',status='REFUSED_BEFORE_WORKER'));save()
        target=a.output/'owner-actual-root-provider';target.mkdir()
        (target/'BUILD.json').write_bytes((build/'BUILD.json').read_bytes())
        shutil.copyfile(build/'implicit_pond_event_state.f90',target/'implicit_pond_event_state.f90')
        (target/'RWU_micro.f90').write_bytes((build/'RWU_micro.f90').read_bytes()+b'\n! foreign root source\n')
        try:m.validate_bundle(target,a.reference_work,project)
        except ValueError as error:assert 'Foreign actual original implicit microscopic root provider' in str(error)
        else:raise AssertionError('Foreign compiled microscopic root provider accepted')
        q['numerical_owner_refusals'].append(dict(owner='implicit_root_finalization',field='actual_provider_bytes',status='REFUSED_BEFORE_WORKER'));save()
        target=a.output/'owner-actual-availability-provider';target.mkdir()
        (target/'BUILD.json').write_bytes((build/'BUILD.json').read_bytes())
        for name in ('implicit_pond_event_state.f90','RWU_micro.f90'):shutil.copyfile(build/name,target/name)
        (target/'implicit_pond_availability.f90').write_bytes((build/'implicit_pond_availability.f90').read_bytes()+b'\n! foreign availability source\n')
        try:m.validate_bundle(target,a.reference_work,project)
        except ValueError as error:assert 'Foreign actual original implicit pond availability provider' in str(error)
        else:raise AssertionError('Foreign compiled pond availability provider accepted')
        q['numerical_owner_refusals'].append(dict(owner='implicit_pond_availability',field='actual_provider_bytes',status='REFUSED_BEFORE_WORKER'));save()
        target=a.output/'owner-actual-interception-provider';target.mkdir()
        (target/'BUILD.json').write_bytes((build/'BUILD.json').read_bytes())
        for name in ('implicit_pond_event_state.f90','RWU_micro.f90','implicit_pond_availability.f90'):shutil.copyfile(build/name,target/name)
        (target/'MOD_meteo.f90').write_bytes((build/'MOD_meteo.f90').read_bytes()+b'\n! foreign interception source\n')
        try:m.validate_bundle(target,a.reference_work,project)
        except ValueError as error:assert 'Foreign actual original implicit interception partition provider' in str(error)
        else:raise AssertionError('Foreign compiled original interception provider accepted')
        q['numerical_owner_refusals'].append(dict(owner='implicit_interception_partition',field='actual_provider_bytes',status='REFUSED_BEFORE_WORKER'));save()
        for label,changes,extra in [
            ('snow',{'SWSNOW':1},''),('frost',{'SWFROST':1},''),('aquifer',{'SWBR':1},''),
            ('tables',{'SWSOPHY':1},''),('heat',{'SWHEA':0},''),('analytic-heat',{'SWCALT':1},''),
            ('detailed',{'SWMETDETAIL':1},''),('bottom9',{'SWBOTB':9},''),('kmean7',{'SWKMEAN':7},''),
            ('alternative-model',{},'IHWCKMODEL = 2\n'),('column-model',{},'IHWCKMODEL\n2\n'),
            ('soil-database',{},"SWAP_SOILS_DB = 'foreign.db'\n")]:
            target=a.output/('descriptor-'+label);shutil.copytree(inputs,target)
            path=target/'swap.swp';text=path.read_text(encoding='cp1252')
            for key,value in changes.items():text=assignment(text,key,value)
            path.write_text(text+'\n'+extra,encoding='cp1252')
            try:m.e.load(target,original_output=True)
            except ValueError as error:q['descriptor_refusals'].append(dict(label=label,error=str(error),status='REFUSED_BEFORE_WORKER'));save()
            else:raise AssertionError('Unqualified implicit domain accepted: '+label)
        target=a.output/'descriptor-examined-ksat';shutil.copytree(inputs,target);path=target/'swap.swp'
        text=path.read_text(encoding='cp1252')
        def unsupported(match):
            names=match[1].split();rows=[]
            for line in match[2].splitlines():
                fields=line.split();fields[names.index('KSATEXM')]=str(1.1*float(fields[names.index('KSATFIT')]))
                rows.append(' '.join(fields))
            return match[1]+'\n'.join(rows)+'\n* End of table'
        text,count=re.subn(r'(?mi)^([ \t]*ORES[ \t]+OSAT[^\r\n]*\n)(.*?)^\* End of table',unsupported,text,count=1,flags=re.S);assert count==1
        path.write_text(text,encoding='cp1252')
        try:m.e.load(target,original_output=True)
        except ValueError as error:
            assert 'does not implement examined-Ksat interpolation' in str(error)
            q['descriptor_refusals'].append(dict(label='examined-ksat',error=str(error),status='REFUSED_BEFORE_WORKER'));save()
        else:raise AssertionError('Original unsupported examined-Ksat derivative accepted')
        source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
        from implicit_groundwater_state import enabled as implicit_groundwater,domain
        attacks=['magic','truncated','trailing','negative-day','changed-counter','witness','nonfinite']
        if implicit_groundwater(project):
            attacks += ['hydraulic-domain-'+str(i) for i in range(13)]
            attacks += ['hydraulic-nan-'+str(i) for i in (0,project.nodes,2*project.nodes,3*project.nodes+1,4*project.nodes+2,5*project.nodes+2,5*project.nodes+3)]
            attacks += ['hydraulic-head','hydraulic-level','hydraulic-volume']
        for attack in attacks:
            target=a.output/('native-'+attack);target.mkdir();origin=target/'origin'
            receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);path=origin/'macro.bin';raw=bytearray(path.read_bytes())
            if attack.startswith('hydraulic-'):
                header=struct.pack('<13i',*domain(project));assert raw.count(header+header)==1
                pos=raw.index(header+header);offset=pos+104
                if attack.startswith('hydraulic-domain-'):
                    i=int(attack.rsplit('-',1)[1])
                    for at in (pos,pos+52):struct.pack_into('<i',raw,at+4*i,domain(project)[i]+1)
                else:
                    i=int(attack.rsplit('-',1)[1]) if attack.startswith('hydraulic-nan-') else {'hydraulic-head':0,'hydraulic-level':5*project.nodes+2,'hydraulic-volume':5*project.nodes+3}[attack]
                    value=float('nan') if attack.startswith('hydraulic-nan-') else struct.unpack_from('<d',raw,offset+8*i)[0]+1
                    struct.pack_into('<d',raw,offset+8*i,value)
            elif attack=='magic':raw[:8]=b'FOREIGN1'
            elif attack=='truncated':raw=raw[:-1]
            elif attack=='trailing':raw+=b'x'
            else:
                candidates=[];prefix=struct.pack('<2i',1,project.nodes);pos=raw.find(prefix)
                while pos>=0:
                    if pos+160<=len(raw):
                        header=struct.unpack_from('<20i',raw,pos)
                        if header[3]>100 and pos+160+16*header[3]<=len(raw) and raw[pos:pos+80]==raw[pos+80:pos+160]:candidates.append((pos,header))
                    pos=raw.find(prefix,pos+1)
                assert len(candidates)==1,candidates
                pos,header=candidates[0]
                if attack=='nonfinite':
                    for offset in (pos+160,pos+160+8*header[3]):struct.pack_into('<d',raw,offset,float('nan'))
                else:
                    index=6 if attack=='negative-day' else 7
                    value=-1 if attack=='negative-day' else header[index]+1
                    struct.pack_into('<i',raw,pos+4*index,value)
                    if attack!='witness':struct.pack_into('<i',raw,pos+80+4*index,value)
            path.write_bytes(raw)
            try:
                with contextlib.ExitStack() as stack:
                    m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,[m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
            except (ValueError,RuntimeError) as error:
                diagnostic='\n'.join(p.read_text(encoding='utf8',errors='replace') for p in target.rglob('donor.stderr'))
                assert ('ERROR STOP' in diagnostic or 'native' in str(error).lower()) and not list(target.glob('accepted-*.zip')),(attack,str(error),diagnostic)
                q['native_refusals'].append(dict(attack=attack,error=str(error),diagnostic=diagnostic,status='REFUSED'));save()
            else:raise AssertionError('Corrupt native state accepted: '+attack)
            assert m.sha(source)==digest
        q['transactions']=transactions(build,a.reference_work,project,full,a.output/'active');save()
        # A real input-derived foreign numerical origin must refuse even when
        # native adoption is explicitly enabled. No checkpoint is rewritten.
        foreign=a.output/'foreign-input';shutil.copytree(inputs,foreign);path=foreign/'swap.swp'
        path.write_text(assignment(path.read_text(encoding='cp1252'),'SWKIMPL',0),encoding='cp1252')
        other=m.e.load(foreign,original_output=True)
        try:CoupledDailyColumn(build,a.reference_work,a.output/'foreign-adoption',other,'implicit',origin=source,day=4,adopt_native=True)
        except ValueError as error:
            assert 'Foreign original implicit conductivity numerical policy' in str(error)
            q['foreign_numerical_adoption']=dict(status='REFUSED',error=str(error),origin_unchanged=m.sha(source)==digest)
        else:raise AssertionError('Foreign numerical origin accepted')
        q['status']='IMPLICIT_CONDUCTIVITY_NUMERICAL_NATIVE_TRANSACTION_DOMAIN_PASS';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
