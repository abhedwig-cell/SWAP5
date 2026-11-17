"""Exact sealed age/RC3/local-wetting composition admission authority."""
from pathlib import Path
import hashlib
import importlib.util
import json
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
PROOF='integration/f-ci/nomacro-complete01/'
PARENT='744eb19ea096bf3622c9e044e8119f4247c9f358'
CANONICAL='e5b3232926e3f24641c4cb0e58db57f115946b59'
RUNTIME='8eff1af5919ff4698b858e5353a13f06cf7a1c5e'
UBUNTU='304e528438f13270f9b421a2a4f386d71ec451dc'
SEALED='5912bee4e9f21f4cc8cc142576ac81fa3c7bacd5'
ENTRY='tests/nomacro_scheduled_subsurface/age_verify.py'
SELF='tests/nomacro_scheduled_subsurface/age_composition_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_age_composition_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('age_composition_admission',ROOT/'tests/nomacro_scheduled_subsurface/age_composition_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""


def require(ok,why):
    if not ok:raise ValueError(why)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)


def tree(ref,prefix):
    return {row.split('\t',1)[1]:row.split('\t',1)[0] for row in git('ls-tree','-r',ref,'--',prefix).decode().splitlines()}


def validate(q):
    require(q['status']=='AGE_RC3_WETTING_CANONICAL_COMPOSITION_QUALIFIED' and q['runtime']==RUNTIME and q['ubuntu']==UBUNTU and q['canonical_parent']==CANONICAL,'foreign age composition source')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['active_macro_qualification'] is False,'unqualified age composition promotion')
    require(q['water_guard_cm']==1e-10 and q['chemical_mass_guard_changed'] is False and q['age_tolerance']=='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)','composition guards changed')
    require(q['workflow']['id']==44134056082 and q['workflow']['status']=='SUCCESS','selected composition Linux run missing')
    require(q['age_workflow']['id']==44132663545 and q['age_workflow']['status']=='FAILURE_RETAINED' and q['age_workflow']['age_subgate']=='FOUR_FULL_AGE_SOURCE_STATE_OUTPUT_AND_ACTIVE_CONTROLS_PASS','age subgate outcome misrepresented')
    require(set(q['age'])==set(q['wetting'])=={'Windows','Ubuntu'},'composition platform missing')
    profiles={a+'-'+o for a in ('0','100') for o in ('O0','O2')}
    for platform,r in q['age'].items():
        require(r['status']=='CANONICAL_COMPOSITION_FOUR_FULL_AGE_SOURCE_STATE_OUTPUT_EXACT' and set(r['profiles'])==profiles,'complete composed age missing')
        require(r['water_guard_cm']==1e-10 and r['chemical_mass_guard_changed'] is False and r['whole_scientific_equivalence']=='NOT_QUALIFIED','actual composed age guards changed')
        for p in r['profiles'].values():
            require(p['days']==1096 and p['prior_native_adopted'] is False,'old age native rebound or period incomplete')
            require(all(p[k] is True for k in ('generated_sources_exact','compiled_closure_inputs_exact','complete_physical_age_output_rows_exact','all_five_csv_exact','all_nine_full_native_payloads_exact')),'composed age physics/output/native drift')
            require(p['effluent']['all_daily_mean_and_volume_fields_match_full_precision_probe'] is True and p['effluent']['missing_value']==-9999,'composed age units changed')
            require(len(p['own'])==4 and {(w['start'],w['end']) for w in p['own']}=={(2,4),(199,201),(365,367),(530,532)} and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged','all_four_age_csv_exact')) for w in p['own']),'composed age native replay missing')
        wet=q['wetting'][platform]
        require(wet['status']=='SELECTED_CANONICAL_COMPOSITION_PASS' and wet['tolerances_changed'] is False and wet['original_full_science']=='FAIL_PRESERVED','prior wetting science promoted')
        require(set(wet['profiles'])=={s+'-'+o for s in ('water-surface-history','chemical-surface-history') for o in ('O0','O2')},'wetting composition profile missing')
        for p in wet['profiles'].values():
            require(p['aquifer_enabled'] is False and p['all_other_identity_fields_exact'] is True and p['input_exact'] is True and p['prefix_physical_exact'] is True and p['coverage']['days']==365,'composed wetting closure/native absent')
            require(len(p['coverage']['own'])==3 and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in p['coverage']['own']),'composed wetting own state absent')
    require(set(q['controls'])=={'Windows','Ubuntu'},'composed age rollback platform absent')
    for controls in q['controls'].values():
        require(set(controls)=={'O0','O2'},'composed age rollback optimization absent')
        for r in controls.values():
            require(r['status']=='ORIGINAL_AGE_ACTIVE_POND_TRANSACTIONS_REFUSALS_AND_ORIGINS_PASS' and len(r['checks'])==16 and all(c['status']=='REFUSED' for c in r['checks']),'composed age candidate refusals missing')
            require(all(r[k] is True for k in ('discard_replay_exact','disk_recovery_exact','committed_state_unchanged','origins_unchanged','foreign_policy_refused')),'composed age state ownership changed')
    p=q['preservation'];require(p['status']=='NINE_EXACT_CONTEXTS_PASS_PULSE_SOURCE_CHANGE_SELECTED_SEPARATELY' and p['raw_outcome']=='FAILED_AT_CHANGED_PULSE_SOURCE' and len(p['profiles'])==9,'composed age-off context missing')
    require(set(p['profiles'])=={'fixed-point-O2','scheduled-water-O2','grass','hupsel','salt','scheduled-chemical-point-O2','scheduled-chemical-interval-O2','aquifer-sorption-decay','aquifer-stiff-loss'},'composed age-off scope changed')
    for r in p['profiles'].values():require(all(r[k] is True for k in ('all_generated_sources_exact','provider_flags_inputs_exact','physical_csv_prefix_exact','exact_current_source_binding')),'composed age-off source/physical drift')
    require(q['parent_owner']['verified_head']=='e28475719846b533c0b3726cd6a1a1f3360de575' and q['parent_owner']['status']=='CURRENT_ORIGINAL_AGE_AQUIFER_CHEMICAL_S_PULSE_R_ADMISSION_PASS','actual age parent owner not established')
    require(set(q['pulse'])=={'Windows','Ubuntu'},'fresh repaired pulse platform missing')
    for platform,pulse in q['pulse'].items():
        require(pulse['policy']=='original-adaptive-irrigation-pulse-v1' and pulse['water_guard_cm']==pulse['solute_guard_mg_cm2']==1e-10 and pulse['tolerances_changed'] is False and pulse['science']=='NOT_QUALIFIED','repaired pulse numerical/scientific scope changed')
        require(set(pulse['cases'])=={'water-surface-history','chemical-surface-history'},'repaired pulse physical context missing')
        for case in pulse['cases'].values():
            require(set(case)=={'O0','O2'},'repaired pulse optimization missing')
            for r in case.values():
                require(r['short']['days']==6 and all(r['short']['own'][k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')),'repaired pulse short native missing')
                require(r['full']['days']==r['full']['budgets']['days']==1096 and all(0<=r['full']['budgets'][k]<=1e-10 for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'repaired pulse incomplete or imbalanced')
                require(len(r['full']['own'])==6 and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in r['full']['own']),'repaired pulse complete native missing')


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty age composition admission surface')
    for ref in (PARENT,CANONICAL,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'composed age runtime differs from qualification')
    require(set(git('diff','--name-only',RUNTIME,UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'composition carrier changed science')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(PARENT,ENTRY).decode(),'literal age admission owner changed')
    for prefix in ('tests','reference','src','app','tools','.github'):
        if prefix in ('app','src','reference','tools'):continue
        delta=set(git('diff','--name-only',RUNTIME,'HEAD','--',prefix).decode().splitlines())
        require(delta<={SELF,TEST,ENTRY},'executed composition controller changed')
    # Complete immutable evidence from both actual parents remains literal.
    mutable={PROOF+n for n in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')}
    current=tree('HEAD','integration')
    for parent in (PARENT,CANONICAL):
        for path,identity in tree(parent,'integration').items():
            if path not in mutable:require(current.get(path)==identity,'immutable parent evidence changed: '+path)
    for path,identity in tree(SEALED,PROOF).items():
        if path not in mutable:require(current.get(path)==identity,'sealed composition evidence changed: '+path)
    allowed={SELF,TEST,ENTRY,*mutable,PROOF+'AGE_MERGE_RECEIPT.json'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<=allowed,'unqualified change after composition seal')
    spec=importlib.util.spec_from_file_location('age_parent',ROOT/ENTRY);parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent)
    original=json.loads((ROOT/PROOF/'AGE_QUALIFICATION.json').read_text());parent.validate(original)
    q=json.loads((ROOT/PROOF/'AGE_COMPOSITION_QUALIFICATION.json').read_text());validate(q)
    for r in (*q['age'].values(),q['preservation']):require(not git('diff',r.get('source',r.get('source_commit')),RUNTIME,'--','app','src','reference','tools'),'actual composed execution source differs')
    for path,digest in q['controller_canonical_sha256'].items():require(hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==digest,'composition controller changed')
    for path in sorted((ROOT/PROOF).glob('AGE_*_RAW_ARCHIVE.json')):
        r=json.loads(path.read_text());archive=ROOT/PROOF/r['archive']
        require(r['all_members_forward_verified'] is True and len(r['members'])==r['member_count'] and archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'age composition raw identity changed')
        with zipfile.ZipFile(archive) as z:
            require({n for n in z.namelist() if not n.endswith('/')}==set(r['members']),'age raw members omitted')
            for name,digest in r['members'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'age raw member changed')
        for name,origin in r.get('origins',{}).items():
            old=json.loads((ROOT/PROOF/origin['archive_record']).read_text());require(old['members'][origin['member']]==r['members'][name],'composition parent subset rebound')
    return dict(status='CURRENT_COMPOSED_ORIGINAL_AGE_AQUIFER_CHEMICAL_S_PULSE_R_ADMISSION_PASS',runtime=RUNTIME,
                whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL',full_model_days=8768,
                water_guard_cm=1e-10,chemical_mass_guard_changed=False,age_units='cm day',native_codec='S5AGE002')


if __name__=='__main__':print(json.dumps(verify(),indent=2))
