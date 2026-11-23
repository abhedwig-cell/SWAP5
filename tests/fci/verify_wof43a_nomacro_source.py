"""Bound the WOF Source guard; every original native oracle still runs after it."""
import ast,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CONTRACT='integration/f-ci/nomacro-complete01/CANONICAL_LEGACY_WOF43A_SOURCE_CONTRACT_V1.json'
CONTRACT_SHA='7d3b959ade716488b9fcf2ebe18d5a815296f6eb13c613838e24e9196e814506'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()

def verify_source():
 def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
 raw=(ROOT/CONTRACT).read_bytes().replace(b'\r\n',b'\n');assert SHA(raw)==CONTRACT_SHA;q=json.loads(raw)
 assert q['status']=='BOUNDED_WOF43A_SOURCE_SUCCESSOR_REQUIRES_UNCHANGED_ORIGINAL_NATIVE_ORACLES' and q['global_DATAQUAL12_waiver'] is False and q['physical_source_changes'] is False
 paths=list(q['source_inventory']);assert not git('status','--porcelain','--',*paths),'Dirty WOF/CO2 compilation dependency'
 for path,item in q['source_inventory'].items():
  assert git('rev-parse','HEAD:'+path).decode().strip()==item['git_blob']==git('rev-parse',q['baseline']+':'+path).decode().strip(),'Foreign WOF/CO2 committed dependency: '+path
  actual=(ROOT/path).read_bytes();normalized=actual.replace(b'\r\n',b'\n');assert SHA(normalized)==item['LF_sha256'],'Foreign actual WOF/CO2 source: '+path
  assert normalized==git('show',q['baseline']+':'+path)
 runner=q['runner'];old=git('show',q['baseline']+':'+runner['path']);current=(ROOT/runner['path']).read_bytes().replace(b'\r\n',b'\n');assert SHA(old)==runner['old_sha256'] and SHA(current)==runner['new_sha256'];assert old.decode().count(runner['exact_old_call'])==runner['replacements']==2
 assert current==old.replace(runner['exact_old_call'].encode(),runner['exact_new_call'].encode()),'Changed original historical identities, numerical oracles or compile/execute recipe'
 # Evaluate only the original immutable recipe's readonly dependency discovery.
 # The full unmodified O0/O2 compile/native body is executed by the caller.
 recipe=ROOT/'tests/fmig431/run_swap431_crop_co2_response.py';tree=ast.parse(recipe.read_text());prefix=[]
 for node in tree.body:
  if isinstance(node,ast.With):break
  prefix.append(node)
 namespace=dict(__file__=str(recipe));exec(compile(ast.Module(body=prefix,type_ignores=[]),str(recipe),'exec'),namespace)
 closure=[path.relative_to(ROOT).as_posix() for path in namespace['order']];assert closure==q['original_CO2_compile_closure'] and len(closure)==15,'Changed actual original CO2 compilation dependency closure'
 return dict(status='WOF43A_SELECTED_SOURCE_AND_WHOLE_ORIGINAL_NATIVE_RECIPE_PRESERVED_PENDING_NATIVE_ORACLES',source_dependencies=len(paths),CO2_compilation_dependencies=len(closure),whole_global_DATAQUAL12_qualification_claimed=False,physical_equations_changed=False,compiler_executions=0,model_executions=0)

def original_runner_source():
 verify_source();q=json.loads((ROOT/CONTRACT).read_text());return q['runner']['path'],subprocess.check_output(['git','show',q['baseline']+':'+q['runner']['path']],cwd=ROOT)

if __name__=='__main__':print(json.dumps(verify_source(),indent=2))
