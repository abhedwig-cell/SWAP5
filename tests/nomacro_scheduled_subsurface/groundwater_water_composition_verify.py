"""Current composed authority; both prior validator bodies and raw remain literal."""
from pathlib import Path
import hashlib,importlib.util,io,json,subprocess,sys,zipfile
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import groundwater_water_verify as gw
from cde_clock_verify import ledger as chemical_ledger

BASE='b28706d8b16661d8a9e85339d317256eaca51206'
META_CANONICAL='472aa69611d5168cdc8d2dd4322669851c442df6'
META_DOCUMENT='docs/publication/SWAP431_MACRO_AUDIT_STATUS_RECONCILIATION_2026-11-19.md'
PRIOR='5e655fc9fe5afef80c525f63900c809814e44449'
RUNTIME='e598948d6324a06e9d3974750471918f8be6ff2b'
SEALED='ee744246789a1ac9858b1b934000f2f207d24763'
PROOF=gw.PROOF
SELF='tests/nomacro_scheduled_subsurface/groundwater_water_composition_verify.py'
ENTRY=gw.ENTRY
GUARD_ENTRY='tests/saltfarm_newton/composition_admission.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('groundwater_composed_admission',ROOT/'tests/nomacro_scheduled_subsurface/groundwater_water_composition_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
GUARD_HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('groundwater_composed_guards',ROOT/'tests/nomacro_scheduled_subsurface/groundwater_water_composition_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.prior_guards()
"""
CHECKOUT_EVIDENCE='''            /integration/f-ci/nomacro-complete01/AGE_GROUNDWATER_WINDOWS_O0_RAW_ARCHIVE.json
            /integration/f-ci/nomacro-complete01/AGE_GROUNDWATER_WINDOWS_O0_RAW.zip
            /integration/f-ci/nomacro-complete01/IMPLICIT_CONDUCTIVITY_*
            /integration/f-ci/nomacro-complete01/GROUNDWATER_WATER_*
            /integration/f-ci/saltfarm-typed07/
'''
TEST_CHECKOUT_ADAPTER="""                current_spec=importlib.util.spec_from_file_location('current_evidence_checkout',s.ROOT/'tests/nomacro_scheduled_subsurface/groundwater_water_composition_verify.py')
                current=importlib.util.module_from_spec(current_spec);current_spec.loader.exec_module(current)
                new=current.strip_evidence_checkout(new)
"""
DIRECT_TEST_OLD=' def test_literal_nonselected_projection(self):owner.nonselected_projection()\n'
DIRECT_TEST_CURRENT=""" def test_literal_nonselected_projection(self):
  spec=importlib.util.spec_from_file_location('current_nonselected_projection',owner.ROOT/'tests/nomacro_scheduled_subsurface/groundwater_water_composition_verify.py')
  current=importlib.util.module_from_spec(spec);spec.loader.exec_module(current)
  self.assertEqual(current.prior_guards(),'LITERAL_NONSELECTED_HOST_COUPLER_CLI_AND_OLD_SCIENTIFIC_CHECKS_PRESERVED')
"""
require=gw.require;digest=gw.digest;git=gw.git;blob=gw.blob;tree=gw.tree
spec=importlib.util.spec_from_file_location('literal_direct_projection',ROOT/'tests/saltfarm_newton/direct_admission.py');direct=importlib.util.module_from_spec(spec);spec.loader.exec_module(direct)


def strip_evidence_checkout(text):
 require(text.count(CHECKOUT_EVIDENCE)==1,'Missing/ambiguous current scientific evidence checkout')
 return text.replace(CHECKOUT_EVIDENCE,'',1)


def prior_guards():
 import importlib.util
 spec=importlib.util.spec_from_file_location('saltfarm_typed_admission07',ROOT/'tests/saltfarm_newton/typed_admission07.py')
 owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
 return owner.operational_guards()
 entry=(ROOT/ENTRY).read_text(encoding='utf8');require(entry.count(HOOK)==1 and entry.replace(HOOK,'',1).encode()==blob(PRIOR,ENTRY),'Qualified groundwater entry body changed')
 body=(ROOT/GUARD_ENTRY).read_text(encoding='utf8');require(body.count(GUARD_HOOK)==1 and body.replace(GUARD_HOOK,'',1).encode()==blob(BASE,GUARD_ENTRY),'Qualified canonical literal-guard body changed')
 for path,ref in [('tests/saltfarm_newton/direct_admission.py',BASE),('tests/nomacro_scheduled_subsurface/implicit_conductivity_verify.py',BASE),(gw.SELF,PRIOR),('tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py',PRIOR)]:require((ROOT/path).read_bytes().replace(b'\r\n',b'\n')==blob(ref,path),'Inherited independent validator rewritten: '+path)
 # The actual literal app/coupler/CLI projection was already executed on
 # RUNTIME before this operational-only checkout addition. Inherit that
 # sealed result only while the actual producer source is still exact.
 name=PROOF+'GROUNDWATER_WATER_COMPOSITION_QUALIFICATION.json';raw=(ROOT/name).read_bytes().replace(b'\r\n',b'\n');require(raw==blob(SEALED,name),'Actual sealed source projection record changed');record=json.loads(raw)['source_projection']
 require(record['composed_source']==RUNTIME and record['groundwater_qualified_source']==gw.RUNTIME and record['incoming_canonical']==BASE and record['status']=='LITERAL_NONSELECTED_HOST_COUPLER_CLI_AND_OLD_SCIENTIFIC_CHECKS_PRESERVED','Actual literal source projection not qualified')
 require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'Qualified nonselected production projection changed')
 workflows={direct.WORKFLOW,direct.COLUMN};require(set(git('diff','--name-only',BASE,'HEAD','--','.github').decode().splitlines())==workflows,'Unqualified workflow dependency changed')
 for path in workflows:require(strip_evidence_checkout((ROOT/path).read_text(encoding='utf8')).encode()==blob(BASE,path),'Original workflow commands, limits or checkout rewritten')
 path='tests/hupsel51/test_successor.py';body=(ROOT/path).read_text(encoding='utf8');require(body.count(TEST_CHECKOUT_ADAPTER)==1 and body.replace(TEST_CHECKOUT_ADAPTER,'',1).encode()==blob(BASE,path),'Original successor tests rewritten beyond evidence checkout adapter')
 path='tests/saltfarm_newton/test_direct_admission.py';body=(ROOT/path).read_text(encoding='utf8');require(body.count(DIRECT_TEST_CURRENT)==1 and body.replace(DIRECT_TEST_CURRENT,DIRECT_TEST_OLD,1).encode()==blob(BASE,path),'Original direct tests rewritten beyond current operational projection adapter')
 return record['status']


def source(q):
 import importlib.util
 spec=importlib.util.spec_from_file_location('saltfarm_typed_admission07',ROOT/'tests/saltfarm_newton/typed_admission07.py')
 owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
 return owner.inherited_groundwater_source(q)
 require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'Dirty composed groundwater admission surface')
 for ref in (BASE,META_CANONICAL,PRIOR,RUNTIME,SEALED):git('merge-base','--is-ancestor',ref,'HEAD')
 require(set(git('diff','--name-only',BASE,META_CANONICAL).decode().splitlines())=={META_DOCUMENT} and blob('HEAD',META_DOCUMENT)==blob(META_CANONICAL,META_DOCUMENT),'Authoritative documentation-only canonical delta changed')
 require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'Unqualified composed groundwater production source change')
 require((q['status'],q['runtime'],q['incoming_canonical'],q['groundwater_qualified_head'])==('BOUNDED_GROUNDWATER_AND_INCOMING_CANONICAL_COMPOSITION_RECORD',RUNTIME,BASE,PRIOR),'Foreign current composition scope')
 require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['water_guard_cm']==q['chemical_guard_mg_cm2']==1e-10 and q['RC3_changed'] is False and q['full_model_periods_repeated']==0,'Composition source/science/guard promoted')
 for group in ('source_sha256','controller_sha256'):require(q[group] and all(gw.sha(ROOT/name)==value for name,value in q[group].items()),'Changed actual composed dependency')
 require(set(q['source_sha256'])==set(git('diff','--name-only',gw.BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines()) and set(q['controller_sha256'])=={'tests/nomacro_scheduled_subsurface/groundwater_water_composition_runtime.py'},'Composition dependency denominator changed')
 require(set(q['locations'])=={platform+'-'+opt for platform in ('Windows','Ubuntu') for opt in ('O0','O2')},'Composition platform/optimization missing')
 require(not git('diff',BASE,'HEAD','--','src','reference','tools'),'Incoming physics/reference/CLI changed')
 for path in ('app/hybrid_water/direct_day_kernel.py','app/hybrid_water/direct_day_kernel.f90'):require(blob(BASE,path)==blob(RUNTIME,path),'Incoming native bridge/lifecycle changed')
 require(prior_guards()=='LITERAL_NONSELECTED_HOST_COUPLER_CLI_AND_OLD_SCIENTIFIC_CHECKS_PRESERVED','Unselected groundwater source projection changed')
 original=json.loads((ROOT/PROOF/'GROUNDWATER_WATER_QUALIFICATION.json').read_text(encoding='utf8'));require(digest((ROOT/PROOF/'GROUNDWATER_WATER_QUALIFICATION.json').read_bytes().replace(b'\r\n',b'\n'))==q['groundwater_qualification_sha256'],'Original groundwater qualification rewritten')
 for name,value in original['controller_sha256'].items():require(gw.sha(ROOT/name)==value,'Original controller/evidence reader changed')
 require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(original['source_sha256']),'Foreign integration dependency surface')
 mutable={PROOF+name for name in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')};current=tree('HEAD','integration')
 for ref in (gw.SEALED,BASE,SEALED):
  for name,value in tree(ref,'integration').items():
   if name not in mutable:require(current.get(name)==value,'Sealed/incoming integration evidence changed: '+name)
 allowed={SELF,ENTRY,GUARD_ENTRY,'tests/nomacro_scheduled_subsurface/test_groundwater_water_composition_verify.py','tests/hupsel51/test_successor.py','tests/saltfarm_newton/test_direct_admission.py',direct.WORKFLOW,direct.COLUMN,PROOF+'GROUNDWATER_WATER_MERGE_RECEIPT.json',*mutable,'docs/science/NOMACRO_GROUNDWATER_WATER_CALENDAR_20261119.md','docs/science/NOMACRO_IMPLICIT_CONDUCTIVITY_20261119.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
 allowed.add(META_DOCUMENT)
 require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<=allowed,'Unqualified post-composition-seal change')
 prior=q['actual_incoming_owner'];require(prior['head']==BASE and prior['returncode']==0 and json.loads(prior['stdout'])['status']=='CANONICAL_IMPLICIT_AND_DIRECT_SALTFARM_COMPOSITION_ADMISSION_PASS','Actual incoming clean canonical owner omitted')
 workflow=q['workflow'];require(workflow['conclusion']=='success' and workflow['merge'] is False and workflow['head_sha']==workflow['carrier'] and set(git('diff','--name-only',workflow['runtime'],workflow['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'Actual composition carrier not isolated/terminal')
 direct.audit_current_seal();return original


def scientific(q,original):
 archives={}
 for key,record in q['archives'].items():
  z=zipfile.ZipFile(io.BytesIO(gw.old.raw_archive(record)));require(set(z.namelist())==set(record['members']),'Composition raw inventory changed')
  for name,value in record['members'].items():require(digest(z.read(name))==value,'Composition raw member changed')
  archives[key]=z
 require(set(q['locations'])=={platform+'-'+opt for platform in ('Windows','Ubuntu') for opt in ('O0','O2')},'Composition platform/optimization missing')
 count=0
 for key,loc in q['locations'].items():
  z=archives[loc['archive']];root=loc['root'];report=gw.read(z,root+'RESULT.json');require(report['status']=='THREE_ACTUAL_COMPOSED_GROUNDWATER_AND_NAMED_SALTFARM_DISPATCH_NATIVE_SEAMS_PASS' and set(report['contexts'])=={'explicit-history-step','implicit-ordinary-step','named-saltfarm'},'Composed actual seam censored')
  cap=gw.capsule(archives[loc['capsule_archive']],loc['capsule_prefix']);old_location=original['locations'][key];old_z=zipfile.ZipFile(io.BytesIO(gw.old.raw_archive(original['archives'][old_location['archive']])))
  salt_q=json.loads(blob(BASE,'integration/f-ci/saltfarm-guard-cost05/COMPOSITION_QUALIFICATION.json'));salt_record=salt_q['archives'][loc['platform']];salt_path=ROOT/'integration/f-ci/saltfarm-guard-cost05'/salt_record['archive'];require(digest(salt_path.read_bytes())==salt_record['sha256'],'Original canonical SaltFarm composition raw changed');salt=zipfile.ZipFile(salt_path)
  for name,item in report['contexts'].items():
   pp=root+name+'/';bp=pp+'build/';build=gw.read(z,bp+'BUILD.json');gw.compiled_files(z,bp,build);require(digest(z.read(bp+'BUILD.json'))==item['build_sha256'] and build['identity']['host']==cap['members']['app/hybrid_water/daily_host.py']['sha256'],'Actual composed compiled host rebound')
   if name!='named-saltfarm':
    prior_item=next(v for v in original['profiles'] if (v['platform'],v['optimization'],v['phase'],v['name'])==(loc['platform'],loc['optimization'],'short',name));prior_report=gw.read(old_z,prior_item['report']);prior_bp=gw.old.locate(prior_report['build_root'],old_location);previous=gw.read(old_z,prior_bp+'BUILD.json');gold=gw.rows(old_z,prior_item['root']+'trajectory/');actual_native=False
   else:prior_bp='qualified-'+loc['optimization']+'/';previous=gw.read(salt,prior_bp+'BUILD.json');gold=gw.rows(salt,'accept-'+loc['optimization']+'/full/');actual_native=True
   baseline=old_z if not actual_native else salt;actual_names={path[len(bp):] for path in z.namelist() if path.startswith(bp) and '/' not in path[len(bp):] and path.endswith('.f90')};before_names={path[len(prior_bp):] for path in baseline.namelist() if path.startswith(prior_bp) and '/' not in path[len(prior_bp):] and path.endswith('.f90')};require(actual_names==before_names==set(item['generated_fortran_sha256']),'Current composed generated inventory differs')
   for path in actual_names:require(z.read(bp+path)==baseline.read(prior_bp+path) and digest(z.read(bp+path))==item['generated_fortran_sha256'][path],'Current composed Fortran differs from qualified physical producer')
   require(build['inputs']==previous['inputs'] and build['identity']['kernel_sources']==previous['identity']['kernel_sources'],'Composed original input/kernel bytes differ')
   for path,value in build['identity']['kernel_sources']:require(cap['members'][path]['sha256']==value,'Actual composed kernel source differs from producer')
   for flags in ('donor_flags','kernel_flags'):require({'-'+loc['optimization'],'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][flags]),'Composed production arithmetic changed')
   direct_id=build['identity'].get('direct_day_kernel');require((direct_id is not None)==actual_native==item['direct_selected'],'Named authority crossed explicit-input boundary')
   if actual_native:
    require(direct_id['protocol']=='swap5-direct-day-kernel-1' and direct_id['model']=='HYBRID_SALTFARM_WATER','Composed named bridge protocol/model changed')
    for field,file in [('bridge_sha256','direct_day_kernel.f90'),('host_sha256','direct_day_kernel.py')]:require(direct_id[field]==cap['members']['app/hybrid_water/'+file]['sha256'],'Actual named bridge source differs')
    library='direct_day_kernel.dll' if loc['platform']=='Windows' else 'direct_day_kernel.so';require(digest(z.read(bp+library))==direct_id['library_sha256'],'Actual named library differs')
   warm=gw.rows(z,pp+'warm/');cold=gw.rows(z,pp+'cold/');endpoint=gw.rows(z,pp+'warm-endpoint/');require(len(warm)==2 and len(cold)==1 and gw.physical(warm)==gw.physical(gold[:2])==gw.physical(endpoint) and gw.physical(cold)==gw.physical(warm[1:2]),'Actual integrated current physical projection differs')
   for data in (warm,cold,endpoint):gw.p.water(data)
   if actual_native:
    for data in (warm,cold,endpoint):chemical_ledger(data,len(data))
   with zipfile.ZipFile(io.BytesIO(z.read(pp+'cold/accepted-column-1-day-2.zip'))) as a,zipfile.ZipFile(io.BytesIO(z.read(pp+'warm-endpoint/accepted-column-1-day-2.zip'))) as b:
    require(all(a.read(member)==b.read(member) for member in ('result.end','macro.bin')),'Actual composed complete warm/cold native differs')
    for native,data in [(a,cold),(b,endpoint)]:
     meta=json.loads(native.read('checkpoint.json'));require(meta['binding']==build['binding'] and meta['receipt']==data[-1],'Composed real native manifest/source receipt differs')
     for member,value in meta['files'].items():require(digest(native.read(member))==value,'Composed native member changed')
     gw.p.sequential_records(native.read('result.end'))
    if not actual_native:
     selected=build['identity']['original_output'];ip=gw.old.locate(prior_report['input_root'],old_location);dz=gw.geometry(old_z.read(ip+'swap.swp'),build['project']['nodes']);gw.f.native(a.read('macro.bin'),cold[-1],build,selected,dz,gw.CASES[name][0])
     with zipfile.ZipFile(io.BytesIO(old_z.read(prior_item['root']+'trajectory/accepted-column-1-day-2.zip'))) as old_native:require(all(a.read(member)==old_native.read(member) for member in ('result.end','macro.bin')),'Composed groundwater complete payload differs from full-period producer')
     require(gw.p.output_continuation(gw.outputs(z,pp+'warm/original/'),gw.outputs(z,pp+'cold/original/'),selected,1,2,build['project']['start_date'])==item['original_output'],'Composed original user continuation differs')
   require(item['status']=='ACTUAL_COMPOSED_DISPATCH_PHYSICAL_NATIVE_REPLAY_PASS' and item['physical_first_two_days_exact'] is item['complete_native_replay_exact'] is item['origin_unchanged'] is True,'Actual shared seam assertion omitted');count+=1
  old_z.close();salt.close()
 return count


def verify():
 import importlib.util
 spec=importlib.util.spec_from_file_location('saltfarm_typed_admission07',ROOT/'tests/saltfarm_newton/typed_admission07.py')
 owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
 return owner.verify()
 q=json.loads((ROOT/PROOF/'GROUNDWATER_WATER_COMPOSITION_QUALIFICATION.json').read_text(encoding='utf8'));original=source(q);seams=scientific(q,original);prior=gw.scientific(original)
 return dict(status='BOUNDED_GROUNDWATER_AND_CANONICAL_NAMED_TRANSPORT_COMPOSITION_ADMISSION_PASS',runtime=RUNTIME,incoming_canonical=BASE,inherited_groundwater=prior,inherited_saltfarm_full_periods=4,inherited_saltfarm_exact_cold_windows=20,actual_two_day_shared_dispatch_native_contexts=seams,full_model_periods_repeated=0,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',water_guard_cm=1e-10,chemical_guard_mg_cm2=1e-10,RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
