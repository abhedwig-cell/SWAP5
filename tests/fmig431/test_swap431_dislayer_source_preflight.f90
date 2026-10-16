! Diagnose source/candidate conservation before binding DISLAYER into runtime.
! A reproduced source defect is evidence of a blocker, never science admission.
program dislayer_source_preflight
  use, intrinsic :: iso_fortran_env,only:real64
  use MOD_grid,only:dz,zbotcp,numnod
  use MOD_drain,only:DIVDRA,nrlevs,qdrain,qdra,cofani,Lspacing,swdivdinf,swdislay,swtopdislay, &
       ztopdislay,ftopdislay,dramet,zbotdr,shape,diffl
  use mod_drainage_discharge_layer_transform
  implicit none
  real(real64)::k(8),base(8),transformed(8),q,top,gw,retained,err,maximum
  real(real64),parameter::rates(4)=[.003d0,-.003d0,2.d-9,-2.d-9]
  type(discharge_layer_diagnostics_t)::d
  integer::grid,rate,mode,i,st,cases,defects,normal
  numnod=8;nrlevs=1;dz=1;cofani=1;Lspacing=40000;gw=0;swdivdinf=0
  zbotcp=[(-real(i,real64),i=1,8)];swtopdislay=0;swtopdislay(1)=1
  zbotdr=-3;shape=1;diffl=3;ftopdislay=.5d0
  cases=0;defects=0;normal=0;maximum=0
  do grid=1,2
    k=1
    if(grid==2)k(2:8)=1.d-7
    do rate=1,4
      q=rates(rate);qdrain=0;qdrain(1)=q
      do mode=1,3
        ! Native untransformed distribution is the production candidate's input.
        swdislay=0
        call DIVDRA(k,gw)
        base=qdra(1,:)
        call check(abs(sum(base)-q)<1.d-14,'pre-transform scalar closure')
        if(mode==1)then
          top=-1.5d0;swdislay=1
        else
          dramet=2
          if(mode==3)dramet=3
          call derive_dynamic_discharge_layer_top(dramet,ftopdislay(1),gw,zbotdr(1),shape,diffl(1),top,st)
          call check(st==DISLAYER_OK.and.top== -1.5d0,'source dynamic top')
          swdislay=2
        end if
        ztopdislay=top
        call DIVDRA(k,gw)
        transformed=base
        call apply_discharge_layer_top(dz,top,q,transformed,d)
        call check(d%status==DISLAYER_OK.and.d%evaluated,'real candidate evaluated')
        call check(maxval(abs(transformed-qdra(1,:)))<1.d-14,'candidate matches complete native source')
        retained=d%retained_before_scale
        err=sum(qdra(1,:))-q;maximum=max(maximum,abs(err))
        if(abs(err)>1.d-12)then
          defects=defects+1
        else
          normal=normal+1
        end if
        print '(A,3I3,5ES25.16,L2)','DISLAYER_OBSERVATION ',grid,rate,mode,q,retained, &
             sum(qdra(1,:)),sum(transformed),err,d%small_retained_fallback
        cases=cases+1
      end do
    end do
  end do
  call check(cases==24.and.defects==18.and.normal==6,'expected source counterexample matrix')
  print '(A,I0,A,I0,A,I0,A,ES25.16)','DISLAYER_SOURCE_PREFLIGHT_CASES=',cases, &
       ' DEFECTS=',defects,' CONSERVATIVE_CONTROLS=',normal,' MAX_RATE_RESIDUAL=',maximum
  print '(A)','DISLAYER_SOURCE_AND_EXISTING_CANDIDATE_NONCONSERVATION_REPRODUCED=PASS'
  print '(A)','DISLAYER_PRODUCTION_ADMISSION=BLOCKED_SOURCE_REFERENCE_CORRECTION_REQUIRED'
contains
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 84
    end if
  end subroutine
end program
