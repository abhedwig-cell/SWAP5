"""Neutral source registration and evidence checks for failed pond policy research."""
import base64
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import runpy
import subprocess
import sys
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[2]
BASE='242a733aaab49bf173b52313bfa9af01cbecdc7b'
STATUS='integration/diagnostics/PERF01_POND_POLICY_STATUS.json'
DRIVER='integration/diagnostics/study_perf01_pond_policy.py'
SELF='integration/diagnostics/verify_perf01_pond_policy.py'
PARENT='integration/diagnostics/verify_perf01_empty_pond.py'
PARENT_STATUS='integration/diagnostics/PERF01_SCOPED_ROUNDING_STATUS.json'
PATCH='benchmarks/performance/SWAP5-PERF01_PREPARED_REJECTED.patch'
CACHE_PATHS={'src/solver/mod_b110_default_mvg_provider.f90','src/adapter/mod_reference_richards_legacy_binding.f90'}
SCIENCE=['src','app','tests','tools','reference','examples','.github',
         'integration/audits','integration/performance','integration/diagnostics']
sha=lambda b:hashlib.sha256(b).hexdigest()


def require(ok,why):
    if not ok:raise ValueError(why)


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def prior(p):return subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT)
def record():return json.loads((ROOT/STATUS).read_text())


def parent_source(text):
    old='    allowed = {STATUS}\n'
    require(text.count(old)==1,'parent registration anchor')
    return text.replace(old,old+
        "    if (ROOT/'"+STATUS+"').exists():\n"
        "        allowed |= runpy.run_path(str(ROOT/'"+SELF+"'))['registered_additions'](reader)\n",1)


def registered_additions(reader=lambda p:(ROOT/p).read_bytes()):
    """Allow only these new diagnostics; retain every incumbent owning assertion."""
    r=record();require(r['baseline']==BASE,'research baseline')
    require(not r['production_changed'] and not r['production_policy_admitted'],'research claims production')
    require(set(r['postimages'])=={SELF,DRIVER},'diagnostic source scope')
    for p,h in r['postimages'].items():require(sha(reader(p))==h,'diagnostic source identity '+p)
    require(reader(PARENT)==parent_source(prior(PARENT).decode()).encode(),'parent assertions changed')
    expected=json.loads(prior(PARENT_STATUS))
    expected['postimages'][PARENT]['sha256']=sha(reader(PARENT))
    require(json.loads(reader(PARENT_STATUS))==expected,'incumbent status changed beyond own checksum')
    for p,v in expected['postimages'].items():require(sha(reader(p))==v['sha256'],'incumbent scientific postimage '+p)
    p='src/runtime/mod_canonical_interval_runtime.f90'
    require(reader(p)==prior(p),'incumbent numerical runtime changed')
    require(reader(PATCH)==prior(PATCH),'frozen rejected patch changed')
    added={SELF,DRIVER,STATUS}
    if 'evidence' in r:
        e=r['evidence'];idx=e['directory']+'/INDEX.json'
        require(e['directory']=='integration/diagnostics/evidence/perf01-pond-policy-20261021','neutral evidence directory')
        require(sha(reader(idx))==e['index_sha256'],'research index binding')
        index=json.loads(reader(idx))
        require(all(re.fullmatch(r'evidence\.part-\d{3}\.b64',p) for p in index['parts']),'part path')
        added|={idx,*[e['directory']+'/'+p for p in index['parts']]}
    delta=dict((x.split('\t')[1],x.split('\t')[0]) for x in
        git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines())
    require(delta=={PARENT:'M',PARENT_STATUS:'M',**{p:'A' for p in added}},'foreign research source delta')
    require(git('rev-parse','HEAD:src')==git('rev-parse',BASE+':src'),'production source tree changed')
    git('merge-base','--is-ancestor',BASE,'HEAD')
    return added


def capsule():
    r=record();e=r['evidence'];folder=ROOT/e['directory'];idx=json.loads((folder/'INDEX.json').read_text())
    require(sha((folder/'INDEX.json').read_bytes())==e['index_sha256'],'index bytes')
    raw=base64.b64decode(b''.join((folder/p).read_bytes() for p in idx['parts']),validate=True)
    require(sha(raw)==idx['decoded_sha256']==e['decoded_sha256'],'capsule bytes')
    with tarfile.open(fileobj=io.BytesIO(raw)) as t:
        members=t.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe member')
        require(len(members)==len({m.name for m in members}),'duplicate member')
        f={m.name:t.extractfile(m).read() for m in members}
    manifest_raw=f.pop('MEMBERS.json');manifest=json.loads(manifest_raw)
    require(sha(manifest_raw)==idx['members_sha256'],'manifest bytes')
    require(f.keys()==manifest.keys() and len(f)==idx['members'],'member inventory')
    require(all(sha(f[p])==h for p,h in manifest.items()),'member corruption')
    return f


def rows(f,p):return list(csv.DictReader(io.StringIO(f[p].decode())))
def work(f,p):return [{k:v for k,v in r.items() if k!='cpu'} for r in rows(f,p)]


def profile_summary(text):
    records=[]
    pattern=r'^\s*(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(?:(\d+)\s+\S+\s+\S+\s+)?(\S+)\s*$'
    for line in text.split('\f')[0].splitlines():
        m=re.match(pattern,line)
        if m:records.append(dict(percent=float(m[1]),self_seconds=float(m[3]),
                                 calls=int(m[4]) if m[4] else None,name=m[5]))
    inclusive=re.findall(r'^\[\d+\]\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+)\s+headcalc_\s+\[\d+\]',text,re.M)
    require(len(records)>100 and len(inclusive)==1,'incomplete profile table')
    captures=[r for r in records if 'capture_attempt_context' in r['name'] or 'restore_attempt_context' in r['name']]
    require(len(captures)==2,'missing context samples')
    return dict(headcalc_model_inclusive_percent=float(inclusive[0][0]),headcalc_calls=int(inclusive[0][3]),
        model_self_seconds=sum(r['self_seconds'] for r in records),
        capture_restore_model_self_percent=sum(r['percent'] for r in captures),top_self=records[:15])


def cache_sources():
    with tempfile.TemporaryDirectory(prefix='perf01-frozen-cache-') as d:
        root=Path(d)
        for p in CACHE_PATHS:
            q=root/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(prior(p))
        subprocess.run(['git','apply',str(ROOT/PATCH)],cwd=root,check=True,capture_output=True)
        return {p:(root/p).read_bytes() for p in CACHE_PATHS}


def validate(f):
    js=lambda p:json.loads(f[p])
    driver=runpy.run_path(str(ROOT/DRIVER))
    old=runpy.run_path(str(ROOT/PARENT))['capsule']('production_evidence')
    for label in ['profile-day','cap-O2-six','cap-O2-balance']:
        r=js(label+'/RESULT.json');b=r['build']
        require(b['status']=='BUILT' and b['provider_count']==189,'native closure')
        for p,h in b['input_sha256'].items():require(sha((ROOT/p).read_bytes())==h,'stale native input '+p)
        for p,h in r['inputs'].items():
            if p==DRIVER:
                require(sha(f['source-versions/'+h+'.py'])==h,'executed driver version')
            else:require(sha((ROOT/p).read_bytes())==h,'executed unchanged helper')
        require(all(e['returncode']==0 for e in r['events']),'failed compile/link/tool')
        for i,e in enumerate(r['events']):
            for stream in ['stdout','stderr']:require(f'{label}/{i:04d}.{stream}' in f,'missing execution stream')
        for p,h in r['raw_sha256'].items():require(sha(f[label+'/native/'+p])==h,'raw native identity')
        require(r['resource']==js(label+'/native/RESOURCE.json'),'resource binding')
        if label.startswith('cap-'):
            require(r['mode']=='cap' and r['native_command'][-1]=='6','screen horizon')
            require(r['resource']['returncode']==1 and not r['resource']['timed_out'] and
                    r['status']=='FAILED_OR_CENSORED_NOT_QUALIFIED','failed policy relabelled')
            require('-pg' not in b['flags'],'instrumented candidate timing')
            text=(ROOT/'src/runtime/mod_canonical_interval_runtime.f90').read_text()
            require(f[label+'/generated/mod_canonical_interval_runtime.f90'].decode()==driver['runtime_source'](text),'generated runtime policy')
            require(f[label+'/generated/main.f90'].decode()==driver['main_source']((ROOT/'app/solute_column/main.f90').read_text()),'generated main guards')
            for p,h in r['generated_sha256'].items():require(sha(f[label+'/generated/'+p])==h,'generated bytes')
            w=rows(f,label+'/native/work.csv');budget=rows(f,label+'/native/budget.csv')
            require(len(w)==2 and len(budget)==1,'failed-window publication')
            stdout=f[label+'/native/stdout'].decode()
            require('joint interval rejected' in stdout and 'COMMITTED_WATER_CLOCK   1.5625000000000000E-002' in stdout and
                    'COMMITTED_CHEMICAL_CLOCK   1.5625000000000000E-002' in stdout,'failed external clocks')
            require(label+'/native/restart.bin' not in f and label+'/native/endpoint.csv' not in f,'failed case produced completed generation')
    profile=js('profile-day/RESULT.json')
    require(profile['mode']=='profile' and '-pg' in profile['build']['flags'],'sampling build')
    require(profile['resource']['returncode']==0 and not profile['resource']['timed_out'] and
            profile['resource']['seconds']<=240.2 and profile['resource']['max_rss_kib']<512*1024,'whole-day profile incomplete')
    require(profile['profile_physical_files_exact'],'profile changed physics')
    for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
        require(f['profile-day/native/'+name]==old['enabled/O2-day/'+name],'actual instrumented physical drift '+name)
    require(f['profile-day/native/gmon.out'][:4]==b'gmon' and b'Flat profile:' in f['profile-day/gprof.txt'],'missing raw sampling data')
    for name in ['budget.csv','trajectory.csv']:
        require(f['cap-O2-six/native/'+name]==f['cap-O2-balance/native/'+name],'capture changed accepted native data')
    require(work(f,'cap-O2-six/native/work.csv')==work(f,'cap-O2-balance/native/work.csv'),'capture changed numerical work')
    text=f['cap-O2-balance/native/stdout'].decode();line=next(x for x in text.splitlines() if 'POND_POLICY_AGGREGATE_BALANCE_REJECTION' in x)
    v=list(map(float,line.split()[1:]));residual,tolerance,steps,before,after,external_in,external_out=v
    require(residual==after-before-external_in+external_out,'captured aggregate balance arithmetic')
    require(tolerance==8192*sys.float_info.epsilon*max(1.,before,after,external_in,external_out),'changed aggregate budget threshold')
    require(residual>tolerance>0 and int(steps)==53730,'missing aggregate chemical blocker')
    route=(ROOT/'src/runtime/mod_fmr_b111_pond_solute_route.f90').read_text()
    replacement='''  if(abs(receipt%residual)>8192d0*epsilon(1d0)*scale)then
    write(*,*) 'POND_POLICY_AGGREGATE_BALANCE_REJECTION',receipt%residual, &
      8192d0*epsilon(1d0)*scale,receipt%completed_substeps, &
      receipt%mass_before,receipt%mass_after,receipt%external_in,receipt%external_out
    return
  end if'''
    require(f['cap-O2-balance/generated/mod_fmr_b111_pond_solute_route.f90'].decode()==
            driver['once'](route,'  if(abs(receipt%residual)>8192d0*epsilon(1d0)*scale)return',replacement),'balance guard changed')
    baseline=rows(old,'enabled/O2-day/work.csv')[0];candidate=rows(f,'cap-O2-six/native/work.csv')[0]
    require(int(candidate['accepted_substeps'])>int(baseline['accepted_substeps']) and
            int(candidate['headcalc_calls'])>int(baseline['headcalc_calls']),'counterfactual cost claim')
    summary=profile_summary(f['profile-day/gprof.txt'].decode())
    baseline_work=rows(old,'enabled/O2-day/work.csv')
    require(summary['headcalc_calls']==sum(int(x['headcalc_calls']) for x in baseline_work),'profile/actual-production work identity')
    cache=cache_sources();direct=js('cache-direct/RESULT.json')
    require(direct['status']=='ACTUAL_CURRENT_PREPARED_INCREMENT_28800_EXACT_PAIRS_O0_O2_O3_PASS','small exact cache contract')
    for p,h in direct['sources'].items():
        key=next((q for q in CACHE_PATHS if p.endswith('/'+q)),None)
        raw=cache[key] if key else (ROOT/('tests/performance/test_perf01_prepared_increment.f90' if p.endswith('test_perf01_prepared_increment.f90') else 'src/solver/mod_soil_water_solver_contract.f90')).read_bytes()
        require(sha(raw)==h,'direct current source binding')
    require(len(direct['events'])==6 and all(e['returncode']==0 for e in direct['events']),'direct cache compile/native matrix')
    for i in [1,3,5]:require(b'PERF01_PREPARED_EXACT_PAIRS=28800' in f[f'cache-direct/{i:04d}.stdout'],'cache direct bit identity')
    cases=['cache-O2-six','cache-O0-six','cache-O2-day','cache-O2-activation',*[f'pair-{i}-{arm}' for i in range(3) for arm in ['control','cache']]]
    for label in cases:
        r=js(label+'/RESULT.json');b=r['build'];arm=r['mode']
        for p,h in r['inputs'].items():
            require(sha(f['source-versions/'+h+'.py'])==h if p==DRIVER else sha((ROOT/p).read_bytes())==h,'cache executed diagnostic version')
        require(r['status']=='COMPLETE_DIAGNOSTIC_NOT_PRODUCTION_ADMISSION' and r['resource']['returncode']==0 and
                not r['resource']['timed_out'] and r['resource']['seconds']<=r['timeout']+.2 and r['resource']['max_rss_kib']<512*1024,'incomplete cache comparison '+label)
        require(b['status']=='BUILT' and b['provider_count']==189 and '-pg' not in b['flags'],'cache build closure')
        for p,h in b['input_sha256'].items():require(sha(cache[p] if arm=='cache' and p in cache else (ROOT/p).read_bytes())==h,'cache executed source '+p)
        require(all(e['returncode']==0 for e in b['events']+r['events']),'failed cache build or observer')
        for p,h in r['raw_sha256'].items():require(sha(f[label+'/native/'+p])==h,'cache raw identity')
        observe=runpy.run_path(str(ROOT/'integration/diagnostics/qualify_trace_scope.py'))['observer_source']
        main=observe((ROOT/'app/solute_column/main.f90').read_text())
        if label=='cache-O2-activation':
            main=driver['cache_counter_main'](main)
            require(r['capture_cache'],'unlabelled diagnostic counters')
            require(f[label+'/generated/cache_observer.f90'].decode()==
                    driver['cache_counter_source'](cache['src/adapter/mod_reference_richards_legacy_binding.f90'].decode()),'cache activation observer')
        require(f[label+'/generated/main.f90'].decode()==main,'cache observer changed model')
        if arm=='cache':
            require(set(r['source_overlay'])==CACHE_PATHS,'cache source overlay scope')
            for p,h in r['source_overlay'].items():
                require(f[label+'/generated/source-overlay/'+p]==cache[p] and sha(cache[p])==h,'cache overlay postimage')
        ref='enabled/O2-day' if label=='cache-O2-day' else 'enabled/O0-six'
        for name in ['budget.csv','state.csv','endpoint.csv','restart.bin','trajectory.csv']:
            require(f[label+'/native/'+name]==old[ref+'/'+name],'cache physical byte drift '+label+'/'+name)
        require(work(f,label+'/native/work.csv')==work(old,ref+'/work.csv'),'cache numerical work drift '+label)
    pairs=[]
    for i in range(3):
        control=js(f'pair-{i}-control/RESULT.json');cached=js(f'pair-{i}-cache/RESULT.json')
        require(control['native_command'][:3]==cached['native_command'][:3] and control['native_command'][0]=='taskset','paired CPU placement')
        require(control['build']['compiler_command']==cached['build']['compiler_command'],'paired compiler identity')
        clean=lambda b:[x for x in b['flags'] if not x.startswith(('-I','-J'))]
        require(clean(control['build'])==clean(cached['build']),'paired compiler policy')
        pairs.append(dict(pair=i,control=control['resource'],cache=cached['resource'],
                          user_cpu_ratio=control['resource']['user_seconds']/cached['resource']['user_seconds']))
    line=next(x for x in f['cache-O2-activation/native/stdout'].decode().splitlines() if x.startswith('PERF01_CACHE_CALLS_PREPARED'))
    calls,prepared=map(int,line.split()[1:])
    require(calls==sum(int(x['headcalc_calls']) for x in rows(old,'enabled/O0-six/work.csv')) and 0<prepared<=calls,'cache was not activated')
    independent=runpy.run_path(str(ROOT/PARENT))['capsule']('experiment_evidence')
    reference=rows(independent,'independent-water/tighter.csv')
    fine_solute=rows(independent,'refined-O2/native/trajectory.csv')
    curve=[]
    for label,tolerance in [('curve-1e-6',1e-6),('curve-1e-5',1e-5),('curve-1e-4',1e-4),('curve-1e-3',1e-3)]:
        r=js(label+'/RESULT.json');trajectory=rows(f,label+'/native/trajectory.csv');budget=rows(f,label+'/native/budget.csv')
        for p,h in r['inputs'].items():
            require(sha(f['source-versions/'+h+'.py'])==h if p==DRIVER else sha((ROOT/p).read_bytes())==h,'curve executed diagnostic version')
        require(r['mode']=='control' and r['tolerance']==tolerance and r['native_command'][:3]==
                js('pair-0-control/RESULT.json')['native_command'][:3],'accuracy/cost controller or CPU differs')
        require(r['resource']['returncode']==0 and not r['resource']['timed_out'] and len(trajectory)==2048 and len(budget)==64,'incomplete accuracy/cost point '+label)
        require(r['resource']==js(label+'/native/RESOURCE.json'),'curve resource binding')
        for p,h in r['raw_sha256'].items():require(sha(f[label+'/native/'+p])==h,'curve raw identity')
        for p,h in r['build']['input_sha256'].items():require(sha((ROOT/p).read_bytes())==h,'curve production source')
        require(all(e['returncode']==0 for e in r['events']),'curve observer build failed')
        require(f[label+'/generated/main.f90'].decode()==observe((ROOT/'app/solute_column/main.f90').read_text()),'curve changed physical calls')
        original=(ROOT/'examples/solute_column/dry32_implicit_pond.nml').read_text()
        expected=driver['once'](original,'temporal_tolerance=1e-06','temporal_tolerance='+str(tolerance))
        require(f[label+'/native/input.nml'].decode()==expected,'curve changed more than explicit tolerance')
        require(max(abs(float(x['water_residual_cm'])) for x in budget)<1e-10 and
                max(abs(float(x['solute_residual_mg_cm2'])) for x in budget)<1e-11,'curve hard conservation')
        errors={key:max(abs(float(a[key])-float(b[key])) for a,b in zip(trajectory,reference)) for key in ['head','theta']}
        errors['relative_theta']=max(abs(float(a['theta'])-float(b['theta']))/float(b['theta']) for a,b in zip(trajectory,reference))
        errors['solute_spread_vs_prior_fine_native']=max(abs(float(a['concentration'])-float(b['concentration'])) for a,b in zip(trajectory,fine_solute))
        require(all(float(b['concentration'])>0 for b in fine_solute),'relative solute comparison denominator')
        errors['relative_solute_spread_vs_prior_fine_native']=max(abs(float(a['concentration'])-float(b['concentration']))/float(b['concentration']) for a,b in zip(trajectory,fine_solute))
        for name,column in [('evaporation','pond_evaporation_cm'),('runoff','runoff_cm')]:
            total=0.;deltas=[]
            for i,x in enumerate(budget):
                total+=float(x[column]);deltas.append(abs(total-float(reference[i*32]['cumulative_'+name])))
            errors['cumulative_'+name]=max(deltas)
        w=rows(f,label+'/native/work.csv')
        curve.append(dict(tolerance=tolerance,resource=r['resource'],errors=errors,
                          headcalc_calls=sum(int(x['headcalc_calls']) for x in w),attempts=sum(int(x['attempts']) for x in w)))
    for name in ['budget.csv','trajectory.csv','state.csv','endpoint.csv','restart.bin']:
        require(f['curve-1e-6/native/'+name]==old['enabled/O2-day/'+name],'matched curve baseline physics')
    return dict(qualified=True,status='COMPLETE_POND_PROFILE_ERROR_COST_AND_REJECTED_CAPPED_POLICY',production_changed=False,
                source_tree=git('rev-parse','HEAD:src'),
                production_policy_admitted=False,profile_resource=profile['resource'],
                profile=summary,exact_cache_direct_pairs_per_profile=28800,exact_cache_pairs=pairs,
                cache_day_resource=js('cache-O2-day/RESULT.json')['resource'],general_cache_admitted=False,
                cache_activation=dict(calls=calls,prepared=prepared),accuracy_cost_curve=curve,
                failure_window=2,chemical_residual=residual,chemical_threshold=tolerance,chemical_substeps=int(steps),
                first_window_baseline=baseline,first_window_candidate=candidate,
                full_fci='NOT_SELECTED_GENERATED_DIAGNOSTICS_ONLY')


def verify():
    parent=runpy.run_path(str(ROOT/PARENT));parent['source']();result=validate(capsule())
    require(parent['verify_qualification']()['qualified'],'incumbent production qualification')
    return result


def self_test():
    runpy.run_path(str(ROOT/PARENT))['source']()
    f=capsule();validate(f);controls=[]
    def reject(name,action):
        try:action()
        except (ValueError,KeyError,AssertionError,StopIteration):controls.append(name);return
        raise ValueError('corruption accepted '+name)
    for p in ['profile-day/native/gmon.out','profile-day/native/restart.bin','cap-O2-balance/native/stdout','cache-O2-day/native/restart.bin','cache-direct/0005.stdout']:
        bad=dict(f);bad.pop(p);reject('missing '+p,lambda bad=bad:validate(bad))
    bad=dict(f);r=json.loads(bad['cap-O2-six/RESULT.json']);r['status']='COMPLETE_DIAGNOSTIC_NOT_PRODUCTION_ADMISSION'
    bad['cap-O2-six/RESULT.json']=json.dumps(r).encode();reject('failed policy relabelled',lambda:validate(bad))
    bad=dict(f);bad['profile-day/native/state.csv']+=b'!';reject('sampled physical drift',lambda:validate(bad))
    bad=dict(f);bad['curve-1e-3/native/budget.csv']=bad['curve-1e-6/native/budget.csv']
    reject('accuracy/cost raw case substituted',lambda:validate(bad))
    bad=dict(f);bad.pop('cache-O2-activation/native/stdout');reject('missing actual cache activation',lambda:validate(bad))
    for p in [PARENT,PARENT_STATUS,'src/runtime/mod_canonical_interval_runtime.f90',DRIVER]:
        reject('source '+p,lambda p=p:registered_additions(lambda q:(ROOT/q).read_bytes()+(b'!' if q==p else b'')))
    return dict(count=len(controls),negative_controls=controls)


if __name__=='__main__':print(json.dumps(self_test() if '--self-test' in sys.argv else verify(),indent=2))
