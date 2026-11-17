"""Source-bound scheduled SSDI successor, preserving prior pulse/R admission."""
from pathlib import Path
import hashlib,json,math,subprocess
ROOT=Path(__file__).resolve().parents[2]
R_ADMITTED='a9044fdab7e333058c6a4dab34884e56e33c35a9'
S_RUNTIME='b97a04d2c9509e4aa49a29a9a582df2ac4dd33d2'
S_UBUNTU='451b28ea4a1b68611952c55437bdcf37c6017ac4'
S_SEALED='504fd73906740b9c43a2d54371184980d7e42e5a'
S_PROOF='integration/f-ci/nomacro-complete01/'
PULSE_ADMITTED='fd162a1ea22c41e798a431f39957aaff9c173e46'
COMPOSED_RUNTIME='PENDING_COMPOSED_RUNTIME'
COMPOSED_SEALED='PENDING_COMPOSED_SEAL'
SELF='tests/nomacro_scheduled_subsurface/verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_verify.py'
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def require(test,message):
    if not test:raise ValueError(message)
def blob(ref,path):return git('show',ref+':'+path)
def validate_s(q, named, comparison, isolation, preflights, *, runtime=S_RUNTIME, ubuntu=S_UBUNTU):
    require(q['status']=='ORIGINAL_SCHEDULED_SUBSURFACE_WATER_POINT_INTERVAL_QUALIFIED' and q['runtime_source']==q['Windows_execution_source']==runtime and q['Ubuntu_execution_source']==ubuntu, 'S actual source identity')
    require((q['full_configurations'],q['full_trajectories'],q['complete_model_days'],q['standard_full_native_windows'],q['active_full_native_windows'],q['short_native_windows'])==(2,8,8768,24,8,8), 'S incomplete trajectory/native scope')
    require(q['mass_guard_cm']==1e-10 and math.isfinite(q['maximum_water_residual_cm']) and 0<=q['maximum_water_residual_cm']<=1e-10, 'S changed or invalid mass guard')
    require(all(q[name] is False for name in ('tolerances_changed','physical_equations_changed','new_persistent_codec')) and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['functional_completion']=='PARTIAL' and q['chemical_subsurface']=='REFUSED_INHERITED_DEFECT_UNCORRECTED', 'S physics/chemical/science promotion')
    require(set(q['platforms'])=={'Windows','Ubuntu'}, 'S missing platform')
    for platform,cases in q['platforms'].items():
        require(set(cases)=={'point','interval'}, 'S missing depth family')
        for name,report in cases.items():
            require(report['status']=='FULL_O0_O2_PASS' and report['configuration']==name and report['source_commit']==(runtime if platform=='Windows' else ubuntu) and report['science']=='NOT_QUALIFIED' and report['water_guard_cm']==1e-10, 'S incomplete actual report')
            require(report['inputs']['selectors']['SWMACRO']==report['inputs']['selectors']['SWSOLU']==0 and set(report['profiles'])=={'O0','O2'}, 'S changed physical scope')
            for opt,r in report['profiles'].items():
                require(r['status']=='FULL_PASS' and r['days']==r['budgets']['days']==1096, 'S incomplete model period')
                for key in ('max_water_cm','max_kernel_cm'):require(math.isfinite(r['budgets'][key]) and 0<=r['budgets'][key]<=1e-10, 'S water budget failed')
                require(len(r['own'])==3 and {w['start'] for w in r['own']}=={2,365,530} and all(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')) for w in r['own']), 'S ordinary/year native missing')
                require(r['short']['days']==5 and all(r['short']['own'][k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')), 'S short own native missing')
                active=r['active_own'];require(all(active[k] is True for k in ('full_period_physical_csv_suffix_exact','exact_native','origin_unchanged','active_external_discard_replay_exact','active_external_disk_recovery')), 'S active native/external missing')
                exposure=r['subsurface_exposure'];require(math.isfinite(exposure['total_cm']) and exposure['total_cm']>0 and active['actual_irrigation_day'] in exposure['days'], 'S process never active')
                require(all(r['controls'][k] is True for k in ('foreign_policy_refused','inconsistent_mass_refused','external_discard_replay_exact','external_disk_recovery')), 'S acceptance/rollback/recovery missing')
    require(set(named)=={'grass','hupsel','salt'} and all(named[k]['status']=='FULL_PASS' and named[k]['full_days']==days and all(w['exact_native_auxiliary'] is True for w in named[k]['restart_windows']) for k,days in (('grass',1827),('hupsel',1096),('salt',1461))), 'S named full/native regression missing')
    require(comparison['status']=='ALL_EIGHT_ACTUAL_COMPOSITION_TRAJECTORIES_AND_NATIVE_EXACT' and len(comparison['profiles'])==8 and all(v['days']==1096 and v['all_physical_rows_exact'] is True and v['all_csv_rows_exact'] is True and v['complete_terminal_native_exact'] is True for v in comparison['profiles'].values()), 'S actual composition drift')
    require(set(isolation['profiles'])=={'O0','O2'} and all(v['status']=='INTERLEAVED_INDEPENDENT_ORIGINS_ACTIVE_IRRIGATION_PASS' and v['alternating_steps']==6 for v in isolation['profiles'].values()), 'S independent active origins missing')
    require(set(preflights)=={'Windows','Ubuntu-point','Ubuntu-interval'}, 'S missing native input/refusal platform')
    for report in preflights.values():
        require(report['status']=='SCHEDULED_SSDI_ORIGINAL_READER_AND_ACTIVE_TRANSACTIONS_PASS', 'S incomplete preflight')
        tests=report['checks'];refusals=[v for v in tests if v.get('status')=='REFUSED'];require(len(refusals)==7 and sum(v['test']=='future-chemical-SSDI' for v in refusals)==1, 'S native or future chemical input refusal missing')
        require({(v['test'],v.get('optimization')) for v in refusals if v['test']!='future-chemical-SSDI'}=={(name,opt) for name in ('reversed','outside-domain','nonfinite') for opt in ('O0','O2')}, 'S actual original reader domains missing')


def verify_s():
    require(not git('diff','HEAD','--','src','app','reference','tools','tests','.github','integration'),'dirty qualified surface')
    git('merge-base','--is-ancestor',R_ADMITTED,S_RUNTIME);git('merge-base','--is-ancestor',S_RUNTIME,S_SEALED);git('merge-base','--is-ancestor',S_SEALED,'HEAD')
    paths=set(git('diff','--name-only',R_ADMITTED,S_RUNTIME,'--','app','src','reference','tools').decode().splitlines())
    require(paths=={'app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py','app/hybrid_water/experimental_project.py','app/hybrid_water/scheduled_subsurface_irrigation.py'}, 'S unqualified physical dependency delta')
    surface=['app','src','reference','tools','.github','tests/nomacro_scheduled_subsurface/run.py','tests/nomacro_scheduled_subsurface/preflight.py','tests/nomacro_drainage','tests/nomacro_mixtures']
    require(not git('diff',COMPOSED_RUNTIME,'HEAD','--',*surface), 'runtime differs from qualified S source')
    require(not git('diff',S_RUNTIME,S_UBUNTU,'--',*[p for p in surface if p!='.github']), 'S actual Ubuntu runtime drift')
    require(set(git('diff','--name-only',S_RUNTIME,S_UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'}, 'S carrier changed physical source')
    def sealed(name):
        path=S_PROOF+name+'.json';require(blob('HEAD',path)==blob(S_SEALED,path),'S immutable proof changed: '+name);return json.loads((ROOT/path).read_text())
    q=sealed('QUALIFICATION')
    validate_s(q,sealed('WINDOWS_NAMED'),sealed('COMPOSITION_COMPARE'),sealed('WINDOWS_ISOLATION'),dict(Windows=sealed('WINDOWS_PREFLIGHT'),**{'Ubuntu-point':sealed('UBUNTU_POINT_PREFLIGHT'),'Ubuntu-interval':sealed('UBUNTU_INTERVAL_PREFLIGHT')}))
    for platform in ('Windows','Ubuntu'):
        for case in ('point','interval'):require(q['platforms'][platform][case]==sealed(platform.upper()+'_'+case.upper()),'S embedded/raw report differs')
    for label in ('WINDOWS_RAW','UBUNTU_RAW','HISTORICAL_RAW'):
        record=sealed(label+'_ARCHIVE');require(record['all_members_forward_verified'] is True and hashlib.sha256((ROOT/S_PROOF/record['archive']).read_bytes()).hexdigest()==record['sha256'],'S raw evidence changed')
    diagnostic=sealed('ORIGINAL_CHEMICAL_AUDIT');require(diagnostic['classification']=='INHERITED_DEFECT' and diagnostic['subsurface_all_output_rows_exact_across_concentration'] is True and diagnostic['surface_solute_maximum_differences']['S_IRRIG']==48.0 and diagnostic['production_change'] is False,'S inherited chemical defect lost')
    for name in ('PRIOR_SOURCE_COMPARISON','ORIGINAL_REFERENCE_POINT','ORIGINAL_REFERENCE_INTERVAL','WINDOWS_NAMED_COMMANDS','UBUNTU_POINT_ARTIFACT','UBUNTU_INTERVAL_ARTIFACT'):sealed(name)
    allowed={SELF,TEST,S_PROOF+'CI_SELECTION.json',S_PROOF+'STATUS.json',S_PROOF+'MERGE_RECEIPT.json',S_PROOF+'GAP_MATRIX.json'}
    require(set(git('diff','--name-only',COMPOSED_SEALED,'HEAD').decode().splitlines())<=allowed,'unqualified delta after S seal')
    return q



def verify():
    original=verify_s()
    require(blob('HEAD','tests/hupsel51/verify_successor.py')==blob(PULSE_ADMITTED,'tests/hupsel51/verify_successor.py'),'historical pulse/R entry changed')
    require(not git('diff',PULSE_ADMITTED,'HEAD','--','integration/irrigation-pulse-time01'),'pulse sealed proof changed')
    def sealed(name):
        path=S_PROOF+name+'.json';require(blob('HEAD',path)==blob(COMPOSED_SEALED,path),'composed proof changed: '+name);return json.loads((ROOT/path).read_text())
    consumer=sealed('PULSE_BASE_CONSUMER');require(consumer['source']==PULSE_ADMITTED and consumer['returncode']==0 and consumer['result']['status']=='CURRENT_R_PLUS_LOCAL_PULSE_ADMISSION_PASS','actual immutable pulse/R consumer missing')
    q=sealed('PULSE_COMPOSED_QUALIFICATION')
    validate_s(q,sealed('PULSE_COMPOSED_NAMED'),sealed('PULSE_COMPOSED_COMPARE'),sealed('PULSE_COMPOSED_ISOLATION'),dict(Windows=sealed('PULSE_COMPOSED_PREFLIGHT'),**{'Ubuntu-point':sealed('PULSE_COMPOSED_UBUNTU_POINT_PREFLIGHT'),'Ubuntu-interval':sealed('PULSE_COMPOSED_UBUNTU_INTERVAL_PREFLIGHT')}),runtime=COMPOSED_RUNTIME,ubuntu=q['Ubuntu_execution_source'])
    require(q['runtime_source']==COMPOSED_RUNTIME,'foreign composed runtime')
    pulse=sealed('PULSE_CODE_PRESERVATION');require(pulse['status']=='ACTUAL_R_PULSE_COMPOSITION_GENERATED_INPUT_CLOSURE_AND_NATIVE_EXACT' and len(pulse['profiles'])==4 and all(v['all_emitted_dependencies_and_inputs_exact'] and v['prefix_exact_to_qualified_full'] for v in pulse['profiles'].values()),'pulse physical/native preservation missing')
    for label in ('PULSE_COMPOSED_WINDOWS_RAW','PULSE_COMPOSED_UBUNTU_RAW'):
        rec=sealed(label+'_ARCHIVE');require(rec['all_members_forward_verified'] and hashlib.sha256((ROOT/S_PROOF/rec['archive']).read_bytes()).hexdigest()==rec['sha256'],'composed raw identity')
    return dict(status='CURRENT_R_PULSE_AND_SCHEDULED_SSDI_ADMISSION_PASS',runtime=COMPOSED_RUNTIME,scheduled_full_days=q['complete_model_days'],pulse_full_days=consumer['result']['inherited_full_days'],prior_R_full_days=consumer['result']['prior_R_full_days'],whole_scientific_equivalence='NOT_QUALIFIED',mass_guard_cm=1e-10)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
