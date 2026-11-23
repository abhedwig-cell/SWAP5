"""Preserve the actual four local legacy component closures and all raw failures."""
import argparse,hashlib,json
from pathlib import Path
from initial_profile_frost_preserve import seal
from explicit_bottom9_source_inverse import ROOT,git
from analytical_hydraulic_archives import SHA

def preserve(ev,stage):
 files={};builds=[];objects={};epochs={}
 def tree(root,prefix):
  assert root.is_dir() and not root.is_symlink()
  for path in sorted(root.rglob('*')):
   assert not path.is_symlink() and not path.is_junction()
   if path.is_file():
    name=prefix+'/'+path.relative_to(root).as_posix();assert name not in files;files[name]=path
 for kind in ('WOF43A','FSI35'):
  receipt=json.loads((ev/('CANONICAL_LEGACY_'+kind+'_CURRENT_ORIGINAL_ORACLES_V1.json')).read_text());producer=receipt['actual_source'];assert not git('diff',producer,'--','src'),'Legacy physical Source changed after actual original native qualification';inventory=receipt.get('source_inventory',receipt.get('actual_source_inventory'));assert inventory
  epochs[producer]={}
  for path,item in inventory.items():
   actual=(ROOT/path).read_bytes();assert SHA(actual)==item['actual_raw_sha256'];blob=git('show',producer+':'+path);digest=hashlib.sha1(b'blob '+str(len(blob)).encode()+b'\0'+blob).hexdigest();assert digest==item['git_blob'] and actual.replace(b'\r\n',b'\n')==blob
   objects['actual-working-source/raw/'+SHA(actual)]=actual;objects['committed-source/blobs/'+digest]=blob;epochs[producer][path]=dict(actual_raw_sha256=SHA(actual),git_blob=digest)
  for opt in ('O0','O2'):
   root=ev.parent/('canonical-legacy-'+kind+'-'+opt+'-v1');prefix='compiled/'+kind+'/'+opt;tree(root,prefix);builds.append(dict(kind=kind,optimization=opt,path=str(root),archive_prefix=prefix,actual_compiler_producer=producer))
 for path in sorted(ev.iterdir()):
  if path.name.lower().startswith(('canonical-legacy-','canonical_legacy_')):
   if path.is_dir():tree(path,'profiles/'+path.name)
   elif path.is_file():files['observations/'+path.name]=path
 # The bounded transaction identity is inherited from the actual old source;
 # retain its original receipt and full original streams unchanged as well.
 for suffix in ('json','stdout.txt','stderr.txt'):
  name='EXPLICIT_BOTTOM9_LEGACY_D12_ACTUAL_HISTORICAL_V2.'+suffix;files['historical/'+name]=ev/name
 for name in ('CANONICAL_LEGACY_WOF43A_SOURCE_CONTRACT_V1.json','CANONICAL_LEGACY_FSI35_SOURCE_CONTRACT_V1.json','CANONICAL_LEGACY_FSI35_ORIGINAL_STUB_INTERFACE_V1.f90'):
  files['contracts/'+name]=ROOT/'integration/f-ci/nomacro-complete01'/name
 objects['ACTUAL_SOURCE_EPOCHS_V1.json']=(json.dumps(epochs,indent=2)+'\n').encode();objects['actual-sealer.py']=Path(__file__).read_bytes()
 assert len(builds)==4
 seal(stage/'CANONICAL_LEGACY_ORIGINAL_ORACLES_RAW_V1.zip','CANONICAL_LEGACY_ORIGINAL_ORACLES_RAW_V1',files,objects,dict(status='ACTUAL_FOUR_WINDOWS_LEGACY_COMPONENT_COMPILED_CLOSURES_ORIGINAL_INPUTS_SOURCE_STREAMS_AND_CI_FAILURES_PRESERVED',actual_preserver_source=git('rev-parse','HEAD').decode().strip(),original_evidence_root=str(ev),builds=builds,actual_Windows_compiler_driver_executions=106,actual_Windows_native_component_executions=12,original_WOF_nominal_compiler_counter=38,actual_WOF_compiler_counter=36,actual_FSI_compiler_counter=70,SWAP_model_periods=0,global_DATAQUAL12_qualification_claimed=False,canonical_admission=False))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,required=True);p.add_argument('--staging',type=Path,required=True);a=p.parse_args();preserve(a.evidence,a.staging)
