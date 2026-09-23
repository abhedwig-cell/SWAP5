program tabhyd_kx02_ksatexm_constitutive_gate
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider, &
       TABHYD_RAW_TABLE_N
  implicit none

  integer, parameter :: NODES=2
  integer, parameter :: NSCAN=6001
  real(real64), parameter :: HTHR=-2.0_real64
  real(real64), parameter :: STEP=0.04_real64

  type(b110_default_mvg_parameters_t), target :: apar_on, apar_off
  type(b110_default_mvg_provider_t) :: analytic_on, analytic_off
  type(tabhyd_raw_provider_t) :: table
  real(real64), allocatable :: cof(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64) :: h(NODES), ta(NODES), ka(NODES), ca(NODES), da(NODES)
  real(real64) :: td(NODES), kd(NODES), cd(NODES), dd(NODES)
  real(real64) :: tt(NODES), kt(NODES), ct(NODES), dt(NODES), kc(NODES)
  real(real64) :: ores,osat,alpha,npar,ksat,lexp,ksatexm,m,help,thr,term1,kthr
  real(real64) :: frac,expo,relsa,relst,f,err,relerr
  real(real64) :: max_theta,max_c,max_logk,max_branch_abs,max_branch_rel
  real(real64) :: max_transition_abs, continuity_jump, below_kdiff, fmin_active, fmax_active
  real(real64) :: kleft,kright,keq,mismatch_hmin(NODES),mismatch_hmax(NODES)
  integer :: iu,ios,i,j,q,mismatch,mismatch_local,active_count,mismatch_node(NODES),f_nonfinite
  character(len=512) :: path
  character(len=32) :: label(NODES)

  if(command_argument_count()<1) error stop 'usage: kx01 INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open input'

  allocate(cof(24,NODES),headtab(TABHYD_RAW_TABLE_N,NODES),thetatab(TABHYD_RAW_TABLE_N,NODES), &
           ktab(TABHYD_RAW_TABLE_N,NODES))
  cof=0.0_real64

  do i=1,NODES
    read(iu,*,iostat=ios) label(i),ores,osat,alpha,npar,ksat,lexp,ksatexm
    if(ios/=0) error stop 'invalid material row'
    m=1.0_real64-1.0_real64/npar
    cof(1,i)=ores
    cof(2,i)=osat
    cof(3,i)=ksat
    cof(4,i)=alpha
    cof(5,i)=lexp
    cof(6,i)=npar
    cof(7,i)=m
    cof(8,i)=alpha
    cof(9,i)=0.0_real64
    cof(10,i)=ksatexm
    help=(1.0_real64+abs(HTHR*alpha)**npar)**m
    thr=1.0_real64/help
    term1=(1.0_real64-thr**(1.0_real64/m))**m
    kthr=ksat*(thr**lexp)*(1.0_real64-term1)**2
    cof(11,i)=thr
    cof(12,i)=kthr
    do j=1,TABHYD_RAW_TABLE_N
      read(iu,*,iostat=ios) headtab(j,i),thetatab(j,i),ktab(j,i)
      if(ios/=0) error stop 'invalid table row'
    end do
  end do
  close(iu)

  call initialize_b110_default_mvg_parameters(apar_on,cof,enable_ksatexm_extension=.true.)
  call initialize_b110_default_mvg_parameters(apar_off,cof,enable_ksatexm_extension=.false.)
  call bind_b110_default_mvg_provider(analytic_on,apar_on,STEP)
  call bind_b110_default_mvg_provider(analytic_off,apar_off,STEP)
  call initialize_tabhyd_raw_provider(table,headtab,thetatab,ktab,cof,STEP)

  max_theta=0.0_real64
  max_c=0.0_real64
  max_logk=0.0_real64
  max_branch_abs=0.0_real64
  max_branch_rel=0.0_real64
  max_transition_abs=0.0_real64
  mismatch=0
  mismatch_local=0
  mismatch_node=0
  mismatch_hmin=huge(1.0_real64)
  mismatch_hmax=-huge(1.0_real64)
  active_count=0
  fmin_active=huge(1.0_real64)
  fmax_active=-huge(1.0_real64)
  f_nonfinite=0

  do q=1,NSCAN
    frac=real(q-1,real64)/real(NSCAN-1,real64)
    expo=7.0_real64-15.0_real64*frac
    h=-10.0_real64**expo
    call analytic_on%evaluate(h,ta,ka,ca,da)
    call table%evaluate(h,tt,kt,ct,dt)
    kc=kt
    do i=1,NODES
      relsa=(ta(i)-cof(1,i))/(cof(2,i)-cof(1,i))
      relst=(tt(i)-cof(1,i))/(cof(2,i)-cof(1,i))
      if ((relsa>cof(11,i)) .neqv. (h(i)>HTHR)) mismatch=mismatch+1
      if (h(i)>HTHR) then
        f=(relst-cof(11,i))/(1.0_real64-cof(11,i))
        if (.not. ieee_is_finite(f)) then
          f_nonfinite=f_nonfinite+1
        else
          fmin_active=min(fmin_active,f)
          fmax_active=max(fmax_active,f)
        end if
        kc(i)=f*cof(10,i)+(1.0_real64-f)*cof(12,i)
      end if
      max_theta=max(max_theta,abs(tt(i)-ta(i)))
      max_c=max(max_c,abs(ct(i)-ca(i)))
      max_logk=max(max_logk,abs(log10(max(kc(i),1.0e-300_real64))-log10(max(ka(i),1.0e-300_real64))))
      if(relsa>cof(11,i)) then
        active_count=active_count+1
        err=abs(kc(i)-ka(i))
        relerr=err/max(abs(ka(i)),1.0e-12_real64)
        max_branch_abs=max(max_branch_abs,err)
        max_branch_rel=max(max_branch_rel,relerr)
      end if
      if(abs(h(i)-HTHR)<0.1_real64) max_transition_abs=max(max_transition_abs,abs(kc(i)-ka(i)))
    end do
  end do

  ! High-resolution branch-classification scan around the exact h=-2 cm transition.
  do q=1,10001
    h = HTHR - 5.0e-2_real64 + real(q-1,real64)*1.0e-5_real64
    call analytic_on%evaluate(h,ta,ka,ca,da)
    call table%evaluate(h,tt,kt,ct,dt)
    kc=kt
    do i=1,NODES
      relsa=(ta(i)-cof(1,i))/(cof(2,i)-cof(1,i))
      relst=(tt(i)-cof(1,i))/(cof(2,i)-cof(1,i))
      if ((relsa>cof(11,i)) .neqv. (h(i)>HTHR)) then
        mismatch_local=mismatch_local+1
        mismatch_node(i)=mismatch_node(i)+1
        mismatch_hmin(i)=min(mismatch_hmin(i),h(i))
        mismatch_hmax(i)=max(mismatch_hmax(i),h(i))
      end if
      if (h(i)>HTHR) then
        f=(relst-cof(11,i))/(1.0_real64-cof(11,i))
        if (.not. ieee_is_finite(f)) then
          f_nonfinite=f_nonfinite+1
        else
          fmin_active=min(fmin_active,f)
          fmax_active=max(fmax_active,f)
        end if
        kc(i)=f*cof(10,i)+(1.0_real64-f)*cof(12,i)
      end if
      max_transition_abs=max(max_transition_abs,abs(kc(i)-ka(i)))
    end do
  end do

  ! Canonical F-SI39 oracles and transition characterization.
  h=1.0_real64
  call analytic_on%evaluate(h,ta,ka,ca,da)
  call table%evaluate(h,tt,kt,ct,dt)
  kc=kt
  do i=1,NODES
    relst=(tt(i)-cof(1,i))/(cof(2,i)-cof(1,i))
    if(h(i)>HTHR) then
      f=(relst-cof(11,i))/(1.0_real64-cof(11,i))
      kc(i)=f*cof(10,i)+(1.0_real64-f)*cof(12,i)
    end if
  end do
  write(*,'(a,2(1x,es24.16))') 'KX02_SAT_ANALYTIC',ka
  write(*,'(a,2(1x,es24.16))') 'KX02_SAT_CANDIDATE',kc

  h=-1.0_real64
  call analytic_on%evaluate(h,ta,ka,ca,da)
  call table%evaluate(h,tt,kt,ct,dt)
  kc=kt
  do i=1,NODES
    relst=(tt(i)-cof(1,i))/(cof(2,i)-cof(1,i))
    if(h(i)>HTHR) then
      f=(relst-cof(11,i))/(1.0_real64-cof(11,i))
      kc(i)=f*cof(10,i)+(1.0_real64-f)*cof(12,i)
    end if
  end do
  write(*,'(a,2(1x,es24.16))') 'KX02_HM1_ANALYTIC',ka
  write(*,'(a,2(1x,es24.16))') 'KX02_HM1_CANDIDATE',kc

  h=-5.0_real64
  call analytic_on%evaluate(h,ta,ka,ca,da)
  call analytic_off%evaluate(h,td,kd,cd,dd)
  below_kdiff=maxval(abs(ka-kd))
  write(*,'(a,es24.16)') 'KX02_BELOW_THRESHOLD_ANALYTIC_ON_OFF_MAX=',below_kdiff

  ! Evaluate candidate immediately around exact h=-2 branch.
  h=HTHR-1.0e-10_real64
  call table%evaluate(h,tt,kt,ct,dt)
  relst=(tt(2)-cof(1,2))/(cof(2,2)-cof(1,2))
  kleft=kt(2)
  if(h(2)>HTHR) then
    f=(relst-cof(11,2))/(1.0_real64-cof(11,2)); kleft=f*cof(10,2)+(1.0_real64-f)*cof(12,2)
  end if

  h=HTHR
  call table%evaluate(h,tt,kt,ct,dt)
  relst=(tt(2)-cof(1,2))/(cof(2,2)-cof(1,2))
  keq=kt(2)
  if(h(2)>HTHR) then
    f=(relst-cof(11,2))/(1.0_real64-cof(11,2)); keq=f*cof(10,2)+(1.0_real64-f)*cof(12,2)
  end if

  h=HTHR+1.0e-10_real64
  call table%evaluate(h,tt,kt,ct,dt)
  relst=(tt(2)-cof(1,2))/(cof(2,2)-cof(1,2))
  kright=kt(2)
  if(h(2)>HTHR) then
    f=(relst-cof(11,2))/(1.0_real64-cof(11,2)); kright=f*cof(10,2)+(1.0_real64-f)*cof(12,2)
  end if
  continuity_jump=max(abs(keq-kleft),abs(kright-keq))

  write(*,'(a,es24.16)') 'KX02_THETA_MAX_ABS=',max_theta
  write(*,'(a,es24.16)') 'KX02_C_MAX_ABS=',max_c
  write(*,'(a,es24.16)') 'KX02_LOG10K_MAX_ABS=',max_logk
  write(*,'(a,es24.16)') 'KX02_BRANCH_K_MAX_ABS=',max_branch_abs
  write(*,'(a,es24.16)') 'KX02_BRANCH_K_MAX_REL=',max_branch_rel
  write(*,'(a,es24.16)') 'KX02_TRANSITION_K_MAX_ABS=',max_transition_abs
  write(*,'(a,i0)') 'KX02_BRANCH_CLASS_MISMATCH=',mismatch
  write(*,'(a,i0)') 'KX02_BRANCH_CLASS_MISMATCH_LOCAL=',mismatch_local
  write(*,'(a,2(1x,i0))') 'KX02_BRANCH_CLASS_MISMATCH_NODE',mismatch_node
  write(*,'(a,2(1x,es24.16))') 'KX02_BRANCH_MISMATCH_HMIN',mismatch_hmin
  write(*,'(a,2(1x,es24.16))') 'KX02_BRANCH_MISMATCH_HMAX',mismatch_hmax
  write(*,'(a,i0)') 'KX02_ACTIVE_SAMPLES=',active_count
  write(*,'(a,es24.16)') 'KX02_CONTINUITY_LOCAL_JUMP=',continuity_jump
  write(*,'(a,2(1x,es24.16))') 'KX02_THRESHOLDS',cof(11,1),cof(11,2)
  write(*,'(a,2(1x,es24.16))') 'KX02_KTHR',cof(12,1),cof(12,2)
  write(*,'(a,es24.16)') 'KX02_ACTIVE_F_MIN=',fmin_active
  write(*,'(a,es24.16)') 'KX02_ACTIVE_F_MAX=',fmax_active
  write(*,'(a,i0)') 'KX02_ACTIVE_F_NONFINITE=',f_nonfinite
  write(*,'(a)') 'KX02_CONSTITUTIVE_GATE_COMPLETED'
end program tabhyd_kx02_ksatexm_constitutive_gate
