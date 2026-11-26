"""Read actual local hydraulic periods through explicit immutable Git ZIP views."""
import io,json,re,zipfile
from contextlib import ExitStack
from pathlib import Path,PureWindowsPath
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_current_science import observe
R=Path(__file__).resolve().parents[2]
BASE='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e'
W=PureWindowsPath('C:/Users/Veldh012/SWAP5-work/01a1e8b4-228b-75f1-8ac4-b07ca1e15713-a9ded600')
ORDINARY={'gardner-water':([2],0,0,None),'model7-snow-cde-fitted':([7],1,1,None),'model3-water':([3],0,0,2),'model4-snow-water':([4],0,1,2),'model5-cde-profile':([5],1,0,1),'model6-snow-cde-profile':([6],1,1,1),'mixed8-9-water':([8,9],0,0,2),'mixed10-11-snow-water':([10,11],0,1,2),'mixed1-7-cde':([1,7],1,0,2)}
FROST={'mixed2-3-water-d0-b5':([2,3],0),'mixed4-5-cde-d1-b5':([4,5],1),'mixed6-7-cde-d0-b8':([6,7],1),'mixed8-9-water-d1-b8':([8,9],0),'mixed10-11-water-d0-b5':([10,11],0)}

class Original:
 def __init__(self,source,name,stack):
  q=self.record=json.loads((source/(name+'.json')).read_text());pieces=[]
  for part in q.get('parts',[dict(file=q['archive'],bytes=q['bytes'],sha256=q['sha256'])]):
   raw=(source/part['file']).read_bytes();assert len(raw)==part['bytes'] and SHA(raw)==part['sha256'];pieces.append(raw)
  raw=b''.join(pieces);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'];self.z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));self.names=q['members'];assert len(self.z.namelist())==len(set(self.z.namelist()))==len(self.names) and set(self.z.namelist())==set(self.names)
 def get(self,name):
  raw=self.z.read(name);item=self.names[name];assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];return raw

def assignment(text,key,value):
 pattern=re.compile(r'(?mi)^([ \t]*'+key+r'[ \t]*=)[^\r\n!]*');matches=list(pattern.finditer(text))
 if not matches:return text+'\n'+key+' = '+str(value)+'\n'
 assert len(matches)==1;match=matches[0];return text[:match.start()]+match[1]+' '+str(value)+text[match.end():]

def original_inputs(folder,locate,item,originals):
 q=json.loads((folder/'RESULT.json').read_text());frost=q['case'] in FROST;name=q['case'];inputs=locate(q['input_root'])
 if frost:models,solute=FROST[name];snow=1;edits={'SWHYST':0,'iHWCKmodel':' '.join(map(str,models))};authority=q['original_input_authority']
 else:
  models,solute,snow,initial=ORDINARY[name];authority=q['input_authority']
  edits=({'iHWCKmodel':'2'} if name=='gardner-water' else {'SWHYST':0,'SWSNOW':1,'iHWCKmodel':7} if name=='model7-snow-cde-fitted' else {'SWHYST':0,'SWSNOW':snow,'SWINCO':initial,'iHWCKmodel':' '.join(map(str,models))})
 assert item['models']==(models*len(item['models']) if len(models)==1 else models) and item['solute']==solute and item['snow']==snow
 assert authority['actual_git_source']==BASE
 origin=originals[authority['archive']];assert authority['archive_sha256']==origin.record['sha256'];prefix=authority['prefix'];before={n[len(prefix):]:origin.get(n) for n in origin.names if n.startswith(prefix)};assert before
 assert set(before)=={n for n,digest in q['input_inventory']}
 text=before['swap.swp'].decode('cp1252');named=[]
 if frost:
  for key,value in edits.items():text=assignment(text,key,value)
 if name!='gardner-water':
  keys=[*(['ALFA_2','NPAR_2','OMEGA_1'] if any(v in (3,6,7,10,11) for v in models) else []),*(['H0'] if any(v in (5,7,8,9,10,11) for v in models) else []),*(['HA','APAR','OMEGA_K','SWVAPOR'] if any(v>=8 for v in models) else [])]
  donor=originals['FROST_ANALYTICAL_BOUNDARY10_SEARCH_WINDOWS_O0_ORIGINAL_V1'];source=donor.get('current-unaffected-postimages/model7-cde-d1-b8-dense/inputs/swap.swp').decode('cp1252')
  for key in keys:
   rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[^\r\n]*(?:\r?\n|$)',source);assert len(rows)==1 and not re.search(r'(?mi)^\s*'+key+r'\s*=',text);text+='\n'+rows[0];named.append(key)
 if not frost:
  for key,value in edits.items():text=assignment(text,key,value)
 expected={**before,'swap.swp':text.encode('cp1252')}
 if 3 in models:
  for n,raw in before.items():
   if n.endswith('.crp'):expected[n]=assignment(raw.decode('cp1252'),'SWOXYGEN',1).encode('cp1252')
 for n,raw in expected.items():assert (inputs/n).read_bytes()==raw,(name,n)
 return dict(actual_original_git_source=BASE,original_archive=authority['archive'],original_archive_sha256=origin.record['sha256'],original_prefix=prefix,exact_original_and_declared_input_files=len(expected),only_original_named_additions=named,explicit_configuration_assignments=edits,original_dates_numerical_limits_boundary_tables_and_other_soil_parameters_unchanged=True,original_model3_valid_oxygen1_explicit=(3 in models))

def local(data):
 results=[]
 with ExitStack() as stack:
  archives={name:Archive(data,name,stack) for name in ['IMPLICIT_HYDRAULIC_STATE11_LOCAL_RAW_V2','IMPLICIT_HYDRAULIC_STATE11_CURRENT_COUPLINGS_RAW_V3','IMPLICIT_HYDRAULIC_STATE11_FROST_CAUSAL_RAW_V1','IMPLICIT_HYDRAULIC_STATE11_MODEL5_PUBLIC_RAW_V1']}
  source=GitArchiveSource(R,BASE);originals={name:Original(source,name,stack) for name in ['ORDINARY_IMPLICIT_POND_UBUNTU_FOLLOWUP_O0_RAW_ARCHIVE','FROST_UNDRAINED_STATE08_WINDOWS_O0_ORIGINAL_V1','FROST_ANALYTICAL_BOUNDARY10_SEARCH_WINDOWS_O0_ORIGINAL_V1']}
  for opt in ['O0','O2']:
   for kind,cases in [('ordinary',ORDINARY),('frost',FROST)]:
    for name in cases:
     if name=='gardner-water':stem='IMPLICIT_HYDRAULIC_STATE11_LOCAL_RAW_V2';prefix='actual/ih11-analysis-v1/'+name+'-'+opt+'-v2'
     elif name in ['model5-cde-profile','mixed4-5-cde-d1-b5']:stem='IMPLICIT_HYDRAULIC_STATE11_MODEL5_PUBLIC_RAW_V1';prefix='actual/ih11-model5-public-v1/'+kind+'-'+name+'-'+opt
     elif name=='mixed10-11-water-d0-b5':stem='IMPLICIT_HYDRAULIC_STATE11_FROST_CAUSAL_RAW_V1';prefix='actual/ih11f-fixed-v1/'+name+'-'+opt
     else:stem='IMPLICIT_HYDRAULIC_STATE11_CURRENT_COUPLINGS_RAW_V3';prefix='actual/ih11-branch-qualified-v1/'+kind+'-'+name+'-'+opt
     archive=archives[stem];folder=ReadView(archive,prefix)
     def locate(path):
      relative=PureWindowsPath(path).relative_to(W);assert '..' not in relative.parts;return ReadView(archive,'actual/'+relative.as_posix())
     item=observe(folder,locate);item['actual_raw_archive_sha256']=archive.record['sha256'];item['original_input_proof']=original_inputs(folder,locate,item,originals);results.append(item)
 assert len(results)==28 and sum(v['days'] for v in results)==980 and sum(len(v['native_samples']) for v in results)==196 and sum(len(v['exact_cold_windows']) for v in results)==88
 return dict(status='TWENTYEIGHT_ACTUAL_LOCAL_IMPLICIT_HYDRAULIC_CONTEXTS_ORIGINAL_INPUTS_DAILY_PREFIX_1E10_EXACT_NATIVE_COLD_TRANSACTIONS_AND_RAW_IDENTITIES_PASS',contexts=results,primary_days=980,native_samples=196,exact_cold_windows=88,external_transaction_contexts=28,original_producer_identities_rewritten=False,compiler_executions=0,model_executions=0,portable_or_canonical_admission=False,additional_local_contexts_counted_in_portable_coadmission=False)
