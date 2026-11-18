"""Actual new native readers, output-policy binding and external transactions."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import shutil
import original_output_matrix as matrix
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical
from original_output import magic

m=matrix.m


def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';digest=m.sha(source)
    attacks=['old002','old003','old004','old005','foreign-kind','truncated','trailing','header-witness','shape','policy','negative-day','foreign-day','negative-counter','changed-counter','print-counter','zero-pointer','overflow-pointer','future-pointer','flag-domain','short-flag','step-flag','nonfinite','value-witness','negative-period']
    if project.solute:attacks+=['cde-header-witness','cde-shape','cde-value-witness','cde-nonfinite','cde-negative-initial']
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
        if attack.startswith('old'):raw[:8]=('S5AGE'+attack[-3:]).encode()
        elif attack=='foreign-kind':raw[:8]=b'S5IOW001' if project.solute or project.age else b'S5IOC001'
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
    if project.solute:assert trial.budget['solute_ledger_mg_cm2'][3]>0
    column.discard(trial);assert column.day==4
    replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'original-output',origin=column.checkpoint,day=5)
    endpoint=recovered.prepare();assert physical(endpoint)==m.physical([data[5]]);recovered.discard(endpoint)
    assert m.sha(source)==digest
    return dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--reference-work',type=Path,required=True);p.add_argument('--matrix-prefix',required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'));a=p.parse_args();a.output.mkdir()
    q=dict(status='RUNNING',profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for case in ('water-nprint3','cde-solbal-csv3','age-csv3','age-perstep-monthly'):
            for opt in ((a.optimization,) if a.optimization else ('O0','O2')):
                name=case+'-'+opt;root=Path(a.matrix_prefix+name);project=m.e.load(root/'input',original_output=True);out=a.output/name;out.mkdir()
                checks=native(root/'build',a.reference_work,project,root/'trajectory',out/'native')
                active=transactions(root/'build',a.reference_work,project,root/'trajectory',out/'active')
                policy=[]
                for field in ('policy','native_codec','source_sha256','vector_catalog_correction_sha256','cde_output_state_sha256'):
                    target=out/('policy-'+field);target.mkdir();bad=json.loads((root/'build/BUILD.json').read_text());bad['identity']['original_output'][field]='foreign';(target/'BUILD.json').write_text(json.dumps(bad))
                    # Earlier accepted chemical owners validate their actual
                    # helper before this new output-policy boundary is reached.
                    for helper in ('mod_subsurface_solute_source.f90','mod_aquifer_solute_reservoir.f90'):
                        if (root/'build'/helper).exists():shutil.copyfile(root/'build'/helper,target/helper)
                    try:m.validate_bundle(target,a.reference_work,project)
                    except ValueError as error:assert 'Foreign original output policy' in str(error),str(error)
                    else:raise AssertionError('Foreign original output policy accepted')
                    policy.append(dict(field=field,status='REFUSED'))
                q['profiles'][name]=dict(native_refusals=checks,transactions=active,policy_refusals=policy);save();print(name,'ORIGINAL_OUTPUT_NATIVE_ACTIVE_POLICY_PASS',flush=True)
        q['status']='ORIGINAL_OUTPUT_NATIVE_ACTIVE_POLICY_PASS';q['contexts']=len(q['profiles'])
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
