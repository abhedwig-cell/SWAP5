"""Bounded opt-in pond physics; current native proof and frozen predecessor."""
import base64
import copy
import csv
from functools import lru_cache
import hashlib
import io
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = 'eaa04cf7b00ff5d676eb533d160109c533a92c8a'
MEASURED = 'd7b891759a8c378ba0367e1a1a112c684712199f'
STATUS = 'integration/diagnostics/PERF01_SCOPED_ROUNDING_STATUS.json'
OWNER = 'integration/audits/verify_nut_humus_timestamp.py'
SELF = 'integration/diagnostics/verify_perf01_empty_pond.py'
PROJECTION = 'integration/diagnostics/perf01_default_false_projection.json'
SCIENCE = ['src','app','tests','tools','reference','examples','.github',
           'integration/audits','integration/performance','integration/diagnostics']
PRODUCTION = {
    'app/solute_column/main.f90',
    'src/solver/mod_b110_dynamic_top_boundary_provider.f90',
    'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90',
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
    'src/process/mod_b111_pond_solute_exchange.f90',
    'src/process/mod_b111_persistent_pond.f90',
    'src/process/mod_b111_reactive_solute_substep.f90',
    'src/runtime/mod_fmr_b111_pond_solute_route.f90',
    'src/runtime/mod_fmr_b111_pond_joint_application.f90',
}
OWNED = PRODUCTION | {OWNER,SELF,PROJECTION,
    'examples/solute_column/dry32_implicit_pond.nml',
    'tests/performance/test_perf01_empty_pond_mass.f90',
    'tests/performance/test_perf01_empty_pond_replay.f90',
    *['integration/diagnostics/'+p+'.py' for p in [
      'qualify_perf01_empty_pond','reference_perf01_empty_pond',
      'replay_perf01_empty_pond','refresh_perf01_main','trial_perf01_scoped_rounding']],
}
sha = lambda b: hashlib.sha256(b).hexdigest()


def require(ok, why):
    if not ok:
        raise ValueError(why)


def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()


@lru_cache(maxsize=None)
def prior(p, ref=BASE):
    return subprocess.check_output(['git','show',ref+':'+p],cwd=ROOT)


def record():
    return json.loads((ROOT/STATUS).read_text())


def handoff(text):
    """Three additive entry hooks; the incumbent assertions remain verbatim."""
    for fn in ['source','verify_qualification','self_test']:
        pattern = r'^def '+fn+r'\([^\n]*\):'
        match = re.search(pattern,text,re.M)
        require(match is not None,'incumbent entry missing '+fn)
        # The predecessor's qualification body is deliberately a one-line body.
        end = text.index('\n',match.end())
        inline = text[match.end():end]
        if inline:
            text = text[:match.end()]+'\n '+inline+text[end:]
        start = text.index('\n',match.end())+1
        hook = (" if 'production_evidence' in json.loads((ROOT/'"+STATUS+"').read_text()):\n"
                "  return __import__('runpy').run_path(str(ROOT/'"+SELF+"'))['"+fn+"']("+
                ('reader,changed' if fn=='source' else '')+")\n")
        text = text[:start]+hook+text[start:]
    return text


def default_projection(reader):
    # Exact statements and context, rather than a general reverse-patch waiver.
    edits = json.loads(reader(PROJECTION))
    require(set(edits)==PRODUCTION,'default projection scope')
    for p, replacements in edits.items():
        text = reader(p).decode()
        for e in replacements:
            require(set(e)=={'enabled_extension','incumbent'},'projection format')
            require(text.count(e['enabled_extension'])==1,'projection anchor '+p)
            text = text.replace(e['enabled_extension'],e['incumbent'],1)
        require(text.encode()==prior(p),'incumbent default body changed '+p)


def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
    s = record()
    require(s['baseline']==BASE and s['measured_baseline']==MEASURED,'source baseline')
    git('merge-base','--is-ancestor',BASE,'HEAD')
    require(not git('status','--porcelain','--',*SCIENCE),'dirty scientific source')
    if changed is None:
        changed = dict((x.split('\t')[1],x.split('\t')[0]) for x in
                       git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines())
    allowed = {STATUS}
    if (ROOT/'integration/diagnostics/PERF01_POND_POLICY_STATUS.json').exists():
        allowed |= runpy.run_path(str(ROOT/'integration/diagnostics/verify_perf01_pond_policy.py'))['registered_additions'](reader)
    for key in ['experiment_evidence','production_evidence','earlier_production_evidence','arithmetic_guard_evidence']:
        e = s[key];index = e['directory']+'/INDEX.json'
        idx = json.loads(reader(index))
        require(sha(reader(index))==e['index_sha256'],'capsule index '+key)
        allowed |= {index,*[e['directory']+'/'+p for p in idx['parts']]}
    require(all(changed.get(p)=='A' for p in allowed),'missing registered proof')
    actual = {p:v for p,v in changed.items() if p not in allowed}
    require(set(s['postimages'])==OWNED,'owning source set')
    require(actual=={p:v['status'] for p,v in s['postimages'].items()},'foreign scientific delta')
    for p,v in s['postimages'].items():
        require(sha(reader(p))==v['sha256'],'source postimage '+p)
    require(reader(OWNER).decode()==handoff(prior(OWNER).decode()),'incumbent owner assertions changed')
    # Preserve all predecessor owning records/evidence, including NUT and FSI35.
    for p,h in s['inherited_records'].items():
        # Exact PR1354 admission receipt only; no scientific/evidence waiver.
        if p == 'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json' and sha(reader(p)) == 'abacd7d08cfeb8931ea14d8573d078b3e5d87a4b9cceae0fc57994b8cc116153':
            require(h==sha(prior(p)),'frozen NUT authority changed')
        else:
            require(sha(reader(p))==h==sha(prior(p)),'inherited authority changed '+p)
    for p in ['src/transaction/mod_transaction_reference.f90','src/legacy/b1_10_port/headcalc.f90']:
        require(reader(p)==prior(p),'unchanged numerical/transaction authority '+p)
    default_projection(reader)
    return s


def capsule(key):
    e = record()[key];path = ROOT/e['directory']
    idx = json.loads((path/'INDEX.json').read_text())
    require(sha((path/'INDEX.json').read_bytes())==e['index_sha256'],'index binding')
    raw = base64.b64decode(b''.join((path/p).read_bytes() for p in idx['parts']),validate=True)
    require(sha(raw)==idx['decoded_sha256']==e['decoded_sha256'],'capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as t:
        members = t.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts
                    for m in members),'unsafe evidence path')
        require(len(members)==len({m.name for m in members}),'duplicate evidence')
        f = {m.name:t.extractfile(m).read() for m in members}
    manifest_raw = f.pop('MEMBERS.json');manifest = json.loads(manifest_raw)
    require(sha(manifest_raw)==idx['members_sha256'],'member manifest identity')
    require(len(f)==idx['members'] and f.keys()==manifest.keys(),'evidence inventory')
    require(all(sha(f[p])==h for p,h in manifest.items()),'member corruption')
    return f


def rows(f,p):
    return list(csv.DictReader(io.StringIO(f[p].decode())))


def work(f,p):
    return [{k:v for k,v in r.items() if k!='cpu'} for r in rows(f,p)]


def balance(f,p,count):
    r = rows(f,p)
    require(len(r)==count,'reporting window count '+p)
    water = max(abs(float(x['water_residual_cm'])) for x in r)
    solute = max(abs(float(x['solute_residual_mg_cm2'])) for x in r)
    require(water<1e-10 and solute<1e-11,'coupled conservation '+p)
    return water,solute


def experiments(f):
    js = lambda p:json.loads(f[p])
    history = js('SOURCE_HISTORY.json')
    for p,v in history.items():
        require(sha(f['reproduction-sources/'+p])==v['sha256'],'historical helper identity')
    candidates = ['control-O2','trial-O2','temporal-O2','surface-O2','mass-capture-O2',
                  'coupled-O0','coupled-O2','full-day-O2','uninterrupted-O2','refined-O2']
    for label in candidates:
        r = js(label+'/TRIAL.json')
        for p,h in r['build']['input_sha256'].items():
            require(sha(prior(p,MEASURED))==h,'measured build input '+p)
        for p,h in r['inputs'].items():
            require(sha(prior(p,MEASURED))==h if p not in {v['path'] for v in history.values()}
                    else any(v['path']==p and v['sha256']==h for v in history.values()),
                    'executed experiment helper '+p)
        require(all(e['returncode']==0 for e in r['events']),'experiment build failed '+label)
        for p,h in r['raw_sha256'].items():
            require(sha(f[label+'/native/'+p])==h,'raw experiment bytes '+label+'/'+p)
        require(r['resource']==js(label+'/native/RESOURCE.json'),'resource binding '+label)
    require(js('control-O2/TRIAL.json')['resource']['returncode']==1,'lost original failure')
    oracle = runpy.run_path(str(ROOT/'integration/diagnostics/verify_perf01_dry.py'))['capsule']()
    for name in ['budget.csv','trajectory.csv','stdout']:
        require(f['control-O2/native/'+name]==oracle['oracle/'+name],'matched unchanged original control '+name)
    require(work(f,'control-O2/native/work.csv')==work(oracle,'oracle/work.csv'),'unchanged original control work')
    r = js('trial-O2/TRIAL.json')
    require(r['resource']['timed_out'] and r['resource']['returncode']!=0 and
            r['status']=='EXPERIMENT_FAILED_OR_CENSORED_NOT_QUALIFIED','censored run relabelled complete')
    require(len(rows(f,'trial-O2/native/budget.csv'))==5,'censored external publication')
    t = rows(f,'temporal-O2/native/temporal.csv')
    require(len(t)==2048 and len({x['sample'] for x in t})==64,'missing full/half capture')
    rates=[];dz=[.5,.5,1.,1.,2.,3.]+[5.]*26
    for start in range(0,len(t),32):
        g=t[start:start+32];dt=float(g[0]['dt'])
        error=max(abs(float(x['full_h'])-float(x['half_h'])) for x in g)
        require(abs(error-float(g[0]['error']))<1e-10,'native full/half norm')
        if 1e-7<dt<1e-5:
            rate=(sum((float(x['full_theta'])-float(x['half_theta']))*d for x,d in zip(g,dz))+
                  float(g[0]['full_pond'])-float(g[0]['half_pond']))/dt
            require(abs(abs(rate)-.025)<1e-6,'reconstructed split evaporation source')
            rates.append(rate)
    require(any(x>0 for x in rates) and any(x<0 for x in rates),'missing opposite source phases')
    require(b'ACTUAL_EMPTY_POND_MASS_BEFORE' in f['mass-capture-O2/native/stdout'],
            'missing actual chemical counterexample')
    for label in ['coupled-O0','coupled-O2','full-day-O2','uninterrupted-O2','refined-O2']:
        r = js(label+'/TRIAL.json')
        require(r['control'] and r['surface_complementarity'] and r['solute_empty_limit'],
                'changed HeadCalc selected '+label)
        require(r['resource']['returncode']==0 and not r['resource']['timed_out'] and
                r['resource']['max_rss_kib']<512*1024 and r['resource']['seconds']<=r['timeout_seconds']+.2,
                'failed/budget-exceeding completed case '+label)
        require(all(int(x['attempted'])==0 for x in rows(f,label+'/native/rounding.csv')),
                'rounding correction entered '+label)
    for p in ['state.csv','endpoint.csv','restart.bin','budget.csv','trajectory.csv']:
        require(f['coupled-O0/native/'+p]==f['coupled-O2/native/'+p],'O0/O2 drift '+p)
    for p in ['state.csv','endpoint.csv','restart.bin']:
        require(f['uninterrupted-O2/native/'+p]==f['full-day-O2/native/'+p],'fresh-process restart drift '+p)
    for p in ['budget.csv','trajectory.csv']:
        require(rows(f,'uninterrupted-O2/native/'+p)==rows(f,'coupled-O2/native/'+p)+
                rows(f,'full-day-O2/native/'+p),'all-window restarted data drift '+p)
    require(work(f,'uninterrupted-O2/native/work.csv')==work(f,'coupled-O2/native/work.csv')+
            work(f,'full-day-O2/native/work.csv'),'restart deterministic work drift')
    require(work(f,'coupled-O0/native/work.csv')==work(f,'coupled-O2/native/work.csv'),'optimization work drift')
    balance(f,'coupled-O2/native/budget.csv',6)
    residual = balance(f,'uninterrupted-O2/native/budget.csv',64)
    balance(f,'refined-O2/native/budget.csv',64)
    require(float(rows(f,'uninterrupted-O2/native/endpoint.csv')[0]['time_day'])==1.,'unfinished day')
    # Recompute the independent-reference spread and native error decrease.
    tight = rows(f,'independent-water/tight.csv');ref = rows(f,'independent-water/tighter.csv')
    require(len(tight)==len(ref)==2048,'independent reference inventory')
    spreads = {k:max(abs(float(a[k])-float(b[k])) for a,b in zip(tight,ref)) for k in ['head','theta','pond']}
    require(spreads['head']<1e-4 and spreads['theta']<1e-8 and spreads['pond']<1e-8,'reference not converged')
    errors = []
    for label in ['uninterrupted-O2','refined-O2']:
        trajectory = rows(f,label+'/native/trajectory.csv');budget = rows(f,label+'/native/budget.csv')
        require(len(trajectory)==2048,'native reference grid')
        e = {k:max(abs(float(a[k])-float(b[k])) for a,b in zip(trajectory,ref)) for k in ['head','theta']}
        for output,column in [('evaporation','pond_evaporation_cm'),('runoff','runoff_cm')]:
            total=0.;values=[]
            for i,r in enumerate(budget):
                total+=float(r[column]);values.append(abs(total-float(ref[i*32]['cumulative_'+output])))
            e['cumulative_'+output]=max(values)
        errors.append(e)
    expected = js('REFINEMENT.json')
    require(errors==[expected['coarse'],expected['refined']],'independent error accounting')
    require(all(0<errors[1][k]<errors[0][k] for k in errors[0]),'refinement failed to reduce error')
    return dict(water_residual=residual[0],solute_residual=residual[1],coarse=errors[0],refined=errors[1])


def validate(p,f,reader=lambda q:(ROOT/q).read_bytes()):
    js = lambda q:json.loads(p[q])
    result = experiments(f)
    swp = runpy.run_path(str(ROOT/'integration/audits/verify_swp_reader.py'))
    # Invoke the original assertions on fresh actual default artifacts verbatim.
    default = {}
    for q,b in p.items():
        for old,new in [('default/swp/','native/'),('default/column/','column/'),
                        ('default/annual/','annual/'),('build-O0/','build-O0/'),('build-O2/','build-O2/')]:
            if q.startswith(old):default[new+q[len(old):]]=b
    default['incumbent-comparison.json']=p['default/incumbent-comparison.json']
    require(swp['validate'](default,reader)['qualified'],'current original default assertions')
    for opt in ['O0','O2']:
        b = js('build-'+opt+'/build-complete.json')
        require('controlled_main_refresh' not in b,'final arithmetic-profile admission needs fresh closure')
        for q,h in b['input_sha256'].items():
            require(sha(reader(q))==h,'current native source '+q)
        for i,event in enumerate(b['events']):
            require(event['returncode']==0,'production build failed')
            for stream in ['stdout','stderr']:
                require('build-'+opt+'/'+event[stream] in p,'missing build stream')
        require(b['events'][-2]['category']=='compile' and b['events'][-1]['category']=='link','current main build missing')
        objects=js('build-'+opt+'/OBJECTS.json')
        names={Path(e['command'][e['command'].index('-o')+1]).name for e in b['events'] if e['category']=='compile'}
        require(set(objects)==names|{'libttutil.a'},'fresh object inventory')
    for label,count,marker in [('production-direct-surface',6,'PRODUCTION_OPTION_DEFAULT_UNSUPPORTED_PATHS_PASS'),
                                ('production-direct-mass',3,'PRODUCTION_EXACT_EMPTY_LIMIT_AND_DISABLED_COUNTEREXAMPLE_PASS')]:
        r = js(label+'/RESULT.json')
        require(r['provider_count']==count and r['runs']['O0']==r['runs']['O2'],'small real provider scope')
        for q,h in r['source_sha256'].items():
            require(sha(p[label+'/source/'+q])==h,'small closure bytes '+q)
            if not q.startswith('generated/'):require(sha(reader(q))==h,'stale small production source '+q)
        require(all(e['returncode']==0 for e in r['events']),'small native failure')
        for i,opt in [(1,'O0'),(3,'O2')]:
            require(marker in r['runs'][opt] and p[f'{label}/{i:04d}.stdout'].decode()==r['runs'][opt],
                    'small native marker')
    enabled = js('enabled/RESULT.json')
    require(enabled['status']=='ACTUAL_PRODUCTION_OPTION_O0_O2_AND_FULL_DAY_EXACT_GENERATED_CANDIDATE_PASS',
            'current enabled run unfinished')
    observer = runpy.run_path(str(ROOT/'integration/diagnostics/qualify_trace_scope.py'))['observer_source']
    for opt,v in enabled['observers'].items():
        require(p['enabled/observer-'+opt+'/main.f90'].decode()==observer(reader('app/solute_column/main.f90').decode()),
                'observer changed application physics')
        require(sha(p['enabled/observer-'+opt+'/main.f90'])==v['main_sha256'],'observer binding')
        protected=js('build-'+opt+'/OBJECTS.json')
        require(all(protected[Path(q).name]==h for q,h in v['linked_objects'].items()),'observer provider reuse drift')
    for r in enabled['native']:
        label=r['label'];resource=r['resource']
        require(resource==js('enabled/'+label+'/RESOURCE.json'),'actual production resource binding')
        require(resource['returncode']==0 and not resource['timed_out'] and resource['seconds']<=r['timeout']+.2 and
                resource['max_rss_kib']<512*1024,'actual production case failed '+label)
        for q,h in r['raw_sha256'].items():require(sha(p['enabled/'+label+'/'+q])==h,'actual production raw '+q)
    require({r['label'] for r in enabled['native']}=={'O0-six','O2-unobserved-six','O2-day'},'production case inventory')
    for label,reference in [('O0-six','coupled-O2'),('O2-day','uninterrupted-O2')]:
        for q in ['budget.csv','trajectory.csv','state.csv','endpoint.csv','restart.bin']:
            require(p['enabled/'+label+'/'+q]==f[reference+'/native/'+q],'actual production physical parity '+q)
        require(work(p,'enabled/'+label+'/work.csv')==work(f,reference+'/native/work.csv'),'actual production work parity')
    for q in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
        require(p['enabled/O2-unobserved-six/'+q]==p['enabled/O0-six/'+q],'unobserved production drift')
    independent=js('independent-water/RESULT.json')
    require(independent['candidate_errors']==result['coarse'],'fresh actual production independent error')
    for q,h in independent['inputs'].items():
        require(sha(p['enabled/O2-day/'+Path(q).name])==h,'independent current native input')
    for q in ['tight.csv','tighter.csv']:
        require(p['independent-water/'+q]==f['independent-water/'+q],'continuous reference reproduction')
    controls=js('controls/RESULT.json')
    require(controls['status']=='UNSUPPORTED_IMPORTED_COMBINATIONS_AND_MISMATCHED_POLICY_FAIL_CLOSED_PASS',
            'unsupported combinations untested')
    require({x['label'] for x in controls['controls']}=={'temperature','proposal','nonlinear','imported-nonlinear','mismatched-policy','missing-water-policy'},
            'negative control inventory')
    for c in controls['controls']:
        label=c['label'];require(c['returncode']!=0,'negative control accepted '+label)
        if label in {'mismatched-policy','missing-water-policy'}:
            projected=observer(reader('app/solute_column/main.f90').decode())
            needle='    supply%implicit_pond_evaporation=implicit_pond_evaporation'
            replacement=('    supply%implicit_pond_evaporation=.not.implicit_pond_evaporation' if label=='mismatched-policy'
                         else needle+'\n    deallocate(forcing%pond_input)')
            require(p['controls/'+label+'/main.f90'].decode()==projected.replace(needle,replacement,1),'policy control source')
            require(sha(p['controls/'+label+'/input.nml'])==c['input_sha256'],'policy control input')
            w=work(p,'controls/'+label+'/work.csv')
            require(len(w)==1 and all(int(v)==0 for k,v in w[0].items() if k!='window'),'rejected policy performed water work')
            require(len(p['controls/'+label+'/budget.csv'].splitlines())==1,'rejected policy published a row')
            marker='joint interval rejected'
        else:
            require(sha(p['controls/'+label+'/input.nml'])==c['input_sha256'],'negative input binding')
            marker='implicit pond '+('imported chemistry' if label=='imported-nonlinear' else 'combination')+' not qualified'
            require('controls/'+label+'/budget.csv' not in p,'unsupported input published budget')
            if label=='imported-nonlinear':
                require(sha(p['controls/'+label+'/source.swp'])==c['swp_sha256'] and
                        p['controls/'+label+'/source.swp']==p['default/swp/O2/layered/source.swp'],
                        'imported chemistry control source')
        require(marker.encode() in p['controls/'+label+'/stdout'],'missing fail-closed marker '+label)
    predecessor=js('predecessor.json')
    require(predecessor['qualified'] and predecessor['source_tree']==git('rev-parse',BASE+':src'),'unqualified frozen NUT/SOL predecessor')
    return dict(qualified=True,status='OPT_IN_EMPTY_POND_CURRENT_NATIVE_AND_DEFAULT_PRESERVATION_QUALIFIED',
                source_tree=git('rev-parse','HEAD:src'),production_option_default=False,
                current_default_observations=86,current_swp_observations=172,current_annual_cases=18,
                enabled_full_day=True,default_body_projection=True,negative_combinations=6,
                independent_water=result,independent_chemical_truth=False,
                full_capability=False,full_migration_qualified=False,master_row_promotion=False,
                nut_qualification='FROZEN_PREDECESSOR_PLUS_DEFAULT_PATH_PROJECTION',
                full_fci='NOT_SELECTED_OPTIONAL_GUARDED_POND_PHYSICS')


def predecessor():
    with tempfile.TemporaryDirectory(prefix='swap5-pond-predecessor-') as d:
        path=Path(d)/'base'
        subprocess.run(['git','worktree','add','--detach',path,BASE],cwd=ROOT,check=True,capture_output=True)
        try:
            p=subprocess.run([sys.executable,'-B',OWNER],cwd=path,capture_output=True,text=True,
                             env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
            require(p.returncode==0,'frozen predecessor failed '+p.stderr[-1200:])
            require(json.loads(p.stdout)['qualified'],'frozen predecessor did not qualify')
        finally:
            subprocess.run(['git','worktree','remove','--force',path],cwd=ROOT,check=True,capture_output=True)
    return True


def verify_qualification():
    source();capsule('earlier_production_evidence');capsule('arithmetic_guard_evidence')
    r=validate(capsule('production_evidence'),capsule('experiment_evidence'))
    r['frozen_predecessor_replayed']=predecessor()
    return r


def self_test():
    source();p=capsule('production_evidence');f=capsule('experiment_evidence');validate(p,f);controls=[]
    def reject(name,action):
        try:action()
        except (ValueError,KeyError,AssertionError,StopIteration):controls.append(name);return
        raise ValueError('corruption accepted '+name)
    for q in PRODUCTION|{PROJECTION,'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'}:
        reject('source '+q,lambda q=q:source(lambda x:(ROOT/x).read_bytes()+(b'!' if x==q else b'')))
    changed=dict((x.split('\t')[1],x.split('\t')[0]) for x in
                 git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines())
    changed['src/foreign_unregistered.f90']='A'
    reject('unregistered scientific source',lambda:source(changed=changed))
    for q in ['enabled/O2-day/restart.bin','default/swp/result.json','production-direct-mass/0003.stdout',
              'controls/imported-nonlinear/source.swp','build-O0/build-complete.json','predecessor.json',
              'independent-water/tighter.csv','controls/missing-water-policy/work.csv']:
        bad=dict(p);bad.pop(q);reject('missing '+q,lambda bad=bad:validate(bad,f))
    for q in ['full-day-O2/native/restart.bin','refined-O2/native/budget.csv',
              'independent-water/tighter.csv','temporal-O2/native/temporal.csv']:
        bad=dict(f);bad.pop(q);reject('missing '+q,lambda bad=bad:experiments(bad))
    bad=dict(f);r=json.loads(bad['trial-O2/TRIAL.json']);r['status']='EXPERIMENT_COMPLETE_NOT_PRODUCTION_QUALIFIED'
    bad['trial-O2/TRIAL.json']=json.dumps(r).encode();reject('censored relabelled complete',lambda:experiments(bad))
    bad=dict(p);bad['enabled/O2-day/restart.bin']+=b'!';reject('current production restart drift',lambda:validate(bad,f))
    bad=dict(p);bad['controls/mismatched-policy/work.csv']=bad['enabled/O0-six/work.csv']
    reject('mismatched policy performed water work',lambda:validate(bad,f))
    return dict(count=len(controls),negative_controls=controls)


if __name__=='__main__':
    print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(),indent=2))
