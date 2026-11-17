"""Bounded corrected chemical successor; prior S/pulse/R proofs stay literal."""
from pathlib import Path
import hashlib
import json
import math
import subprocess

ROOT=Path(__file__).resolve().parents[2]
BASE='f0e5e39ea3d166755e394700a5a8765700eab875'
RUNTIME='0de849d96cb4e81af2f08a07cac6a48fd5a73ff8'
UBUNTU='6e749382691e7a8446eadb6dec0681f292277934'
SEALED='6514334fb843f820da9e981bfb45d36bad36bf01'
PROOF='integration/f-ci/nomacro-complete01/'
SELF='tests/nomacro_scheduled_subsurface/chemical_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_chemical_verify.py'
ENTRY='tests/nomacro_scheduled_subsurface/verify.py'
HOOK="    import importlib.util\n    spec=importlib.util.spec_from_file_location('fixed_chemical_admission',ROOT/'tests/nomacro_scheduled_subsurface/chemical_verify.py')\n    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)\n    return owner.verify()\n"


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def require(test,message):
    if not test:raise ValueError(message)


def bounded(value,limit):return isinstance(value,(int,float)) and math.isfinite(value) and 0<=value<=limit


def validate(q):
    require(q['status']=='CORRECTED_FIXED_CHEMICAL_POINT_INTERVAL_BRANCH_QUALIFIED','incomplete chemical qualification')
    require(q['runtime']==RUNTIME and q['ubuntu']==UBUNTU,'foreign chemical runtime')
    require(q['water_guard_cm']==q['solute_guard_mg_cm2']==1e-10,'changed chemical/water guard')
    require((q['full_trajectories'],q['full_model_days'],q['native_windows'])==(8,8768,24),'incomplete chemical full/native scope')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['scheduled_chemical']=='REFUSED','unqualified scope promotion')
    require(all(q[k] is False for k in ('b1_promotion','active_macro_qualification','new_persistent_codec','tolerances_changed')),'unqualified physical/state promotion')
    require(set(q['platforms'])=={'Windows','Ubuntu'},'missing chemical platform')
    for platform,cases in q['platforms'].items():
        require(set(cases)=={'point','interval'},'missing chemical depth family')
        for kind,r in cases.items():
            require(r['status']=='FULL_O0_O2_PASS' and r['configuration']==kind and r['science']=='NOT_QUALIFIED' and not r['inline'],'incomplete actual chemical report')
            require(r['water_guard_cm']==r['chemical_guard_mg_cm2']==1e-10,'report changed guards')
            selected=r['inputs']['selectors']
            require(selected['SWMACRO']==0 and selected['SWSOLU']==selected['SWIRFIX']==selected['SWIRGFIL']==1,'foreign chemical physical scope')
            require(set(r['profiles'])=={'O0','O2'},'missing chemical optimization')
            if platform=='Ubuntu':require(r['source_commit']==UBUNTU,'foreign actual Ubuntu source')
            for opt,profile in r['profiles'].items():
                require(profile['status']=='FULL_PASS' and profile['days']==profile['budgets']['days']==1096,'incomplete chemical model period')
                for key in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):
                    require(bounded(profile['budgets'][key],1e-10),'chemical mass guard failed')
                require(bounded(abs(profile['irrigation_water_cm']-2.4),1e-12) and bounded(abs(profile['irrigation_mass_mg_cm2']-48),1e-10),'actual chemical source missing')
                own=profile['own']
                require(len(own)==3 and {(w['start'],w['end']) for w in own}=={(2,4),(4,6),(365,367)},'active/year native scope missing')
                require(all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in own),'chemical native drift')
                require(all(profile['controls'][k] is True for k in ('foreign_policy_refused','active_discard_replay_exact','active_disk_recovery','inconsistent_chemical_mass_refused','committed_state_unchanged','origin_unchanged')),'chemical acceptance/refusal state missing')
    for platform,ref in q['references'].items():
        require(ref['status']=='CORRECTED_ORIGINAL_NODAL_CHEMICAL_SOURCE_O0_O2_AND_SOURCE_ABSENT_PRESERVATION_PASS' and ref['b1_promotion'] is False and ref['whole_scientific_equivalence']=='NOT_QUALIFIED','unqualified original reference')
        require(set(ref['profiles'])=={'original-O0','original-O2','corrected-O0','corrected-O2'},'missing paired original optimization')
        require((ref['original_sha256'],ref['corrected_sha256'],ref['original_irrigation_sha256'],ref['corrected_irrigation_sha256'],ref['helper_canonical_sha256'])==
                ('2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2','7731a8db5712fd3d2c6631ee910d79c1801b5b762673c9427a30cfdfb5f29c0b',
                 '65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1','92ca8e7ea395a66a1023b24dfe1c73cd561fc1d9e07370fdef84812a7a3508a2',
                 '0a5cf80aa06eecf23ad408292b710e56d616a2236acb8b26f14527f0f838fd0f'),'foreign original/corrected reference source')
        for opt in ('O0','O2'):
            require(all(ref['checks'][opt][k] is True for k in ('surface_and_source_absent_all_rows_exact','original_missing_source_preserved','corrected_point_interval_mass_matches_actual_water')),'original source-absent preservation missing')
            for version in ('original','corrected'):
                cases=ref['profiles'][version+'-'+opt]['cases']
                require(set(cases)=={kind+'-'+str(c) for kind in ('surface','point','interval') for c in (0,20)},'missing original concentration/depth control')
                require(all(r['complete'] is True and r['days']==1096 for r in cases.values()),'incomplete original control')
                for kind in ('point','interval'):
                    r=cases[kind+'-20'];expected=48 if version=='corrected' else 0
                    require(bounded(abs(r['irrigation_mass_mg_cm2']-expected),1e-10),'original source defect/correction missing')
                    require(bounded(r['max_printed_solute_residual_mg_cm2'],1e-10),'original solute imbalance')
    require(set(q['references'])=={'Windows','Ubuntu'},'missing portable original reference')
    inputs=q['input_controls']
    require(inputs['status']=='FIXED_CHEMICAL_FILE_INLINE_AND_NATIVE_INPUT_CONTROLS_PASS','input controls failed')
    require(len(inputs['checks'])==10 and sum(r.get('physical_csv_exact') is True for r in inputs['checks'])==4,'inline equality missing')
    require({(r['test'],r['optimization']) for r in inputs['checks'] if r.get('status')=='REFUSED'}=={(name,opt) for name in ('reversed','outside-domain','nonfinite') for opt in ('O0','O2')},'native invalid domains missing')
    sal=q['salinity'];require(sal['status']=='FULL_O0_O2_PASS' and sal['salinity'] is True,'active salinity composition missing')
    require(set(sal['profiles'])=={'O0','O2'},'salinity optimization missing')
    for opt,r in sal['profiles'].items():
        require(r['days']==1096 and math.isfinite(r['actual_salinity_reduction_cm']) and r['actual_salinity_reduction_cm']>0,'salinity never active')
        require({(w['start'],w['end']) for w in r['own']}=={(2,4),(144,146),(365,367)} and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in r['own']),'active salinity native missing')
        require(r['controls']['actual_irrigation_day']==145 and all(r['controls'][k] is True for k in ('active_discard_replay_exact','active_disk_recovery','inconsistent_chemical_mass_refused','committed_state_unchanged','origin_unchanged')),'active salinity state/transaction missing')
        require(all(bounded(r['budgets'][k],1e-10) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'salinity mass imbalance')
    original=q['salinity_reference']
    require(original['status']=='CORRECTED_ORIGINAL_SOURCE_ACTIVATES_SALINITY_PRISTINE_SOURCE_ABSENT_PASS' and original['b1_promotion'] is False,'original salinity causality missing')
    for opt in ('O0','O2'):
        require(original['profiles']['original-'+opt]['salinity_reduction_cm']==0 and math.isfinite(original['profiles']['corrected-'+opt]['salinity_reduction_cm']) and original['profiles']['corrected-'+opt]['salinity_reduction_cm']>0,'original source response missing')
    require(q['water_compare']['status']=='ALL_FOUR_WATER_TRAJECTORIES_AND_GENERATED_SOURCES_EXACT' and len(q['water_compare']['profiles'])==4,'admitted water preservation missing')
    require(all(all(r[k] is True for k in ('all_physical_rows_exact','all_csv_rows_exact','selected_complete_native_exact','all_generated_sources_exact')) for r in q['water_compare']['profiles'].values()),'admitted water drift')
    require(q['named_compare']['status']=='ALL_THREE_REGISTERED_FULL_TRAJECTORIES_AND_GENERATED_SOURCES_EXACT' and set(q['named_compare']['profiles'])=={'grass','hupsel','salt'},'registered preservation missing')
    require(all(all(r[k] is True for k in ('all_physical_rows_exact','all_csv_rows_exact','complete_terminal_native_exact','all_generated_sources_exact')) for r in q['named_compare']['profiles'].values()),'registered drift')
    require(set(q['named'])=={'grass','hupsel','salt'} and all(q['named'][name]['status']=='FULL_PASS' and q['named'][name]['full_days']==days and all(w['exact_native_auxiliary'] is True for w in q['named'][name]['restart_windows']) for name,days in (('grass',1827),('hupsel',1096),('salt',1461))),'registered full/native test missing')
    pulse=q['pulse'];require(pulse['status']=='CORRECTED_CHEMICAL_SOURCE_PRESERVES_PULSE_PHYSICAL_CSV_NATIVE_PASS' and len(pulse['profiles'])==4,'pulse preservation missing')
    for name,r in pulse['profiles'].items():
        require(r['days']==201 and r['physical_csv_prefix_exact'] is True and r['inputs_exact'] is True,'pulse prefix drift')
        require(set(r['changed_generated'])==({'solute.f90','irrigation.f90','mod_subsurface_solute_source.f90'} if name.startswith('chemical') else set()),'unqualified pulse source delta')
        require({(w['start'],w['end']) for w in r['prefix']['own']}=={(4,6),(199,201)} and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in r['prefix']['own']),'pulse native drift')
    require(q['base_consumer']['source']==BASE and q['base_consumer']['returncode']==0 and q['base_consumer']['result']['status']=='CURRENT_R_PULSE_AND_SCHEDULED_SSDI_ADMISSION_PASS','actual immutable predecessor consumer missing')


def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('scheduled_chemical_admission',ROOT/'tests/nomacro_scheduled_subsurface/scheduled_chemical_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty chemical qualified surface')
    git('merge-base','--is-ancestor',BASE,RUNTIME);git('merge-base','--is-ancestor',RUNTIME,SEALED);git('merge-base','--is-ancestor',SEALED,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'chemical runtime differs from qualification')
    require(set(git('diff','--name-only',RUNTIME,UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'chemical carrier changed source')
    for path in ('tests/hupsel51/verify_successor.py','tests/irrigation_pulse/verify.py'):
        require(blob('HEAD',path)==blob(BASE,path),'prior literal entry changed')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'prior literal S consumer changed')
    require(not git('diff',BASE,'HEAD','--','integration/irrigation-pulse-time01'),'immutable pulse proof changed')
    old=git('ls-tree','-r','--name-only',BASE,'--',PROOF).decode().splitlines()
    for path in old:
        if Path(path).name in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json'):continue
        require(blob('HEAD',path)==blob(BASE,path),'immutable S proof changed: '+path)
    sealed=git('ls-tree','-r','--name-only',SEALED,'--',PROOF).decode().splitlines()
    for path in sealed:
        if Path(path).name.startswith('CHEMICAL_'):require(blob('HEAD',path)==blob(SEALED,path),'sealed chemical evidence changed: '+path)
    q=json.loads((ROOT/PROOF/'CHEMICAL_QUALIFICATION.json').read_text());validate(q)
    for report in q['platforms']['Windows'].values():
        delta=set(git('diff','--name-only',report['source_commit'],RUNTIME,'--','app','src','reference','tools').decode().splitlines())
        require(delta<={'reference/swap-4.3.1/patches/NOMACRO-SUBSURFACE-SOLUTE-01/README.md'},'actual Windows numerical source differs')
    for path in sealed:
        if Path(path).name.startswith('CHEMICAL_') and path.endswith('_ARCHIVE.json'):
            rec=json.loads((ROOT/path).read_text());archive=ROOT/PROOF/rec['archive']
            require(rec['all_members_forward_verified'] is True and rec['member_count']==len(rec['members']) and archive.stat().st_size==rec['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==rec['sha256'],'chemical raw archive changed')
    allowed={SELF,TEST,ENTRY,PROOF+'STATUS.json',PROOF+'GAP_MATRIX.json',PROOF+'CI_SELECTION.json',PROOF+'CHEMICAL_MERGE_RECEIPT.json'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<=allowed,'unqualified delta after chemical seal')
    return dict(status='CURRENT_R_PULSE_SCHEDULED_AND_FIXED_CHEMICAL_ADMISSION_PASS',runtime=RUNTIME,
                chemical_full_days=8768,prior_scheduled_full_days=8768,whole_scientific_equivalence='NOT_QUALIFIED',
                functional_completion='PARTIAL',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
