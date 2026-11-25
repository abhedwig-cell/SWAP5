"""Focused portable Frost/hysteresis state composition, no old-model replay."""
import argparse,itertools,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
from frost_history_state_batch import source
from frost_history_state_inputs import prepare
from frost_history_state_model_forensics import audit


def main():
    p=argparse.ArgumentParser()
    for name in ('reference-work','build-root','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();head=source();a.output.mkdir();q=dict(status='RUNNING_PORTABLE_FROST_STATE_REPRESENTATIVES_NOT_ADMITTED',actual_source=head,optimization=a.optimization,contexts=[],canonical_admission=False)
    def save():(a.output/'BATCH.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for implicit,kind,hys in itertools.product((0,1),('water','cde'),(0,1)):
            assert source()==head
            initial=1 if kind=='water' else 2
            label=('implicit' if implicit else 'explicit')+'-'+kind+'-hys'+str(hys)+'-initial'+str(initial)
            inputs=a.output/'inputs'/label;prepare(kind,hys,initial,implicit,inputs)
            profile=a.output/label;build=a.build_root/label
            command=[sys.executable,'-B',str(R/'tests/nomacro_drainage/frost_cde_drainage_runtime.py'),'--reference-work',str(a.reference_work),'--build-root',str(build),'--output',str(profile),'--kind',kind,'--optimization',a.optimization,'--phase','short','--existing-input',str(inputs)]
            with (a.output/(label+'-controller.stdout')).open('xb') as out,(a.output/(label+'-controller.stderr')).open('xb') as err:r=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=600)
            r.check_returncode();independent=audit(profile,a.reference_work)
            (a.output/(label+'-INDEPENDENT.json')).write_text(json.dumps(independent,indent=2)+'\n')
            controls=a.output/(label+'-controls');command=[sys.executable,'-B',str(R/'tests/nomacro_drainage/frost_history_state_controls.py'),'--reference-work',str(a.reference_work),'--profile',str(profile),'--output',str(controls)]
            with (a.output/(label+'-controls.stdout')).open('xb') as out,(a.output/(label+'-controls.stderr')).open('xb') as err:r=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=600)
            r.check_returncode();q['contexts'].append(dict(implicit=implicit,kind=kind,hysteresis=hys,initial=initial,profile=str(profile),independent=independent,controls=str(controls)));save();print('PASS',label,flush=True)
        assert source()==head and len(q['contexts'])==8
        q['status']='EIGHT_PORTABLE_FROST_STATE_35DAY_24COLD_NATIVE_ROOT_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_PORTABLE_FROST_STATE_NOT_ADMITTED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
