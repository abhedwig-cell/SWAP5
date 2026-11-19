"""Independent source/raw admission of groundwater water state/calendar composition."""
from pathlib import Path
from datetime import date
import hashlib,io,json,re,struct,subprocess,sys,zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import implicit_conductivity_verify as old
import implicit_conductivity_forensics as p
import groundwater_water_forensics as f
from age_groundwater_verify import geometry
from perstep_domain_verify import build_files as compiled_files

BASE='b24dd2b7ac353300eaa5a18d11fdcbeaba8b23f1'
RUNTIME='3424a6c156b79b3d84395913dcc94424a586fd15'
MAIN='72aee8e15b928b9f2a8e6c96722cd4bf547925d2'
SEALED='03ddd8b8cbccfe716779c2aaf1ddfb4ed53a4b2e'
PROOF='integration/f-ci/nomacro-complete01/'
SELF='tests/nomacro_scheduled_subsurface/groundwater_water_verify.py'
ENTRY='tests/nomacro_scheduled_subsurface/age_groundwater_verify.py'
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('groundwater_water_admission',ROOT/'tests/nomacro_scheduled_subsurface/groundwater_water_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
CASES={'explicit-ordinary':(0,0,False,1,'periodic',3,1,1,True),
 'explicit-history-step':(0,1,True,3,'explicit',2,0,1,False),
 'explicit-history-clock':(0,2,False,3,'monthly',0,0,0,True),
 'implicit-ordinary-step':(1,0,True,3,'explicit',3,1,1,True),
 'implicit-history-clock':(1,1,False,3,'periodic',2,0,1,False),
 'implicit-history-step':(1,2,True,1,'monthly',0,0,1,False)}
require=p.require
digest=lambda raw:hashlib.sha256(raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def sha(path):return digest(path.read_bytes().replace(b'\r\n',b'\n'))
def tree(ref,path):return {line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-r',ref,'--',path).decode().splitlines()}
def read(z,path):return json.loads(z.read(path))
def rows(z,path):return [json.loads(line) for line in z.read(path+'daily.jsonl').splitlines()]
def physical(data):return [{k:v for k,v in row.items() if k not in ('column','revision')} for row in data]

MODEL_GUARD=r"""    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]+)',active)
    remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if (len(models)>1 or models and re.fullmatch(r'1(?:[ \t]+1)*[ \t]*',models[0].strip()) is None
            or re.search(r'(?i)\b(?:IHWCKMODEL|SWAP_SOILS_DB)\b',remainder)):return False
"""
PREFIX_GUARD="""    if len(raw)<36:raise ValueError('Incomplete groundwater native prefix')
    nodes,clock,step,canopy=struct.unpack_from('<i3d',raw,8)
    if (nodes!=n or not all(map(math.isfinite,(clock,step,canopy))) or not 0<step<=1 or canopy<0
            or clock!=project.start_clock+receipt.get('day',-1)
            or canopy!=receipt.get('stock_end_cm',[None]*4)[3]):
        raise ValueError('Actual groundwater native prefix differs from accepted receipt')
"""


def source(q):
 require(not git('status','--porcelain','--','app','src','reference','tools','tests','.github','integration'),'Dirty groundwater water admission surface')
 for ref in (BASE,RUNTIME,MAIN,SEALED,*q['source_producer_refs']):git('merge-base','--is-ancestor',ref,'HEAD')
 require(not git('diff',RUNTIME,'HEAD','--','app','src','reference','tools'),'Unqualified groundwater water production source change')
 require((q['baseline'],q['runtime'],q['main_producer'],q['status'])==(BASE,RUNTIME,MAIN,'BOUNDED_GROUNDWATER_WATER_COMPOSITION_QUALIFICATION_RECORD'),'Foreign groundwater water scope')
 require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and q['water_guard_cm']==1e-10 and q['implicit_age_admission'] is False and q['weighted_history_full_admission'] is False,'Whole scientific or unrelated blocked scope promoted')
 for group in ('source_sha256','controller_sha256'):require(q[group] and all(sha(ROOT/name)==value for name,value in q[group].items()),'Changed sealed groundwater source/controller')
 require(set(git('diff','--name-only',BASE,RUNTIME,'--','app','src','reference','tools').decode().splitlines())==set(q['source_sha256']),'Unregistered composition source change')
 require(not git('diff',BASE,'HEAD','--','src','reference','tools'),'Original physics/reference/tool provider changed')
 path='app/hybrid_water/implicit_groundwater_state.py';body=blob(RUNTIME,path).decode();require(body.count(MODEL_GUARD)==body.count(PREFIX_GUARD)==1,'Foreign current native/admission guard')
 require(body.replace(MODEL_GUARD,'',1).replace(PREFIX_GUARD,'',1).encode()==blob(MAIN,path) and set(git('diff','--name-only',MAIN,RUNTIME,'--','app','src','reference','tools').decode().splitlines())=={path},'Full producer differs beyond exact preworker/admission guards')
 mutable={PROOF+name for name in ('STATUS.json','GAP_MATRIX.json','CI_SELECTION.json')}
 current=tree('HEAD','integration')
 for ref in (BASE,SEALED):
  for name,value in tree(ref,'integration').items():
   if name not in mutable:require(current.get(name)==value,'Immutable admitted/raw evidence changed: '+name)
 docs={'docs/science/NOMACRO_GROUNDWATER_WATER_CALENDAR_20261119.md','docs/science/NOMACRO_IMPLICIT_CONDUCTIVITY_20261119.md','docs/science/SWAP5_FUNCTIONAL_CLOSURE.md','docs/status-a/CURRENT_STATUS.md','docs/status-a/CURRENT_ARCHITECTURE.md','docs/status-a/TRACEABILITY.md'}
 allowed={SELF,ENTRY,'tests/nomacro_scheduled_subsurface/test_groundwater_water_verify.py',PROOF+'GROUNDWATER_WATER_MERGE_RECEIPT.json',*mutable,*docs}
 require(set(git('diff','--name-only',SEALED,'HEAD').decode().splitlines())<=allowed,'Unqualified groundwater post-seal change')
 entry=(ROOT/ENTRY).read_text(encoding='utf8');require(entry.count(HOOK)==1 and entry.replace(HOOK,'',1).encode()==blob(BASE,ENTRY),'Literal predecessor registered entry changed')
 require(old.ROOT==ROOT and Path(f.__file__).resolve()==ROOT/'tests/nomacro_scheduled_subsurface/groundwater_water_forensics.py','Foreign admission/evidence module')
 for path in ('tests/nomacro_scheduled_subsurface/implicit_conductivity_forensics.py','tests/nomacro_scheduled_subsurface/implicit_conductivity_verify.py','tests/nomacro_scheduled_subsurface/perstep_domain_verify.py'):
  require((ROOT/path).read_bytes().replace(b'\r\n',b'\n')==blob(BASE,path),'Inherited independent reader changed')
 for workflow in q['workflows'].values():
  require(workflow['conclusion']=='success' and workflow['merge'] is False and workflow['head_sha']==workflow['carrier'] and set(git('diff','--name-only',workflow['runtime'],workflow['carrier']).decode().splitlines())=={'.github/workflows/nomacro-coverage-prescribed-head.yml'},'Portable producer/carrier/conclusion changed')
 receipt=json.loads((ROOT/PROOF/q['inheritance']['prior_actual_canonical_receipt']).read_text(encoding='utf8'))
 require(receipt['canonical']==BASE and receipt['ordered_parents']==git('show','-s','--format=%P',BASE).decode().split() and receipt['complete_tree']==git('rev-parse',BASE+'^{tree}').decode().strip()==git('rev-parse',receipt['qualified_head']+'^{tree}').decode().strip(),'Prior actual canonical source/tree rebound')
 prior=receipt['clean_detached_registered_owner'];require(prior['head']==BASE and prior['returncode']==0 and json.loads(prior['stdout'])['status']=='BOUNDED_ORIGINAL_IMPLICIT_WATER_CDE_SOURCE_RAW_NATIVE_ADMISSION_PASS','Prior actual clean canonical owner omitted')


def capsule(z,prefix):
 record=read(z,prefix+'RESULT.json');raw=z.read(prefix+record['archive']);require(len(raw)==record['bytes'] and digest(raw)==record['sha256'],'Changed original source capsule')
 actual={name:info.split()[2] for name,info in ((line.split('\t',1)[1],line.split('\t',1)[0]) for line in git('ls-tree','-r',record['producer_head']).decode().splitlines())}
 with zipfile.ZipFile(io.BytesIO(raw)) as source:
  require(set(source.namelist())=={name for name,item in record['members'].items() if item.get('checkout')!='ABSENT'},'Source capsule inventory changed')
  for name,item in record['members'].items():
   require(actual.get(name)==item['git_blob'],'Producer Git source identity changed')
   if item.get('checkout')=='ABSENT':continue
   data=source.read(name);require(len(data)==item['bytes'] and digest(data)==item['sha256'] and data[:8192].count(b'\0')==item['prefix_nul_8192'],'Producer raw source bytes changed')
   require(item['git_blob'] in {old.git_blob_id(data),old.git_blob_id(data.replace(b'\r\n',b'\n'))},'Actual producer raw/Git body differs')
 return record


def build_files(z,bp,ip,build,cap,opt):
 compiled_files(z,bp,build)
 for name,value in build['inputs'].items():require(digest(z.read(ip+name))==value,'Actual original input changed')
 for name,value in build['identity']['kernel_sources']:require(cap['members'][name]['sha256']==value,'Actual compiled kernel differs from producer source')
 for field in ('donor_flags','kernel_flags'):require({'-'+opt,'-ffp-contract=off','-march=x86-64','-mtune=generic'}<=set(build['identity'][field]),'Unqualified production arithmetic')
 require(build['project']['water_tolerance']==1e-10 and build['identity']['water_polish_policy']=='strict-water-always-polish-v1','Changed strict water boundary/polishing')
 for field,path in [('groundwater_native_state','implicit_groundwater_state.py'),('implicit_groundwater_trial','implicit_groundwater_trial.py'),('original_output','groundwater_water_output.py')]:
  require(build['identity'][field]['source_sha256']==cap['members']['app/hybrid_water/'+path]['sha256'],'Actual compiled composition helper differs from producer')
 # provider_sha256 names the rendered LF Fortran body. donor_generated
 # above separately verifies the actual compiled CRLF/LF checkout bytes.
 native=build['identity']['groundwater_native_state'];require(native['domain_bytes']==104 and native['hydraulic_doubles']=='5*actual_nodes+4' and native['provider_sha256']==digest(z.read(bp+native['provider_filename']).replace(b'\r\n',b'\n')),'Compiled typed carry differs')


def checkpoint(raw,build,row,selected,dz,implicit):
 with zipfile.ZipFile(io.BytesIO(raw)) as z:
  require(set(z.namelist())=={'checkpoint.json','result.end','macro.bin'},'Foreign checkpoint inventory');meta=json.loads(z.read('checkpoint.json'))
  require(meta['schema']=='swap5-hybrid-water-checkpoint-3' and meta['binding']==build['binding'] and meta['receipt']==row and set(meta['files'])=={'result.end','macro.bin'},'Checkpoint binding/receipt changed')
  for name,value in meta['files'].items():require(digest(z.read(name))==value,'Actual checkpoint member changed')
  p.sequential_records(z.read('result.end'));return f.native(z.read('macro.bin'),row,build,selected,dz,implicit)


def outputs(z,prefix):return {Path(name).name:p.output_records(z.read(name),name) for name in z.namelist() if name.startswith(prefix) and '/' not in name[len(prefix):] and Path(name).name in ('result_output.csv','result_output.bin')}


def period(z,root,report,build,selected,dz,implicit,phase):
 days={'short':35,'full':1096,'limit':2}[phase];require(report['status']=='ACTUAL_GROUNDWATER_WATER_'+phase.upper()+'_COMPLETE_CALENDAR_NATIVE_PASS' and report['trajectory']['days']==report['trajectory']['budgets']['days']==days,'Failed/censored period promoted')
 data=rows(z,root+'trajectory/');require(len(data)==days and data[0]['day']==1,'Censored actual period');p.water(data);p.original_observations(z.read(root+'trajectory/original/donor.stdout'),data,build['project']['start_date'])
 windows={(1,2)} if phase=='limit' else {(2,4),(7,9),(30,34)}
 if phase=='full':windows|={(199,201),(364,367),(530,532),(1094,1096)}
 require({(item['start'],item['end']) for item in report['cold']}==windows,'Actual cold window missing')
 def checks(prefix,actual):
  for name in z.namelist():
   if name.startswith(prefix+'accepted-column-1-day-') and name.endswith('.zip'):
    day=int(name.rsplit('-',1)[1][:-4]);checkpoint(z.read(name),build,next(row for row in actual if row['day']==day),selected,dz,implicit)
 checks(root+'trajectory/',data);warm=outputs(z,root+'trajectory/original/')
 for item in report['cold']:
  low,high=item['start'],item['end'];cp=root+f'own-{low}/';cold=rows(z,cp);require(physical(cold)==physical(data[low:high]),'Actual cold physical trajectory differs');p.water(cold);p.original_observations(z.read(cp+'original/donor.stdout'),cold,build['project']['start_date']);checks(cp,cold)
  with zipfile.ZipFile(io.BytesIO(z.read(root+f'trajectory/accepted-column-1-day-{high}.zip'))) as a,zipfile.ZipFile(io.BytesIO(z.read(cp+f'accepted-column-1-day-{high}.zip'))) as b:require(all(a.read(name)==b.read(name) for name in ('result.end','macro.bin')),'Complete cold payload differs')
  require(p.output_continuation(warm,outputs(z,cp+'original/'),selected,low,high,build['project']['start_date'])==item['exact_original_output'],'Actual user output continuation differs')
 return data,len(windows)


def controls_verify(q,archives,caps,periods):
 expected={(platform,opt,name) for platform in ('Windows','Ubuntu') for opt in ('O0','O2') for name in CASES};require({(v['platform'],v['optimization'],v['name']) for v in q['controls']}==expected and len(q['controls'])==len(expected),'Actual public/native control contexts missing/duplicated')
 native_count=policy_count=0
 for item in q['controls']:
  loc=q['locations'][item['location']];z=archives[loc['archive']];root=item['root'];control=read(z,root+'RESULT.json');policy=control
  require(control['status'] in ('ACTUAL_GROUNDWATER_WATER_PUBLIC_NATIVE_TRANSACTION_POLICY_PASS','ACTUAL_GROUNDWATER_WATER_INHERITED_PUBLIC_NATIVE_COMPLETE_POLICY_PASS'),'Failed public control promoted')
  if 'inherited_actual_controls' in control:
   inherited=control['inherited_actual_controls'];root=old.locate(inherited['root'],loc);require(digest(z.read(root+'RESULT.json'))==inherited['report_sha256'] and inherited['fresh_model_periods']==inherited['fresh_native_workers']==0,'Completed controls rebound as fresh');control=read(z,root+'RESULT.json')
   require(control['status']=='FAILED' and control['error'].startswith('FileNotFoundError('),'Unrelated failed subgate inherited')
  short=periods[(item['platform'],item['optimization'],item['name'],'short')];_,prior_root,report,prior_build,selected,dz,old_data=short;bp=root+'build/';build=read(z,bp+'BUILD.json');ip=old.locate(report['input_root'],loc);build_files(z,bp,ip,build,caps[item['capsule']],item['optimization']);prior_bp=old.locate(report['build_root'],loc)
  current_names={name[len(bp):] for name in z.namelist() if name.startswith(bp) and '/' not in name[len(bp):] and name.endswith('.f90')};before_names={name[len(prior_bp):] for name in z.namelist() if name.startswith(prior_bp) and '/' not in name[len(prior_bp):] and name.endswith('.f90')};require(current_names==before_names==set(control['unchanged_actual_fortran']),'Actual emitted-provider inventory changed')
  for name in current_names:require(z.read(bp+name)==z.read(prior_bp+name) and digest(z.read(bp+name))==control['unchanged_actual_fortran'][name],'Physical/state/calendar emitted provider changed across guard-only source')
  warm=rows(z,root+'warm/');cold=rows(z,root+'cold/');require(len(warm)==10 and physical(warm)==physical(old_data[:10]) and physical(cold)==physical(warm[4:9]),'Actual public physical trajectory differs');p.water(warm);p.water(cold)
  for pp,data in [(root+'warm/',warm),(root+'cold/',cold)]:p.original_observations(z.read(pp+'original/donor.stdout'),data,build['project']['start_date'])
  require(control['public_physical_complete_native_exact'] is True and all(control['transactions'].values()) and set(control['transactions'])=={'discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged'},'Actual public/active transaction gate omitted')
  raw=z.read(root+'warm/accepted-column-1-day-4.zip');checkpoint(raw,build,warm[3],selected,dz,CASES[item['name']][0])
  raw=z.read(root+'cold/accepted-column-1-day-9.zip');checkpoint(raw,build,warm[8],selected,dz,CASES[item['name']][0])
  with zipfile.ZipFile(io.BytesIO(raw)) as a,zipfile.ZipFile(io.BytesIO(z.read(prior_root+'trajectory/accepted-column-1-day-9.zip'))) as b:require(all(a.read(name)==b.read(name) for name in ('result.end','macro.bin')),'Actual complete public payload differs from qualified physical producer')
  require(p.output_continuation(outputs(z,root+'warm/original/'),outputs(z,root+'cold/original/'),selected,4,9,build['project']['start_date'])==control['public_output'],'Actual public user output differs')
  require(len(control['native_refusals'])==42 and len({v['attack'] for v in control['native_refusals']})==42,'Actual native refusal denominator differs')
  for attack in control['native_refusals']:
   pp=root+'native-'+attack['attack']+'/';wire=z.read(pp+'origin/macro.bin');require(attack['status']=='REFUSED' and not any(name.startswith(pp) and Path(name).name.startswith('accepted-') for name in z.namelist()),'Forged native accepted/published')
   try:f.native(wire,warm[3],build,selected,dz,CASES[item['name']][0])
   except (ValueError,struct.error,UnicodeError,IndexError):pass
   else:raise ValueError('Independent reader accepted actual corrupted native: '+attack['attack'])
   require('ERROR STOP' in attack['diagnostic'] or 'native' in attack['error'].lower() or 'receipt' in attack['error'].lower(),'Actual native rejection evidence missing')
  native_count+=42
  require({v['field'] for v in policy['policy_refusals']}=={'original_output','groundwater_native_state','implicit_groundwater_trial'} and len(policy['policy_refusals'])==3,'Actual metadata refusal missing')
  for attack in policy['policy_refusals']:
   bad=read(z,item['root']+'policy-'+attack['field']+'/BUILD.json');require(bad['identity'][attack['field']]=={'policy':'foreign'} and attack['status']=='REFUSED_BEFORE_WORKER' and 'Foreign' in attack['error'],'Actual immutable-policy corruption omitted')
  policy_count+=3
 return dict(public=len(expected),native=native_count,policy=policy_count)


def inheritance_verify(q,archives):
 selected=q['inheritance'];z=archives[selected['archive']];record=read(z,selected['prior_compiled']);require(record['status']=='THREE_ACTUAL_PRIOR_COMPILED_FORTRAN_CLOSURES_EXACT_NO_MODEL_PERIODS' and record['model_periods_executed']==0 and set(record['profiles'])=={'implicit-daily-water','implicit-daily-cde','explicit-groundwater-age'},'Unchanged prior compiled closure evidence missing')
 base_records={key:json.loads(blob(BASE,PROOF+key)) for key in ('IMPLICIT_CONDUCTIVITY_WINDOWS_O0_RAW_ARCHIVE.json','AGE_GROUNDWATER_WINDOWS_O0_RAW_ARCHIVE.json')};prior_archives={key:zipfile.ZipFile(io.BytesIO(old.raw_archive(value))) for key,value in base_records.items()};location=dict(platform='Windows',producer_root='C:/Users/Veldh012/swap5-complete01-evidence')
 for name,item in record['profiles'].items():
  prior=prior_archives['AGE_GROUNDWATER_WINDOWS_O0_RAW_ARCHIVE.json' if name=='explicit-groundwater-age' else 'IMPLICIT_CONDUCTIVITY_WINDOWS_O0_RAW_ARCHIVE.json'];bp=old.locate(item['current_build'],location);pp=old.locate(item['prior_build'],location)
  require(digest(z.read(bp+'BUILD.json'))==item['current_build_sha256'] and digest(prior.read(pp+'BUILD.json'))==item['prior_build_sha256'] and item['changed_emitted_providers']==[],'Actual prior build binding changed')
  actual={path[len(bp):] for path in z.namelist() if path.startswith(bp) and '/' not in path[len(bp):] and path.endswith('.f90')};require(actual==set(item['fortran_sha256']),'Prior actual provider inventory differs')
  for path in actual:require(z.read(bp+path)==prior.read(pp+path) and digest(z.read(bp+path))==item['fortran_sha256'][path],'Unchanged original provider reimplemented/changed')
  require(read(z,bp+'BUILD.json')['identity']['kernel_sources']==read(prior,pp+'BUILD.json')['identity']['kernel_sources'],'Unchanged computational kernel rebound')
 prior_q=json.loads(blob(BASE,PROOF+'IMPLICIT_CONDUCTIVITY_QUALIFICATION.json'));prefix=read(z,selected['prior_prefixes']);require(prefix['status']=='ALL_ACTUAL_PRIOR_IMPLICIT_GROUNDWATER_PREFIXES_SATISFY_NEW_GUARD_NO_MODELS' and prefix['fresh_model_periods']==0 and prefix['checkpoints']==len(prefix['members'])==296,'Prior actual typed prefixes omitted')
 for key,record in prior_q['archives'].items():
  actual=zipfile.ZipFile(io.BytesIO(old.raw_archive(record)))
  for item in prefix['members']:
   if item['archive']!=key:continue
   with zipfile.ZipFile(io.BytesIO(actual.read(item['member']))) as native:
    wire=native.read('macro.bin');receipt=json.loads(native.read('checkpoint.json'))['receipt'];nodes,clock,step,canopy=struct.unpack_from('<i3d',wire,8)
    require(digest(wire)==item['sha256'] and wire[:8]==b'S5IGW001' and nodes==len(receipt['pressure_head_cm']) and p.finite([clock,step,canopy]) and 0<step<=1 and canopy>=0 and canopy==receipt['stock_end_cm'][3] and receipt['day']==item['day'],'New guard would invalidate actual prior typed state')
  actual.close()
 return dict(compiled=3,prefixes=296)


def scientific(q):
 archives={}
 for key,record in q['archives'].items():
  z=zipfile.ZipFile(io.BytesIO(old.raw_archive(record)));require(set(z.namelist())==set(record['members']),'Raw artifact member inventory changed')
  for name,value in record['members'].items():require(digest(z.read(name))==value,'Actual raw member changed: '+name)
  archives[key]=z
 caps={name:capsule(archives[item['archive']],item['prefix']) for name,item in q['capsules'].items()}
 for name,item in q['capsules'].items():require(caps[name]['producer_head']==item['producer'],'Actual capsule producer rebound')
 periods={};counts=dict(short=0,full=0,limit=0,cold=0)
 expected={(platform,opt,name,phase) for platform in ('Windows','Ubuntu') for opt in ('O0','O2') for name,case in CASES.items() for phase in (('short','full') if case[-1] else ('short',))}|{(platform,opt,'limit-'+str(implicit),'limit') for platform in ('Windows','Ubuntu') for opt in ('O0','O2') for implicit in (0,1)}
 require({(v['platform'],v['optimization'],v['name'],v['phase']) for v in q['profiles']}==expected and len(q['profiles'])==len(expected),'Selected functional contexts missing/duplicated')
 for item in q['profiles']:
  loc=q['locations'][item['location']];z=archives[loc['archive']];root=item['root'];report=read(z,item['report']);bp=old.locate(report['build_root'],loc);ip=old.locate(report['input_root'],loc);build=read(z,bp+'BUILD.json');build_files(z,bp,ip,build,caps[loc['capsule']],item['optimization'])
  require(report['source_commit']==item['source_commit'] and report['trajectory']['build_sha256']==digest(z.read(bp+'BUILD.json')),'Actual model producer/build rebound')
  case=CASES[item['name']] if item['phase']!='limit' else (int(item['name'][-1]),1,False,1440,'explicit',3,1,1,False)
  implicit,hys,step,npd,mode,fmt,reset,drainage,_=case;raw=z.read(ip+'swap.swp');text=raw.decode('cp1252')
  def one(name):
   values=re.findall(r'(?mi)^[ \t]*'+name+r'[ \t]*=[ \t]*([+-]?\d+)[ \t]*(?:!.*)?$',text);require(len(values)==1,'Missing/ambiguous actual input selector');return int(values[0])
  require([one(name) for name in ('SWMACRO','SWSOLU','SWSNOW','SWFROST','SWHEA','SWCALT','SWBR','SWMETDETAIL','SWSOPHY','SWBOTB','SWKIMPL','SWKMEAN','SWHYST','SWDRA','NPRINTDAY','MAXIT','MAXBACKTR')]==[0,0,0,0,1,2,0,0,0,1,implicit,2,hys,drainage,npd,100,10],'Actual physical/numerical input domain differs')
  if implicit:
   expected_policy=old.numerical_policy(raw,2);expected_policy['source_sha256']=caps[loc['capsule']]['members']['app/hybrid_water/implicit_conductivity.py']['sha256'];require(build['identity']['implicit_conductivity']==expected_policy,'Inherited implicit numerical criteria changed')
  else:require('implicit_conductivity' not in build['identity'] and 'implicit_conductivity_retry' not in build['identity'],'Implicit numerical policy silently applied to explicit0')
  for crop in ('maize.crp','potato.crp','grass.crp'):
   body=z.read(ip+crop).decode('cp1252')
   for key,value in [('TOL_2',1e-10),('MYTOLX',1e-10),('TOLCONV',1e-9)]:
    actual=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([+\-\d.eEdD]+)[ \t]*(?:!.*)?$',body);require(len(actual)==1 and float(actual[0].replace('d','e').replace('D','E'))==value,'Explicit scheduled crop numerical qualification input changed')
  selected=build['identity']['original_output'];require(selected['policy']=='original-groundwater-water-complete-state-calendar-v1' and (selected['swhyst'],selected['flprintdt'],selected['nprintday'],selected['swcsv'],selected['swres'],selected['swdra'])==(hys,step,npd,fmt,reset,drainage) and selected['physical_equations_changed'] is False,'Compiled calendar selection differs')
  dz=geometry(raw,build['project']['nodes']);data,colds=period(z,root,report,build,selected,dz,implicit,item['phase']);counts[item['phase']]+=1;counts['cold']+=colds;periods[(item['platform'],item['optimization'],item['name'],item['phase'])]=(z,root,report,build,selected,dz,data)
 controls=controls_verify(q,archives,caps,periods);inherit=inheritance_verify(q,archives)
 return dict(status='BOUNDED_GROUNDWATER_WATER_COMPLETE_STATE_CALENDAR_SOURCE_RAW_NATIVE_ADMISSION_PASS',runtime=RUNTIME,actual_full_periods=counts['full'],actual_short_periods=counts['short'],actual_two_day_1440_periods=counts['limit'],actual_complete_native_cold_windows=counts['cold']+controls['public'],actual_public_contexts=controls['public'],actual_native_refusals=controls['native'],actual_policy_refusals=controls['policy'],actual_prior_compiled_closures=inherit['compiled'],actual_prior_typed_prefixes=inherit['prefixes'],fresh_unaffected_model_periods=0,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',implicit_age_admission=False,weighted_history_full_admission=False)


def verify():
 q=json.loads((ROOT/PROOF/'GROUNDWATER_WATER_QUALIFICATION.json').read_text(encoding='utf8'));source(q);return scientific(q)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
