"""Inherit compiled root ABI attacks only through complete actual postimages."""
import json,types
from pathlib import Path
from analytical_hydraulic_archives import SHA
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence


def compare(old,new):
 a=json.loads((old/'BUILD.json').read_text());b=json.loads((new/'BUILD.json').read_text())
 for field in ('donor_objects','donor_modules','ttutil_modules','ttutil_library','donor_flags','kernel_flags'):
  assert a['identity'][field]==b['identity'][field]
 files=lambda root:{p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in root.glob('*.f90')}
 before,after=files(old),files(new);assert before and before==after
 changed=differences(a['identity'],b['identity']);assert set(changed)<={'restart_publisher.library_sha256'}
 exact=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value))
 publisher=exact(old/'restart_publish.dll',new/'restart_publish.dll')
 return dict(status='ACTUAL_INITIAL2_TO_PROFILE1_COMPLETE_FORTRAN_PROVIDER_FLAGS_ROOT_NATIVE3_AND_PUBLISHER_POSTIMAGE_UNCHANGED',complete_Fortran={name:SHA(raw) for name,raw in before.items()},identity_changes=changed,publisher_equivalence=publisher,root_native3_actual_compiled_28_refusals_inherited=True,compiler_executions=0,model_executions=0)
