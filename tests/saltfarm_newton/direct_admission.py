"""Bounded current admission for the direct day-kernel transport, with literal history."""
from pathlib import Path
import contextlib,hashlib,importlib.util,io,json,runpy,subprocess,sys,tarfile,tempfile
ROOT=Path(__file__).resolve().parents[2]
BASE='cce2561eb87e992f671d97a35baef84ddb8d91e0'
RUNTIME='e7e24ab31f8a70b2bab68529ab085d2164d903d9'
NATIVE='8ba61729a79a365b41c00140dfb296f9bb821b24'
PROOF='integration/f-ci/saltfarm-guard-cost05/'
ENTRY='tests/nomacro_scheduled_subsurface/age_groundwater_verify.py'
SELF='tests/saltfarm_newton/direct_admission.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('saltfarm_direct_admission',ROOT/'tests/saltfarm_newton/direct_admission.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""

def require(value,message):
    if not value:raise ValueError(message)

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def normalized(raw):return raw.replace(b'\r\n',b'\n')
def tree(ref,path):return {v.split('\t',1)[1]:v.split('\t',1)[0] for v in git('ls-tree','-r',ref,'--',path).decode().splitlines()}

def validate(q):
    expected=dict(status='BOUNDED_DIRECT_DAY_KERNEL_QUALIFIED_PENDING_CANONICAL_ADMISSION',base=BASE,runtime=RUNTIME,native_producer=NATIVE,pr=1758,model='HYBRID_SALTFARM_WATER',protocol='swap5-direct-day-kernel-1',scope='registered original macro-free SaltFarm; external CoupledDailyColumn keeps pipe transport',water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10,full_periods=4,cold_windows=20,whole_scientific_equivalence='NOT_QUALIFIED',RC3_changed=False,predecessor=ENTRY,predecessor_receipt='integration/f-ci/nomacro-complete01/AGE_GROUNDWATER_MERGE_RECEIPT.json',owner=SELF)
    require(all(q.get(k)==v for k,v in expected.items()),'direct kernel admission scope/source/guard changed')
    require(q.get('test_selection',{}).get('not_selected')==['new physical models','new tolerance experiments','repeated full model runs at unchanged runtime dependency hashes'],'direct kernel test scope changed')


def remove(text,needle,replacement=''):
    require(text.count(needle)==1,'unreviewed nonselected transport projection: '+needle[:72])
    return text.replace(needle,replacement,1)


def nonselected_projection():
    """Delete only the qualified inactive hooks; literal old code must remain."""
    path='app/hybrid_water/daily_host.py';s=blob(RUNTIME,path).decode()
    s=remove(s,"    from direct_day_kernel import build as build_direct_kernel\n    direct_kernel=build_direct_kernel(output,[ROOT/s for s in sources],adapter,kernel_flags,project)\n\n")
    s=remove(s,"    if direct_kernel is not None:build_identity['direct_day_kernel']=direct_kernel\n")
    s=remove(s,'def start_process(stack, command, directory, name, *, direct_identity=None):','def start_process(stack, command, directory, name):')
    s=remove(s,"    if direct_identity is not None:\n        from direct_day_kernel import NativeDayKernel, library_path\n        transcript=stack.enter_context((directory/(name+'.stdout')).open('w',encoding='utf8'))\n        process=NativeDayKernel(library_path(Path(command[0]).parent),command[1],transcript)\n        stack.callback(process.terminate)\n        return process,transcript\n")
    s=remove(s,"    from direct_day_kernel import NativeDayKernel\n    if isinstance(process,NativeDayKernel):return process.write(text)\n")
    s=remove(s,"    from direct_day_kernel import NativeDayKernel\n    if isinstance(process,NativeDayKernel):return process.receive(prefixes)\n")
    s=remove(s,"        direct_identity=binding['build'].get('direct_day_kernel') if binding is not None else None\n        if direct_identity is not None:\n            from direct_day_kernel import validate as validate_direct\n            validate_direct(Path(kernel).parent,direct_identity,project)\n")
    s=remove(s,", **({'direct_identity':direct_identity} if direct_identity is not None else {}))",')')
    require(s.encode()==normalized(blob(BASE,path)),'nonselected host body changed')
    path='app/hybrid_water/daily_coupling.py';s=blob(RUNTIME,path).decode();s=remove(s,"    from direct_day_kernel import validate as validate_direct\n    validate_direct(bundle,identity.get('direct_day_kernel'),project)\n");require(s.encode()==normalized(blob(BASE,path)),'nonselected coupling body changed')
    path='tools/solute/run_water.py';s=blob(RUNTIME,path).decode();s=remove(s,"checkpoint_binding=binding if (args.checkpoint_at is not None or build_id.get('direct_day_kernel')) else None","checkpoint_binding=binding if args.checkpoint_at is not None else None");s=remove(s,"    if build_id.get('direct_day_kernel'):\n        report['kernel_transport']=build_id['direct_day_kernel']['protocol']\n        report['kernel_library_sha256']=build_id['direct_day_kernel']['library_sha256']\n");require(s.encode()==normalized(blob(BASE,path)),'nonselected CLI body changed')
    path='tests/saltfarm_newton/qualify.py';s=blob(RUNTIME,path).decode();s=remove(s,";p.add_argument('--model-cap',type=float,default=25)");s=s.replace('bounded(a.model_cap,','bounded(25,');require(s.encode()==normalized(blob(BASE,path)),'qualification scientific checks changed')
    body=blob(RUNTIME,'app/hybrid_water/direct_day_kernel.py').decode()
    require("MODEL = 'HYBRID_SALTFARM_WATER'" in body and 'return project.model == MODEL and not project.macro and not project.input_directory' in body,'transport selection broadened')
    return 'LITERAL_NONSELECTED_HOST_COUPLER_CLI_AND_OLD_SCIENTIFIC_CHECKS_PRESERVED'


def source_guard():
    require(not git('diff','HEAD','--','app','src','reference','tools','tests','.github','integration'),'dirty direct admission surface')
    untracked=git('ls-files','--others','--exclude-standard','--','app','src','reference','tools').decode().splitlines()
    require(all('__pycache__/' in p and p.endswith('.pyc') for p in untracked),'untracked production source')
    for ref in (BASE,RUNTIME,NATIVE):git('merge-base','--is-ancestor',ref,'HEAD')
    require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'production differs from qualified direct source')
    require(not git('diff',NATIVE,RUNTIME,'--','app','src','reference'),'native runtime producer changed')
    expected={'app/hybrid_water/daily_host.py','app/hybrid_water/daily_coupling.py','app/hybrid_water/direct_day_kernel.py','app/hybrid_water/direct_day_kernel.f90','tools/solute/run_water.py'}
    require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==expected,'unqualified direct production delta')
    current=tree('HEAD','integration')
    for p,v in tree(BASE,'integration').items():require(current.get(p)==v,'historical evidence rewritten: '+p)
    require((ROOT/ENTRY).read_text(encoding='utf8').replace(HOOK,'',1).encode()==normalized(blob(BASE,ENTRY)),'historical validator body rewritten')
    allowed={ENTRY,SELF,'tests/saltfarm_newton/test_direct_admission.py',PROOF+'ADMISSION.json',PROOF+'MERGE_RECEIPT.json','docs/science/SALTFARM_DIRECT_KERNEL05.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
    require(set(git('diff','--name-only',RUNTIME,'HEAD').decode().splitlines())<=allowed,'unqualified post-runtime controller/evidence change')
    # The full prior unit seal and all data remain literal; append only admission records.
    for name,digest in json.loads((ROOT/PROOF/'SEAL.json').read_text()).items():require(hashlib.sha256((ROOT/PROOF/name).read_bytes()).hexdigest()==digest,'sealed direct evidence changed: '+name)


def predecessor():
    """Validate literal prior sources and inherit the actual admitted old audit."""
    qp='integration/f-ci/nomacro-complete01/AGE_GROUNDWATER_QUALIFICATION.json';q=json.loads(blob(BASE,qp));receipt_path='integration/f-ci/nomacro-complete01/AGE_GROUNDWATER_MERGE_RECEIPT.json';receipt=json.loads(blob(BASE,receipt_path))
    require(receipt['status']=='ACTUAL_AGE_GROUNDWATER_CANONICAL_MERGE_VERIFIED' and receipt['exact_complete_tree'] is True and receipt['actual_detached_owner']['returncode']==0,'prior canonical owner not verified')
    previous=receipt['merge'];git('merge-base','--is-ancestor',previous,BASE)
    require(not git('diff',previous,BASE,'--','app','src','reference','tools'),'prior canonical metadata changed production')
    require(blob(previous,ENTRY)==blob(BASE,ENTRY),'admitted prior owner changed')
    report=json.loads(receipt['actual_detached_owner']['stdout']);require(report['status']=='ORIGINAL_AGE_GROUNDWATER_REACTION_PRIVATE_CALENDAR_NATIVE_ADMISSION_PASS' and report['whole_scientific_equivalence']=='NOT_QUALIFIED','prior actual owner verdict changed')
    paths={ENTRY,qp}
    for group in ('source_sha256','controller_sha256','frozen_predecessor_sources','frozen_predecessor_controllers'):paths.update(q[group])
    with tempfile.TemporaryDirectory(prefix='s5-literal-direct-predecessor-') as directory:
        snapshot=Path(directory);batches=[];batch=[];length=0
        for p in sorted(paths):
            if length+len(p)>11000:batches.append(batch);batch=[];length=0
            batch.append(p);length+=len(p)+3
        if batch:batches.append(batch)
        for batch in batches:
            with tarfile.open(fileobj=io.BytesIO(git('archive',BASE,'--',*batch))) as archive:
                for m in archive.getmembers():
                    if m.isdir():continue
                    target=snapshot/m.name;require(m.isfile() and m.name in paths and target.resolve().is_relative_to(snapshot.resolve()),'foreign frozen predecessor path');target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.extractfile(m).read())
        spec=importlib.util.spec_from_file_location('literal_age_groundwater_direct',snapshot/ENTRY);owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner);owner.validate(q)
    return dict(status='LITERAL_ADMITTED_AGE_SOURCE_SCHEMA_AND_IMMUTABLE_PRODUCER_AUDIT_INHERITED',merge=previous,actual_owner_seconds=receipt['actual_detached_owner']['seconds'],fresh_pass_claim=False)


def verify():
    q=json.loads((ROOT/PROOF/'ADMISSION.json').read_text());validate(q);source_guard();projection=nonselected_projection();prior=predecessor()
    checks=subprocess.run([sys.executable,'-B',str(ROOT/'tests/saltfarm_newton/test_direct_admission.py')],cwd=ROOT,capture_output=True,text=True,timeout=30)
    require(checks.returncode==0,'direct admission negative controls failed: '+checks.stderr)
    log=io.StringIO()
    with contextlib.redirect_stdout(log):runpy.run_path(str(ROOT/PROOF/'verify.py'),run_name='__main__')
    require('TWENTY_COLD_WINDOWS' in log.getvalue(),'current raw qualification incomplete')
    return dict(status='DIRECT_SALTFARM_KERNEL_WINDOWS_UBUNTU_O0_O2_ADMISSION_PASS',runtime=RUNTIME,native_producer=NATIVE,predecessor=prior,nonselected_projection=projection,current_full_periods=4,current_exact_cold_windows=20,water_guard_cm=1e-10,solute_guard_mg_cm2=1e-10,whole_scientific_equivalence='NOT_QUALIFIED',RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
