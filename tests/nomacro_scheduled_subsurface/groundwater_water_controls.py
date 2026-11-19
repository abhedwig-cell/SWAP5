"""Actual public restart, native corruption and transactions on water GW carry."""
from pathlib import Path
import argparse,contextlib,copy,json,struct,subprocess,sys,time,zipfile
import groundwater_water_runtime as runtime
from groundwater_water_output import metadata
from implicit_groundwater_state import domain
from age_groundwater_controls import transactions
from original_output_files import compare

m=runtime.m;ROOT=runtime.ROOT


def main():
    p=argparse.ArgumentParser()
    for name in ('reference-work','profile-root','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir()
    previous=json.loads((a.profile_root/'RESULT.json').read_text(encoding='utf8'));inputs=Path(previous['input_root']);project=m.e.load(inputs,original_output=True);build=a.output/'build';q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),prior_profile=str(a.profile_root),native_refusals=[],policy_refusals=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(inputs),'--original-output','--reference-work',str(a.reference_work)]
        def call(label,extra):
            cmd=[*command,*map(str,extra)];start=time.monotonic();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180);(a.output/(label+'.stdout')).write_text(r.stdout,encoding='utf8');(a.output/(label+'.stderr')).write_text(r.stderr,encoding='utf8');r.check_returncode();return dict(command=cmd,returncode=r.returncode,seconds=time.monotonic()-start)
        q['build']=call('build',['--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]);save()
        # A guard-only source delta requires a real current build/identity.
        # Inherit full periods only after exact emitted-source and native proof.
        before=Path(previous['build_root']);names={p.name for p in build.glob('*.f90')};assert names=={p.name for p in before.glob('*.f90')}
        q['unchanged_actual_fortran']={name:m.sha(build/name) for name in sorted(names)}
        for name in names:assert (build/name).read_bytes()==(before/name).read_bytes(),name
        q['public_warm']=call('warm',['--build-bundle',build,'--days',10,'--checkpoint-at',4,'--output',a.output/'warm']);save()
        source=a.output/'warm/accepted-column-1-day-4.zip';digest=m.sha(source)
        q['public_cold']=call('cold',['--build-bundle',build,'--days',9,'--checkpoint-at',9,'--restart',source,'--restart-day',4,'--output',a.output/'cold']);save()
        warm=m.rows(a.output/'warm');cold=m.rows(a.output/'cold');old=m.rows(a.profile_root/'trajectory');m.check(warm);m.check(cold)
        assert m.physical(warm)==m.physical(old[:10]);assert m.physical(cold)==m.physical(warm[4:9])
        with zipfile.ZipFile(a.output/'cold/accepted-column-1-day-9.zip') as x,zipfile.ZipFile(a.profile_root/'trajectory/accepted-column-1-day-9.zip') as y:
            for name in ('macro.bin','result.end'):assert x.read(name)==y.read(name),name
        q['public_output']=compare(a.output/'warm/original',a.output/'cold/original',metadata(project),4,9,project.start_date);assert m.sha(source)==digest
        q['public_physical_complete_native_exact']=True;save()
        # Active discard/replay/accept/recovery uses the new public warm origin.
        q['transactions']=transactions(build,a.reference_work,project,a.output/'warm',a.output/'active');save()
        meta,case=m.validate_bundle(build,a.reference_work,project);source=a.output/'warm/accepted-column-1-day-4.zip';digest=m.sha(source)
        attacks=['magic','truncated','trailing','node-count','native-clock','negative-canopy']+['hydraulic-domain-'+str(i) for i in range(13)]+['hydraulic-nan-'+str(i) for i in (0,project.nodes,2*project.nodes,3*project.nodes+1,4*project.nodes+2,5*project.nodes+2,5*project.nodes+3)]+['hydraulic-head','hydraulic-level','hydraulic-volume']+['calendar-'+str(i) for i in (4,5,6,7,8,9,10,11,18,19)]+['calendar-witness','calendar-nan','calendar-value-witness']
        for attack in attacks:
            target=a.output/('native-'+attack);target.mkdir();origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);path=origin/'macro.bin';raw=bytearray(path.read_bytes());header=struct.pack('<13i',*domain(project));assert raw.count(header+header)==1;pos=raw.index(header+header);offset=pos+104;calendar=offset+8*(5*project.nodes+4)
            if attack=='magic':raw[:8]=b'FOREIGN1'
            elif attack=='truncated':raw=raw[:-1]
            elif attack=='trailing':raw+=b'x'
            elif attack=='node-count':struct.pack_into('<i',raw,8,project.nodes+1)
            elif attack=='native-clock':struct.pack_into('<d',raw,12,project.start_clock+5)
            elif attack=='negative-canopy':struct.pack_into('<d',raw,28,-1.)
            elif attack.startswith('hydraulic-domain-'):
                i=int(attack.rsplit('-',1)[1])
                for at in (pos,pos+52):struct.pack_into('<i',raw,at+4*i,domain(project)[i]+1)
            elif attack.startswith('hydraulic-'):
                i=int(attack.rsplit('-',1)[1]) if attack.startswith('hydraulic-nan-') else {'hydraulic-head':0,'hydraulic-level':5*project.nodes+2,'hydraulic-volume':5*project.nodes+3}[attack]
                struct.pack_into('<d',raw,offset+8*i,float('nan') if attack.startswith('hydraulic-nan-') else struct.unpack_from('<d',raw,offset+8*i)[0]+1)
            elif attack in ('calendar-nan','calendar-value-witness'):
                count=struct.unpack_from('<i',raw,calendar+12)[0];struct.pack_into('<d',raw,calendar+160,float('nan') if attack=='calendar-nan' else 123.)
                if attack=='calendar-nan':struct.pack_into('<d',raw,calendar+160+8*count,float('nan'))
            else:
                i=6 if attack=='calendar-witness' else int(attack.rsplit('-',1)[1]);value=struct.unpack_from('<i',raw,calendar+4*i)[0]+1
                if i in (9,10):value=2147483647
                for at in ([calendar] if attack=='calendar-witness' else [calendar,calendar+80]):struct.pack_into('<i',raw,at+4*i,value)
            path.write_bytes(raw)
            try:
                with contextlib.ExitStack() as stack:m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,[m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
            except (ValueError,RuntimeError) as error:
                diagnostic='\n'.join(v.read_text(encoding='utf8',errors='replace') for v in target.rglob('donor.stderr'));assert ('ERROR STOP' in diagnostic or 'native' in str(error).lower() or 'receipt' in str(error).lower()) and not list(target.glob('accepted-*.zip')),(attack,str(error),diagnostic);q['native_refusals'].append(dict(attack=attack,status='REFUSED',error=str(error),diagnostic=diagnostic));save()
            else:raise AssertionError('Corrupted groundwater water native accepted: '+attack)
            assert m.sha(source)==digest
        for key in ('original_output','groundwater_native_state','implicit_groundwater_trial'):
            bad=copy.deepcopy(meta);bad['identity'][key]={'policy':'foreign'};target=a.output/('policy-'+key);target.mkdir();(target/'BUILD.json').write_text(json.dumps(bad),encoding='utf8')
            try:m.validate_bundle(target,a.reference_work,project)
            except ValueError as error:assert 'Foreign' in str(error);q['policy_refusals'].append(dict(field=key,status='REFUSED_BEFORE_WORKER',error=str(error)))
            else:raise AssertionError('Foreign groundwater water identity accepted')
        q['status']='ACTUAL_GROUNDWATER_WATER_PUBLIC_NATIVE_TRANSACTION_POLICY_PASS';print(q['status'],len(q['native_refusals']),flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
