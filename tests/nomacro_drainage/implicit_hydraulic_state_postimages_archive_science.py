"""Compare complete actual old/current compiler bytes through immutable views."""
import json
from contextlib import ExitStack
from pathlib import PureWindowsPath
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
W=PureWindowsPath('C:/Users/Veldh012/SWAP5-work/01a1e8b4-228b-75f1-8ac4-b07ca1e15713-a9ded600')

def actual(store,path):
 relative=PureWindowsPath(path).relative_to(W);assert '..' not in relative.parts;return ReadView(store,'actual/'+relative.as_posix())

def compare(before,current,expected_before,expected_current):
 assert SHA((before/'BUILD.json').read_bytes())==expected_before and SHA((current/'BUILD.json').read_bytes())==expected_current
 left=json.loads((before/'BUILD.json').read_text());right=json.loads((current/'BUILD.json').read_text())
 for key in ['compiler','compiler_sha256','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources']:assert left['identity'][key]==right['identity'][key],key
 assert left['inputs']==right['inputs']
 counts={}
 for suffix in ['f90','o']:
  old={v.name:v.read_bytes() for v in before.glob('*.'+suffix)};new={v.name:v.read_bytes() for v in current.glob('*.'+suffix)};assert old and old.keys()==new.keys() and all(raw==new[n] for n,raw in old.items());counts[suffix]=len(old)
 for folder,meta in [(before,left),(current,right)]:
  for role in ['donor','kernel']:
   names=[n for n in ['day_'+role,'day_'+role+'.exe'] if (folder/n).is_file()];assert len(names)==1 and SHA((folder/names[0]).read_bytes())==meta['executable_sha256'][role]
 return dict(actual_complete_generated_files=counts['f90'],actual_complete_objects=counts['o'],whole_file_bytes_identical=True,compiler_and_original_SDK_identical=True,PE_links_separately_byte_verified_without_normalization=True)

def audit(data):
 with ExitStack() as stack:
  names=['IMPLICIT_HYDRAULIC_STATE11_NONSELECTED_POSTIMAGE_RAW_V1','IMPLICIT_HYDRAULIC_STATE11_PARENT824_POSTIMAGE_RAW_V1','IMPLICIT_HYDRAULIC_STATE11_LOCAL_RAW_V2','IMPLICIT_HYDRAULIC_STATE11_CURRENT_COUPLINGS_RAW_V3','IMPLICIT_HYDRAULIC_STATE11_FROST_CAUSAL_RAW_V1','IMPLICIT_HYDRAULIC_STATE11_GUARD_RAW_V1','FROST_UNDRAINED_STATE08_LOCAL_WINDOWS_O0_O2_RAW_V1','FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V1','FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V2']
  stores={name:Archive(data,name,stack) for name in names};bysha={s.record['sha256']:s for s in stores.values()};nonselected=[];parent=[]
  current=stores['IMPLICIT_HYDRAULIC_STATE11_NONSELECTED_POSTIMAGE_RAW_V1']
  for opt in ['O0','O2']:
   q=json.loads(current.get('actual/ih11-current-postimages-v1/'+opt+'/RESULT.json'));assert q['status'].startswith('TWELVE_ACTUAL') and q['model_days']==q['model_executions']==0 and len(q['contexts'])==12
   for item in q['contexts']:
    old=bysha[item['original_archive_sha256']];matches=[n for n,v in old.names.items() if n.endswith('/BUILD.json') and v['sha256']==item['actual_original_BUILD_sha256']];assert len(matches)==1
    before=ReadView(old,matches[0].removesuffix('/BUILD.json'));now=actual(current,item['build_root']);report=compare(before,now,item['actual_original_BUILD_sha256'],item['actual_current_BUILD_sha256']);assert report['actual_complete_objects']==len(item['whole_objects'])
    nonselected.append(dict(case=item['case'],optimization=opt,actual_original_producer=item['actual_original_scientific_source'],actual_compiler_source=q['actual_current_compiler_source'],**report))
  current=stores['IMPLICIT_HYDRAULIC_STATE11_PARENT824_POSTIMAGE_RAW_V1']
  for opt in ['O0','O2']:
   q=json.loads(current.get('actual/ih11-parent-postimages-v1/'+opt+'/RESULT.json'));assert q['status'].startswith('EIGHT_ORIGINAL_PARENT') and q['model_days']==q['model_executions']==0 and len(q['contexts'])==8
   for item in q['contexts']:
    old=bysha[item['actual_original_archive_sha256']];before=ReadView(old,item['original_build_prefix']);now=actual(current,item['build_root']);report=compare(before,now,item['actual_original_BUILD_sha256'],item['actual_current_BUILD_sha256']);assert report['actual_complete_objects']==len(item['whole_objects'])
    parent.append(dict(case=item['case'],optimization=opt,actual_original_producer=item['actual_original_producer'],actual_compiler_source=q['actual_compiler_source'],**report))
  assert len(nonselected)==24 and sum(q['actual_complete_objects'] for q in nonselected)==648 and len(parent)==16
  return dict(status='INDEPENDENT40_ACTUAL_CURRENT_ORIGINAL_GENERATED_AND_WHOLE_OBJECT_POSTIMAGE_CONTEXTS_AND_SDK_EXACT_PASS',nonselected_contexts=nonselected,parent_contexts=parent,nonselected_whole_objects=648,parent_whole_objects=sum(q['actual_complete_objects'] for q in parent),compiler_executions=0,model_executions=0,original_scientific_producers_rebound=False)
