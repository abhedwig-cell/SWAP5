"""Keep the original microscopic root endpoint and inner state consistent."""
from pathlib import Path
import hashlib
from implicit_conductivity_retry import enabled

POLICY='original-implicit-complete-dry-end-final-root-evaluation-v2'


def source(text):
    old='      fxp = myFun(xp)                                    ! should be nearly zero (< Tol_2)'
    assert text.count(old)==1
    text=text.replace(old,'',1)
    anchor='   ! convergence reached (NB: we assume TolConv > Tol_2)'
    assert text.count(anchor)==1
    return text.replace(anchor,'   ! Final xp and the original myFun inner X must describe the same root.\n   fxp = myFun(xp)\n\n'+anchor,1)


def metadata(project):
    if not enabled(project):return None
    import micro_lookup_state as lookup
    return dict(policy=POLICY,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),provider='literal original RWU_micro.myFun',evaluation='once at selected final xp in every endpoint/Brent branch, before uptake and convergence check',lookup_policy=lookup.POLICY,lookup_owner_sha256=hashlib.sha256(Path(lookup.__file__).read_bytes()).hexdigest(),lookup_composition='literal existing complete dry-end preprocessing for every new SWKIMPL1, including nohistory; existing history native state unchanged',equations_changed=False,tolerances_changed=False)


def expected(original,project):
    from micro_lookup_state import render
    return source(render(original))


def apply_build(output,donor_build,project,patched):
    if not enabled(project):return patched
    path=output/'RWU_micro.f90'
    text=(path if path.exists() else donor_build/'swap-selected/RWU_micro.f90').read_text(encoding='cp1252')
    from micro_lookup_state import enabled as history,render
    if not history(project):text=render(text)
    path.write_text(source(text),encoding='cp1252')
    if 'RWU_micro' not in patched:patched.insert(0,'RWU_micro')
    return patched
