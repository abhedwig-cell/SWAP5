"""Compare every actual compiled file, retaining PE link metadata differences."""
import json,sys,types
from pathlib import Path
R=Path(__file__).resolve().parents[2];sys.path.insert(0,str(R/'tests/nomacro_drainage'))
from analytical_hydraulic_archives import SHA
from calendar_publisher import publisher_equivalence
from explicit_bottom9_source_inverse import BASE,blob,norm
assert norm((R/'tests/nomacro_drainage/calendar_publisher.py').read_bytes())==blob(BASE,'tests/nomacro_drainage/calendar_publisher.py')

def compare(left,right):
 suffixes={'.o','.mod','.smod','.exe','.dll','.so','.a'}
 files=lambda root:{p.relative_to(root).as_posix():p for p in root.rglob('*') if p.is_file() and (p.suffix.lower() in suffixes or p.name in ('day_donor','day_kernel'))}
 a,b=files(left),files(right);assert a and set(a)==set(b);observed=[]
 for name,path in sorted(a.items()):
  old,new=path.read_bytes(),b[name].read_bytes();item=dict(file=name,left_sha256=SHA(old),right_sha256=SHA(new),left_bytes=len(old),right_bytes=len(new))
  if old==new:item['status']='ACTUAL_COMPLETE_COMPILED_BYTES_EXACT'
  else:
   assert path.suffix.lower() in ('.dll','.exe') and old[:2]==new[:2]==b'MZ'
   read_PE=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value));item['PE_loader_relative_whole_code_data']=read_PE(path,b[name]);item['status']='ACTUAL_COMPLETE_PE_CODE_DATA_RELOCATIONS_EXACT_LINK_METADATA_DIFFERENCES_RETAINED'
  observed.append(item)
 assert {'day_donor.exe','day_kernel.exe','restart_publish.dll'}<=set(a) or {'day_donor','day_kernel','restart_publish.so'}<=set(a)
 return dict(status='ALL_ACTUAL_GENERATED_OBJECT_MODULE_EXECUTABLE_PUBLISHER_CODE_DATA_POSTIMAGES_VERIFIED',files=observed,raw_bytes_rewritten=False,model_executions=0,compiler_executions_in_reader=0)

