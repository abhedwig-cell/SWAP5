"""Preserve every modeled nonzero interception in the original partition."""
from pathlib import Path
import hashlib
from implicit_conductivity_retry import enabled

POLICY='original-implicit-exact-interception-partition-v1'


def source(text):
    begin='   subroutine ProcessMeteoDT';end='   end subroutine ProcessMeteoDT'
    assert text.count(begin)==text.count(end)==1
    first=text.index(begin);last=text.index(end,first)+len(end);body=text[first:last]
    for old,new in [('      if (aintcdt < small) then','      if (aintcdt == 0d0) then'),('         if (graidt + gird > small) then','         if (graidt + gird > 0d0) then')]:
        assert body.count(old)==1
        body=body.replace(old,new,1)
    return text[:first]+body+text[last:]


def metadata(project):
    if not enabled(project):return None
    return dict(policy=POLICY,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),provider='literal original MOD_meteo.ProcessMeteoDT',correction='exact zero interception and positive total-input tests; retain original partition expressions and booked modeled interception',interception_equations_changed=False,state_added=False,tolerance_changed=False)


def apply_build(output,donor_build,project,patched):
    if not enabled(project):return patched
    path=output/'MOD_meteo.f90'
    text=(path if path.exists() else donor_build/'swap-selected/MOD_meteo.f90').read_text(encoding='cp1252')
    path.write_text(source(text),encoding='cp1252')
    return ['MOD_meteo',*(name for name in patched if name!='MOD_meteo')]
