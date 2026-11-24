"""Actual numerical-policy binding, compiled native refusals and transactions."""
import argparse,copy,json,re,struct,subprocess,sys,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
from ria12_water_polish_source import complete_inverse,git,SHA
from ria12_water_polish import POLICY,TIME_POLICY
from explicit_bottom9_runtime import m
from ria12_corrected_native import native
from daily_coupling import CoupledDailyColumn
from original_output_controls import physical

def main():
    p=argparse.ArgumentParser()
    for name in ('profile','reference-work','reference-samples','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--current-postimage',type=Path)
    a=p.parse_args();complete_inverse();head=git('rev-parse','HEAD').decode().strip()
    q=json.loads((a.profile/'RESULT.json').read_text());assert q['days']==35 and q['status']=='ACTUAL_RIA_ADDITIONAL_WATER_POLISH35_GLOBAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    build=Path(q['build_root']);trajectory=a.profile/'trajectory';compiler=q['actual_compiler_source']
    if a.current_postimage:
        current=json.loads((a.current_postimage/'RESULT.json').read_text())
        assert current['status']=='CURRENT_RIA_POLISH_ALL_GENERATED_COMPILED_NATIVE_PREFIX_COLD_EXTERNAL_PASS_NOT_ADMITTED'
        assert current['original_RESULT_sha256']==SHA((a.profile/'RESULT.json').read_bytes())
        build=Path(current['actual_build_root']);trajectory=a.current_postimage/'prefix6';compiler=current['actual_source']
    assert not git('diff',compiler,head,'--','app','src','tools','reference')
    project=m.e.load(q['input_root'],original_output=True,time_step_policy=TIME_POLICY,water_polish_policy=POLICY)
    meta,_=m.validate_bundle(build,a.reference_work,project);a.output.mkdir()
    record=dict(status='RUNNING_RIA_POLISH_CONTROLS_NOT_ADMITTED',actual_source=head,actual_compiler_source=compiler,kind=q['kind'],optimization=q['optimization'],actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),compiled_refusals=[],policy_refusals=[],accepted_mutant_model_days=0,canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
    save()
    try:
        source=trajectory/'accepted-column-1-day-2.zip';digest=SHA(source.read_bytes());data=m.rows(trajectory);row=data[1]
        with zipfile.ZipFile(source) as z:good=z.read('macro.bin')
        parameters=(a.reference_samples/'original-parameters.bin').read_bytes();native(good,row,meta,parameters)
        def run(label,raw):
            root=a.output/label;root.mkdir();origin=root/'origin';receipt=m.h.verify_checkpoint(source,2,meta['binding'],origin)
            (origin/'macro.bin').write_bytes(raw)
            directory=root/'original';m.h.prepare_column(Path(q['input_root']),directory,m.h.ColumnStart('original',2,origin,receipt),True,True,project)
            result=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=directory,input=b'0 0\n',capture_output=True,timeout=20)
            (root/'donor.stdout').write_bytes(result.stdout);(root/'donor.stderr').write_bytes(result.stderr)
            assert b'HYBRID_DAY_RETURN' not in result.stdout and SHA(source.read_bytes())==digest
            return result
        positive=run('own-positive',good);assert positive.returncode in (0,100) and b'HYBRID_READY' in positive.stdout and not positive.stderr
        expected=(2,project.nodes,2,int(q['kind']=='cde'),6,1,0,0,16,4,12,12);footer=8*len(expected);at=len(good)-footer-704
        assert struct.unpack_from('<24i',good,len(good)-footer)==expected+expected
        attacks=[('truncated',good[:-1]),('trailing',good+b'X'),('missing-domain',good[:at]),('foreign-kind', (b'S5RKW001' if q['kind']=='cde' else b'S5RKC001')+good[8:])]
        for both in (False,True):
            for index,value in enumerate(expected):
                raw=bytearray(good);struct.pack_into('<i',raw,len(raw)-footer+4*index,value+1)
                if both:struct.pack_into('<i',raw,len(raw)-footer+4*(len(expected)+index),value+1)
                attacks.append((f'domain-{index}-both{both}',bytes(raw)))
        for index in (0,3,8,19):
            for both in (False,True):
                raw=bytearray(good);raw[at+16*index]^=1
                if both:raw[at+352+16*index]^=1
                attacks.append((f'parameter-{index}-both{both}',bytes(raw)))
        raw=bytearray(good);nan=(1|32767<<112).to_bytes(16,'little');raw[at:at+16]=nan;raw[at+352:at+368]=nan;attacks.append(('nonfinite',bytes(raw)))
        for label,raw in attacks:
            result=run(label,raw);assert result.returncode not in (0,100) and b'HYBRID_READY' not in result.stdout and b'ERROR STOP' in result.stderr,(label,result.stderr)
            try:native(raw,row,meta,parameters)
            except (ValueError,AssertionError,struct.error):pass
            else:raise AssertionError('Typed reader accepted '+label)
            record['compiled_refusals'].append(dict(attack=label,mutant_sha256=SHA(raw),returncode=result.returncode,typed_refusal=True));save()
        for key,value in [('water_polish_policy','strict-water-always-polish-v1'),('time_step_policy','original-adaptive-day-seed-v1'),('ria12_water_polish_source','0'*64)]:
            binding=copy.deepcopy(meta['binding']);assert key in binding['build'];binding['build'][key]=value;out=a.output/('foreign-binding-'+key)
            try:m.h.verify_checkpoint(source,2,binding,out)
            except ValueError as error:assert str(error)=='Accepted checkpoint identity, day or content does not match'
            else:raise AssertionError('Foreign policy binding accepted')
            assert not out.exists();record['policy_refusals'].append(dict(field=key,refused_before_extraction=True));save()
        try:m.e.load(q['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1',water_polish_policy=POLICY)
        except ValueError as error:assert 'physical-iteration growth v2' in str(error)
        else:raise AssertionError('Incompatible time policy accepted')
        record['input_scope_refusals']=[]
        for key,value in [('SWDRA','0'),('SWBOTB','5'),('IHWCKMODEL','1 1'),('SWHYST','1'),('SWHEA','1'),('SWSOLU','2'),('FLPRINTDT','.TRUE.'),('SWMACRO','1')]:
            inputs=a.output/('invalid-input-'+key);inputs.mkdir()
            for path in Path(q['input_root']).iterdir():
                if not path.is_file():continue
                raw=path.read_bytes()
                if path.name=='swap.swp':
                    raw,n=re.subn(rb'(?mi)^([ \t]*'+key.encode()+rb'[ \t]*=[ \t]*)[^!\r\n]*',lambda match:match[1]+value.encode(),raw)
                    assert n==1,(key,n)
                (inputs/path.name).write_bytes(raw)
            try:m.e.load(inputs,original_output=True,time_step_policy=TIME_POLICY,water_polish_policy=POLICY)
            except ValueError as error:record['input_scope_refusals'].append(dict(selector=key,diagnostic=str(error)))
            else:raise AssertionError('Foreign numerical scope accepted '+key)
            save()
        original=m.rows(a.profile/'trajectory');origin=trajectory/'accepted-column-1-day-4.zip';originsha=SHA(origin.read_bytes())
        column=CoupledDailyColumn(build,a.reference_work,a.output/'external',project,'original-output',origin=origin,day=4,adopt_native=True)
        trial=column.prepare();assert physical(trial)==m.physical([original[4]]);column.discard(trial);assert column.day==4
        replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
        recovered=CoupledDailyColumn(build,a.reference_work,a.output/'recovered',project,'original-output',origin=column.checkpoint,day=5)
        nextday=recovered.prepare();assert physical(nextday)==m.physical([original[5]]);recovered.discard(nextday)
        assert SHA(origin.read_bytes())==originsha
        record['transactions']=dict(prepares=3,commits=1,discard_preserved_day=True,replay_exact=True,recovery_exact=True,origin_unchanged=True)
        complete_inverse();assert git('rev-parse','HEAD').decode().strip()==head
        record['status']='RIA_POLISH_COMPILED_NATIVE_POLICY_BINDING_AND_EXTERNAL_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:record.update(status='FAILED_RIA_POLISH_CONTROLS_NOT_ADMITTED',error=repr(error));raise
    finally:save()
    print(record['status'],q['kind'],q['optimization'],len(record['compiled_refusals']))
if __name__=='__main__':main()
