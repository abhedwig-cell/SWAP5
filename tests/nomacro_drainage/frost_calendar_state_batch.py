"""Dependency-ordered real Windows calendar cohort with explicit completed reuse."""
import argparse,hashlib,itertools,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from frost_calendar_state_inputs import prepare
from experimental_project import inventory


def source():
    git=lambda *args:subprocess.check_output(['git',*args],cwd=R)
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','reference','.github')
    q=json.loads((R/'integration/f-ci/nomacro-complete01/FROST_CALENDAR_STATE02_CONTRACT_V1.json').read_text());base=q['baseline_actual_canonical']
    assert set(git('diff','--name-only',base,'HEAD','--','app','src','tools','reference').decode().splitlines())==set(q['files'])
    for path,item in q['files'].items():
        raw=(R/path).read_bytes().replace(b'\r\n',b'\n');assert hashlib.sha256(raw).hexdigest()==item['proposed_lf_sha256'] and raw==git('show','HEAD:'+path)
        if item['added']:continue
        old=git('show',base+':'+path);assert hashlib.sha256(old).hexdigest()==item['before_lf_sha256'];before=old.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            assert before[edit['base_start']:edit['base_end']]==edit['before'];parts.extend((before[cursor:edit['base_start']],edit['after']));cursor=edit['base_end']
        parts.append(before[cursor:]);assert ''.join(parts).encode()==raw
    return git('rev-parse','HEAD').decode().strip(),q


def main():
    p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--phase',choices=('v1','daily-v2'),default='v1');a=p.parse_args();head,contract=source();a.output.mkdir(exist_ok=True);record=a.output/'BATCH.json'
    q=dict(status='RUNNING_ACTUAL_WINDOWS_FROST_CALENDAR_REPRESENTATIVES_NOT_ADMITTED',actual_controller_source=head,phase=a.phase,contexts=[],compiler_executions=0,canonical_admission=False)
    if record.exists():
        previous=json.loads(record.read_text());assert previous['status']!='WINDOWS_FROST_CALENDAR_EIGHT_FULL35_SIX_SHORT_AND_REQUIRED_COLD_PASS_NOT_ADMITTED';q['previous_batch_sha256']=hashlib.sha256(record.read_bytes()).hexdigest();(a.output/('PREVIOUS_BATCH_'+q['previous_batch_sha256']+'.json')).write_bytes(record.read_bytes())
    def save():record.write_text(json.dumps(q,indent=2)+'\n')
    def run(command,label,cap):
        with (a.output/(label+'.stdout')).open('xb') as stdout,(a.output/(label+'.stderr')).open('xb') as stderr:r=subprocess.run(command,cwd=R,stdout=stdout,stderr=stderr,timeout=cap)
        r.check_returncode()
    save()
    try:
        for case,opt in itertools.product(contract['representative_cases'],('O0','O2')):
            assert source()[0]==head;label=case['name']+'-'+opt;inputs=a.output/'inputs'/case['name']
            if case['name']=='water-explicit-monthly-hys0-initial1':inputs=a.evidence/'frost-calendar-state02-first-public-inputs-v2/water-hys0-initial1-implicit0-monthly'
            elif not inputs.exists():prepare(case['kind'],case['hysteresis'],case['initial'],case['implicit'],case['calendar'],inputs,reset=case['reset'],start=case['start'])
            if case['name']=='water-explicit-monthly-hys0-initial1' and opt=='O0' and a.phase=='v1':
                profile=a.evidence/'frost-calendar-state02-water-explicit-monthly-hys0-initial1-O0-full35-v1';build_record=a.evidence/'frost-calendar-state02-water-monthly-O0-build-v2/RESULT.json'
            else:
                stem='frost-calendar-state02-'+label;profile=a.evidence/(stem+'-science-'+a.phase);build_record=a.evidence/(stem+'-build-'+a.phase+'/RESULT.json')
            reused=profile.exists()
            if a.phase=='daily-v2' and reused:
                prior=json.loads(build_record.read_text());assert not subprocess.check_output(['git','diff',prior['actual_source'],head,'--','app','src','tools','reference'],cwd=R)
            if not reused:
                if not build_record.exists():
                    run([sys.executable,'-B','tests/nomacro_drainage/frost_calendar_state_build.py','--inputs',str(inputs),'--reference-work','C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider','--output',str(build_record.parent),'--label','frost-calendar-state02-'+label+'-'+a.phase,'--optimization',opt],label+'-build',300);q['compiler_executions']+=1;save()
                command=[sys.executable,'-B','tests/nomacro_drainage/frost_calendar_state_runtime.py','--build-record',str(build_record),'--reference-work','C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider','--output',str(profile),'--days',str(case['days'])]
                if case['start'][5:7]=='12':command.append('--year-seam')
                run(command,label+'-science',600)
            result=json.loads((profile/'RESULT.json').read_text());assert result['status']=='ACTUAL_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED' and result['duration_days']==case['days']
            assert result['kind']==case['kind'] and result['selection']['hysteresis']==case['hysteresis'] and result['selection']['implicit']==case['implicit']
            assert source()[0]==head
            q['contexts'].append(dict(case=case,optimization=opt,profile=str(profile),build_record=str(build_record),actual_compiler_source=result['source'],actual_science_controller=result['actual_controller_source'],original_completed_context_reused_without_replay=reused,input_inventory=inventory(inputs),result_sha256=hashlib.sha256((profile/'RESULT.json').read_bytes()).hexdigest()));save();print('PASS',label,case['days'],'reused' if reused else 'new',len(q['contexts']),flush=True)
        assert len(q['contexts'])==14 and sum(x['case']['days']==35 for x in q['contexts'])==8
        q['status']='WINDOWS_FROST_CALENDAR_EIGHT_FULL35_SIX_SHORT_AND_REQUIRED_COLD_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_WINDOWS_FROST_CALENDAR_BATCH_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
