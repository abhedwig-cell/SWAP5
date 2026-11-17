"""Real schedule004 native readers and active external transaction controls."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import age_schedule as s
from age_calendar_controls import transactions

m=s.m


def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project)
    source=full/'accepted-column-1-day-4.zip';digest=m.sha(source);checks=[]
    attacks=('old002','old003','truncated','header-witness','shape','policy','negative-day','foreign-day',
             'negative-counter','changed-counter','print-counter','zero-pointer','overflow-pointer',
             'foreign-pointer','flag-domain','foreign-short-flag','nonfinite-value','value-witness',
             'negative-period','foreign-age-clock')
    for attack in attacks:
        target=out/attack;target.mkdir(parents=True);origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        path=origin/'macro.bin';raw=bytearray(path.read_bytes());assert raw[:8]==b'S5AGE004'
        age_bytes=24*project.nodes+8*26+20+128;prefix=struct.pack('<3i',1,project.nodes,1);start=raw.find(prefix)
        while start>=0:
            header=list(struct.unpack_from('<20i',raw,start));nreal=header[3]
            if start+160+16*nreal==len(raw)-age_bytes and header==list(struct.unpack_from('<20i',raw,start+80)):break
            start=raw.find(prefix,start+1)
        assert start>0
        def hi(index,value,witness=True):
            struct.pack_into('<i',raw,start+4*index,value)
            if witness:struct.pack_into('<i',raw,start+80+4*index,value)
        def value(index,v,witness=True):
            struct.pack_into('<d',raw,start+160+8*index,v)
            if witness:struct.pack_into('<d',raw,start+160+8*nreal+8*index,v)
        if attack in ('old002','old003'):raw[:8]=('S5AGE'+attack[-3:]).encode()
        elif attack=='truncated':raw=raw[:-1]
        elif attack=='header-witness':hi(7,header[7]+1,False)
        elif attack=='shape':hi(1,project.nodes+1)
        elif attack=='policy':hi(4,header[4]+1)
        elif attack=='negative-day':hi(6,-1)
        elif attack=='foreign-day':hi(6,5)
        elif attack=='negative-counter':hi(7,-1)
        elif attack=='changed-counter':hi(7,header[7]+1 if header[4]==0 else header[4])
        elif attack=='print-counter':hi(8,2)
        elif attack=='zero-pointer':hi(9,0)
        elif attack=='overflow-pointer':hi(9,2147483647)
        elif attack=='foreign-pointer':hi(9,header[9]+1)
        elif attack=='flag-domain':hi(12,2)
        elif attack=='foreign-short-flag':hi(18,1)
        elif attack=='nonfinite-value':value(0,float('nan'))
        elif attack=='value-witness':value(0,123.,False)
        elif attack=='negative-period':value(nreal-1,-1.)
        elif attack=='foreign-age-clock':struct.pack_into('<i',raw,len(raw)-20,5)
        path.write_bytes(raw)
        try:
            with contextlib.ExitStack() as stack:
                m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                    [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            diagnostic='\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
            assert any(token in (diagnostic+' '+str(error)).lower() for token in ('calendar','checkpoint','age','original schedule','original zero-period','original output','original regular output','original interval date')),(attack,diagnostic,str(error))
            assert not list(target.glob('accepted-*.zip'));checks.append(dict(attack=attack,status='REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Corrupt native004 schedule accepted: '+attack)
        assert m.sha(source)==digest
    return checks


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','matrix','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();result=dict(status='RUNNING',profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    try:
        for mode,kind in [('monthly','subsurface-interval'),('explicit','surface'),('combined','plain')]:
            for opt in ('O0','O2'):
                name=mode+'-'+kind+'-'+opt;root=a.matrix/name;project=m.e.load(root/'input');out=a.output/name;out.mkdir()
                checks=native(root/'build',a.reference_work,project,root/'short',out/'native')
                active=transactions(root/'build',a.reference_work,project,root/'short',out/'active') if kind!='plain' else None
                meta,_=m.validate_bundle(root/'build',a.reference_work,project);policy=[]
                for field,value in [('policy','foreign'),('regular_owner_sha256','0'*64),('source_sha256','0'*64)]:
                    target=out/('policy-'+field);target.mkdir();bad=json.loads((root/'build/BUILD.json').read_text());bad['identity']['conserved_original_age']['output_schedule'][field]=value;(target/'BUILD.json').write_text(json.dumps(bad))
                    try:m.validate_bundle(target,a.reference_work,project)
                    except ValueError as error:assert 'Foreign original age source/state policy' in str(error),str(error)
                    else:raise AssertionError('Foreign schedule policy accepted')
                    policy.append(dict(field=field,status='REFUSED'))
                result['profiles'][name]=dict(native_refusals=checks,transactions=active,policy_refusals=policy);save();print(name,'SCHEDULE004_NATIVE_ACTIVE_POLICY_CONTROLS_PASS',flush=True)
        result['status']='ORIGINAL_AGE_SCHEDULE004_NATIVE_ACTIVE_POLICY_AND_ISOLATION_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
