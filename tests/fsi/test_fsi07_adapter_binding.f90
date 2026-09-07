module mod_fsi07_test_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  public :: fsi07_constitutive_t

  type, extends(constitutive_hydraulics_provider_t) :: fsi07_constitutive_t
   contains
     procedure :: evaluate => fsi07_evaluate
  end type fsi07_constitutive_t
contains
  subroutine fsi07_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fsi07_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    if (storage_size(self) <= 0 .or. size(pressure_head) <= 0) error stop 'invalid provider use'
    water_content=0.30_real64; conductivity=1.0_real64; capacity=0.01_real64; dconductivity_dhead=0.0_real64
  end subroutine fsi07_evaluate
end module mod_fsi07_test_provider

program test_fsi07_adapter_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract
  use mod_reference_richards_legacy_binding
  use mod_a23bu_worker_execution_context, only: a23bu_initialize_worker
  use mod_fsi07_test_provider, only: fsi07_constitutive_t
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_top, only: q0, flrunoff, ftoph, hsurf
  use variables
  use fsi07_stub_control
  implicit none

  type(soil_water_parameter_set_t), target :: params
  type(fsi07_constitutive_t), target :: provider
  type(soil_water_solve_request_t) :: request_a, request_b
  type(soil_water_solve_result_t) :: result_a1, result_a2, result_b, result_retry, result_reject
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  real(real64) :: sh(numnod), st(numnod), shm1(numnod), stm1(numnod), sk(numnod), skm(numnod+1), sdm(numnod)
  real(real64) :: sp, sg, spm1, sgm1, sqt, sqb, shbot, sgwlinp, sdtold, srunots, sq0, shsurf
  integer :: sitnumb(100,2), snumbit, failures, calls_before
  logical :: sfldecdt, sfllowgwl, sflrunoff, sftoph

  failures=0
  call configure_parameters(params)
  call seed_request_origin()
  call build_legacy_reference_request(request_a, params, provider)
  request_b=request_a
  request_b%base_state%pressure_head=request_a%base_state%pressure_head-20.0_real64
  request_b%base_state%water_content=request_a%base_state%water_content+0.05_real64
  request_b%base_state%ponding_depth=request_a%base_state%ponding_depth+0.10_real64
  request_b%base_state%groundwater_level=request_a%base_state%groundwater_level-0.50_real64

  call seed_global_sentinels()
  call capture_globals()
  call a23bu_initialize_worker(workspace%legacy_worker,numnod,47)
  workspace%legacy_worker%history%flwarn=.false.
  workspace%legacy_worker%history%iwarn=777
  workspace%legacy_worker%history%nstep=888

  call solver%solve(request_a, workspace, result_a1)
  call expect(result_a1%status==SW_SOLVE_CONVERGED, failures)
  call expect(.not.result_a1%retry_advised, failures)
  call expect(trim(result_a1%diagnostics%route)=='legacy-reference-bound', failures)
  call expect(near_vector(observed_head,request_a%base_state%pressure_head), failures)
  call expect(near_vector(observed_theta,request_a%base_state%water_content), failures)
  call expect(near_scalar(observed_pond,request_a%base_state%ponding_depth), failures)
  call expect(near_scalar(observed_gwl,request_a%base_state%groundwater_level), failures)
  call expect(near_vector(result_a1%candidate_state%pressure_head,request_a%base_state%pressure_head-1.0_real64), failures)
  call expect(near_vector(result_a1%candidate_state%water_content,request_a%base_state%water_content+0.01_real64), failures)
  call expect(near_scalar(result_a1%candidate_state%ponding_depth,request_a%base_state%ponding_depth+0.02_real64), failures)
  call expect(near_scalar(result_a1%candidate_state%groundwater_level,request_a%base_state%groundwater_level-0.03_real64), failures)
  call expect(near_scalar(result_a1%top_flux,1.25_real64), failures)
  call expect(near_scalar(result_a1%bottom_flux,-0.75_real64), failures)
  call expect(ieee_is_nan(result_a1%unrounded_mass_balance_residual), failures)
  call expect(result_a1%diagnostics%nonlinear_iterations==4, failures)
  call expect(result_a1%diagnostics%backtracking_attempts==6, failures)
  call expect_globals_restored(failures)
  call expect(.not.workspace%legacy_worker%history%flwarn, failures)
  call expect(workspace%legacy_worker%history%iwarn==777, failures)
  call expect(workspace%legacy_worker%history%nstep==888, failures)

  call solver%solve(request_a, workspace, result_a2)
  call expect_same_candidate(result_a1,result_a2,failures)
  call solver%solve(request_b, workspace, result_b)
  call solver%solve(request_a, workspace, result_a2)
  call expect_same_candidate(result_a1,result_a2,failures)
  call expect_globals_restored(failures)

  request_retry=.true.
  call solver%solve(request_a, workspace, result_retry)
  call expect(result_retry%status==SW_SOLVE_RETRY_ADVISED, failures)
  call expect(result_retry%retry_advised, failures)
  call expect(trim(result_retry%diagnostics%route)=='legacy-reference-retry', failures)
  call expect(result_retry%diagnostics%internal_retries==1, failures)
  request_retry=.false.
  call expect_globals_restored(failures)

  calls_before=headcalc_calls
  swmacro=1
  call solver%solve(request_a, workspace, result_reject)
  call expect(result_reject%status==SW_SOLVE_FAILED, failures)
  call expect(trim(result_reject%diagnostics%route)=='legacy-macropore-deferred', failures)
  call expect(headcalc_calls==calls_before, failures)
  swmacro=0

  if (failures/=0) then
    print '(A,I0)', 'F-SI07_ADAPTER_BINDING FAIL failures=',failures
    error stop 1
  end if
  print '(A)', 'F-SI07_ADAPTER_BINDING PASS'
  print '(A,I0)', 'headcalc_stub_calls=',headcalc_calls
  print '(A,I0)', 'parameter_set_id=',params%parameter_set_id
contains
  subroutine configure_parameters(p)
    type(soil_water_parameter_set_t), intent(out), target :: p
    p%parameter_set_id=4701_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
  end subroutine

  subroutine seed_request_origin()
    integer :: i
    do i=1,numnod
      h(i)=-real(i,real64); theta(i)=0.20_real64+0.01_real64*real(i,real64)
    end do
    pond=0.03_real64; gwl=-2.25_real64; hm1=h; thetm1=theta; pondm1=pond; gwlm1=gwl
    qtop=0.0_real64; qbot=0.0_real64; hbot=-100.0_real64; fldecdt=.false.; numbit=0
  end subroutine

  subroutine seed_global_sentinels()
    integer :: i
    do i=1,numnod
      h(i)=100.0_real64+real(i,real64); theta(i)=0.40_real64+0.01_real64*real(i,real64)
      hm1(i)=200.0_real64+real(i,real64); thetm1(i)=0.50_real64+0.01_real64*real(i,real64)
      k(i)=10.0_real64+real(i,real64); dimoca(i)=20.0_real64+real(i,real64)
    end do
    kmean=30.0_real64; pond=9.0_real64; gwl=-9.0_real64; pondm1=8.0_real64; gwlm1=-8.0_real64
    qtop=7.0_real64; qbot=-7.0_real64; hbot=-99.0_real64; gwlinp=-77.0_real64; dtold=0.125_real64
    runots=5.0_real64; itnumb=3; fldecdt=.true.; numbit=99; fllowgwl=.true.
    q0=6.0_real64; hsurf=0.4_real64; flrunoff=.true.; ftoph=.true.
  end subroutine

  subroutine capture_globals()
    sh=h; st=theta; shm1=hm1; stm1=thetm1; sk=k; skm=kmean; sdm=dimoca
    sp=pond; sg=gwl; spm1=pondm1; sgm1=gwlm1; sqt=qtop; sqb=qbot; shbot=hbot; sgwlinp=gwlinp
    sdtold=dtold; srunots=runots; sitnumb=itnumb; sfldecdt=fldecdt; snumbit=numbit; sfllowgwl=fllowgwl
    sq0=q0; shsurf=hsurf; sflrunoff=flrunoff; sftoph=ftoph
  end subroutine

  subroutine expect_globals_restored(fails)
    integer,intent(inout)::fails
    call expect(near_vector(h,sh),fails); call expect(near_vector(theta,st),fails)
    call expect(near_vector(hm1,shm1),fails); call expect(near_vector(thetm1,stm1),fails)
    call expect(near_vector(k,sk),fails); call expect(near_vector(kmean,skm),fails); call expect(near_vector(dimoca,sdm),fails)
    call expect(near_scalar(pond,sp),fails); call expect(near_scalar(gwl,sg),fails)
    call expect(near_scalar(pondm1,spm1),fails); call expect(near_scalar(gwlm1,sgm1),fails)
    call expect(near_scalar(qtop,sqt),fails); call expect(near_scalar(qbot,sqb),fails)
    call expect(near_scalar(hbot,shbot),fails); call expect(near_scalar(gwlinp,sgwlinp),fails)
    call expect(near_scalar(dtold,sdtold),fails); call expect(near_scalar(runots,srunots),fails)
    call expect(all(itnumb==sitnumb),fails); call expect(fldecdt.eqv.sfldecdt,fails); call expect(numbit==snumbit,fails)
    call expect(fllowgwl.eqv.sfllowgwl,fails); call expect(near_scalar(q0,sq0),fails); call expect(near_scalar(hsurf,shsurf),fails)
    call expect(flrunoff.eqv.sflrunoff,fails); call expect(ftoph.eqv.sftoph,fails)
  end subroutine

  subroutine expect_same_candidate(a,b,fails)
    type(soil_water_solve_result_t),intent(in)::a,b
    integer,intent(inout)::fails
    call expect(a%status==b%status,fails)
    call expect(near_vector(a%candidate_state%pressure_head,b%candidate_state%pressure_head),fails)
    call expect(near_vector(a%candidate_state%water_content,b%candidate_state%water_content),fails)
    call expect(near_scalar(a%candidate_state%ponding_depth,b%candidate_state%ponding_depth),fails)
    call expect(near_scalar(a%candidate_state%groundwater_level,b%candidate_state%groundwater_level),fails)
    call expect(near_scalar(a%top_flux,b%top_flux),fails); call expect(near_scalar(a%bottom_flux,b%bottom_flux),fails)
  end subroutine

  logical function near_scalar(a,b)
    real(real64),intent(in)::a,b
    real(real64)::scale
    scale=max(1.0_real64,abs(a),abs(b)); near_scalar=abs(a-b)<=16.0_real64*epsilon(1.0_real64)*scale
  end function
  logical function near_vector(a,b)
    real(real64),intent(in)::a(:),b(:)
    integer::i
    near_vector=size(a)==size(b); if(.not.near_vector)return
    do i=1,size(a); if(.not.near_scalar(a(i),b(i)))then; near_vector=.false.; return; end if; end do
  end function
  subroutine expect(condition,fails)
    logical,intent(in)::condition; integer,intent(inout)::fails
    if(.not.condition)fails=fails+1
  end subroutine
end program test_fsi07_adapter_binding
