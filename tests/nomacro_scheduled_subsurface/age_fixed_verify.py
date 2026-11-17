"""Exact original fixed young-water age source/state successor admission."""
from pathlib import Path
import hashlib
import importlib.util
import json
import math
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
BASE='17834a639bb9c749c159c79e36faa96d99f3fe1b'
RUNTIME='67ef706a42dd894a9b67cf0e86ad90ce48ac1de6'
UBUNTU='58468f98452d55e556f0aa6420e074714154ba7e'
SEALED='56ae017e413503891d6c1a9709d1c882f2a14edb'
PROOF='integration/f-ci/nomacro-complete01/'
SELF='tests/nomacro_scheduled_subsurface/age_fixed_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_age_fixed_verify.py'
ENTRY='tests/nomacro_scheduled_subsurface/age_composition_verify.py'
KINDS={'sprinkler','surface','subsurface','subsurface-interval'}
PROFILES={k+'-'+o for k in KINDS for o in ('O0','O2')}
AGE_TOL='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)'
POLICY='original-fixed-young-water-age-zero-days-v1'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('fixed_young_age_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_fixed_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""


def require(ok,why):
    if not ok:raise ValueError(why)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def tree(ref,prefix):return {r.split('\t',1)[1]:r.split('\t',1)[0] for r in git('ls-tree','-r',ref,'--',prefix).decode().splitlines()}
def bounded(value,limit=1e-10):return isinstance(value,(int,float)) and math.isfinite(value) and 0<=value<=limit
def exact(w):return all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged','all_four_age_csv_exact'))


def validate(q):
    require(q['status']=='ORIGINAL_FIXED_YOUNG_WATER_AGE_SOURCE_STATE_OUTPUT_QUALIFIED' and (q['baseline'],q['runtime'],q['ubuntu'])==(BASE,RUNTIME,UBUNTU),'foreign fixed age source/evidence')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['release_readiness']=='RC3_FIXED_NAMED_PROFILES_ONLY','unqualified fixed age scope promotion')
    require(q['water_guard_cm']==1e-10 and q['chemical_mass_guard_changed'] is False and q['age_tolerance']==AGE_TOL and q['age_units']=='cm day','fixed age guards/units changed')
    require(q['fixed_policy']==POLICY and q['native_codec']=='S5AGE002' and q['new_persistent_fields'] is False,'fixed age numerical/native policy changed')
    scope=q['scope'];require(set(scope['kinds'])==KINDS and (scope['full_initial_age_day'],scope['short_initial_age_day'],scope['irrigation_age_day'],scope['output'])==(100,0,0.,'daily') and all(scope[k] is False for k in ('snow','aquifer','macro')),'unqualified fixed age domain')
    parent=json.loads((ROOT/PROOF/'AGE_QUALIFICATION.json').read_text())
    require(q['provider_canonical_sha256']==parent['provider_canonical_sha256'] and q['current_age_solute_sha256']==parent['current_generated_solute_sha256'],'fixed age physical provider changed')
    require(all(set(q[k])=={'Windows','Ubuntu'} for k in ('platforms','original_reference','controls','inline','inactive','builds','generated_irrigation_raw_sha256')),'fixed age platform missing')
    for platform,run in q['platforms'].items():
        require(run['status']=='AGE_FIXED_FULL_O0_O2_PASS' and set(run['profiles'])==PROFILES and run['water_guard_cm']==1e-10 and run['chemical_mass_guard_changed'] is False and run['whole_scientific_equivalence']=='NOT_QUALIFIED','fixed age complete runtime absent')
        require(set(q['builds'][platform])==PROFILES,'fixed age compiled context missing')
        for name,r in run['profiles'].items():
            require(r['short']['days']==8 and exact(r['short']['own']),'fixed age active short native absent')
            full=r['full'];require(full['status']=='FULL_PASS' and full['days']==full['budgets']['days']==1096 and all(bounded(full['budgets'][k]) for k in ('max_water_cm','max_kernel_cm')),'fixed age period incomplete or water imbalanced')
            require(bounded(r['maximum_age_tolerance_fraction'],1),'fixed age balance exceeded')
            require(len(full['own'])==5 and {(w['start'],w['end']) for w in full['own']}=={(2,4),(4,6),(199,201),(365,367),(530,532)} and all(map(exact,full['own'])),'fixed age active/year native missing')
            require(full['effluent']['all_daily_mean_and_volume_fields_match_full_precision_probe'] is True and full['effluent']['missing_value']==-9999,'fixed age output units changed')
            build=q['builds'][platform][name];identity=build['identity'];age=identity['conserved_original_age'];fixed=identity['original_age_fixed_irrigation']
            require(build['project']['model']=='HYBRID_NOMACRO_WATER' and build['project']['nodes']==34 and build['project']['water_tolerance']==1e-10,'foreign fixed age compiled model')
            require(identity['donor_generated']['irrigation.f90']==q['generated_irrigation_raw_sha256'][platform] and identity['donor_generated']['solute.f90']==q['current_age_solute_sha256'],'actual fixed age generated source differs')
            require(age['providers']==q['provider_canonical_sha256'] and age['native_codec']=='S5AGE002' and age['age_tolerance']==AGE_TOL and age['chemical_mass_guard_changed'] is False,'actual fixed age provider/native identity differs')
            fixed_sha=hashlib.sha256((ROOT/'app/hybrid_water/age_fixed_irrigation.py').read_bytes().replace(b'\r\n',b'\n')).hexdigest()
            require(fixed['policy']==POLICY and fixed['irrigation_age_day']==0. and fixed['units']=='days' and fixed['source_sha256']==fixed_sha,'actual fixed age input policy differs')
            require('conserved_subsurface_solute' not in identity and 'conserved_scheduled_subsurface_solute' not in identity,'fixed age activated chemical source')
            for flags in (identity['donor_flags'],identity['kernel_flags']):require('-'+name.rsplit('-',1)[1] in flags and all(f in flags for f in ('-ffp-contract=off','-march=x86-64','-mtune=generic')),'fixed age compiler arithmetic drift')
        ref=q['original_reference'][platform];require(ref['status']=='ORIGINAL_FIXED_YOUNG_AGE_EIGHT_FULL_REFERENCE_PASS' and set(ref['profiles'])==PROFILES,'fixed age original reference incomplete')
        for name,r in ref['profiles'].items():
            opt=name.rsplit('-',1)[1];require(r['days']==1096 and bounded(r['maximum_fraction_of_accepted_age_tolerance'],1) and r['final'][5]==0 and r['returncode'] in (0,100),'original fixed age source/balance absent')
            require(r['executable_sha256']==parent['original_provider_reference'][platform]['profiles'][opt]['executable_sha256'] and r['effluent_output']['all_daily_mean_and_volume_fields_match_full_precision_probe'] is True,'unbound original fixed age executable/output')
        c=q['controls'][platform];require(c['status']=='FIXED_YOUNG_AGE_ACTIVE_TRANSACTIONS_AND_NATIVE_READERS_PASS' and set(c['profiles'])==PROFILES,'fixed age active transactions absent')
        for r in c['profiles'].values():
            metrics=r['metrics'];require(r['status']=='ACTIVE_FIXED_YOUNG_AGE_TRANSACTION_PASS' and all(r[k] is True for k in ('discard_replay_exact','disk_recovery_exact','origin_unchanged')),'fixed age origin/rejected state changed')
            require(metrics['active_day']==5 and abs(metrics['actual_fixed_irrigation_cm']-2.4)<1e-11 and metrics['external_input_age_cm_day']==0 and metrics['soil_mean_age_before_day']>metrics['soil_mean_age_after_day'],'young-water dilution/source not exercised')
        expected={(k+'-'+o,v) for k in ('surface','subsurface-interval') for o in ('O0','O2') for v in ('1.0','1.0e-300','NaN','-1.0','1001.0')}
        require(len(c['reader_refusals'])==20 and {(r['profile'],r['input']) for r in c['reader_refusals']}==expected and all(r['status']=='REFUSED' for r in c['reader_refusals']),'fixed young-water actual reader refusal missing')
        inline=q['inline'][platform];require(inline['status']=='AGE_FIXED_FILE_INLINE_O0_O2_EXACT_AND_ZERO_AGE_SHORT_NATIVE_PASS' and set(inline['profiles'])==PROFILES and set(inline['zero_initial'])=={'O0','O2'},'fixed age input form/zero-age control absent')
        for r in inline['profiles'].values():require(r['generated_closure_exact'] is True and r['physical_all_csv_and_four_native_payloads_exact'] is True and r['own']['days']==8 and exact(r['own']['own']),'fixed age file/inline closure/native drift')
        for r in inline['zero_initial'].values():require(r['days']==8 and exact(r['own']),'zero-initial fixed age native absent')
        inactive=q['inactive'][platform];require(inactive['status']=='FOUR_INACTIVE_FIXED_AGE_SOURCE_AND_ACTIVE_POND_NATIVE_EXACT' and set(inactive['profiles'])=={'0-O0','0-O2','100-O0','100-O2'},'old age context missing')
        for r in inactive['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_all_csv_four_native_payloads_exact'] is True and r['coverage']['days']==368 and len(r['coverage']['own'])==2 and all(map(exact,r['coverage']['own'])),'old age source/state changed')
    preserved=q['age_off_preservation'];require(preserved['status']=='THIRTEEN_AGE_FIXED_OFF_CURRENT_PARENT_CONTEXTS_SOURCE_NATIVE_EXACT' and len(preserved['profiles'])==13,'fixed age-off context missing')
    for r in preserved['profiles'].values():require(r['generated_provider_inputs_exact'] is True and r['physical_csv_exact'] is True and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in r['coverage']['own']),'fixed age-off physical/native drift')
    boundary=q['boundary_refusals'];require(boundary['status']=='FIXED_YOUNG_AGE_POLICY_FOREIGN_NATIVE_AND_ACTIVE_SOURCE_REFUSALS_PASS' and len(boundary['checks'])==16 and all(r['status']=='REFUSED' for r in boundary['checks']),'fixed age policy/input/candidate refusal absent')
    require(all(r.get('committed_state_unchanged') is True for r in boundary['checks'] if r['attack']=='active-nonzero-age-source'),'active fixed age candidate leaked state')
    cli=q['public_cli'];require(cli['status']=='PUBLIC_FIXED_YOUNG_AGE_BUILD_BUNDLE_RUN_ACTIVE_RESTART_PASS' and cli['warm_days']==8 and cli['window']==[4,6] and all(cli[k] is True for k in ('all_physical_age_rows_exact','all_five_csv_windows_exact','complete_native_payload_exact')),'public fixed age run/restart absent')
    base=q['base_consumer'];require(base['merge']==BASE and base['exact_complete_tree'] is True and base['actual_detached_owner']['returncode']==0 and base['actual_detached_owner']['result']['status']=='CURRENT_COMPOSED_ORIGINAL_AGE_AQUIFER_CHEMICAL_S_PULSE_R_ADMISSION_PASS','actual canonical age parent missing')
    require(set(q['reference_comparison'])=={'Windows','Ubuntu'} and all(set(p)==PROFILES for p in q['reference_comparison'].values()) and all(r['classification']=='UNRESOLVED_COMPOSITE_REFERENCE_DIFFERENCE' and r['whole_scientific_equivalence']=='NOT_QUALIFIED' for p in q['reference_comparison'].values() for r in p.values()),'fixed age reference science promoted')
    inherit=q['original_reference_inheritance'];require(inherit['status']=='EXACT_QUALIFIED_REFERENCE_EXECUTABLE_SOURCE_COMPILER_REUSED' and inherit['fresh_compile'] is False,'unbound old original reference reuse')
    require(q['workflow']['id']==44140757783 and q['workflow']['status']=='SUCCESS','fixed age actual Linux gate missing')


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty fixed age admission surface')
    for ref in (BASE,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'fixed age runtime differs from qualification')
    require(not git('diff',BASE,RUNTIME,'--','src','reference','tools'),'fixed age changed prior physical provider/reference/public driver')
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app').decode().splitlines())=={'app/hybrid_water/age_fixed_irrigation.py','app/hybrid_water/experimental_project.py','app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py'},'unqualified fixed age physical dependency delta')
    require(set(git('diff','--name-only',RUNTIME,UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'fixed age carrier changed science')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'literal composed age parent owner changed')
    added={'tests/nomacro_scheduled_subsurface/age_fixed_preserve.py','tests/nomacro_scheduled_subsurface/age_fixed_boundary_controls.py'}
    require(set(git('diff','--name-only',RUNTIME,'HEAD','--','tests').decode().splitlines())<={SELF,TEST,ENTRY}|added,'executed fixed age controller changed')
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
    for path,identity in tree(BASE,'integration').items():
        if path not in mutable:require(current.get(path)==identity,'immutable fixed age parent evidence changed: '+path)
    for path,identity in tree(SEALED,PROOF).items():
        if path not in mutable:require(current.get(path)==identity,'sealed fixed age evidence changed: '+path)
    allowed={SELF,TEST,ENTRY,*mutable,PROOF+'AGE_FIXED_MERGE_RECEIPT.json'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<=allowed,'unqualified change after fixed age seal')
    q=json.loads((ROOT/PROOF/'AGE_FIXED_QUALIFICATION.json').read_text());validate(q)
    for r in (*q['platforms'].values(),*q['original_reference'].values(),q['age_off_preservation']):require(not git('diff',r['source_commit'],RUNTIME,'--','app','src','reference','tools'),'actual fixed age execution source differs')
    spec=importlib.util.spec_from_file_location('fixed_age_parent',ROOT/ENTRY);parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent);parent.validate(json.loads((ROOT/PROOF/'AGE_COMPOSITION_QUALIFICATION.json').read_text()))
    for path,digest in q['controller_canonical_sha256'].items():require(hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==digest,'fixed age controller changed')
    for path in sorted((ROOT/PROOF).glob('AGE_*_RAW_ARCHIVE.json')):
        r=json.loads(path.read_text());archive=ROOT/PROOF/r['archive']
        require(r['all_members_forward_verified'] is True and len(r['members'])==r['member_count'] and archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'fixed age raw identity changed')
        with zipfile.ZipFile(archive) as z:
            require({n for n in z.namelist() if not n.endswith('/')}==set(r['members']),'fixed age raw member omitted')
            for name,digest in r['members'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'fixed age raw member changed')
    return dict(status='CURRENT_FIXED_YOUNG_AGE_COMPOSED_CHEMICAL_AQUIFER_S_PULSE_R_ADMISSION_PASS',runtime=RUNTIME,
                whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL',full_model_days=17536,
                water_guard_cm=1e-10,chemical_mass_guard_changed=False,age_units='cm day',native_codec='S5AGE002')


if __name__=='__main__':print(json.dumps(verify(),indent=2))
