"""Bounded current-source admission; old source/proofs retain their own verdicts."""
from pathlib import Path
import hashlib,json,math,subprocess
ROOT=Path(__file__).resolve().parents[2]
BASE='d4ccdc7cb9e3d18ed044e74cd2d277252b291461'
RUNTIME='4156596c70460a849892d1d81fd69853bf68f50c'
INCOMING='8dcda0fb247ae7823d720817d6340114d5227728'
COMPOSED='d0e34c8764e334b078c1b256a181890310cd19c3'
COMPOSITION_SHA256='19cf5901d186dcbb9dce6a5abe9ac3bc491dd330db89131f0c18f11964384edc'
PROOF='integration/pondmx-restart01/'
SELF='tests/hupsel51/verify_successor.py'
QUALIFICATION_SHA256='899f3656ccfa58b6deb0287ea0693d108f64d6274f1efa3b24091c1f794ffabe'
HOOK='''    if (ROOT/'integration/pondmx-restart01/QUALIFICATION.json').is_file():
        import runpy
        return runpy.run_path(str(ROOT/'tests/pondmx_restart/verify.py'))['verify']()
'''


def require(ok,message):
    if not ok:raise ValueError(message)


def validate(q):
    require(q['baseline']==BASE and q['runtime_source']==RUNTIME,'foreign source binding')
    require(q['water_guard_cm']==q['solute_guard_mg_cm2']==1e-10 and not q['tolerances_changed'],'changed tolerance')
    require(q['science']=='NOT_QUALIFIED','science promotion')
    full=q['results']['full'];require(set(full['reports'])=={'water-surface-history','chemical-surface-history'},'missing full configuration')
    for name,c in full['reports'].items():
        require(c['status']=='SCHEDULED_PONDMX_RESTART_FULL_O0_O2_PASS' and c['missing_history_policy_refused'],'unfinished/foreign policy')
        for opt in ('O0','O2'):
            r=c[opt];f=r['full']
            require(f['status']=='FULL_PASS' and f['days']==1096 and f['budgets']['days']==1096,'incomplete full period')
            require(f['prior_failed_source_full_physics_and_csv_exact'] and r['old_source_checkpoint_refused'],'old source reused/rebound')
            for key in ('max_water_cm','max_kernel_cm','max_solute_mg_cm2'):
                v=f['budgets'][key];require(math.isfinite(v) and 0<=v<=1e-10,'balance limit')
            require({(w['start'],w['end']) for w in f['own']}=={(2,4),(199,201),(365,367),(530,532)},'missing native windows')
            for w in [r['short']['own'],*f['own']]:
                require(all(w[k] is True for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')),'nonexact native continuation')
        require(c['reference']['status']=='COMPLETE_DIAGNOSTIC_REFERENCE' and c['reference']['original_rows']==c['reference']['swap5_rows']==1097,'incomplete original comparison')
    component=q['results']['component'];require(component['status']=='SCHEDULED_PONDMX_TOP_CODEC_O0_O2_PASS' and component['legacy_v1_emitted_source_byte_exact'],'component/legacy source missing')
    for opt in ('O0','O2'):
        c=component['profiles'][opt]
        require(c['roundtrip_exact'] and c['staged_assignment'] and c['state_bytes']==80 and len(c['negative_tests'])==10 and all(x['returncode']!=0 for x in c['negative_tests']),'component refusals missing')
    probe=q['results']['probe'];require(probe['status']=='ACTUAL_PONDMX_CAUSAL_HYPOTHESIS_CONFIRMED','causal probe absent')
    a,b=probe['results']['unseeded'],probe['results']['actual-warm-pondmx-only']
    require(a['physical_exact'] and not a['native']['macro.bin'] and b['physical_exact'] and all(b['native'].values()) and b['seed']==float(probe['warm_trace'][0][-1]),'causal counterfactual invalid')
    preservation=q['results']['preservation'];require(preservation['status']=='DEFAULT_AND_LEGACY_HISTORY_GENERATION_PRESERVED' and set(preservation['reports'])=={'plate-v1','grass','hupsel','salt'},'unaffected generation missing')
    require(all(r['status']=='UNAFFECTED_EMITTED_SOURCE_INPUTS_EXACT' and r['generated_sources'] and r['input_sha256'] and not r['binary_identity_claim'] for r in preservation['reports'].values()),'unaffected source changed')
    require(q['results']['legacy']['status']=='PRODUCTION_ORIGINAL_TOP_HISTORY_CODEC_O0_O2_PASS','legacy codec missing')
    require(q['baseline_consumer']['source_commit']==BASE and q['baseline_consumer']['returncode']==0,'old baseline consumer not actually executed')


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)


def validate_composition(c):
    require(c['status']=='COMPOSED_N_AND_PONDMX_SELECTED_DEPENDENCIES_PRESERVED' and c['source_commit']==COMPOSED and c['incoming_canonical']==INCOMING,'foreign composition')
    selected={'water-O0','water-O2','chemical-O0','chemical-O2'}
    require(set(c['reports'])==selected|{'plate-v1','grass','hupsel','salt','external-irrigation-N'},'missing composed closure')
    for key,r in c['reports'].items():
        if key=='external-irrigation-N':
            require(r['scheduled_history_inactive'] and r['images'] and all(x['line_ending_normalized_source_exact'] for x in r['images'].values()),'incoming N physical source changed')
        else:
            require(r['generated_sources_byte_exact'] and r['input_bytes_exact'] and r['images'] and not r['binary_identity_claim'],'composed physical closure changed')
        if key in selected:
            require(r['short']['days']==201 and all(r['own'][k] for k in ('exact_physical','exact_csv','exact_native','origin_unchanged')),'composed native failure')
    require(c['incoming_baseline_consumer']['source_commit']==INCOMING and c['incoming_baseline_consumer']['returncode']==0,'incoming old admission not actually verified')


def verify():
    git('merge-base','--is-ancestor',RUNTIME,COMPOSED)
    git('merge-base','--is-ancestor',COMPOSED,'HEAD')
    require(not git('diff',COMPOSED,'HEAD','--','src','app','reference','tools'),'unqualified runtime delta')
    require(not git('diff','HEAD','--','src','app','reference','tools','tests','.github','integration'),'dirty qualified surface')
    changes=git('diff','--name-only',INCOMING,'HEAD').decode().splitlines()
    physical={'app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py','app/hybrid_water/history_top_state.py'}
    require(all(p in physical|{SELF,'.github/workflows/pondmx-restart.yml'} or p.startswith(('tests/pondmx_restart/',PROOF)) for p in changes),'foreign source/evidence delta')
    original=git('show',INCOMING+':'+SELF).decode().replace('\r\n','\n');current=(ROOT/SELF).read_text()
    require(current.count(HOOK)==1 and current.replace(HOOK,'',1)==original,'old admission body changed')
    raw=git('show','HEAD:'+PROOF+'QUALIFICATION.json')
    require(hashlib.sha256(raw).hexdigest()==QUALIFICATION_SHA256,'qualification proof changed')
    q=json.loads(raw);validate(q)
    for name,record in q['archives'].items():
        require(hashlib.sha256((ROOT/PROOF/name).read_bytes()).hexdigest()==record['sha256'],'raw capsule changed')
    raw=git('show','HEAD:'+PROOF+'COMPOSITION.json')
    require(hashlib.sha256(raw).hexdigest()==COMPOSITION_SHA256,'composition proof changed')
    c=json.loads(raw);validate_composition(c)
    require(hashlib.sha256((ROOT/PROOF/c['raw_archive']['path']).read_bytes()).hexdigest()==c['raw_archive']['sha256'],'composition raw changed')
    return dict(status='SCHEDULED_PONDMX_RESTART_SOURCE_BOUND_PASS',runtime=COMPOSED,
                full_physics_runtime=RUNTIME,incoming_canonical=INCOMING,
                full_days=4384,exact_full_native_windows=16,prior_failed_source=BASE,
                old_failures='PRESERVED; no old checkpoint rebind',science='NOT_QUALIFIED')


if __name__=='__main__':print(json.dumps(verify(),indent=2))
