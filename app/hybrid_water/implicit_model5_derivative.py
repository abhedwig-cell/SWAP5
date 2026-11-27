"""Differentiate the actual original scaled single-mode Mualem K equation.

Gamma=(1+|alpha*h|**n)**(-m), S=(Gamma-Gamma0)/(1-Gamma0),
U=(1-Gamma**(1/m))/(1-Gamma0**(1/m)), A=1-U**m, K=Ks*S**L*A**2.
The chain rule below preserves that K, water and capacity literally.
U uses the equal expression x/(1+x)/den to avoid cancellation near h=0.
Only model5 in the new implicit hydraulic composition selects this owner.
"""
import hashlib
from pathlib import Path
POLICY='original-implicit-model5-scaled-mualem-exact-chain-rule-v1'
SEAM='              else if(imod>=4.and.imod<=11)then'
BRANCH='              else if(imod==5)then\n                 block\n                   real(8)::ax,gm,gm0,sc,uu,aa,dgm,dsc,daa,mm,nnn,ll,den\n                   if(head>=0d0)then\n                     dhconduc=0d0\n                   else\n                     mm=cofgen(7,node);nnn=cofgen(6,node);ll=cofgen(5,node)\n                     ax=abs(cofgen(4,node)*head)**nnn\n                     gm=(1d0+ax)**(-mm)\n                     gm0=(1d0+abs(cofgen(4,node)*cofgen(18,node))**nnn)**(-mm)\n                     den=1d0-gm0**(1d0/mm)\n                     sc=(gm-gm0)/(1d0-gm0)\n                     uu=(ax/(1d0+ax))/den\n                     aa=1d0-uu**mm\n                     dgm=mm*nnn*gm*(ax/(1d0+ax))/abs(head)\n                     dsc=dgm/(1d0-gm0)\n                     daa=uu**(mm-1d0)*gm**(1d0/mm-1d0)*dgm/den\n                     dhconduc=cofgen(3,node)*(ll*sc**(ll-1d0)*dsc*aa**2+2d0*sc**ll*aa*daa)\n                     if(swfrost==1)dhconduc=dhconduc*rfcp\n                   end if\n                   return\n                 end block\n'


def enabled(project):
    from implicit_hydraulic_state import selected
    item=selected(project)
    return bool(item and 5 in item['models'])


def source(text):
    begin='      real(8) function dhconduc';end='      end function dhconduc'
    if text.count(begin)!=1 or text.count(end)!=1:raise ValueError('Foreign original derivative owner')
    low=text.index(begin);high=text.index(end,low)+len(end);body=text[low:high]
    if body.count(SEAM)!=1 or BRANCH in body:raise ValueError('Foreign actual model5 derivative seam')
    result=text[:low]+body.replace(SEAM,BRANCH+SEAM,1)+text[high:]
    if result.replace(BRANCH,'',1)!=text:raise ValueError('Incomplete model5 exact derivative inverse')
    return result


def metadata(project):
    if not enabled(project):return None
    return dict(policy=POLICY,source_lf_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        original_equation='WC_K_models_04_11.K_MvG_s; exact chain rule with original cofgen',
        physical_water_K_and_capacity_unchanged=True,new_physical_state=False,
        original_frost_rfcp_multiplier_preserved=True,tolerances_or_iteration_limits_changed=False)


def apply_build(output,project,patched):
    if not enabled(project):return patched
    if 'MOD_MvG_functions' not in patched:raise ValueError('Missing actual implicit constitutive provider')
    path=output/'MOD_MvG_functions.f90'
    path.write_text(source(path.read_text(encoding='cp1252')),encoding='cp1252')
    return patched
