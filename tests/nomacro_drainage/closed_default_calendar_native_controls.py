"""Real original model1 calendar readers: own positive and zero-day corruptions."""
import argparse,importlib,json,subprocess,zipfile
from pathlib import Path
from closed_default_calendar_feedback import R,SHA,m,git

READERS={'S5IOW001':'original_output_controls','S5IHW001':'output_hysteresis_controls',
         'S5CIC001':'cde_interval_controls','S5CIH001':'cde_interval_controls'}


def controls(profile,reference,out):
    q=json.loads((profile/'RESULT.json').read_text())
    assert q['status']=='ACTUAL_CLOSED_DEFAULT_CALENDAR_BUDGET_NATIVE_COLD_AND_TRANSACTION_FEEDBACK_PASS_NOT_QUALIFIED'
    project=m.e.load(q['input_root'],original_output=True,time_step_policy=q['time_step_policy'])
    build=Path(q['build_root']);meta,case=m.validate_bundle(build,reference,project)
    source=profile/'trajectory/accepted-column-1-day-4.zip';digest=SHA(source.read_bytes())
    with zipfile.ZipFile(source) as z:raw=z.read('macro.bin')
    codec=raw[:8].decode();reader=READERS[codec]
    out.mkdir();positive=out/'genuine-own-positive';positive.mkdir()
    result=dict(status='RUNNING_ACTUAL_DEFAULT_CALENDAR_NATIVE_CONTROLS',actual_observer_source=git('rev-parse','HEAD').decode().strip(),
        actual_producer_source=q['actual_source'],actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),
        original_checkpoint_sha256=digest,native_codec=codec,original_reader=reader,compiler_executions=0,model_days=0,
        canonical_admission=False,refusals=[])
    save=lambda:(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    save()
    try:
        origin=positive/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        worker=positive/'original';m.h.prepare_column(case,worker,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
        child=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=worker,input=b'0 0\n',capture_output=True,timeout=20)
        (positive/'donor.stdout').write_bytes(child.stdout);(positive/'donor.stderr').write_bytes(child.stderr)
        assert child.returncode in (0,100) and not child.stderr and b'HYBRID_READY' in child.stdout and b'HYBRID_DAY_RETURN' not in child.stdout
        result['genuine_own_positive_ready']=True;save()
        result['refusals']=importlib.import_module(reader).native(build,reference,project,profile/'trajectory',out/'native')
        assert result['refusals'] and all(v['status']=='REFUSED' for v in result['refusals'])
        assert SHA(source.read_bytes())==digest
        result['status']='ACTUAL_DEFAULT_CALENDAR_OWN_POSITIVE_AND_COMPILED_NATIVE_REFUSALS_PASS_ZERO_MODEL_DAYS'
    except Exception as error:
        result.update(status='FAILED_ACTUAL_DEFAULT_CALENDAR_NATIVE_CONTROLS',error=repr(error));raise
    finally:save()
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['profile','reference-work','output']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();q=controls(a.profile,a.reference_work,a.output);print(q['status'],len(q['refusals']),flush=True)
