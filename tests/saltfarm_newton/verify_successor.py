"""Scoped Newton successor: real raw trajectories and literal frozen authority."""
from pathlib import Path
import hashlib,importlib.util,io,json,math,subprocess,sys,tarfile,tempfile,zipfile

ROOT=Path(__file__).resolve().parents[2]
BASE='f2fc11124d98e1238d5996ec2af21cbde24e49d9'
RUNTIME='355559313c8b47f7fd83b88c5c123e84e5b66d03'
SEALED='0c84f62b39e16ac6184ca39865e337aba8fe261e'
PROOF='integration/f-ci/saltfarm-newton-work01/'
ENTRY='tests/nomacro_scheduled_subsurface/thermal_calendar_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('saltfarm_newton_admission',ROOT/'tests/saltfarm_newton/verify_successor.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
def require(value,message):
    if not value:raise ValueError(message)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def digest(data):return hashlib.sha256(data).hexdigest()
def blob(ref,path):return git('show',ref+':'+path)
def tree(ref,path):return {s.split('\t',1)[1]:s.split('\t',1)[0] for s in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def source_guard():
    require(not git('diff','HEAD','--','app','src','reference','tools','tests','.github','integration'),'dirty Newton qualification surface')
    untracked=git('ls-files','--others','--exclude-standard','--','app','src','reference','tools').decode().splitlines()
    require(all('__pycache__/' in p and p.endswith('.pyc') for p in untracked),'untracked production source on Newton surface')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'production differs from qualified Newton source')
    changed=set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())
    require(changed=={'app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py','tools/solute/run_water.py'},'foreign Newton production delta')
    require((ROOT/ENTRY).read_text(encoding='utf8').replace(HOOK,'',1).encode()==blob(BASE,ENTRY).replace(b'\r\n',b'\n'),'literal preceding Snow owner changed')
    current=tree('HEAD','integration')
    for path,value in tree(BASE,'integration').items():require(current.get(path)==value,'historical evidence rewritten: '+path)
    allowed={ENTRY,'.github/workflows/saltfarm-newton.yml','docs/science/SALTFARM_NEWTON_WORK01.md',
        'docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    delta=git('diff','--name-only',RUNTIME,'HEAD').decode().splitlines()
    require(all(p in allowed or p.startswith((PROOF,'tests/saltfarm_newton/')) for p in delta),'unqualified Newton post-runtime change')

def predecessor():
    """Reuse admitted canonical records only at their exact frozen source.

    This is an explicit historical validation, never a current source PASS.
    Model reruns are not justified for byte-identical inherited evidence.
    """
    path='integration/f-ci/nomacro-complete01/THERMAL_CALENDAR_QUALIFICATION.json';raw=blob(BASE,path)
    require((ROOT/path).read_bytes().replace(b'\r\n',b'\n')==raw.replace(b'\r\n',b'\n'),'preceding canonical qualification changed')
    q=json.loads(raw);paths={ENTRY,path}
    for group in ('source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):paths.update(q[group])
    with tempfile.TemporaryDirectory(prefix='saltfarm-literal-snow-') as directory:
        snapshot=Path(directory);batches=[];batch=[];length=0
        for p in sorted(paths):
            if length+len(p)>11000:batches.append(batch);batch=[];length=0
            batch.append(p);length+=len(p)+3
        if batch:batches.append(batch)
        for batch in batches:
            with tarfile.open(fileobj=io.BytesIO(git('archive',BASE,'--',*batch))) as archive:
                for member in archive.getmembers():
                    if member.isdir():continue
                    target=snapshot/member.name;require(member.isfile() and target.resolve().is_relative_to(snapshot.resolve()),'foreign frozen source path');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(member).read())
        spec=importlib.util.spec_from_file_location('literal_snow_newton',snapshot/ENTRY);owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner);owner.validate(q)
        # Read-only archive decoder receives current immutable bytes, not a
        # fictitious current-source validation. All source checks ran above.
        owner.ROOT=ROOT
        for record in q['archives'].values():owner.raw_archive(record)
    return 'EXACT_CANONICAL_SNOW_SOURCE_SCHEMA_AND_UNCHANGED_RAW_ARCHIVES_INHERITED'

def native(z,path):
    with zipfile.ZipFile(io.BytesIO(z.read(path))) as q:return {n:q.read(n) for n in ('result.end','macro.bin')}
def physical(data):return [{k:v for k,v in r.items() if k not in ('column','revision')} for r in data]
def audit(z,platform,producer=RUNTIME):
    result={};data={}
    def rows(path):return [json.loads(s) for s in z.read(path).splitlines()]
    def csv(path):return [s for s in z.read(path).decode().splitlines() if s.strip() and not s.startswith('*')]
    for opt in ('O0','O2'):
        prefix='accept-'+opt;report=json.loads(z.read(prefix+'/RESULT.json'));buildraw=z.read('qualified-'+opt+'/BUILD.json');build=json.loads(buildraw);identity=build['identity'];data[opt]=rows(prefix+'/full/daily.jsonl')
        require(report['status']=='FULL_PASS' and report['source_commit']==producer and report['days']==1461,'incomplete or foreign Newton producer')
        require(digest(buildraw)==report['build_sha256'] and '-'+opt in identity['donor_flags'] and '-'+opt in identity['kernel_flags'],'Newton optimization/build rebound')
        require(identity['water_polish_policy']=='strict-water-half-interior-polish-v1','foreign Newton stopping policy')
        require([r['day'] for r in data[opt]]==list(range(1,1462)),'censored Newton trajectory')
        def balance(values):
            require(all(r['committed'] and all(math.isfinite(r[k]) and abs(r[k])<=1e-10 for k in ('independent_residual_cm','kernel_residual_cm','solute_independent_residual_mg_cm2')) for r in values),'Newton mass acceptance changed or failed')
            for r in values:
                start,end,flow=r['stock_start_cm'],r['stock_end_cm'],r['external_flux_cm'];ledger=r['solute_ledger_mg_cm2']
                require(len(start)==len(end)==6 and len(flow)==16 and len(r['pressure_head_cm'])==195 and len(ledger)==9,'incomplete actual Newton state/ledger')
                require(all(math.isfinite(v) for v in [*start,*end,*flow,*ledger,*r['pressure_head_cm'],*r['uptake_terms_cm']]),'nonfinite actual Newton state')
                water=math.fsum([*flow[:7],*(-v for v in flow[7:]),*start,*(-v for v in end)])
                stock,delta,rain,irrig,bottom,drain,decay,root,reported=ledger
                solute=math.fsum([stock,-r['solute_start_mg_cm2'],-rain,-irrig,-bottom,drain,decay,root])
                require(water==r['independent_residual_cm'] and solute==r['solute_independent_residual_mg_cm2'] and abs(reported)<=1e-10,'actual stock/flux ledger differs from claimed Newton balance')
            require(all(b['stock_start_cm']==a['stock_end_cm'] and b['solute_start_mg_cm2']==a['solute_end_mg_cm2'] for a,b in zip(values,values[1:])),'actual Newton daily stock continuity differs')
        balance(data[opt]);require(max(abs(r['independent_residual_cm']) for r in data[opt])==report['budgets']['max_water_cm'],'reported Newton water balance differs')
        windows=[(v['start'],v['end']) for v in report['restarts']];require(windows==[(109,111),(365,367),(453,455),(1460,1461),(109,1461)],'Newton cold window omitted')
        for start,end in windows:
            sub=prefix+f'/restart{start}-{end}';actual=rows(sub+'/daily.jsonl');balance(actual);require(physical(actual)==physical(data[opt][start:end]),'Newton cold physical differs');require(csv(sub+'/original/result_output.csv')[-(end-start):]==csv(prefix+'/full/original/result_output.csv')[start+2:end+2],'Newton cold CSV differs');require(native(z,sub+f'/accepted-column-1-day-{end}.zip')==native(z,prefix+f'/full/accepted-column-1-day-{end}.zip'),'Newton native cold differs')
        for p,d in [*identity['kernel_sources'],('app/hybrid_water/daily_host.py',identity['host'])]:
            raw=blob(RUNTIME,p).replace(b'\r\n',b'\n')
            require(d in (digest(raw),digest(raw.replace(b'\n',b'\r\n'))),'foreign actual compiled source hash')
            require(digest(raw)==digest((ROOT/p).read_bytes().replace(b'\r\n',b'\n')),'changed qualified source')
        result[opt]=dict(days=1461,max_water_cm=report['budgets']['max_water_cm'],max_solute_mg_cm2=report['budgets']['max_solute_mg_cm2'],exact_cold_windows=len(windows),build_sha256=report['build_sha256'])
    require(physical(data['O0'])==physical(data['O2']),'Newton optimization physical difference')
    transactions=json.loads(z.read('transactions/RESULT.json'))
    for opt in ('O0','O2'):
        require(all(transactions[opt][k] is True for k in ('discard_replay_exact','independent_columns_exact','continuous_day454_exact','origin_unchanged','foreign_policy_refused')),'Newton actual transaction contract incomplete')
        for side in ('left','right'):
            path=f'transactions/{opt}/{side}/accepted-column-1-day-454.zip'
            require(native(z,path)==native(z,f'transactions/{opt}/'+('right' if side=='left' else 'left')+'/accepted-column-1-day-454.zip'),'independent Newton native differs')
    return result

def verify():
    source_guard()
    require((ROOT/PROOF/'PORTABLE.json').read_bytes()==blob(SEALED,PROOF+'PORTABLE.json'),'sealed Newton platform qualification changed')
    q=json.loads((ROOT/PROOF/'PORTABLE.json').read_text());require(q['runtime']==RUNTIME and q['base']==BASE and q['water_guard_cm']==q['solute_guard_mg_cm2']==1e-10,'foreign portable Newton scope')
    require(q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['RC3_changed'] is False,'Newton scientific/release scope promoted')
    prior=predecessor();reports={}
    require(set(q['archives'])=={'Windows','Ubuntu'},'portable Newton platform omitted')
    for platform,record in q['archives'].items():
        producer=record['producer_ref'];git('merge-base','--is-ancestor',producer,'HEAD')
        require(not git('diff',RUNTIME,producer,'--','app','src','reference','tools','tests/saltfarm_newton/qualify.py','tests/saltfarm_newton/transactions.py'),'Newton model/controller producer differs')
        raw=(ROOT/PROOF/record['file']).read_bytes();require(digest(raw)==record['sha256'] and len(raw)==record['bytes'],'Newton producer archive changed')
        if platform=='Ubuntu':require(record['actual_artifact_bytes_preserved'] is True and record['origin_artifact_digest']=='sha256:'+digest(raw),'Ubuntu artifact rebound')
        with zipfile.ZipFile(io.BytesIO(raw)) as z:reports[platform]=audit(z,platform,producer)
    return dict(status='SALTFARM_NEWTON_WINDOWS_UBUNTU_O0_O2_FULL_NATIVE_ADMISSION_PASS',runtime=RUNTIME,base=BASE,platforms=reports,predecessor=prior,whole_scientific_equivalence='NOT_QUALIFIED',RC3_changed=False)
if __name__=='__main__':print(json.dumps(verify(),indent=2))
