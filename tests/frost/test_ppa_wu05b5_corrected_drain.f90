program corrected_probe
  use iso_fortran_env,only:int64
  use MOD_frost,only:legacy_bounds=>FrozenBounds,legacy_node=>nodfrostbot,legacy_depth=>zfrostbot,legacy_factor=>rfcp
  use MOD_frost_corrected,only:corrected_bounds=>FrozenBounds,corrected_node=>nodfrostbot, &
       corrected_depth=>zfrostbot,corrected_factor=>rfcp
  use MOD_drain
  use MOD_swap_base
  use variables
  implicit none
  real(8)::original_qdra(2,4),original_qbot,original_total,node_rate,report_rate
  integer::signq,signd,regime,cases
  cases=0
  do regime=1,6
    do signq=-1,1
      do signd=-1,1
        call fixture(regime,signq,signd)
        call legacy_bounds
        original_qdra=qdra;original_qbot=qbot;original_total=qdrtot
        call fixture(regime,signq,signd)
        call corrected_bounds
        call require(all(transfer(qdra,[0_int64],8)==transfer(original_qdra,[0_int64],8)),'nodal physical bit identity')
        call require(transfer(qbot,0_int64)==transfer(original_qbot,0_int64),'bottom physical bit identity')
        call require(all(legacy_factor==corrected_factor),'hydraulic factors held')
        if(swdra==1.and.swmacro==0)then
          call require(all(abs(qdrain-sum(qdra,dim=2))<=1.d-14),'each level is actual nodal sum')
          call require(abs(qdrtot-sum(qdra))<=1.d-14,'aggregate is actual nodal sum')
          node_rate=sum(qdra)-qbot;report_rate=qdrtot-qbot
          call require(abs(node_rate-report_rate)<=1.d-14,'independent node/report accounting closes')
        end if
        if(regime==1.and.signq/=0.and.signd/=0)then
          call require(abs(original_total-qdrtot)>1.d-3,'actually corrected legacy discrepancy')
        end if
        if(regime/=1)call require(original_total==qdrtot,'noncorrected branch report identity')
        cases=cases+1
      end do
    end do
  end do
  print '(A,I0)','FROST_DRAIN_01_PHYSICAL_IDENTITY_CASES=',cases
  print '(A)','PPA-WU05B5_CORRECTED_B1_DRAIN_REPORT=PASS'
contains
  subroutine fixture(regime,signq,signd)
    integer,intent(in)::regime,signq,signd
    theta=.5d0;thetas=.5d0;swdra=1;swmacro=0;swdivd=0
    qbot_nonfrozen=real(signq,8)*.01d0;qbot=999.d0
    qdra=0.d0;qdra(1,2)=real(signd,8)*.02d0;qdra(2,4)=real(signd,8)*.1d0
    qdrain=sum(qdra,dim=2);qdrtot=sum(qdrain)
    legacy_node=2;corrected_node=2;legacy_depth=-2.d0;corrected_depth=-2.d0
    legacy_factor=0.d0;corrected_factor=0.d0
    if(regime==2)theta=.4d0
    if(regime==3)then
      legacy_node=1;corrected_node=1
    end if
    if(regime==4)swdra=0
    if(regime==5)swdra=2
    if(regime==6)swmacro=1
  end subroutine
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
