"""Only missing controls on genuine completed Ubuntu periods; no full replay."""
import argparse,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser()
    for key in ('runner-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();root=a.runner_root;current=root/'proof/current';reference=root/'provider';a.output.mkdir(exist_ok=True)
    record=dict(status='RUNNING_MISSING_RIA_THERMAL_CONTROLS_ONLY',actual_observer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),
                actual_model_and_compiler_producer='0ef37c9d733cea90274a0b9a051e72228670a38b',full35_periods_replayed=0,compiler_executions=0,original_metadata_rewritten=False,cases=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
    def run(script,*args):subprocess.run([sys.executable,'-B',str(R/'tests/nomacro_drainage'/script),*map(str,args)],cwd=R,check=True)
    save()
    for kind in ('water','cde'):
        for snow in (0,1):
            label=f'{kind}-snow{snow}';profile=current/label;q=json.loads((profile/'RESULT.json').read_text());assert q['source']==q['actual_completion_head']==record['actual_model_and_compiler_producer']
            assert q['status']=='ACTUAL_RIA12_THERMAL_FULL35_PHYSICAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED' and q['days']==35 and len(q['cold'])==3
            item=dict(label=label,original_profile=str(profile),original_full35_replayed=False)
            if kind=='water':
                control=current/(label+'-controls');old=json.loads((control/'RESULT.json').read_text())
                assert old['status']=='ACTUAL_RIA12_CURRENT_COMPILED_MODEL_PARAMETER_NATIVE_REFUSALS_AND_OWN_POSITIVE_PASS_NO_MODEL_DAYS' and old['own_positive_ready']
                assert len(old['compiled_refusals'])==43+6*snow and len(old['private_input_refusals'])==3
                item['native_controls']='INHERITED_EXACT_ORIGINAL_COMPLETED_REFUSALS_NOT_REPLAYED'
            else:
                control=a.output/(label+'-controls')
                run('ria12_thermal_controls.py','--profile',profile,'--reference-work',reference,'--reference-samples',current/(label+'-original-samples'),
                    '--model1-origin',current/'origins/legacy/model1/accepted-column-1-day-1.zip',
                    '--legacy-ria-origin',current/'origins/legacy/legacy-ria/accepted-column-1-day-1.zip',
                    '--primary-origin',current/f'origins/parent/primary-{kind}/accepted-column-1-day-2.zip',
                    '--other-kind-origin',current/f'water-snow{snow}/trajectory/accepted-column-1-day-2.zip',
                    '--foreign-context-origin',current/f'{kind}-snow{1-snow}/trajectory/accepted-column-1-day-2.zip','--output',control)
                item['native_controls']=str(control)
            if snow or kind=='cde':
                transaction=a.output/(label+'-transactions')
                run('ria12_thermal_transactions.py','--profile',profile,'--reference-work',reference,'--current-controls',control,'--output',transaction)
                item['transactions']=str(transaction)
            record['cases'].append(item);save()
    record['status']='RIA_THERMAL_MISSING_NATIVE_AND_EXTERNAL_CONTROLS_PASS_ZERO_FULL_MODEL_REPLAY';save();print(record['status'])


if __name__=='__main__':main()
