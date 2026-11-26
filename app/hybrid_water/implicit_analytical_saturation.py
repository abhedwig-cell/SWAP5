"""Compose each original model's actual constant-conductivity branch.

The default Mualem near-saturation cutoff is absent from original models3..11.
Keep their original nonconstant derivative body; apply zero only where their
actual original hconduc is constant. No retention/conductivity/state changes.
"""
import hashlib
from pathlib import Path

POLICY='original-implicit-analytical-per-model-constant-conductivity-branches-v1'
BEFORE='''              if((h_enpr(node)>h_crit.and.relsat>1d0-1d-6).or. &
                 (h_enpr(node)<=h_crit.and.head>=h_enpr(node)))then
                 dhconduc=0d0
                 return
              end if'''
AFTER='''              if(imod==1)then
                 if((h_enpr(node)>h_crit.and.relsat>1d0-1d-6).or. &
                    (h_enpr(node)<=h_crit.and.head>=h_enpr(node)))then
                    dhconduc=0d0
                    return
                 end if
              else if(imod==3)then
                 if(relsat>=1d0)then
                    dhconduc=0d0
                    return
                 end if
              else if(imod>=4.and.imod<=11)then
                 if(head>=0d0)then
                    dhconduc=0d0
                    return
                 end if
              end if'''


def enabled(project):
    from implicit_hydraulic_state import selected
    item=selected(project)
    return bool(item and any(model>=3 for model in item['models']))


def source(text):
    begin='      real(8) function dhconduc';end='      end function dhconduc'
    if text.count(begin)!=1 or text.count(end)!=1:raise ValueError('Foreign original implicit derivative owner')
    low=text.index(begin);high=text.index(end,low)+len(end);body=text[low:high]
    if body.count(BEFORE)!=1 or AFTER in body:raise ValueError('Foreign actual per-model constant-conductivity seam')
    result=text[:low]+body.replace(BEFORE,AFTER,1)+text[high:]
    if result.replace(AFTER,BEFORE,1)!=text:raise ValueError('Incomplete per-model derivative inverse')
    return result


def metadata(project):
    if not enabled(project):return None
    return dict(policy=POLICY,source_lf_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
                constant_branches={'model1':'unchanged qualified original Mualem cutoff',
                    'model3':'actual original relsat>=1 branch',
                    'models4..11':'actual original head>=0 branch'},
                original_nonconstant_derivative_body_unchanged=True,physical_equations_changed=False,
                physical_stores_fluxes_or_parameters_assigned=False,tolerances_or_iteration_limits_changed=False)


def apply_build(output,project,patched):
    if not enabled(project):return patched
    if 'MOD_MvG_functions' not in patched:raise ValueError('Missing actual original implicit constitutive provider')
    path=output/'MOD_MvG_functions.f90';path.write_text(source(path.read_text(encoding='cp1252')),encoding='cp1252')
    return patched
