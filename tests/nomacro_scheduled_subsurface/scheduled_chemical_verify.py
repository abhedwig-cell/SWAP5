"""Exact scheduled chemical successor to the immutable fixed/S/pulse/R chain."""
from pathlib import Path
import hashlib
import json
import math
import subprocess

ROOT=Path(__file__).resolve().parents[2]
BASE='e709ab5a4b9b858c539e3c7208b8997ea6205ce2'
RUNTIME='6c5b084d93724be546daf387f8bd1d0a31add3c9'
UBUNTU='70293c7e7807d02c08643617e63b49e054044221'
SEALED='a5ee02d766a6c5434eeb613d95bc003e9a301ef7'
PROOF='integration/f-ci/nomacro-complete01/'
SELF='tests/nomacro_scheduled_subsurface/scheduled_chemical_verify.py'
TEST='tests/nomacro_scheduled_subsurface/test_scheduled_chemical_verify.py'
ENTRY='tests/nomacro_scheduled_subsurface/chemical_verify.py'
HOOK="    import importlib.util\n    spec=importlib.util.spec_from_file_location('scheduled_chemical_admission',ROOT/'tests/nomacro_scheduled_subsurface/scheduled_chemical_verify.py')\n    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)\n    return owner.verify()\n"

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def require(test,message):
    if not test:raise ValueError(message)
def bounded(value,limit=1e-10):return isinstance(value,(int,float)) and math.isfinite(value) and 0<=value<=limit
def exact(w):return all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged'))


def validate(q):
    require(q['status']=='ORIGINAL_SCHEDULED_CHEMICAL_POINT_INTERVAL_BRANCH_QUALIFIED' and q['runtime']==RUNTIME and q['ubuntu']==UBUNTU,'foreign/incomplete scheduled chemistry')
    require((q['full_trajectories'],q['full_model_days'],q['full_native_windows'],q['short_native_windows'])==(8,8768,32,8),'incomplete scheduled chemistry scope')
    require(q['water_guard_cm']==q['solute_guard_mg_cm2']==1e-10,'changed scheduled mass guards')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED','unqualified migration/science promotion')
    require(all(q[k] is False for k in ('new_physical_formula','new_persistent_codec','tolerances_changed','active_macro_qualification','b1_promotion')),'unqualified scheduled physical/state promotion')
    require(set(q['platforms'])=={'Windows','Ubuntu'},'scheduled platform missing')
    for platform,cases in q['platforms'].items():
        require(set(cases)=={'point','interval'},'scheduled geometry missing')
        for kind,report in cases.items():
            require(report['status']=='FULL_O0_O2_PASS' and report['configuration']==kind and report['science']=='NOT_QUALIFIED' and report['new_persistent_codec'] is False,'actual scheduled run incomplete')
            require(report['water_guard_cm']==report['chemical_guard_mg_cm2']==1e-10,'actual scheduled guards changed')
            selected=report['inputs']['selectors']
            require(selected['SWMACRO']==selected['SWIRFIX']==0 and selected['SWSOLU']==1,'foreign scheduled physical input')
            require(set(report['profiles'])=={'O0','O2'},'scheduled optimization missing')
            if platform=='Ubuntu':require(report['source_commit']==UBUNTU,'actual Ubuntu source mismatch')
            for profile in report['profiles'].values():
                require(profile['status']=='FULL_PASS' and profile['days']==profile['budgets']['days']==1096,'scheduled period incomplete')
                require(all(bounded(profile['budgets'][k]) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'scheduled mass imbalance')
                water=profile['irrigation_water_cm'];mass=profile['irrigation_mass_mg_cm2']
                require(bounded(abs(water-(3.2 if kind=='point' else 8.7)),1e-12) and bounded(abs(mass-water*20)),'scheduled actual source absent/wrong')
                require(profile['first_actual_source_day']==252 and profile['active_source_day']==545,'scheduled source exposure wrong')
                require(len(profile['own'])==4 and {(w['start'],w['end']) for w in profile['own']}=={(2,4),(365,367),(530,532),(544,546)} and all(exact(w) for w in profile['own']),'scheduled active/year native missing')
                require(profile['short']['days']==5 and exact(profile['short']['own']),'scheduled short native missing')
                controls=profile['controls']
                require(controls['actual_irrigation_day']==545 and all(controls[k] is True for k in ('foreign_policy_refused','active_discard_replay_exact','active_disk_recovery','inconsistent_chemical_mass_refused','committed_state_unchanged','origin_unchanged')),'scheduled active acceptance/refusal state missing')
    ref=q['original_reference']
    require(ref['status']=='ORIGINAL_SCHEDULED_CHEMICAL_SOURCE_POINT_INTERVAL_O0_O2_REFERENCE_PASS' and ref['whole_scientific_equivalence']=='NOT_QUALIFIED' and ref['SWAP5_scheduled_chemical_activation'] is False,'unqualified original scheduled reference')
    require(set(ref['profiles'])=={'original-O0','original-O2','corrected-O0','corrected-O2'},'original scheduled optimization missing')
    for name,cases in ref['profiles'].items():
        require(set(cases)=={kind+'-'+str(c) for kind in ('point','interval') for c in (0,20)},'original scheduled concentration/depth missing')
        for case,report in cases.items():
            require(report['days']==1096 and bounded(report['max_printed_solute_residual_mg_cm2']),'original scheduled period/mass failed')
            expected=(64 if case.startswith('point') else 174) if name.startswith('corrected') and case.endswith('-20') else 0
            require(bounded(abs(report['irrigation_mass_mg_cm2']-expected)),'original omission/correction missing')
            if name.startswith('corrected'):require(bounded(abs(report['mass_difference_mg_cm2'])),'original scheduled mass/source mismatch')
    controls=q['native_controls'];require(controls['status']=='SCHEDULED_CHEMICAL_NATIVE_INPUT_AND_INDEPENDENT_ORIGINS_PASS','scheduled native controls incomplete')
    tests=controls['checks']
    require(len(tests)==12 and {(r['test'],r['optimization']) for r in tests if r['status']=='REFUSED'}=={(name,opt) for name in ('reversed','outside-domain','nonfinite-depth','negative-concentration','nonfinite-concentration') for opt in ('O0','O2')},'scheduled original depth/concentration refusal missing')
    independent=[r for r in tests if r['test']=='independent-native-origins']
    require({r['optimization'] for r in independent}=={'O0','O2'} and all(r['status']=='PASS' and r['alternating_steps']==6 and all(r[k] is True for k in ('active_source','physical_exact','origins_unchanged')) for r in independent),'scheduled active independent state missing')
    preserved=q['preservation'];require(preserved['status']=='SCHEDULED_CHEMICAL_SELECTION_PRESERVES_ADMITTED_CONTEXTS_PASS','admitted source/native preservation missing')
    required={'fixed-point-O0','fixed-point-O2','scheduled-water-O0','scheduled-water-O2','grass','hupsel','salt','pulse-water','pulse-chemical'}
    require(set(preserved['profiles'])==required,'admitted context missing')
    for name,r in preserved['profiles'].items():
        require(all(r[k] is True for k in ('all_generated_sources_exact','provider_flags_inputs_exact','physical_csv_prefix_exact','exact_current_source_binding')),'admitted emitted/physical prefix drift')
        expected=201 if name.startswith('pulse') else 8 if name.startswith('fixed') else 5 if name.startswith('scheduled') else 4
        require(r['prefix']['days']==expected and all(exact(w) for w in r['prefix']['own']),'admitted native prefix missing')
        require(all(bounded(r['prefix']['budgets'][k]) for k in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2')),'admitted native prefix mass imbalance')
    base=q['base_consumer'];require(base['source']==BASE and base['returncode']==0 and base['result']['status']=='CURRENT_R_PULSE_SCHEDULED_AND_FIXED_CHEMICAL_ADMISSION_PASS','actual immutable fixed predecessor missing')


def verify():
    require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'dirty scheduled chemical surface')
    git('merge-base','--is-ancestor',BASE,RUNTIME);git('merge-base','--is-ancestor',RUNTIME,SEALED);git('merge-base','--is-ancestor',SEALED,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'scheduled chemical runtime differs from qualification')
    require(not git('diff',BASE,RUNTIME,'--','src','reference','tools'),'shared physical source/reference changed')
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app').decode().splitlines())=={'app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py','app/hybrid_water/experimental_project.py','app/hybrid_water/conserved_scheduled_subsurface_solute.py'},'unqualified scheduled application delta')
    require(set(git('diff','--name-only',RUNTIME,UBUNTU).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'scheduled carrier changed source')
    for path in ('tests/hupsel51/verify_successor.py','tests/irrigation_pulse/verify.py','tests/nomacro_scheduled_subsurface/verify.py'):
        require(blob('HEAD',path)==blob(BASE,path),'prior literal entry changed')
    body=blob('HEAD',ENTRY).decode();require(body.count(HOOK)==1 and body.replace(HOOK,'',1)==blob(BASE,ENTRY).decode(),'literal fixed consumer changed')
    require(not git('diff',BASE,'HEAD','--','integration/irrigation-pulse-time01'),'immutable pulse proof changed')
    for path in git('ls-tree','-r','--name-only',BASE,'--',PROOF).decode().splitlines():
        if Path(path).name in ('STATUS.json','CI_SELECTION.json','GAP_MATRIX.json'):continue
        require(blob('HEAD',path)==blob(BASE,path),'immutable predecessor proof changed: '+path)
    sealed=git('ls-tree','-r','--name-only',SEALED,'--',PROOF).decode().splitlines()
    for path in sealed:
        if Path(path).name.startswith('SCHEDULED_CHEMICAL_'):require(blob('HEAD',path)==blob(SEALED,path),'sealed scheduled chemistry changed: '+path)
    q=json.loads((ROOT/PROOF/'SCHEDULED_CHEMICAL_QUALIFICATION.json').read_text());validate(q)
    for report in q['platforms']['Windows'].values():require(not git('diff',report['source_commit'],RUNTIME,'--','app','src','reference','tools'),'actual Windows scheduled source differs')
    for path in sealed:
        if Path(path).name.startswith('SCHEDULED_CHEMICAL_') and path.endswith('_ARCHIVE.json'):
            r=json.loads((ROOT/path).read_text());archive=ROOT/PROOF/r['archive']
            require(r['all_members_forward_verified'] is True and r['member_count']==len(r['members']) and archive.stat().st_size==r['bytes'] and hashlib.sha256(archive.read_bytes()).hexdigest()==r['sha256'],'scheduled raw evidence changed')
    allowed={SELF,TEST,ENTRY,PROOF+'STATUS.json',PROOF+'GAP_MATRIX.json',PROOF+'CI_SELECTION.json',PROOF+'SCHEDULED_CHEMICAL_MERGE_RECEIPT.json'}
    require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<=allowed,'unqualified delta after scheduled chemical seal')
    return dict(status='CURRENT_FIXED_AND_SCHEDULED_CHEMICAL_S_PULSE_R_ADMISSION_PASS',runtime=RUNTIME,scheduled_chemical_full_days=8768,fixed_chemical_full_days=8768,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
