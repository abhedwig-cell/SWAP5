module mod_fsi07_common_constitutive
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  public :: fsi07_common_constitutive_t

  type, extends(constitutive_hydraulics_provider_t) :: fsi07_common_constitutive_t
   contains
     procedure :: evaluate => evaluate_constitutive
  end type fsi07_common_constitutive_t
contains
  subroutine evaluate_constitutive(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fsi07_common_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    if (storage_size(self) <= 0 .or. size(pressure_head) <= 0) error stop 'invalid F-SI07 constitutive provider'
    water_content=0.30_real64
    conductivity=1.0_real64
    capacity=0.0_real64
    dconductivity_dhead=0.0_real64
  end subroutine evaluate_constitutive
end module mod_fsi07_common_constitutive

program test_fsi07_common_route_serial
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_top, only: q0, flrunoff, ftoph, hsurf
  use variables
  use fsi05_fixture_control, only: force_tridag_failure
  use mod_soil_water_solver_contract
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_workspace, only: initialize_reference_workspace, poison_reference_workspace
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_fsi07_top_provider, only: fsi07_flux_top_provider_t
  use mod_fsi07_common_constitutive, only: fsi07_common_constitutive_t
  implicit none

  type(soil_water_parameter_set_t), target :: params
  type(fsi07_common_constitutive_t), target :: constitutive
  type(fsi07_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  integer :: failures
  integer(int64) :: fp_a1, fp_a2, globals_before

  failures=0
  call seed_shared_fixture()
  call configure_parameters()
  top_provider%fixed_flux=-1.0_real64
  top_provider%surface_tracks_head=.false.
  globals_before=global_state_fingerprint()

  call run_case(-100.0_real64,.false.,'MAIN-A1',fp_a1,failures)
  call run_case(-200.0_real64,.false.,'MAIN-B ',fp_a2,failures)
  call run_case(-100.0_real64,.false.,'MAIN-A2',fp_a2,failures)
  if(fp_a1/=fp_a2) failures=failures+1

  call run_case(-100.0_real64,.true.,'BAND-A1',fp_a1,failures)
  call run_case(-200.0_real64,.true.,'BAND-B ',fp_a2,failures)
  call run_case(-100.0_real64,.true.,'BAND-A2',fp_a2,failures)
  if(fp_a1/=fp_a2) failures=failures+1

  if(global_state_fingerprint()/=globals_before) failures=failures+1
  if(failures/=0) then
    write(*,'(A,I0)') 'F-SI07_STATE_BINDING FAIL failures=',failures
    error stop 1
  end if
  write(*,'(A)') 'F-SI07_STATE_BINDING PASS'

contains

  subroutine configure_parameters()
    params%parameter_set_id=4707_int64
    params%active_nodes=numnod
    allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod))
    params%z=z
    params%dz=dz
    params%node_distance=disnod(1:numnod)
  end subroutine configure_parameters

  subroutine seed_shared_fixture()
    swmacro=0
    swbotb=7
    swkimpl=0
    swkmean=1
    fldtmin=.false.
    fldaystart=.false.
    maxit=8
    maxbacktr=4
    CritDevBalCp=1.0e-12_real64
    CritDevBalTot=1.0e-12_real64
    critdevh2cp=1.0e-12_real64
    critdevh1cp=1.0e-12_real64
    critdevponddt=1.0e-12_real64
    h=-999.0_real64
    theta=0.30_real64
    hm1=-888.0_real64
    thetm1=0.31_real64
    pond=9.0_real64
    pondm1=8.0_real64
    gwl=-9.0_real64
    gwlm1=-8.0_real64
    gwlinp=-77.0_real64
    qtop=7.0_real64
    qbot=-7.0_real64
    hbot=-99.0_real64
    dtold=0.125_real64
    runots=5.0_real64
    k=11.0_real64
    kmean=12.0_real64
    dimoca=13.0_real64
    itnumb=3
    numbit=99
    fllowgwl=.true.
    fldecdt=.true.
    q0=6.0_real64
    hsurf=0.4_real64
    flrunoff=.true.
    ftoph=.true.
  end subroutine seed_shared_fixture

  subroutine make_request(request, head_value)
    type(soil_water_solve_request_t), intent(out) :: request
    real(real64), intent(in) :: head_value
    request%parameters=>params
    request%evaluation%constitutive=>constitutive
    request%evaluation%top_boundary=>top_provider
    request%step_duration=dt
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=7
    request%boundary%top_flux=-1.0_real64
    request%boundary%top_head=0.0_real64
    request%boundary%bottom_flux=-1.0_real64
    request%boundary%bottom_head=-100.0_real64
    request%numerical%max_iterations=maxit
    request%numerical%max_backtracking=maxbacktr
    request%numerical%conductivity_implicit_mode=swkimpl
    request%numerical%conductivity_mean_method=swkmean
    request%numerical%min_step_duration=dtmin
    request%numerical%compartment_balance_tolerance=CritDevBalCp
    request%numerical%total_balance_tolerance=CritDevBalTot
    request%numerical%head_abs_tolerance=critdevh2cp
    request%numerical%head_rel_tolerance=critdevh1cp
    request%numerical%ponding_tolerance=critdevponddt
    request%base_state%active_nodes=numnod
    allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
    request%base_state%pressure_head=head_value
    request%base_state%water_content=0.30_real64
    request%base_state%ponding_depth=0.0_real64
    request%base_state%groundwater_level=-2.0_real64
  end subroutine make_request

  subroutine run_case(head_value,fallback,label,fingerprint,fails)
    real(real64),intent(in)::head_value
    logical,intent(in)::fallback
    character(len=*),intent(in)::label
    integer(int64),intent(out)::fingerprint
    integer,intent(inout)::fails
    type(soil_water_solve_request_t)::request
    type(soil_water_solve_result_t)::result
    integer(int64)::request_before
    real(real64)::residual
    integer::i,expected_alternative,out_numbit

    call make_request(request,head_value)
    request_before=request_fingerprint(request)
    force_tridag_failure=fallback
    expected_alternative=merge(1,0,fallback)
    call initialize_reference_workspace(workspace%richards,numnod)
    call poison_reference_workspace(workspace%richards)
    workspace%legacy_worker%active_nodes=0
    call solver%solve(request,workspace,result)

    if(result%status/=SW_SOLVE_CONVERGED) fails=fails+1
    if(result%retry_advised) fails=fails+1
    if(trim(result%diagnostics%route)/='legacy-reference-bound') fails=fails+1
    if(request_fingerprint(request)/=request_before) fails=fails+1
    if(global_state_fingerprint()/=globals_before) fails=fails+1
    if(workspace%richards%poisoned) fails=fails+1
    if(.not.all(ieee_is_finite(workspace%richards%residual))) fails=fails+1
    residual=sum(dz*(result%candidate_state%water_content-request%base_state%water_content))+result%top_flux-result%bottom_flux
    if(.not.ieee_is_finite(residual)) fails=fails+1
    if(abs(residual)>16.0_real64*epsilon(1.0_real64)) fails=fails+1
    out_numbit=workspace%legacy_worker%control%last_numbit
    if(out_numbit/=1) fails=fails+1
    if(result%diagnostics%nonlinear_iterations/=1) fails=fails+1
    if(result%diagnostics%jacobian_builds/=1) fails=fails+1
    if(result%diagnostics%linear_solves/=1) fails=fails+1
    if(result%diagnostics%alternative_solver_calls/=expected_alternative) fails=fails+1

    fingerprint=1469598103934665603_int64
    do i=1,numnod
      fingerprint=ieor(fingerprint,transfer(result%candidate_state%pressure_head(i),fingerprint))
      fingerprint=ieor(fingerprint,transfer(result%candidate_state%water_content(i),fingerprint))
    end do
    fingerprint=ieor(fingerprint,transfer(result%top_flux,fingerprint))
    fingerprint=ieor(fingerprint,transfer(result%bottom_flux,fingerprint))
    fingerprint=ieor(fingerprint,int(out_numbit,int64))
    fingerprint=ieor(fingerprint,int(result%diagnostics%nonlinear_iterations,int64))
    fingerprint=ieor(fingerprint,int(result%diagnostics%jacobian_builds,int64))
    fingerprint=ieor(fingerprint,int(result%diagnostics%linear_solves,int64))
    fingerprint=ieor(fingerprint,int(result%diagnostics%alternative_solver_calls,int64))

    write(*,'(A,1X,A,1X,Z16.16,1X,ES24.16,1X,ES24.16,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0)') &
      'CASE',trim(label),fingerprint,result%top_flux,result%bottom_flux,out_numbit, &
      result%diagnostics%nonlinear_iterations,result%diagnostics%jacobian_builds, &
      result%diagnostics%linear_solves,result%diagnostics%alternative_solver_calls
  end subroutine run_case

  integer(int64) function request_fingerprint(request) result(fp)
    type(soil_water_solve_request_t),intent(in)::request
    integer::i
    fp=1469598103934665603_int64
    do i=1,numnod
      fp=ieor(fp,transfer(request%base_state%pressure_head(i),fp))
      fp=ieor(fp,transfer(request%base_state%water_content(i),fp))
    end do
    fp=ieor(fp,transfer(request%base_state%ponding_depth,fp))
    fp=ieor(fp,transfer(request%base_state%groundwater_level,fp))
    fp=ieor(fp,transfer(request%boundary%top_flux,fp))
    fp=ieor(fp,transfer(request%boundary%bottom_flux,fp))
  end function request_fingerprint

  integer(int64) function global_state_fingerprint() result(fp)
    integer::i
    fp=1469598103934665603_int64
    do i=1,numnod
      fp=ieor(fp,transfer(h(i),fp)); fp=ieor(fp,transfer(theta(i),fp))
      fp=ieor(fp,transfer(hm1(i),fp)); fp=ieor(fp,transfer(thetm1(i),fp))
      fp=ieor(fp,transfer(k(i),fp)); fp=ieor(fp,transfer(dimoca(i),fp))
    end do
    fp=ieor(fp,transfer(kmean(1),fp)); fp=ieor(fp,transfer(kmean(numnod+1),fp))
    fp=ieor(fp,transfer(pond,fp)); fp=ieor(fp,transfer(pondm1,fp))
    fp=ieor(fp,transfer(gwl,fp)); fp=ieor(fp,transfer(gwlm1,fp))
    fp=ieor(fp,transfer(qtop,fp)); fp=ieor(fp,transfer(qbot,fp))
    fp=ieor(fp,int(numbit,int64)); fp=ieor(fp,merge(1_int64,0_int64,fldecdt))
  end function global_state_fingerprint

end program test_fsi07_common_route_serial
