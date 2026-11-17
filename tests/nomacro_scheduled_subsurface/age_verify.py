"""Exact age source/state/output successor over immutable aquifer/chemical proof."""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
BASE='edbc66b9e2f9debee588db5763da960aee04b36c'
RUNTIME='df243e2f43b1d7243ebcb447feb8540a2a9fe03a'
UBUNTU='f74eabd497604a3dc498207ede5f555b56498a5f'
CORE='4c6b52b4e09dec9906d41115990942ee7b40a14a'
CORE_UBUNTU='ca0356cfdec82853bd3c3f8f0eb611ea70e258dc'
CORE_SEAL='d38489e60e1a0f44436ead579c3562f7da68a48a'
SEALED='271fddac1e4b9930e6c0ec743a60a29e2b031de7'
PROOF='integration/f-ci/nomacro-complete01/'
SELF='tests/nomacro_scheduled_subsurface/age_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_age_verify.py'
ENTRY='tests/nomacro_scheduled_subsurface/aquifer_verify.py'
OLD_AGE='tests/nut-sol/verify_age_successor.py'
OLD_SURFACE='tests/nut-sol/verify_surface_age_successor.py'
PROFILES={a+'-'+o for a in ('0','100') for o in ('O0','O2')}
SOLUTE='be29db94a6d083cc2a60b2c969c17190496063f9b029713b937b81f7d7414ced'
PROVIDERS={
 'mod_solute_compartment_state':'b02f470222aa1a8b55a2a0a5b7d37741821bb9b755cbe7272db47cf30f7db046',
 'mod_b111_age_tracer_substep':'01dfcbbf058257d39b9132d473d3994ea0cc595e6bacccf1fe71da0366af280e',
 'mod_b111_surface_age_budget':'d2c25fa02ec2bfab33c508187fa9256cc0018559f16afa11eb1d1646eeac0b1a',
 'mod_age_effluent_observer':'fc5ed6830daa510b11e17d4bcf8a8cf344346244b72212e2bc138c216a85c52d'}
AGE_TOL='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
EFF_POLICY='water-weighted-positive-export-age-over-output-interval-v1'


def hook(indent,method):
    lines=["import importlib.util", "spec=importlib.util.spec_from_file_location('original_age_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_verify.py')",
           'owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)', 'return owner.'+method+'()']
    return ''.join(' '*indent+line+'\n' for line in lines)


HOOK=hook(4,'verify')
LEGACY_HOOKS={OLD_AGE:(hook(1,'source_status'),hook(1,'qualification_status')),
              OLD_SURFACE:(hook(4,'source_status'),hook(4,'qualification_status'))}


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def require(ok,why):
    if not ok:raise ValueError(why)
def finite_nonnegative(v):return isinstance(v,(float,int)) and math.isfinite(v) and v>=0
def bounded(v,limit=1e-10):return finite_nonnegative(v) and v<=limit
def exact(w):return all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged','all_four_age_csv_exact'))


def validate(q):
    require(q['status']=='ORIGINAL_AGE_SOURCE_STATE_AND_WATER_WEIGHTED_OUTPUT_BRANCH_QUALIFIED' and (q['baseline'],q['runtime'],q['ubuntu'])==(BASE,RUNTIME,UBUNTU),'foreign age source/evidence')
    require((q['core_runtime'],q['core_ubuntu'],q['core_seal'])==(CORE,CORE_UBUNTU,CORE_SEAL),'foreign age core predecessor')
    require((q['full_model_days'],q['full_trajectories'],q['full_native_windows'],q['short_native_windows'],q['prior_core_native_projections'])==(8768,8,32,8,72),'incomplete age scope')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['release_readiness']=='RC2_QUALIFIED_NAMED_PROFILES_ONLY','unqualified age scope promotion')
    require(all(q[k] is False for k in ('chemical_mass_guard_changed','active_macro_qualification','b1_promotion','tolerances_changed')),'changed age/chemical scope or guards')
    require(q['water_guard_cm']==1e-10 and q['units']=='cm day' and q['age_tolerance']==AGE_TOL,'age unit/balance policy drift')
    require(q['native_codec']=='S5AGE002' and q['effluent_missing']==-9999 and q['effluent_policy']==EFF_POLICY,'age output/state policy drift')
    require(q['numerical_policy']=='original-age-dtmin-floor-capped-by-remaining-water-interval-v1','age clock policy drift')
    require(q['current_generated_solute_sha256']==SOLUTE and q['provider_canonical_sha256']==PROVIDERS,'age physical provider changed')
    scope=q['scope'];require(scope['initial_ages_day']==[0,100] and scope['qualified_output']=='daily' and all(scope[k] is False for k in ('fixed_irrigation','aquifer','snow','macro','salinity')),'unqualified age input domain')
    require(set(q['platforms'])==set(q['builds'])==set(q['controls'])==set(q['original_provider_reference'])=={'Windows','Ubuntu'},'age platform missing')
    for platform,run in q['platforms'].items():
        require(run['status']=='FOUR_FULL_ORIGINAL_AGE_CORRECTED_EFFLUENT_O0_O2_NATIVE_PASS' and set(run['profiles'])==PROFILES,'age complete trajectories missing')
        require(run['water_guard_cm']==1e-10 and run['chemical_mass_guard_changed'] is False and run['units']=='cm day' and run['whole_scientific_equivalence']=='NOT_QUALIFIED','actual age guards/units changed')
        if platform=='Ubuntu':require(run['source_commit']==UBUNTU,'age actual Linux source differs')
        require(set(q['builds'][platform])==PROFILES,'age compiled profile missing')
        for name,r in run['profiles'].items():
            require(r['status']=='FULL_ORIGINAL_AGE_CORRECTED_EFFLUENT_NATIVE_PASS' and r['full']['status']=='FULL_PASS' and r['full']['days']==r['full']['budgets']['days']==1096,'age period incomplete')
            require(all(bounded(r['full']['budgets'][k]) for k in ('max_water_cm','max_kernel_cm')),'age actual water imbalance')
            require(set(r['maximum_residual_cm_day'])=={'age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day'} and all(map(finite_nonnegative,r['maximum_residual_cm_day'].values())) and bounded(r['maximum_fraction_of_accepted_age_tolerance'],1),'age balance policy exceeded')
            require(len(r['final_state_cm_day'])==11 and all(map(math.isfinite,r['final_state_cm_day'])) and all(r['final_state_cm_day'][i]>0 for i in (3,4,10)),'soil/pond production or handoff not exercised')
            require(r['short']['days']==5 and exact(r['short']['own']),'age short native missing')
            require(len(r['own'])==4 and {(w['start'],w['end']) for w in r['own']}=={(2,4),(199,201),(365,367),(530,532)} and all(map(exact,r['own'])),'age year/active/full native missing')
            output=r['effluent_output'];require(output['all_daily_mean_and_volume_fields_match_full_precision_probe'] is True and output['missing_value']==-9999 and all(output[k]>0 for k in ('positive_root_export_days','positive_runoff_export_days','positive_drain_export_days')),'age effluent units/actual exports missing')
            require(all(v is True for v in r['prior_core_preservation'].values()),'age output correction changed core trajectory/native state')
            build=q['builds'][platform][name];identity=build['identity'];require(build['project']['model']=='HYBRID_NOMACRO_WATER' and build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10,'foreign compiled age model')
            require(identity['donor_generated']['solute.f90']==SOLUTE,'actual generated age source differs')
            policy=identity['conserved_original_age'];require(policy['providers']==PROVIDERS and policy['native_codec']=='S5AGE002' and policy['age_tolerance']==AGE_TOL and policy['effluent_policy']==EFF_POLICY and policy['effluent_missing']==-9999 and policy['chemical_mass_guard_changed'] is False,'actual age provider/state identity differs')
            for flags in (identity['donor_flags'],identity['kernel_flags']):require('-'+name.rsplit('-',1)[1] in flags and all(f in flags for f in ('-ffp-contract=off','-march=x86-64','-mtune=generic')),'age compiler arithmetic/optimization drift')
        controls=q['controls'][platform];require(set(controls)=={'O0','O2'},'age transaction optimization missing')
        for c in controls.values():
            require(c['status']=='ORIGINAL_AGE_ACTIVE_POND_TRANSACTIONS_REFUSALS_AND_ORIGINS_PASS' and c['active_pond_day']==367 and c['independent_steps']==6 and all(c[k] is True for k in ('discard_replay_exact','disk_recovery_exact','committed_state_unchanged','origins_unchanged','foreign_policy_refused')),'age active transaction/state isolation absent')
            required={'soil-stock','pond-stock','total-stock','soil-production','pond-production','external-input','drainage','bottom','root','runoff','internal-infiltration','nonfinite','effluent-mean','effluent-negative-volume','effluent-nonfinite','effluent-orphan'}
            require(len(c['checks'])==16 and {t['attack'] for t in c['checks']}==required and all(t['status']=='REFUSED' for t in c['checks']),'age candidate/effluent/internal transfer refusal absent')
        ref=q['original_provider_reference'][platform];require(ref['status']=='ORIGINAL_HOST_AGE_CORE_AND_CORRECTED_EFFLUENT_FULL_O0_O2_PASS' and ref['effluent_policy']==EFF_POLICY and set(ref['profiles'])=={'O0','O2'},'corrected original age/output reference missing')
        for opt,p in ref['profiles'].items():
            require(set(p['cases'])=={'0','100'},'original age initial condition missing')
            for r in p['cases'].values():
                require(r['days']==1096 and bounded(r['maximum_fraction_of_accepted_age_tolerance'],1) and r['all_core_reference_rows_exact'] is True,'corrected age reference changed core or exceeded age guard')
                require(r['effluent_output']['all_daily_mean_and_volume_fields_match_full_precision_probe'] is True and r['effluent_output']['missing_value']==-9999,'original age mean/volume output absent')
    require(set(q['components'])=={'clock','surface_default','effluent'},'age independent physical contract missing')
    for name,c in q['components'].items():
        require(c['status']=='PASS' and len(c['records'])==2 and {r['optimization'] for r in c['records']}=={0,2},'age independent optimization missing')
        for r in c['records']:
            require(r['compiler_requests']==(5 if name=='clock' else 3),'age independent closure changed')
            require(r['case']=={'clock':'original_age_clock','surface_default':'surface_age_budget','effluent':'age_effluent_observer'}[name],'foreign independent age contract')
    native=q['native_refusals'];require(native['status']=='ORIGINAL_AGE_READER_AND_PRIVATE_NATIVE_REFUSALS_PASS' and len(native['checks'])==48 and all(t['status']=='REFUSED' for t in native['checks']),'age actual reader/private native refusals absent')
    for opt in ('O0','O2'):
        rows=[r for r in native['checks'] if r['optimization']==opt]
        require(len(rows)==24 and {r['test'] for r in rows if r['test'].startswith('reader-')}=={'reader-negative','reader-above-input-domain','reader-nonfinite','reader-missing'},'age original reader scope absent')
        require({'native-old-codec','native-orphan-export-age','native-changed-export-water','native-changed-export-amount','native-nonfinite-export-amount'}<={r['test'] for r in rows},'age private output/native version refusal missing')
    preserved=q['preservation'];required={'fixed-point-O2','scheduled-water-O2','grass','hupsel','salt','scheduled-chemical-point-O2','scheduled-chemical-interval-O2','aquifer-sorption-decay','aquifer-stiff-loss','pulse-water','pulse-chemical'}
    require(preserved['status']=='AGE_OFF_PRESERVES_ELEVEN_SELECTED_ADMITTED_CONTEXTS_PASS' and set(preserved['profiles'])==required,'age-off admitted context missing')
    for r in preserved['profiles'].values():require(all(r[k] is True for k in ('all_generated_sources_exact','provider_flags_inputs_exact','physical_csv_prefix_exact','exact_current_source_binding')) and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in r['prefix']['own']),'age-off admitted emitted/physical/native drift')
    inherited=q['existing_owner_inheritance'];require(inherited['status']=='EXACT_INPUT_AND_COMPILER_EXISTING_OWNER_INHERITED' and inherited['previous_runtime']==CORE and inherited['previous_ubuntu']==CORE_UBUNTU and inherited['fresh_execution'] is False,'unbound existing age owner inheritance')
    require(q['base_consumer']['source']==BASE and q['base_consumer']['returncode']==0 and q['base_consumer']['result']['status']=='CURRENT_AQUIFER_FIXED_SCHEDULED_CHEMICAL_S_PULSE_R_ADMISSION_PASS','actual immutable aquifer predecessor missing')
    old=q['legacy_source_baseline_failure'];require(old['source']==BASE and old['returncode']!=0 and 'unregistered projected reader' in old['stderr'],'legacy source-only failure misrepresented')
    cli=q['public_cli'];require(cli['status']=='PUBLIC_ORIGINAL_AGE_BUILD_BUNDLE_RUN_RESTART_PASS' and cli['window']==[2,4] and cli['all_physical_and_age_budgets_exact'] is True and cli['all_five_csv_windows_exact'] is True,'public age run/restart missing')
    require(set(q['reference_comparison'])==PROFILES and all(r['whole_scientific_equivalence']=='NOT_QUALIFIED' and r['classification']=='UNRESOLVED_COMPOSITE_REFERENCE_DIFFERENCE' for reports in q['reference_comparison'].values() for r in reports.values()),'unqualified age reference equivalence promotion')
    require(q['workflow']['id']==44119992547 and q['workflow']['status']=='SUCCESS','corrected age selected Ubuntu run missing')


def verify():
    import importlib.util
    spec=importlib.util.spec_from_file_location('age_composition_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_composition_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty age admission surface')
    for a,b in ((BASE,CORE),(CORE,CORE_SEAL),(CORE_SEAL,RUNTIME),(RUNTIME,SEALED),(SEALED,'HEAD')):git('merge-base','--is-ancestor',a,b)
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'age runtime differs from qualification')
    require(set(git('diff','--name-only',RUNTIME,UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'age carrier changed science')
    expected={'app/hybrid_water/conserved_original_age.py','app/hybrid_water/daily_coupling.py','app/hybrid_water/daily_host.py','app/hybrid_water/donor_sources.py','app/hybrid_water/experimental_project.py','app/hybrid_water/original_pond_budget.py','reference/swap-4.3.1/patches/NOMACRO-AGE-SOURCE-01/run.py','reference/swap-4.3.1/patches/NOMACRO-AGE-SOURCE-01/source.py','src/process/mod_age_effluent_observer.f90','src/process/mod_b111_age_tracer_substep.f90','src/process/mod_b111_surface_age_budget.f90'}
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==expected,'unqualified age physical dependency delta')
    require(not git('diff',CORE,RUNTIME,'--',*('src/process/'+p+'.f90' for p in PROVIDERS if p!='mod_age_effluent_observer')),'existing age physical owner changed after supported qualification')
    require(set(git('diff','--name-only',RUNTIME,SEALED,'--','tests').decode().splitlines())=={'tests/nomacro_scheduled_subsurface/age_public_cli_verify.py'},'executed age controllers changed before seal')
    for path in ('tests/hupsel51/verify_successor.py','tests/irrigation_pulse/verify.py','tests/nomacro_scheduled_subsurface/verify.py','tests/nomacro_scheduled_subsurface/chemical_verify.py','tests/nomacro_scheduled_subsurface/scheduled_chemical_verify.py'):
        require(blob('HEAD',path)==blob(BASE,path),'prior literal age predecessor entry changed')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'literal aquifer owner changed')
    for path,(source,qualified) in LEGACY_HOOKS.items():
        body=blob('HEAD',path).decode();require(body.count(source)==1 and body.count(qualified)==1 and body.replace(source,'',1).replace(qualified,'',1)==blob(BASE,path).decode(),'literal historical age assertions changed')
    require(not git('diff',BASE,'HEAD','--','integration/irrigation-pulse-time01','integration/audits'),'immutable prior physical evidence changed')
    for path in git('ls-tree','-r','--name-only',BASE,'--',PROOF).decode().splitlines():
        if Path(path).name in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json'):continue
        require(blob('HEAD',path)==blob(BASE,path),'immutable age predecessor proof changed: '+path)
    for seal in (CORE_SEAL,SEALED):
        for path in git('ls-tree','-r','--name-only',seal,'--',PROOF).decode().splitlines():
            if Path(path).name.startswith('AGE_'):require(blob('HEAD',path)==blob(seal,path),'sealed age proof changed: '+path)
    q=json.loads((ROOT/PROOF/'AGE_QUALIFICATION.json').read_text());validate(q)
    for r in (q['platforms']['Windows'],q['original_provider_reference']['Windows'],q['preservation']):require(not git('diff',r['source_commit'],RUNTIME,'--','app','src','reference','tools'),'actual Windows age source differs')
    core=json.loads((ROOT/PROOF/'AGE_CORE_QUALIFICATION.json').read_text());old=core['existing_age_owner'];inherited=q['existing_owner_inheritance']
    require(old['status']=='PHYSICAL_PASS_NOT_ADMITTED' and inherited['input_sha256']==old['input_sha256'] and inherited['compiler']==old['compiler'],'existing supported owner closure/qualification differs')
    for opt,r in old['runs'].items():
        require('AGE_LITERAL_150_STEPS_PRODUCTION_UNITS_BALANCE_INVALID_RETRY=PASS' in r['process_stdout'] and 'AGE_JOINT_ATOMIC_RETRY_RESTART_BALANCE=PASS' in r['physical_stdout'] and 'SURFACE_AGE_REAL_REFERENCE_TRIPLET=PASS' in r['surface']['stdout'],'existing real age/pond owner science absent')
        require(r['endpoint_sha256']==r['fresh_sha256'] and r['surface']['endpoint_sha256']==r['surface']['fresh_sha256'],'existing supported owner native drift')
    sources=json.loads((ROOT/PROOF/'AGE_TEST_SOURCES.json').read_text())
    for path,digest in sources['sources'].items():require(hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==digest,'actual age controller changed')
    for path in sorted((ROOT/PROOF).glob('AGE_*_RAW_ARCHIVE.json')):
        r=json.loads(path.read_text());archive=ROOT/PROOF/r['archive']
        require(r['all_members_forward_verified'] is True and r['member_count']==len(r['members']) and archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'age raw archive identity changed')
        with zipfile.ZipFile(archive) as z:
            require({n for n in z.namelist() if not n.endswith('/')}==set(r['members']),'age raw member omitted')
            for name,digest in r['members'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'age raw member changed')
    allowed={SELF,TEST,ENTRY,OLD_AGE,OLD_SURFACE,PROOF+'STATUS.json',PROOF+'GAP_MATRIX.json',PROOF+'CI_SELECTION.json',PROOF+'AGE_MERGE_RECEIPT.json'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<=allowed,'unqualified delta after age seal')
    return dict(status='CURRENT_ORIGINAL_AGE_AQUIFER_CHEMICAL_S_PULSE_R_ADMISSION_PASS',runtime=RUNTIME,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL',full_model_days=8768,water_guard_cm=1e-10,chemical_mass_guard_changed=False,age_units='cm day',age_tolerance=AGE_TOL,native_codec='S5AGE002')


def source_status():
    return {**verify(),'qualified':False,'admitted':False,'full_capability':False,'current_source_tree':git('rev-parse','HEAD:src').decode().strip()}


def qualification_status():
    return {**verify(),'qualified':True,'full_capability':False,'accepted_age_owner_preserved':True,'surface_age_successor':True,
            'full_fci':'NOT_SELECTED_IMPACT','performance':'NO_NEW_SPEED_CLAIM','current_source_tree':git('rev-parse','HEAD:src').decode().strip()}


if __name__=='__main__':print(json.dumps(verify(),indent=2))
