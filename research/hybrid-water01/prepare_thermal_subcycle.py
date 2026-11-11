"""Materialize three private research postimages, optionally into the build tree.

No production admission. The exact original bodies come from the pinned canonical
commit; --apply temporarily replaces them for the existing native build recipe.
Restore those three production paths before publishing this research package.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = 'f96c9f23ed2234255c0ceeb64e82c3e87f2e77fe'
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--apply', action='store_true')
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
paths = ['src/process/mod_soil_temperature_contract.f90',
         'src/process/mod_restricted_soil_temperature.f90',
         'src/runtime/mod_fmr_thermal_substep_receipt.f90']
record = dict(base=BASE, production_admission=False, sources={})
for name in paths:
    original = subprocess.check_output(['git', 'show', BASE+':'+name], cwd=ROOT)
    text = original.decode()
    if name == paths[0]:
        needle = '  end type soil_temperature_workspace_t'
        assert text.count(needle) == 1
        text = text.replace(needle, '    ! Private research: actual integrated flux at every conductive face.\n'
                            '    real(real64), allocatable :: substep_conductive_face_energy_j_cm2(:)\n'+needle)
    elif name == paths[1]:
        text = text.replace('subroutine trial_restricted_soil_temperature(',
                            'subroutine trial_restricted_soil_temperature_single(')
        text = text.replace('end subroutine trial_restricted_soil_temperature\n',
                            'end subroutine trial_restricted_soil_temperature_single\n')
        wrapper = (Path(__file__).with_name('thermal_subcycle_wrapper.inc')).read_text()
        needle = '  subroutine trial_restricted_soil_temperature_single('
        assert text.count(needle) == 1
        text = text.replace(needle, wrapper+'\n\n'+needle)
    else:
        needle = '  receipt%available=.true.'
        assert text.count(needle) == 1
        text = text.replace(needle, '''  if(allocated(w%substep_conductive_face_energy_j_cm2))then
   if(size(w%substep_conductive_face_energy_j_cm2)/=n+1)return
   if(any(.not.ieee_is_finite(w%substep_conductive_face_energy_j_cm2)))return
   receipt%conductive_face_energy_j_cm2=w%substep_conductive_face_energy_j_cm2
  end if
'''+needle)
    dst = a.output/Path(name).name
    dst.write_text(text, newline='\n')
    record['sources'][name] = dict(original_sha256=hashlib.sha256(original).hexdigest(),
                                  private_sha256=hashlib.sha256(dst.read_bytes()).hexdigest())
    if a.apply:
        (ROOT/name).write_bytes(dst.read_bytes())
(a.output/'POSTIMAGES.json').write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps(record, indent=2))
