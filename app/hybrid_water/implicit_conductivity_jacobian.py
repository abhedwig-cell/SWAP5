"""Use literal original dkmean for the actual original boundary mean inputs."""
from pathlib import Path
import hashlib
from implicit_conductivity_retry import enabled

POLICY='original-implicit-exact-boundary-jacobian-v1'


def source(text):
    anchor='   use MOD_top,            only: boundtop, pondrunoff, hsurf';assert text.count(anchor)==1
    text=text.replace(anchor,'   use MOD_top,only:katm\n   use variables,only:ksatfit\n'+anchor,1)
    anchor='      if (ftoph) dFdhM(1) = dFdhM(1) - dkdh(1) * hgrad(1) * 0.5d0';assert text.count(anchor)==1
    text=text.replace(anchor,'''      if (ftoph) then
         ! Original Boundtop: atmospheric katm or saturated KSATFIT, frost0.
         ! Differentiate its actual selected mean with original dkmean.
         if(hsurf<0d0)then
            dFdhM(1)=dFdhM(1)-dkdh(1)*hgrad(1)*dkmean(swkmean,k(1),katm,dz(1),dz(1))
         else
            dFdhM(1)=dFdhM(1)-dkdh(1)*hgrad(1)*dkmean(swkmean,k(1),ksatfit(1),dz(1),dz(1))
         end if
      end if''',1)
    anchor='''      if (swbotb == 1 .OR. swbotb == 5 .OR. swbotb == 8 .AND. flboth) then
         dFdhM(NN) = dFdhM(NN) + 0.5d0 * dkdh(NN) * hgrad(NN+1)
      end if''';assert text.count(anchor)==1
    text=text.replace(anchor,'''      if(swbotb==1.and..not.fllowgwl)then
         ! Literal original vector_F uses the next layer's saturated K.
         dFdhM(NN)=dFdhM(NN)+dkdh(NN)*hgrad(NN+1)* &
            dkmean(swkmean,k(NN),cofgen(3,NN+1),dz(NN),dz(NN+1))
      else if(swbotb==5.or.(swbotb==1.and.fllowgwl).or.(swbotb==8.and.flboth))then
         ! The original implicit update assigns Kmean(NN+1)=K(NN).
         dFdhM(NN)=dFdhM(NN)+dkdh(NN)*hgrad(NN+1)
      end if''',1)
    return text


def metadata(project):
    if not enabled(project):return None
    return dict(policy=POLICY,source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),derivative_provider='literal original HeadCalc.dkmean',surface_inputs='actual original Boundtop katm/KSATFIT, frost0/examined-Ksat inactive',groundwater_inputs='actual original vector_F K(NN),cofgen(3,NN+1),dz(NN),dz(NN+1)',direct_boundary='actual original implicit Kmean(NN+1)=K(NN), derivative factor1',physical_equations_changed=False)


def apply_build(output,project,patched):
    if not enabled(project):return patched
    path=output/'headcalc.f90';path.write_text(source(path.read_text(encoding='cp1252')),encoding='cp1252')
    return patched
