"""Bounded typed-reply owner: literal baseline, actual raw continuations, no reruns."""
from pathlib import Path
import ast,ctypes as c,hashlib,importlib.util,io,json,math,statistics,textwrap,zipfile
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('composition07',ROOT/'tests/saltfarm_newton/composition_admission.py')
prior=importlib.util.module_from_spec(spec);spec.loader.exec_module(prior)
git,blob,require,normalized=prior.git,prior.blob,prior.require,prior.normalized
BASE='b28706d8b16661d8a9e85339d317256eaca51206'
RUNTIME='9f640a440fde680c7dfed3618044ed83f6ad062f'
CANONICAL_DOC='472aa69611d5168cdc8d2dd4322669851c442df6'
PROOF='integration/f-ci/saltfarm-typed07/'
ENTRY='tests/saltfarm_newton/composition_admission.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('saltfarm_typed_admission07',ROOT/'tests/saltfarm_newton/typed_admission07.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
SCOPE='Actual new Python SDK on unchanged byte-bound admitted Windows O0/O2 Fortran libraries and complete actual input-word streams; not fresh Windows public-build full runs'
sha=lambda b:hashlib.sha256(b).hexdigest()

def validate(q):
    expected=dict(status='TYPED_DAY_REPLY_BOUNDED_QUALIFICATION',baseline=BASE,runtime=RUNTIME,model='HYBRID_SALTFARM_WATER',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10,full_periods_ubuntu=2,cold_windows_ubuntu=10,windows_role=SCOPE,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL',RC3_changed=False)
    require(all(q.get(k)==v for k,v in expected.items()),'typed reply source/scope/guards changed')

def projection():
    remove=prior.direct.remove
    path='app/hybrid_water/daily_host.py';s=normalized((ROOT/path).read_bytes()).decode()
    helper='def send_reply(process, values):\n    from direct_day_kernel import NativeDayKernel\n    if isinstance(process, NativeDayKernel):\n        return process.submit(values)\n    return send(process, " ".join(map(str, values)))\n\n\n'
    s=remove(s,helper);s=remove(s,'        send_reply(self.host, reply)','        send(self.host, " ".join(map(str, reply)))')
    require(s.encode()==normalized(blob(BASE,path)),'nonselected pipe/host changed')
    path='app/hybrid_water/direct_day_kernel.py';s=normalized((ROOT/path).read_bytes()).decode();old=blob(BASE,path).decode()
    start=s.index('    def submit(');end=s.index('    def receive(',start);submit=s[start:end]
    original=old[old.index('            reply = (c.c_double * len(values))'):old.index('        else:\n            raise ValueError(\'Invalid direct day kernel lifecycle\')')]
    # The C executor, disposition, revision, residual and receipt stay verbatim.
    require(textwrap.dedent(submit[submit.index('        result, status'):].rstrip())==textwrap.dedent(original[original.index('            result, status'):].rstrip()),'native guarded apply changed')
    s=remove(s,submit);s=remove(s,'            self.submit(tuple(map(float, values)))\n',original)
    require(s.encode()==normalized(blob(BASE,path)),'native lifecycle/selection/build identity changed')
    require(normalized((ROOT/ENTRY).read_bytes()).replace(HOOK.encode(),b'',1)==normalized(blob(BASE,ENTRY)),'literal predecessor rewritten')

def source_guard():
    require(not git('diff','HEAD','--','app','src','reference','tools','tests','.github','integration'),'dirty typed admission surface')
    for ref in (BASE,RUNTIME):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'unqualified production change')
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())=={'app/hybrid_water/daily_host.py','app/hybrid_water/direct_day_kernel.py'},'typed production scope broadened')
    current=prior.direct.tree('HEAD','integration')
    for p,v in prior.direct.tree(BASE,'integration').items():require(current.get(p)==v,'historical evidence rewritten: '+p)
    allowed={ENTRY,'tests/saltfarm_newton/typed_admission07.py','tests/saltfarm_newton/test_typed_admission07.py','tests/saltfarm_newton/typed_api07.py','tests/saltfarm_newton/typed_words07.py','tests/saltfarm_newton/isolated07.py','.github/workflows/saltfarm-isolated07.yml','.github/workflows/saltfarm-typed07.yml','docs/science/SALTFARM_TYPED_REPLY07.md','docs/status-a/CURRENT_STATUS.md'}
    canonical_delta=git('diff','--name-only',BASE,CANONICAL_DOC).decode().splitlines()
    require(len(canonical_delta)==1 and canonical_delta[0].startswith('docs/'),'canonical reconciliation has non-documentation changes')
    for p in canonical_delta:require(blob('HEAD',p)==blob(CANONICAL_DOC,p),'canonical documentation rewritten');allowed.add(p)
    require(all(p in allowed or p.startswith(PROOF) for p in git('diff','--name-only',RUNTIME,'HEAD').decode().splitlines()),'foreign post-runtime change')
    projection()

def windows_words(z,opt,record):
    p='accept-'+opt+'/full';raw=z.read(p+'/daily.jsonl');stdout=z.read(p+'/original/donor.stdout')
    data=[json.loads(x) for x in raw.splitlines()];hyd=[list(map(float,x.split()[1:])) for x in stdout.decode().splitlines() if x.startswith('HYBRID_HYDRAULIC')]
    require(len(data)==1461 and len(hyd)==1462,'incomplete Windows input words')
    digest=hashlib.sha256();count=0
    for day,row in enumerate(data,1):
        f=row['external_flux_cm'];v=[day,math.fsum(row['stock_end_cm']),math.fsum(f[:7]),math.fsum(f[7:]),f[15]-f[6],-hyd[day][1],*row['pressure_head_cm'],*row['stock_end_cm']]
        direct=bytes((c.c_double*len(v))(*v));text=bytes((c.c_double*len(v))(*map(float,' '.join(map(str,v)).split())))
        require(direct==text and all(math.isfinite(x) for x in v),'actual Windows C ABI words differ');digest.update(direct);count+=len(v)
    require(record['days']==1461 and record['actual_reply_words']==count==302427 and record['all_actual_c_abi_bytes_exact'] is True and record['reply_stream_sha256']==digest.hexdigest() and record['journal_sha256']==sha(raw) and record['hydraulic_stdout_sha256']==sha(stdout),'Windows word-stream evidence differs')

def decoder():
    # Reuse only the literal sealed pure payload/ledger decoding functions.
    # The actual old owner PASS is inherited from its detached receipt below;
    # this does not rerun/rebind an old current-source admission authority.
    prior.direct.audit_current_seal()
    source=(ROOT/prior.PROOF/'verify.py').read_text();tree=ast.parse(source)
    names={'rows','physical','csv','native','balance','cold'}
    selected=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names]
    require({n.name for n in selected}==names,'sealed payload decoder missing')
    namespace=dict(json=json,io=io,zipfile=zipfile,math=math,sha=sha)
    exec(compile(ast.Module(body=selected,type_ignores=[]),'<literal sealed payload decoders>','exec'),namespace)
    return namespace

def raw_verify(q):
    audit_raw=(ROOT/PROOF/'BASELINE_AUDIT.json').read_bytes();require(sha(normalized(audit_raw))==q['baseline_audit_sha256'],'actual canonical baseline receipt changed')
    audit=json.loads(audit_raw);a=audit['actual_detached_owner'];v=json.loads(a['stdout'])
    require(audit['merge']==BASE and audit['exact_complete_tree'] is True and a['head']==BASE and a['returncode']==0 and v['status']=='CANONICAL_IMPLICIT_AND_DIRECT_SALTFARM_COMPOSITION_ADMISSION_PASS','actual predecessor admission missing')
    require(audit['complete_tree']==git('rev-parse',BASE+'^{tree}').decode().strip() and audit['ordered_parents']==git('rev-list','--parents','-n','1',BASE).decode().split()[1:],'baseline Git tree or ordered parents differ')
    require(v['fresh_saltfarm_full_periods']==4 and v['fresh_saltfarm_exact_cold_windows']==20 and v['whole_scientific_equivalence']=='NOT_QUALIFIED','inherited qualification censored')
    for name,record in q['archives'].items():
        raw=(ROOT/PROOF/name).read_bytes();require(len(raw)==record['bytes'] and sha(raw)==record['sha256'],'typed raw archive changed: '+name)
    component_raw=(ROOT/PROOF/'WINDOWS_COMPONENT.json').read_bytes();require(sha(component_raw)==q['windows_component_sha256'],'Windows component receipt changed');w=json.loads(component_raw)
    require(w['scope']==SCOPE,'Windows component scope differs')
    prior.direct.sealed_representation(blob(RUNTIME,'app/hybrid_water/direct_day_kernel.py'),w['actual_python_host_sha256'],'direct_day_kernel.py')
    d=decoder()
    with zipfile.ZipFile(ROOT/PROOF/'TYPED_UBUNTU.zip') as z,zipfile.ZipFile(ROOT/prior.PROOF/'COMPOSITION_UBUNTU.zip') as old,zipfile.ZipFile(ROOT/prior.PROOF/'COMPOSITION_WINDOWS.zip') as win:
        data={};api=json.loads(z.read('TYPED_API.json'));transactions=json.loads(z.read('transactions/RESULT.json'))
        for opt in ('O0','O2'):
            p='accept-'+opt;data[opt]=d['cold'](z,p,p+'/restart{a}-{b}');previous=d['rows'](old,p+'/full')
            require(d['physical'](data[opt])==d['physical'](previous) and d['csv'](z,p+'/full')==d['csv'](old,p+'/full'),'production full trajectory changed')
            report=json.loads(z.read(p+'/RESULT.json'));build=json.loads(z.read('qualified-'+opt+'/BUILD.json'))
            require(report['source_commit']==q['workflows']['production']['source'] and report['status']=='FULL_PASS' and report['days']==1461,'fresh producer source/scope differs')
            require(not git('diff',RUNTIME,report['source_commit'],'--','app','src','reference','tools'),'producer production differs')
            native=build['identity']['direct_day_kernel']
            require(native['protocol']=='swap5-direct-day-kernel-1' and native['host_sha256']==sha(blob(RUNTIME,'app/hybrid_water/direct_day_kernel.py')) and native['bridge_sha256']==sha(blob(BASE,'app/hybrid_water/direct_day_kernel.f90')),'fresh native source identity differs')
            for day in (109,111,365,367,453,455,1460,1461):
                payload,meta=d['native'](z,p+'/full',day);require(payload==d['native'](old,p+'/full',day)[0] and meta['binding']['build']==build['identity'],'fresh complete native endpoint or binding differs')
            generated=lambda archive:{n.split('/',1)[1]:archive.read(n) for n in archive.namelist() if n.startswith('qualified-'+opt+'/') and n.endswith('.f90')}
            require(generated(z)==generated(old),'unchanged Fortran source differs')
            keys=('typed_text_exact','wrong_stage_refused','wrong_shape_does_not_consume_request','mass_refusal_keeps_revision_and_backend_clock','stale_day_refused','cancellation_refused','freed_context_refused','independent_columns_and_contexts','free_other_context_safe')
            require(all(api[opt][k] is True and w['api'][opt][k] is True for k in keys),'actual API ownership/rollback refusal missing')
            require(all(transactions[opt][k] is True for k in ('discard_replay_exact','independent_columns_exact','continuous_day454_exact','origin_unchanged','foreign_policy_refused')),'external transaction changed')
            windows_words(win,opt,w['words'][opt]);braw=win.read('qualified-'+opt+'/BUILD.json');b=json.loads(braw)
            require(w['libraries'][opt]['build_sha256']==sha(braw) and w['libraries'][opt]['library_sha256']==b['identity']['direct_day_kernel']['library_sha256'],'Windows actual library not bound')
        require(d['physical'](data['O0'])==d['physical'](data['O2']),'fresh optimization differs')
    with zipfile.ZipFile(ROOT/PROOF/'ISOLATED_RAW.zip') as z:
        r=json.loads(z.read('RESULT.json'));require(r['head']==q['workflows']['profile']['source'] and r['baseline']==BASE and r['status']=='ISOLATED_COMPARISON_AND_TYPED_FULL_COLD_EXACT','isolated source/scope differs')
        require(not git('diff',BASE,r['head'],'--','app','src','reference','tools'),'profile baseline changed')
        warm=d['rows'](z,'full1-canonical');d['balance'](warm)
        for p in ('full2-canonical','candidate-full0-canonical','candidate-full1-typed','candidate-full2-typed','candidate-full3-canonical'):
            rows=d['rows'](z,p);d['balance'](rows);require(d['physical'](rows)==d['physical'](warm) and d['csv'](z,p)==d['csv'](z,'full1-canonical'),'benchmark trajectory differs')
        for low,high in ((109,111),(365,367),(453,455),(1460,1461),(109,1461)):
            p=f'candidate-cold{low}-{high}';rows=d['rows'](z,p);d['balance'](rows);require(d['physical'](rows)==d['physical'](warm[low:high]) and d['native'](z,p,high)[0]==d['native'](z,'full1-canonical',high)[0],'prototype cold continuation differs')
        require([x for x in z.read('full0-original/result_output.csv').decode().splitlines() if x and not x.startswith('*')]==[x for x in z.read('full3-original/result_output.csv').decode().splitlines() if x and not x.startswith('*')],'original full outputs differ')
        controls=[v for v in r['candidate'] if v['mode']=='canonical'];typed=[v for v in r['candidate'] if v['mode']=='typed'];a=q['analysis']
        for field,items in [('control_seconds',[v['seconds'] for v in controls]),('typed_seconds',[v['seconds'] for v in typed]),('control_parent_cpu',[v['parent_cpu'] for v in controls]),('typed_parent_cpu',[v['parent_cpu'] for v in typed])]:require(a[field]==items,'timing cohort altered')
        require(a['wall_fraction_saved']==1-statistics.mean(a['typed_seconds'])/statistics.mean(a['control_seconds']) and a['parent_cpu_fraction_saved']==1-statistics.mean(a['typed_parent_cpu'])/statistics.mean(a['control_parent_cpu']) and max(a['typed_seconds'])<min(a['control_seconds']),'bounded timing conclusion differs')

def verify():
    q=json.loads((ROOT/PROOF/'QUALIFICATION.json').read_bytes());validate(q);source_guard();raw_verify(q)
    return dict(status='BOUNDED_SALTFARM_TYPED_REPLY_SOURCE_RAW_ADMISSION_PASS',baseline=BASE,runtime=RUNTIME,fresh_ubuntu_full_periods=2,fresh_ubuntu_exact_cold_windows=10,windows_full_periods_inherited=2,windows_actual_complete_input_words_per_period=302427,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10,RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
