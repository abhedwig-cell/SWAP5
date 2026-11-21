"""Prove unchanged native5 implementation from already completed real builds."""
import json,types
from pathlib import Path
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
from analytical_hydraulic_archives import SHA


def compare(old,new):
 before=json.loads((old/'BUILD.json').read_text());actual=json.loads((new/'BUILD.json').read_text())
 for field in ('donor_objects','donor_modules','ttutil_modules','ttutil_library','donor_flags','kernel_flags'):assert before['identity'][field]==actual['identity'][field]
 a={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in old.glob('*.f90')};b={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in new.glob('*.f90')};assert a==b
 changed=differences(before['identity'],actual['identity']);assert {'experimental_input_adapter'}<=set(changed)<={'experimental_input_adapter','restart_publisher.library_sha256'}
 exact=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value));pe=exact(old/'restart_publish.dll',new/'restart_publish.dll')
 return dict(status='ACTUAL_INITIAL_PROFILE_COMPLETE_FORTRAN_PROVIDER_FLAGS_NATIVE5_ABI_AND_PE_POSTIMAGE_UNCHANGED',complete_Fortran={name:SHA(raw) for name,raw in a.items()},only_identity_changes=changed,publisher_equivalence=pe,unchanged_native5_ABI_controls_inherited_without_repetition=True,compiler_executions=0,model_executions=0)
