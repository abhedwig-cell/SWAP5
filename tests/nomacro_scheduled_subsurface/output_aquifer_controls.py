"""Hysteresis domain, inherited output readers and actual external transactions."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import shutil
import zipfile
import output_aquifer_runtime as matrix
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical
from original_output_aquifer import magic,metadata,selection

m=matrix.m


def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    attacks=['old002','old003','old004','old005','foreign-kind','truncated','trailing','header-witness','shape','policy','negative-day','foreign-day','negative-counter','changed-counter','print-counter','zero-pointer','overflow-pointer','future-pointer','flag-domain','short-flag','step-flag','nonfinite','value-witness','negative-period','ordinary-water','ordinary-cde','ordinary-age','domain-version','domain-shape','domain-macro','domain-mode','domain-kind','domain-witness','domain-aquifer','domain-drainage']
    if project.solute:attacks+=['cde-header-witness','cde-shape','cde-value-witness','cde-nonfinite','cde-negative-initial']
    attacks += ['aq-'+name for name in ('concentration','capacity','stock','soil-cumulative','surface-cumulative','decay-cumulative','count','nonfinite','truncated')]
    checks=[]
    for attack in attacks:
        target=out/attack;target.mkdir(parents=True);origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        path=origin/'macro.bin';raw=bytearray(path.read_bytes());assert raw[:8]==magic(project)
        starts=[];prefix=struct.pack('<3i',1,project.nodes,1);pos=raw.find(prefix)
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
        if attack.startswith('aq-'):
            state=m.rows(full)[3]['aquifer_state'];needle=struct.pack('<6dq',*state[:6],int(state[6]));assert raw.count(needle)==1
            offset=raw.index(needle);values=state.copy();label=attack[3:]
            if label=='truncated':raw=raw[:offset+8]
            else:
                index={'concentration':0,'capacity':1,'stock':2,'soil-cumulative':3,'surface-cumulative':4,'decay-cumulative':5,'count':6,'nonfinite':0}[label]
                values[index]=float('nan') if label=='nonfinite' else values[index]+1
                raw[offset:offset+len(needle)]=struct.pack('<6dq',*values[:6],int(values[6]))
        elif attack.startswith('domain-'):
            mode=selection(project)['swhyst'];domain=struct.pack('<7i',1,project.nodes,0,1,1,mode,1);assert raw.count(domain+domain)==1;d=raw.index(domain+domain)
            index={'domain-version':0,'domain-shape':1,'domain-macro':2,'domain-mode':5,'domain-kind':3,'domain-witness':0,'domain-aquifer':4,'domain-drainage':6}[attack]
            previous=struct.unpack_from('<i',raw,d+4*index)[0];changed=(3-previous) if attack=='domain-mode' else previous+1
            struct.pack_into('<i',raw,d+4*index,changed)
            if attack!='domain-witness':struct.pack_into('<i',raw,d+28+4*index,changed)
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
            assert ('ERROR STOP' in diagnostic or 'Restored aquifer state differs' in str(error)) and not list(target.glob('accepted-*.zip')),(attack,diagnostic,str(error))
            checks.append(dict(attack=attack,status='REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Corrupt original-output native accepted: '+attack)
        assert m.sha(source)==digest
    return checks


def transactions(build,reference,project,full,out):
    out.mkdir();data=m.rows(full);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'original-output',origin=source,day=4,adopt_native=True)
    trial=column.prepare();assert physical(trial)==m.physical([data[4]])
    assert any(abs(v)>0 for v in trial.budget['aquifer_ledger_mg_cm2']),'Aquifer source/exports not active'
    column.discard(trial);assert column.day==4
    replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'original-output',origin=column.checkpoint,day=5)
    endpoint=recovered.prepare();assert physical(endpoint)==m.physical([data[5]]);recovered.discard(endpoint)
    assert m.sha(source)==digest
    return dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();project=m.e.load(a.profile_root/'input',original_output=True);build=a.profile_root/'build';full=a.profile_root/'trajectory';q=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'),native_refusals=[],policy_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        q['native_refusals']=native(build,a.reference_work,project,full,a.output/'native');save()
        q['transactions']=transactions(build,a.reference_work,project,full,a.output/'active')
        for field in ('policy','native_codec','source_sha256','domain_source_sha256','original_hysteresis_sha256','ordinary_owner_sha256','vector_catalog_correction_sha256','cde_output_state_sha256','aquifer_owner','selector_bridge_policy'):
            target=a.output/('policy-'+field);target.mkdir();bad=json.loads((build/'BUILD.json').read_text());bad['identity']['original_output'][field]='foreign';(target/'BUILD.json').write_text(json.dumps(bad))
            for helper in ('mod_subsurface_solute_source.f90','mod_aquifer_solute_reservoir.f90'):
                if (build/helper).exists():shutil.copyfile(build/helper,target/helper)
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:assert 'Foreign original output policy' in str(error),str(error)
            else:raise AssertionError('Foreign original aquifer output policy accepted')
            q['policy_refusals'].append(dict(field=field,status='REFUSED'))
        q['status']='ORIGINAL_OUTPUT_AQUIFER_ACTUAL_NATIVE_ACTIVE_AND_POLICY_REFUSALS_PASS';print(q['status'],len(q['native_refusals']),flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
