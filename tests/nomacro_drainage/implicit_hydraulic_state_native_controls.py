"""Real compiled consumer refusals for the appended static hydraulic domain."""
import argparse,contextlib,hashlib,json,struct,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from explicit_bottom9_runtime import m
from implicit_hydraulic_state import selected,header,native_tag,validate_candidate


def main():
    p=argparse.ArgumentParser()
    for n in ['profile','output','reference-work']:p.add_argument('--'+n,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();q=json.loads((a.profile/'RESULT.json').read_text());build=Path(q['build_root'])
    record=json.loads((build/'BUILD.json').read_text());project=m.e.load(q['input_root'],original_output=True,time_step_policy=record['project']['time_step_policy'])
    meta,case=m.validate_bundle(build,a.reference_work,project);item=selected(project);values=header(item,project.nodes);size=4*len(values)
    source=a.profile/'trajectory/accepted-column-1-day-4.zip';source_hash=m.sha(source);checks=[]
    result=dict(status='RUNNING_COMPILED_IMPLICIT_HYDRAULIC_NATIVE_CONTROLS',actual_producer_source=q['actual_source'],actual_BUILD_sha256=m.sha(build/'BUILD.json'),model_period_replays=0,checks=checks)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    try:
        attacks=['missing-extension','truncated-extension','foreign-tag','trailing-byte','single-witness']+['field-'+str(i) for i in range(len(values))]
        for attack in attacks:
            target=a.output/attack;target.mkdir();origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
            path=origin/'macro.bin';raw=bytearray(path.read_bytes());validate_candidate(raw,project);pos=len(raw)-(8+2*size);assert raw[pos:pos+8]==native_tag(item)
            if attack=='missing-extension':raw=raw[:pos]
            elif attack=='truncated-extension':raw=raw[:-1]
            elif attack=='foreign-tag':raw[pos:pos+8]=b'S5IHX999'
            elif attack=='trailing-byte':raw+=b'x'
            elif attack=='single-witness':struct.pack_into('<i',raw,pos+8+size,values[0]+1)
            else:
                i=int(attack.split('-')[1])
                for offset in (pos+8,pos+8+size):struct.pack_into('<i',raw,offset+4*i,values[i]+1)
            mutated=bytes(raw);path.write_bytes(mutated)
            try:validate_candidate(mutated,project)
            except ValueError:python_refused=True
            else:raise AssertionError('Python candidate accepted foreign static hydraulic domain')
            try:
                with contextlib.ExitStack() as stack:
                    m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                        [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
            except (ValueError,RuntimeError) as error:
                stderr='\n'.join(p.read_text(encoding='utf8',errors='replace') for p in target.rglob('donor.stderr'))
                stdout='\n'.join(p.read_text(encoding='utf8',errors='replace') for p in target.rglob('donor.stdout'))
                assert 'ERROR STOP' in stderr and 'READY' not in stdout and not list(target.rglob('accepted-*.zip')),(attack,stderr,stdout)
                checks.append(dict(attack=attack,python_refused=python_refused,compiled_consumer_refused_before_ready=True,diagnostic=stderr,error=str(error),actual_mutant_sha256=hashlib.sha256(mutated).hexdigest()))
            else:raise AssertionError('Compiled original worker accepted foreign static hydraulic domain')
            assert m.sha(source)==source_hash;save()
        result['status']='ACTUAL_COMPILED_AND_PYTHON_IMPLICIT_HYDRAULIC_NATIVE_REFUSALS_BEFORE_READY_PASS'
    except Exception as error:result.update(status='FAILED_COMPILED_IMPLICIT_HYDRAULIC_NATIVE_CONTROLS',error=repr(error));raise
    finally:save()
    print(result['status'],len(checks),flush=True)


if __name__=='__main__':main()
