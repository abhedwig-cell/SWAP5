"""Read the actual incompatible clock refusals, including zero accepted host state."""
import argparse,json
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_source_inverse import ROOT,CORE,complete_inverse,producer_epoch


def audit(proof):
    complete_inverse();observations=[]
    with ExitStack() as stack:
        store=Archive(proof,'EXPLICIT_BOTTOM9_WINDOWS_RAW_V1',stack);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
        aggregate=json.loads(store.get('observations/EXPLICIT_BOTTOM9_FINAL_CLOCK_INCOMPATIBLE_O0_O2_REFUSALS_V2.json'))
        assert aggregate['status']=='BOTH_FINAL_CLOCK_INCOMPATIBLE_FORCINGS_REFUSED_WITHOUT_ACCEPTED_STATE_OR_NATIVE_PUBLICATION' and len(aggregate['observations'])==2
        for opt in ('O0','O2'):
            profile=ReadView(store,'profiles/explicit-bottom9-incompatible-final-clock-'+opt+'-v2');q=json.loads((profile/'RESULT.json').read_text())
            assert q['status']=='ACTUAL_FINAL_CLOCK_INCOMPATIBLE_FORCING_ORIGINAL_RESOLUTION_REFUSAL_ACCEPTED_HOST_STATE_UNCHANGED_NO_CHECKPOINT' and q['optimization']==opt
            assert q in aggregate['observations'] and producer_epoch(q['source'])=='composed-clock' and q['physical_core']==CORE
            assert q['before_accepted_state']==q['after_accepted_state'] and q['before_accepted_state']['day']==q['before_accepted_state']['revision']==q['accepted_days']==0
            assert q['accepted_host_state_unchanged'] is True and q['checkpoint_published'] is False and q['private_Fortran_state_after_process_exit_claimed'] is False and q['operational_deadline_counted_as_scientific_refusal'] is False and 0<q['seconds']<60
            inputs=ReadView(store,'profiles/'+q['input_root'].replace('\\','/').split('/evidence/',1)[1])
            for name,digest in q['input_inventory']:assert SHA((inputs/name).read_bytes())==digest
            import experimental_project as e
            assert e.switches((inputs/'swap.swp').read_text(encoding='cp1252'))['SWBOTB']==9
            item=projection[q['build_root']];build=ReadView(store,item['archive_prefix']);raw=(build/'BUILD.json').read_bytes();meta=json.loads(raw)
            assert SHA(raw)==q['actual_BUILD_sha256']==item['actual_BUILD_sha256']
            assert meta['identity']['original_output']['nprintday']==3
            for name,digest in meta['identity']['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
            for role,digest in meta['executable_sha256'].items():assert SHA((build/('day_'+role+'.exe')).read_bytes())==digest
            for field in ('donor_flags','kernel_flags'):assert '-'+opt in meta['identity'][field] and '-ffp-contract=off' in meta['identity'][field]
            assert 'ERROR STOP Implicit original retry reached clock resolution' in (profile/'trajectory/original/donor.stderr').read_text()
            assert not (profile/'trajectory').glob('accepted-column-*-day-*.zip') and not (profile/'trajectory/original/macro.bin').is_file()
            observations.append(dict(optimization=opt,producer=q['source'],BUILD_sha256=SHA(raw),accepted_host_state_before=q['before_accepted_state'],accepted_host_state_after=q['after_accepted_state'],accepted_days=0,published_native_checkpoint=False,private_Fortran_state_after_process_exit_claimed=False,operational_deadline_counted_as_scientific_refusal=False))
        # Retain the V1 instrumentation failure as a failure, never a successful
        # numerical refusal. V2 reuses its actual completed O0 build explicitly.
        diagnostic=json.loads(store.get('profiles/explicit-bottom9-incompatible-final-clock-O0-v1/RESULT.json'))
        assert diagnostic['status']=='ACTUAL_NEGATIVE_OBSERVATION_FAILED_NOT_QUALIFIED'
        reuse=json.loads(store.get('profiles/explicit-bottom9-incompatible-final-clock-O0-v2/BUILD_REUSE.json'));assert reuse['new_compiler_executions']==0 and reuse['actual_build_root']==aggregate['observations'][0]['build_root']
    return dict(status='ACTUAL_ARCHIVED_BOTH_FINAL_CLOCK_INCOMPATIBLE_REFUSALS_ZERO_ACCEPTED_HOST_STATE_AND_NO_NATIVE_PUBLICATION_VERIFIED',observations=observations,failed_V1_observer_preserved=True,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,default=ROOT/'integration/f-ci/nomacro-complete01');p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.proof)
    with a.output.open('x',encoding='utf-8') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],flush=True)
