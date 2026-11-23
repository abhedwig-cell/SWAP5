"""Invert every frozen Snow9 wrapper edit; retain whole actual source identities."""
import ast,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import SHA
from explicit_bottom9_source_inverse import git,blob,norm,SURFACES
BASE='04dadca2bf52027ef9c72360684c86bd98aa77ff'
CORE='342c5dd92861f67fa90b094f1a63c5a6b53b9c4e'
RECORD='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_SOURCE_EDITS_V1.json'
RECORD_SHA='d79831111b583a193f5a74e4eac66e1075772f10bafd447425a3df2a4c96f03a'


def complete_inverse():
 raw=norm((ROOT/RECORD).read_bytes());assert SHA(raw)==RECORD_SHA;q=json.loads(raw)
 assert q['parent']==BASE and q['core']==CORE and not q['physical_original_Fortran_equations_changed'] and not q['new_physical_state'] and not q['new_native_codec'] and q['absolute_water_guard_cm']=='1e-10'
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed current Snow9 execution source'
 changes=git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines()
 assert sorted(changes)==sorted(['M\t'+row['path'] for row in q['modified']]+['A\t'+path for path in q['added']])
 for row in q['modified']:
  current=norm((ROOT/row['path']).read_bytes());assert current==blob(CORE,row['path']) and SHA(current)==row['new_sha256']
  lines=current.decode().splitlines(keepends=True)
  for edit in reversed(row['edits']):
   low,high=edit['new_lines'];assert ''.join(lines[low:high])==edit['new']
   lines[low:high]=edit['old'].splitlines(keepends=True)
  original=''.join(lines).encode();assert original==blob(BASE,row['path']) and SHA(original)==row['old_sha256'],'Incomplete whole Snow9 source inverse: '+row['path']
  functions=lambda value:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(value).body if isinstance(n,ast.FunctionDef)}
  before,after=functions(original),functions(current);assert before.keys()==after.keys() and sorted(name for name in before if before[name]!=after[name])==row['changed_functions']
 for path in q['added']:
  assert not git('ls-tree','--name-only',BASE,'--',path)
  assert norm((ROOT/path).read_bytes())==blob(CORE,path)
 return dict(status='COMPLETE_EIGHT_FILE_SNOW9_WRAPPER_AND_WHOLE_PRIOR_SOURCE_INVERSE_PASS',parent=BASE,core=CORE,modified_files=len(q['modified']),new_bounded_selector_files=len(q['added']),actual_Git_and_scientific_data_projected=False,compiler_executions=0,model_executions=0,canonical_admission=False)
