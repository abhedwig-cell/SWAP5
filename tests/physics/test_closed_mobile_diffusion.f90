program test_closed_mobile_diffusion
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_solute_mobile_salt_state
  use mod_solute_closed_mobile_diffusion
  implicit none
  type(mobile_salt_state_t) :: initial,candidate,bad,replay
  type(closed_diffusion_receipt_t) :: receipt
  real(real64) :: g,exact(2),errors(3),dz(2),theta(2),nan
  type(mobile_salt_state_t) :: source_step
  integer :: status,j
  dz=[1.0_real64,2.0_real64];theta=0.4_real64
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  call initialize_mobile_salt_state(dz,theta,[1.0_real64,0.0_real64],initial,status)
  call req(status==SOLUTE_OK,'init')
  g=0.4_real64**3.33_real64/0.5_real64**2
  exact(1)=1.0_real64/3.0_real64+2.0_real64/3.0_real64*exp(-g*(1.0_real64/0.4_real64+1.0_real64/0.8_real64))
  exact(2)=1.0_real64/3.0_real64-1.0_real64/3.0_real64*exp(-g*(1.0_real64/0.4_real64+1.0_real64/0.8_real64))
  call advance_closed_mobile_diffusion(initial,dz,theta,[0.4_real64],[0.5_real64],[1.0_real64], &
    1.0_real64,0.1_real64,0.1_real64,1,source_step,receipt,status)
  call req(status==SOLUTE_OK,'one source-equation step')
  call req(abs(source_step%mass_mg_cm2(1)-(0.4_real64-0.1_real64*g))<1e-15_real64.and. &
    abs(source_step%mass_mg_cm2(2)-0.1_real64*g)<1e-15_real64,'direct B1.11 molecular coefficient and sign')
  do j=1,3
    call solve(1.0_real64,0.1_real64/2.0_real64**(j-1),1000)
    call req(status==SOLUTE_OK,'analytical relaxation')
    errors(j)=maxval(abs(candidate%concentration_mg_cm3-exact))
    call req(abs(sum(candidate%mass_mg_cm2)-0.4_real64)<1e-14_real64,'analytical mass')
    call req(all(candidate%concentration_mg_cm3>=0.0_real64),'nonnegative')
    call req(all(initial%mass_mg_cm2==[0.4_real64,0.0_real64]),'committed unchanged')
  end do
  call req(errors(2)<0.6_real64*errors(1).and.errors(3)<0.6_real64*errors(2),'first order refinement')
  replay=candidate
  call solve(1.0_real64,0.025_real64,1000)
  call req(all(candidate%mass_mg_cm2==replay%mass_mg_cm2),'deterministic replay')
  call solve(0.0_real64,1.0_real64,1)
  call req(status==SOLUTE_OK.and.all(candidate%mass_mg_cm2==initial%mass_mg_cm2),'zero diffusion identity')
  call solve(1.0_real64,0.01_real64,2)
  call empty(SOLUTE_DIFFUSION_STEP_LIMIT,'exhaustion')
  bad=initial;bad%concentration_mg_cm3(1)=2.0_real64
  call advance_closed_mobile_diffusion(bad,dz,theta,[0.4_real64],[0.5_real64],[1.0_real64], &
    1.0_real64,1.0_real64,0.1_real64,100,candidate,receipt,status)
  call empty(SOLUTE_INVALID,'inconsistent authority')
  call solve(nan,0.1_real64,100)
  call empty(SOLUTE_INVALID,'nonfinite')
  call solve(-1.0_real64,0.1_real64,100)
  call empty(SOLUTE_INVALID,'negative diffusion')
  call advance_closed_mobile_diffusion(initial,dz,theta,[0.4_real64],[0.5_real64],[0.0_real64], &
    1.0_real64,1.0_real64,0.1_real64,100,candidate,receipt,status)
  call empty(SOLUTE_INVALID,'invalid distance')
  call advance_closed_mobile_diffusion(initial,dz,theta,[0.4_real64],[0.5_real64],[1.0_real64,2.0_real64], &
    1.0_real64,1.0_real64,0.1_real64,100,candidate,receipt,status)
  call empty(SOLUTE_INVALID,'malformed dimensions')
  call solve(1.0_real64,0.0_real64,100)
  call empty(SOLUTE_INVALID,'zero maximum timestep')
  call solve(1.0_real64,0.1_real64,0)
  call empty(SOLUTE_INVALID,'invalid substep limit')
  call advance_closed_mobile_diffusion(initial,dz,theta,[0.4_real64],[0.5_real64],[tiny(1.0_real64)], &
    huge(1.0_real64),1.0_real64,0.1_real64,100,candidate,receipt,status)
  call empty(SOLUTE_INVALID,'overflowing conductance rejects under FPE traps')
  call initialize_mobile_salt_state([1.0_real64],[0.4_real64],[2.0_real64],bad,status)
  call advance_closed_mobile_diffusion(bad,[1.0_real64],[0.4_real64],[real(real64)::], &
    [real(real64)::],[real(real64)::],1.0_real64,1.0_real64,1.0_real64,1,candidate,receipt,status)
  call req(status==SOLUTE_OK.and.all(candidate%mass_mg_cm2==bad%mass_mg_cm2),'single node identity')
  call initialize_mobile_salt_state([1.0_real64,2.0_real64,0.5_real64],[0.2_real64,0.4_real64,0.3_real64], &
    [2.0_real64,0.0_real64,1.0_real64],initial,status)
  call advance_closed_mobile_diffusion(initial,[1.0_real64,2.0_real64,0.5_real64], &
    [0.2_real64,0.4_real64,0.3_real64],[0.3_real64,0.35_real64],[0.5_real64,0.45_real64], &
    [1.5_real64,1.25_real64],1.0_real64,20.0_real64,20.0_real64,10000,candidate,receipt,status)
  call req(status==SOLUTE_OK.and.receipt%substeps>1,'automatic monotone substeps')
  call req(abs(sum(candidate%mass_mg_cm2)-sum(initial%mass_mg_cm2))<1e-14_real64,'heterogeneous closure')
  call req(all(candidate%concentration_mg_cm3>=0.0_real64).and. &
    all(candidate%concentration_mg_cm3<=2.0_real64),'heterogeneous extrema')
  call initialize_mobile_salt_state([1.0_real64,2.0_real64,0.5_real64],[0.2_real64,0.4_real64,0.3_real64], &
    [2.0_real64,2.0_real64,2.0_real64],initial,status)
  call advance_closed_mobile_diffusion(initial,[1.0_real64,2.0_real64,0.5_real64], &
    [0.2_real64,0.4_real64,0.3_real64],[0.3_real64,0.35_real64],[0.5_real64,0.45_real64], &
    [1.5_real64,1.25_real64],1.0_real64,20.0_real64,20.0_real64,10000,candidate,receipt,status)
  call req(status==SOLUTE_OK.and.all(candidate%mass_mg_cm2==initial%mass_mg_cm2),'uniform steady identity')
  print '(a,3es23.14)','RELAXATION_ERRORS=',errors
  print '(a)','PPA_WU05E_CLOSED_DIFFUSION=PASS'
contains
  subroutine solve(d,maxdt,limit)
    real(real64),intent(in)::d,maxdt
    integer,intent(in)::limit
    call advance_closed_mobile_diffusion(initial,dz,theta,[0.4_real64],[0.5_real64],[1.0_real64], &
      d,1.0_real64,maxdt,limit,candidate,receipt,status)
  end subroutine
  subroutine empty(expected,label)
    integer,intent(in)::expected
    character(*),intent(in)::label
    call req(status==expected,label)
    call req(.not.allocated(candidate%mass_mg_cm2).and..not.allocated(candidate%concentration_mg_cm3),label//' empty')
    call req(receipt%substeps==0.and.receipt%closure_error_mg_cm2==0.0_real64,label//' receipt')
  end subroutine
  subroutine req(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *, 'FAIL ',label
      error stop 1
    end if
  end subroutine
end program
