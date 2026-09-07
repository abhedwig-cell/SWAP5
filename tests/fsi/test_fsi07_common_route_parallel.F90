module mod_fsi07_parallel_constitutive
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  public :: fsi07_parallel_constitutive_t

  type, extends(constitutive_hydraulics_provider_t) :: fsi07_parallel_constitutive_t
   contains
     procedure :: evaluate => evaluate_constitutive
  end type fsi07_parallel_constitutive_t
contains
  subroutine evaluate_constitutive(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fsi07_parallel_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    if (storage_size(self) <= 0 .or. size(pressure_head) <= 0) error stop 'invalid F-SI07 parallel constitutive provider'
    water_content=0.30_real64; conductivity=1.0_real64; capacity=0.0_real64; dconductivity_dhead=0.0_real64
  end subroutine evaluate_constitutive
end module mod_fsi07_parallel_constitutive

program test_fsi07_common_route_parallel
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use omp_lib, only: omp_get_max_threads, omp_get_thread_num
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
  use mod_fsi07_parallel_constitutive, only: fsi07_parallel_constitutive_t
  implicit none

  type(soil_water_parameter_set_t), target :: params
  type(fsi07_parallel_constitutive_t), target :: constitutive
  type(fsi07_flux_top_provider_t), target :: top_provider
  type(soil_water_solve_request_t), allocatable :: requests(:)
  type(soil_water_solve_result_t), allocatable :: serial_results(:), parallel_results(:)
  type(reference_richards_legacy_solver_t), allocatable :: serial_solvers(:), parallel_solvers(:)
  type(reference_richards_legacy_workspace_t), allocatable :: serial_ws(:), parallel_ws(:)
  integer(int64), allocatable :: request_before(:), serial_fp(:), parallel_fp(:)
  integer :: nthreads, i, failures
  integer(int64) :: globals_before

  nthreads=omp_get_max_threads()
  if(.not.any(nthreads==[1,2,4,8])) error stop 'F-SI07 common-route parallel gate requires 1/2/4/8 threads'
  failures=0
  call seed_shared_fixture()
  call configure_parameters()
  top_provider%fixed_flux=-1.0_real64
  top_provider%surface_tracks_head=.true.
  globals_before=global_state_fingerprint()

  allocate(requests(nthreads),serial_results(nthreads),parallel_results(nthreads))
  allocate(serial_solvers(nthreads),parallel_solvers(nthreads),serial_ws(nthreads),parallel_ws(nthreads))
  allocate(request_before(nthreads),serial_fp(nthreads),parallel_fp(nthreads))
  do i=1,nthreads
    call make_request(requests(i),i)
    request_before(i)=request_fingerprint(requests(i))
  end do

  call run_mode(.false.,'MAIN',failures)
  call run_mode(.true.,'BAND',failures)

  if(global_state_fingerprint()/=globals_before) failures=failures+1
  do i=1,nthreads
    if(request_fingerprint(requests(i))/=request_before(i)) failures=failures+1
  end do

  if(failures/=0) then
    write(*,'(A,I0)') 'F-SI07_COMMON_ROUTE_PARALLEL FAIL failures=',failures
    error stop 1
  end if

contains

  subroutine configure_parameters()
    params%parameter_set_id=4708_int64
    params%active_nodes=numnod
    allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod))
    params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)
  end subroutine configure_parameters

  subroutine seed_shared_fixture()
    swmacro=0; swbotb=7; swkimpl=0; swkmean=1; fldtmin=.false.; fldaystart=.false.
    maxit=8; maxbacktr=4
    CritDevBalCp=1.0e-12_real64; CritDevBalTot=1.0e-12_real64
    critdevh2cp=1.0e-12_real64; critdevh1cp=1.0e-12_real64; critdevponddt=1.0e-12_real64
    h=-999.0_real64; theta=0.30_real64; hm1=-888.0_real64; thetm1=0.31_real64
    pond=9.0_real64; pondm1=8.0_real64; gwl=-9.0_real64; gwlm1=-8.0_real64
    gwlinp=-77.0_real64; qtop=7.0_real64; qbot=-7.0_real64; hbot=-99.0_real64
    dtold=0.125_real64; runots=5.0_real64; k=11.0_real64; kmean=12.0_real64; dimoca=13.0_real64
    itnumb=3; numbit=99; fllowgwl=.true.; fldecdt=.true.
    q0=6.0_real64; hsurf=0.4_real64; flrunoff=.true.; ftoph=.true.
  end subroutine seed_shared_fixture

  subroutine make_request(request,column)
    type(soil_water_solve_request_t),intent(out)::request
    integer,intent(in)::column
    real(real64)::head_value
    head_value=-100.0_real64-10.0_real64*real(column,real64)
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
    request%base_state%ponding_depth=0.001_real64*real(column,real64)
    request%base_state%groundwater_level=-2.0_real64-0.1_real64*real(column,real64)
  end subroutine make_request

  subroutine prepare_workspace(ws,column)
    type(reference_richards_legacy_workspace_t),intent(inout)::ws
    integer,intent(in)::column
    call initialize_reference_workspace(ws%richards,numnod)
    call poison_reference_workspace(ws%richards)
    ws%legacy_worker%active_nodes=0
    ws%legacy_worker%worker_id=column
  end subroutine prepare_workspace

  subroutine run_mode(fallback,label,fails)
    logical,intent(in)::fallback
    character(len=*),intent(in)::label
    integer,intent(inout)::fails
    integer::j,mismatches
    real(real64)::residual_serial,residual_parallel

    force_tridag_failure=fallback
    do j=1,nthreads
      call prepare_workspace(serial_ws(j),j)
      call serial_solvers(j)%solve(requests(j),serial_ws(j),serial_results(j))
      serial_fp(j)=result_fingerprint(serial_results(j),serial_ws(j))
      if(serial_results(j)%status/=SW_SOLVE_CONVERGED) fails=fails+1
      if(trim(serial_results(j)%diagnostics%route)/='legacy-reference-bound') fails=fails+1
      residual_serial=focused_residual(requests(j),serial_results(j))
      if(.not.ieee_is_finite(residual_serial).or.abs(residual_serial)>16.0_real64*epsilon(1.0_real64)) fails=fails+1
    end do

    do j=1,nthreads
      call prepare_workspace(parallel_ws(j),j)
    end do
!$omp parallel default(shared) private(j)
    j=omp_get_thread_num()+1
    if(j<=nthreads) call parallel_solvers(j)%solve(requests(j),parallel_ws(j),parallel_results(j))
!$omp end parallel

    mismatches=0
    do j=1,nthreads
      parallel_fp(j)=result_fingerprint(parallel_results(j),parallel_ws(j))
      if(serial_fp(j)/=parallel_fp(j)) mismatches=mismatches+1
      if(parallel_results(j)%status/=serial_results(j)%status) mismatches=mismatches+1
      if(trim(parallel_results(j)%diagnostics%route)/=trim(serial_results(j)%diagnostics%route)) mismatches=mismatches+1
      residual_serial=focused_residual(requests(j),serial_results(j))
      residual_parallel=focused_residual(requests(j),parallel_results(j))
      if(transfer(residual_serial,0_int64)/=transfer(residual_parallel,0_int64)) mismatches=mismatches+1
      if(request_fingerprint(requests(j))/=request_before(j)) fails=fails+1
    end do
    if(global_state_fingerprint()/=globals_before) fails=fails+1
    if(mismatches/=0) then
      write(*,'(A,A,A,I0,A,I0)') 'F-SI07_COMMON_ROUTE_',trim(label),'_',nthreads,' FAIL mismatches=',mismatches
      fails=fails+1
    else
      write(*,'(A,A,A,I0,A)') 'F-SI07_COMMON_ROUTE_',trim(label),'_',nthreads,' PASS'
    end if
  end subroutine run_mode

  real(real64) function focused_residual(request,result) result(residual)
    type(soil_water_solve_request_t),intent(in)::request
    type(soil_water_solve_result_t),intent(in)::result
    residual=sum(dz*(result%candidate_state%water_content-request%base_state%water_content))+result%top_flux-result%bottom_flux
  end function focused_residual

  integer(int64) function result_fingerprint(result,ws) result(fp)
    type(soil_water_solve_result_t),intent(in)::result
    type(reference_richards_legacy_workspace_t),intent(in)::ws
    integer::j
    fp=1469598103934665603_int64
    do j=1,numnod
      fp=ieor(fp,transfer(result%candidate_state%pressure_head(j),fp))
      fp=ieor(fp,transfer(result%candidate_state%water_content(j),fp))
    end do
    fp=ieor(fp,transfer(result%candidate_state%ponding_depth,fp))
    fp=ieor(fp,transfer(result%candidate_state%groundwater_level,fp))
    fp=ieor(fp,transfer(result%top_flux,fp)); fp=ieor(fp,transfer(result%bottom_flux,fp))
    fp=ieor(fp,int(result%status,int64)); fp=ieor(fp,int(ws%legacy_worker%control%last_numbit,int64))
    fp=ieor(fp,int(result%diagnostics%nonlinear_iterations,int64))
    fp=ieor(fp,int(result%diagnostics%jacobian_builds,int64))
    fp=ieor(fp,int(result%diagnostics%linear_solves,int64))
    fp=ieor(fp,int(result%diagnostics%alternative_solver_calls,int64))
  end function result_fingerprint

  integer(int64) function request_fingerprint(request) result(fp)
    type(soil_water_solve_request_t),intent(in)::request
    integer::j
    fp=1469598103934665603_int64
    do j=1,numnod
      fp=ieor(fp,transfer(request%base_state%pressure_head(j),fp))
      fp=ieor(fp,transfer(request%base_state%water_content(j),fp))
    end do
    fp=ieor(fp,transfer(request%base_state%ponding_depth,fp))
    fp=ieor(fp,transfer(request%base_state%groundwater_level,fp))
    fp=ieor(fp,transfer(request%boundary%top_flux,fp)); fp=ieor(fp,transfer(request%boundary%bottom_flux,fp))
  end function request_fingerprint

  integer(int64) function global_state_fingerprint() result(fp)
    integer::j
    fp=1469598103934665603_int64
    do j=1,numnod
      fp=ieor(fp,transfer(h(j),fp)); fp=ieor(fp,transfer(theta(j),fp))
      fp=ieor(fp,transfer(hm1(j),fp)); fp=ieor(fp,transfer(thetm1(j),fp))
      fp=ieor(fp,transfer(k(j),fp)); fp=ieor(fp,transfer(dimoca(j),fp))
    end do
    fp=ieor(fp,transfer(kmean(1),fp)); fp=ieor(fp,transfer(kmean(numnod+1),fp))
    fp=ieor(fp,transfer(pond,fp)); fp=ieor(fp,transfer(pondm1,fp)); fp=ieor(fp,transfer(gwl,fp)); fp=ieor(fp,transfer(gwlm1,fp))
    fp=ieor(fp,transfer(qtop,fp)); fp=ieor(fp,transfer(qbot,fp)); fp=ieor(fp,int(numbit,int64)); fp=ieor(fp,merge(1_int64,0_int64,fldecdt))
  end function global_state_fingerprint

end program test_fsi07_common_route_parallel
