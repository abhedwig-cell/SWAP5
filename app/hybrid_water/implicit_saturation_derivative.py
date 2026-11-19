"""Differentiate the actual original constant conductivity regions consistently."""
from pathlib import Path
import hashlib
from implicit_conductivity_retry import enabled

POLICY='original-implicit-saturated-conductivity-derivative-v1'


def source(text):
    begin='      real(8) function dhconduc';end='      end function dhconduc'
    assert text.count(begin)==text.count(end)==1
    first=text.index(begin);last=text.index(end,first)+len(end);body=text[first:last]
    anchor='              relsat = (theta-wcr(node))/wcsMINwcr(node)';assert body.count(anchor)==1
    body=body.replace(anchor,anchor+'''
              ! Literal original hconduc returns constant KSATFIT here.
              if((h_enpr(node)>h_crit.and.relsat>1d0-1d-6).or. &
                 (h_enpr(node)<=h_crit.and.head>=h_enpr(node)))then
                 dhconduc=0d0
                 return
              end if''',1)
    return text[:first]+body+text[last:]


def metadata(project):
    if not enabled(project):return None
    return dict(policy=POLICY,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),provider='literal original MOD_MvG.hconduc constant KSATFIT regions',correction='zero derivative on the actual original saturation/air-entry plateau; original nonconstant derivative body literal',physical_equations_changed=False,tolerance_changed=False)


def apply_build(output,donor_build,project,patched):
    if not enabled(project):return patched
    path=output/'MOD_MvG_functions.f90'
    text=(path if path.exists() else donor_build/'swap-selected/MOD_MvG_functions.f90').read_text(encoding='cp1252')
    path.write_text(source(text),encoding='cp1252')
    return ['MOD_MvG_functions',*(name for name in patched if name!='MOD_MvG_functions')]
