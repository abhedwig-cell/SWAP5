"""Expose actual saved CDE interval scalars and observe original flux increments."""
import re

ORIGINAL_SHA='6e451efc04fd555c8ed6eaa4425de1a31e6032d8ab2b806495d94033ade1fa86'
FIELDS=('sampro0','rounderr')
FLUXES={'imsqprec':1,'imsqirrig':1,'imsqbot':3,'imsqdra':4,'imdectot':5,'imrottot':6}
INTERFACE='''      module subroutine hybrid_cde_interval_get(values)
        real(8),intent(out)::values(2)
      end subroutine
      module subroutine hybrid_cde_interval_set(values)
        real(8),intent(in)::values(2)
      end subroutine
'''
BRIDGE='''
      module subroutine hybrid_cde_interval_get(values)
      use ieee_arithmetic,only:ieee_is_finite
      use MOD_swap_base,only:swmacro,swsolu
      implicit none
      real(8),intent(out)::values(2)
      if(swmacro/=0.or.swsolu/=1.or..not.hybrid_cde_interval_initialized) &
        error stop 'Uninitialized or foreign actual CDE interval getter'
      values=[sampro0,rounderr]
      if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite actual private CDE interval state'
      if(values(1)<0d0)error stop 'Negative actual private CDE interval stock'
      end subroutine

      module subroutine hybrid_cde_interval_set(values)
      use ieee_arithmetic,only:ieee_is_finite
      use MOD_swap_base,only:swmacro,swsolu
      implicit none
      real(8),intent(in)::values(2)
      if(swmacro/=0.or.swsolu/=1.or..not.hybrid_cde_interval_initialized) &
        error stop 'Uninitialized or foreign actual CDE interval setter'
      if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite restored private CDE interval state'
      if(values(1)<0d0)error stop 'Negative restored private CDE interval stock'
      sampro0=values(1);rounderr=values(2)
      end subroutine
'''


def source(original):
    prefix='submodule (MOD_Solute) MOD_Solute_CDE'
    assert original.count(prefix)==1
    a=original.index(prefix);head=original[:a];tail=original[a:]
    anchor='    end interface';assert head.count(anchor)==1
    head=head.replace(anchor,INTERFACE+anchor,1)
    anchor='   public :: sbaldev, sdstor';assert head.count(anchor)==1
    head=head.replace(anchor,anchor+'\n   public :: hybrid_cde_interval_get,hybrid_cde_interval_set',1)
    anchor='      implicit none';assert tail.startswith(prefix+'\n') and anchor in tail
    tail=tail.replace(anchor,'      use hybrid_cde_interval_receipt,only:cde_day_open,cde_day_observe,CDE_DAY_OK\n'+anchor+
        '\n      real(8),save::sampro0=0d0,rounderr=0d0\n      logical,save::hybrid_cde_interval_initialized=.false.',1)
    a=tail.index('      module subroutine solute_CDE(task)');b=tail.index('      end subroutine solute_CDE',a)
    begin,body,end=tail[:a],tail[a:b],tail[b:]
    body,n=re.subn(r'(?mi)^([ \t]*real\(8\)[ \t]*::[ \t]*tcumsol),[ \t]*rounderr[ \t]*$',r'\1',body);assert n==1
    body,n=re.subn(r'(?mi)^[ \t]*real\(8\)[ \t]*::[ \t]*sampro0[ \t]*\n','',body);assert n==1
    anchor='      implicit none';assert body.count(anchor)==1
    body=body.replace(anchor,'      use variables,only:daycum\n'+anchor+'\n      real(8)::hybrid_cde_observed_increment\n      integer::hybrid_cde_observe_status',1)
    anchor='         sampro0 = samini';assert body.count(anchor)==1
    body=body.replace(anchor,anchor+'\n         hybrid_cde_interval_initialized=.true.',1)
    first=body.index('      case (2)');last=body.index('      case(3)',first)
    transport=body[first:last];found={name:0 for name in FLUXES}
    anchor='      case (2)';assert transport.count(anchor)==1
    transport=transport.replace(anchor,anchor+"\n      call cde_day_open(daycum,sampro,hybrid_cde_observe_status)\n"+
        "      if(hybrid_cde_observe_status/=CDE_DAY_OK)error stop 'Actual original CDE day begin rejected'",1)
    for name,slot in FLUXES.items():
        pattern=r'(?mi)^([ \t]*)'+name+r'[ \t]*=[ \t]*'+name+r'[ \t]*\+[ \t]*([^!\n]+)[ \t]*$'
        def observe(match):
            indent,expression=match.groups();found[name]+=1
            return (indent+'hybrid_cde_observed_increment='+expression.strip()+'\n'+
                indent+name+'='+name+'+hybrid_cde_observed_increment\n'+
                indent+f'call cde_day_observe({slot},hybrid_cde_observed_increment,hybrid_cde_observe_status)\n'+
                indent+"if(hybrid_cde_observe_status/=CDE_DAY_OK)error stop 'Actual original CDE increment receipt rejected'")
        transport=re.sub(pattern,observe,transport)
    assert found==dict(imsqprec=1,imsqirrig=2,imsqbot=2,imsqdra=1,imdectot=1,imrottot=1) or found==dict(imsqprec=1,imsqirrig=1,imsqbot=2,imsqdra=1,imdectot=1,imrottot=1),found
    body=body[:first]+transport+body[last:]
    anchor='end submodule MOD_Solute_CDE';assert end.count(anchor)==1
    return head+begin+body+end.replace(anchor,BRIDGE+anchor,1)
