"""Original implicit line search and rollback must reject nonfinite trials."""
from pathlib import Path
import hashlib
from implicit_conductivity_retry import enabled

POLICY='original-implicit-finite-newton-rate-rollback-v1'


def source(text):
    anchor='   use MOD_rootextraction, only: RootExtraction';assert text.count(anchor)==1
    text=text.replace(anchor,'   use ieee_arithmetic,only:ieee_is_finite\n'+anchor,1)
    anchor='      call jacobian_F()';assert text.count(anchor)==1
    text=text.replace(anchor,'''      if(.not.all(ieee_is_finite([h(1:NN),theta(1:NN),dimoca(1:NN),dkdh(1:NN), &
         k(1:NN),kmean(1:NN+1),F(1:NN),qrot(1:numnod)])))exit
'''+anchor,1)
    anchor='            call Rootextraction(2)';assert text.count(anchor)==1
    text=text.replace(anchor,'''            if(.not.all(ieee_is_finite([h(1:NN),theta(1:NN)])))then
               factor=factor/3d0
               cycle
            end if
'''+anchor,1)
    anchor=' 1    continue';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'''
      if(.not.all(ieee_is_finite([h(1:NN),theta(1:NN),k(1:NN),kmean(1:NN+1), &
         F(1:NN),qrot(1:numnod)])))exit''',1)
    anchor='      pond            = pondm1';assert text.count(anchor)==1
    return text.replace(anchor,anchor+'\n      ! Restore the actual dependent original rates before the next residual.\n      call Rootextraction(2)',1)


def metadata(project):
    if not enabled(project):return None
    return dict(policy=POLICY,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),candidate='nonfinite head/water skips original backtracking candidate; exhausted nonfinite derivative/residual takes full original rollback',dependent_rates='real original RootExtraction after restored original head/water/pond',new_accepted_state=False,physical_equations_changed=False,tolerance_changed=False)


def apply_build(output,project,patched):
    if not enabled(project):return patched
    path=output/'headcalc.f90';path.write_text(source(path.read_text(encoding='cp1252')),encoding='cp1252')
    return patched
