"""Source-bound mixed aquifer successor; prior chemical/S/pulse/R proof sealed."""
from pathlib import Path
import hashlib
import json
import math
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]
BASE='e67710244d84a9a37b30b76e853a3e5b0eeb55d2'
RUNTIME='931f4c033361bfb5139e706d92641aeafc9292df'
UBUNTU='fbe3347a484ca78cb4ce46c217b4977cc4485545'
SEALED='680df6a5cea1b66b3b79d36d1f9230db0f33ed61'
PROOF='integration/f-ci/nomacro-complete01/'
ENTRY='tests/nomacro_scheduled_subsurface/scheduled_chemical_verify.py'
SELF='tests/nomacro_scheduled_subsurface/aquifer_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_aquifer_verify.py'
HOOK="    import importlib.util\n    spec=importlib.util.spec_from_file_location('aquifer_admission',ROOT/'tests/nomacro_scheduled_subsurface/aquifer_verify.py')\n    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)\n    return owner.verify()\n"
CASES={c+'-'+o for c in ('soil-transfer','box-release','sorption-decay','stiff-loss') for o in ('O0','O2')}


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def require(ok,message):
    if not ok:raise ValueError(message)
def bounded(v):return isinstance(v,(int,float)) and math.isfinite(v) and 0<=v<=1e-10
def exact(w):return all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged'))


def validate(q):
    require(q['status']=='ORIGINAL_CORRECTED_AQUIFER_SOURCE_STATE_BRANCH_QUALIFIED' and q['baseline']==BASE and q['runtime']==RUNTIME and q['ubuntu']==UBUNTU,'foreign aquifer source/evidence')
    require(q['water_guard_cm']==q['solute_guard_mg_cm2']==1e-10,'changed aquifer guards')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['release_readiness']=='RC2_QUALIFIED_NAMED_PROFILES_ONLY','unqualified aquifer scope promotion')
    require(q['new_persistent_codec'] is True and all(q[k] is False for k in ('active_macro_qualification','b1_promotion','tolerances_changed')),'foreign aquifer state/qualification policy')
    require(q['step_policy']=='original-aquifer-loss-limited-forward-euler-v1' and q['safety_factor']==.9,'foreign aquifer clock')
    require(q['component']['status']=='PASS' and len(q['component']['records'])==2 and {r['optimization'] for r in q['component']['records']}=={0,2},'aquifer independent driver missing')
    for r in q['component']['records']:
        require(r['sources']==['src/process/mod_aquifer_solute_reservoir.f90','tests/modularity/test_aquifer_solute_reservoir.f90'] and r['compiler_requests']==3,'aquifer independent closure changed')
        require(r['inputs']['src/process/mod_aquifer_solute_reservoir.f90']=='260e6c62d8bfa285c36c357e3cda57b46a25b43df2dc1408125c7c1592350823','foreign aquifer production driver')
    require(q['original_bounds']['status']=='ORIGINAL_SWBR1_AQUIFER_OUT_OF_BOUNDS_O0_O2_PROVEN' and all(r['accessed_index']==35 and r['upper_bound']==34 for r in q['original_bounds']['profiles'].values()),'original bounds defect missing')
    require(q['original_nonfinite']['nonfinite_values']==5480 and q['original_nonfinite']['days']==1096,'original unchecked defect missing')
    require(set(q['platforms'])==set(q['controls'])==set(q['original_reference'])=={'Windows','Ubuntu'},'aquifer platform missing')
    for platform,run in q['platforms'].items():
        require(run['status']=='EIGHT_FULL_PERIODS_COMPOUND_NATIVE_PASS' and set(run['cases'])==CASES,'aquifer full case missing')
        require(run['guard_mg_cm2']==1e-10 and run['science']=='NOT_QUALIFIED','aquifer actual guard/promotion changed')
        if platform=='Ubuntu':require(run['source_commit']==UBUNTU,'aquifer Linux source differs')
        for name,r in run['cases'].items():
            require(r['status']=='FULL_COMPOUND_AND_EXACT_NATIVE_PASS' and r['trajectory']['days']==1096,'aquifer period incomplete')
            require(all(bounded(r['trajectory']['budgets'][k]) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'aquifer water/soil imbalance')
            require(set(r['maximum_residuals'])=={'aquifer_residual_mg_cm2','aquifer_exchange_residual_mg_cm2','soil_aquifer_residual_mg_cm2'} and all(map(bounded,r['maximum_residuals'].values())),'aquifer compound mass imbalance')
            require(len(r['own'])==4 and {(w['start'],w['end']) for w in r['own']}=={(2,4),(199,201),(365,367),(530,532)} and all(map(exact,r['own'])),'aquifer exact native/year missing')
            require(len(r['final_aquifer_state'])==7 and all(map(math.isfinite,r['final_aquifer_state'])) and r['final_aquifer_state'][0]>=0,'aquifer state nonfinite/negative')
            if name.startswith('stiff'):require(r['final_aquifer_state'][6]>0,'aquifer new loss bound not exercised')
        controls=q['controls'][platform]
        require(set(controls)=={'O0','O2'},'aquifer transaction optimization missing')
        for c in controls.values():
            require(c['status']=='AQUIFER_TRANSACTIONS_REFUSALS_INDEPENDENT_ORIGINS_PASS' and c['independent_steps']==6 and all(c[k] is True for k in ('discard_replay_exact','disk_recovery_exact','committed_state_unchanged','origin_unchanged')),'aquifer transaction/state isolation missing')
            require(len(c['checks'])==8 and {t['attack'] for t in c['checks']}=={'concentration','capacity','stock','transfer','surface','decay','nonfinite','negative-count'} and all(t['refused'] is True for t in c['checks']),'aquifer candidate refusal missing')
        ref=q['original_reference'][platform]
        require(ref['status']=='CORRECTED_ORIGINAL_AQUIFER_SOIL_BOX_COMPOUND_REFERENCE_O0_O2_PASS' and set(ref['profiles'])=={'legacy-index-only-O0','legacy-index-only-O2','corrected-O0','corrected-O2'},'aquifer actual original reference incomplete')
        require(ref['helper_canonical_sha256']=='260e6c62d8bfa285c36c357e3cda57b46a25b43df2dc1408125c7c1592350823' and ref['safety_factor']==.9 and ref['chemical_guard_mg_cm2']==1e-10,'aquifer reference provider/guard changed')
        for name,p in ref['profiles'].items():
            expected={'soil-transfer'} if name.startswith('legacy') else {'soil-transfer','box-release','sorption-decay','stiff-loss'}
            require(set(p['cases'])==expected,'aquifer original period missing')
            for case,r in p['cases'].items():
                require(r['days']==1096,'original aquifer period censored')
                if name.startswith('legacy'):require(r['max_residual_mg_cm2']['compound']>1e-10,'legacy time defect absent')
                else:
                    require(all(map(bounded,r['max_residual_mg_cm2'].values())) and r['minimum_concentration_mg_cm3']>=0,'corrected original aquifer imbalance')
                    if case=='stiff-loss':require(r['loss_limited_steps']>0,'original loss limit not exercised')
    native=q['native_refusals'];require(native['status']=='AQUIFER_INVALID_INPUT_AND_PRIVATE_NATIVE_REFUSALS_PASS' and len(native['checks'])==32 and all(t['status']=='REFUSED' for t in native['checks']),'aquifer actual native/input refusal missing')
    require({(t['optimization'],t['test']) for t in native['checks']}=={(o,n) for o in ('O0','O2') for n in ('invalid-input-DAQUIF-0.0','invalid-input-POROS-0.0','invalid-input-KFSAT--1.0','invalid-input-DECSAT--1.0','invalid-input-CDRAINI--1.0','invalid-input-CDRAINI-NaN','invalid-input-BDENS-missing',*('native-'+k for k in ('concentration','capacity','stock','soil-cumulative','surface-cumulative','decay-cumulative','count','nonfinite','truncated')))},'aquifer native/input exposure changed')
    composition=q['chemical_composition'];require(composition['status']=='AQUIFER_FIXED_CHEMICAL_FULL_O0_O2_COMPOSITION_PASS' and set(composition['profiles'])=={'O0','O2'},'aquifer chemical composition missing')
    for r in composition['profiles'].values():require(r['days']==1096 and bounded(abs(r['actual_ssdi_mass_mg_cm2']-48)) and bounded(r['maximum_compound_residual_mg_cm2']) and len(r['own'])==3 and all(map(exact,r['own'])),'aquifer chemical source/state failed')
    preservation=q['preservation'];required={'fixed-point-O0','fixed-point-O2','scheduled-water-O0','scheduled-water-O2','grass','hupsel','salt','pulse-water','pulse-chemical'}|{'scheduled-chemical-'+k+'-'+o for k in ('point','interval') for o in ('O0','O2')}
    require(preservation['status']=='AQUIFER_OFF_PRESERVES_THIRTEEN_ADMITTED_CONTEXTS_PASS' and set(preservation['profiles'])==required,'aquifer-off context missing')
    for r in preservation['profiles'].values():require(all(r[k] is True for k in ('all_generated_sources_exact','provider_flags_inputs_exact','physical_csv_prefix_exact','exact_current_source_binding')) and all(map(exact,r['prefix']['own'])),'aquifer-off physical/native drift')
    require(q['base_consumer']['source']==BASE and q['base_consumer']['returncode']==0 and q['base_consumer']['result']['status']=='CURRENT_FIXED_AND_SCHEDULED_CHEMICAL_S_PULSE_R_ADMISSION_PASS','actual immutable aquifer predecessor missing')
    require(q['reference_rendering']['current_production_patch_matches_actual_generated_source'] is True,'actual aquifer reference rendering changed')
    require(set(q['reference_comparison'])==CASES and all(r['whole_model_equivalence']=='NOT_QUALIFIED' and r['interpretation'].startswith('UNRESOLVED_NUMERICAL_DIFFERENCE:') for r in q['reference_comparison'].values()),'unqualified aquifer equivalence promotion')
    require(q['workflow']['id']==44100595269 and q['workflow']['status']=='SUCCESS','aquifer selected Linux run missing')


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty aquifer admission surface')
    git('merge-base','--is-ancestor',BASE,RUNTIME);git('merge-base','--is-ancestor',RUNTIME,SEALED);git('merge-base','--is-ancestor',SEALED,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'aquifer runtime differs from qualification')
    require(set(git('diff','--name-only',RUNTIME,UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'aquifer carrier changed production')
    expected={'app/hybrid_water/conserved_aquifer_solute.py','app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py','app/hybrid_water/experimental_project.py','src/process/mod_aquifer_solute_reservoir.f90','reference/swap-4.3.1/patches/NOMACRO-AQUIFER-SOLUTE-01/source.py','reference/swap-4.3.1/patches/NOMACRO-AQUIFER-SOLUTE-01/run.py'}
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==expected,'unqualified aquifer physical dependency delta')
    for path in ('tests/hupsel51/verify_successor.py','tests/irrigation_pulse/verify.py','tests/nomacro_scheduled_subsurface/verify.py','tests/nomacro_scheduled_subsurface/chemical_verify.py'):
        require(blob('HEAD',path)==blob(BASE,path),'prior literal aquifer predecessor entry changed')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'literal scheduled chemical owner body changed')
    require(not git('diff',BASE,'HEAD','--','integration/irrigation-pulse-time01'),'immutable aquifer predecessor pulse proof changed')
    for path in git('ls-tree','-r','--name-only',BASE,'--',PROOF).decode().splitlines():
        if Path(path).name in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json'):continue
        require(blob('HEAD',path)==blob(BASE,path),'immutable aquifer predecessor proof changed: '+path)
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PROOF).decode().splitlines():
        if Path(path).name.startswith('AQUIFER_'):require(blob('HEAD',path)==blob(SEALED,path),'sealed aquifer proof changed: '+path)
    q=json.loads((ROOT/PROOF/'AQUIFER_QUALIFICATION.json').read_text());validate(q)
    for source in (q['platforms']['Windows']['source_commit'],q['preservation']['source_commit'],q['chemical_composition']['source_commit']):
        require(not git('diff',source,RUNTIME,'--','app','src','reference','tools'),'actual Windows aquifer production surface differs')
    sources=json.loads((ROOT/PROOF/'AQUIFER_TEST_SOURCES.json').read_text())
    for path,digest in sources['sources'].items():require(hashlib.sha256((ROOT/path).read_bytes().replace(b'\r\n',b'\n')).hexdigest()==digest,'actual aquifer controller source changed')
    for path in sorted((ROOT/PROOF).glob('AQUIFER_*_RAW_ARCHIVE.json')):
        record=json.loads(path.read_text());archive=ROOT/PROOF/record['archive']
        require(record['all_members_forward_verified'] is True and record['member_count']==len(record['members']) and archive.stat().st_size==record['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256'],'aquifer raw archive identity changed')
        with zipfile.ZipFile(archive) as z:
            require({n for n in z.namelist() if not n.endswith('/')}==set(record['members']),'aquifer raw member omitted')
            for name,digest in record['members'].items():require(hashlib.sha256(z.read(name)).hexdigest()==digest,'aquifer raw member changed')
    allowed={SELF,TEST,ENTRY,PROOF+'STATUS.json',PROOF+'GAP_MATRIX.json',PROOF+'CI_SELECTION.json',PROOF+'AQUIFER_MERGE_RECEIPT.json'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<=allowed,'unqualified delta after aquifer seal')
    return dict(status='CURRENT_AQUIFER_FIXED_SCHEDULED_CHEMICAL_S_PULSE_R_ADMISSION_PASS',runtime=RUNTIME,platform_full_days=17536,additional_chemical_days=2192,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
