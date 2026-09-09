program test_fsi23_gate_c1b_hydraulic_eigenmode
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_fsi23_mms_providers, only: fsi23_linear_hydraulics_provider_t
  implicit none

  integer, parameter :: ndt=5
  real(real64), parameter :: h_eq=-100.0_real64, theta_eq=0.30_real64
  real(real64), parameter :: cap=0.001_real64, kval=0.01_real64
  real(real64), parameter :: eig0=0.25619777153614321838_real64
  real(real64), parameter :: lambda=2.5619777153614321838_real64
  real(real64), parameter :: amplitude=10.0_real64
  real(real64), parameter :: v(numnod)=[ &
       0.6752098721931038_real64, 0.5887162399055651_real64, &
       0.4268087132525549_real64, 0.1555537453920313_real64]
  real(real64), parameter :: dts(ndt)=[ &
       0.15612938301595253_real64, 0.07806469150797626_real64, &
       0.03903234575398813_real64, 0.019516172876994066_real64, &
       0.009758086438497033_real64]
  real(real64), parameter :: xs(ndt)=[0.4_real64,0.2_real64,0.1_real64,0.05_real64,0.025_real64]

  type(soil_water_parameter_set_t), target :: parameters
  type(fsi23_linear_hydraulics_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64) :: u0(numnod), h0(numnod), theta0(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: u_be(numnod), h_be(numnod), u_exact(numnod), h_exact(numnod)
  real(real64) :: hdot_n(numnod), hdot_np1(numnod), observer(numnod), observer_analytic(numnod)
  real(real64) :: a_over_k(numnod,numnod), av(numnod), mv(numnod), eig_residual
  real(real64) :: storage0, storage1, discrete_mass_residual, exact_storage_delta, exact_qdiff_integral, exact_mass_residual
  real(real64) :: endpoint_diff, observer_diff, observer_mag, exact_error, rho
  real(real64) :: prev_observer, prev_error, prev_rho, bound
  integer :: i

  call require(numnod==4,'frozen four-node geometry')
  call initialize_geometry_and_providers()

  a_over_k = reshape([ &
       1.0_real64,-1.0_real64, 0.0_real64, 0.0_real64, &
      -1.0_real64, 2.0_real64,-1.0_real64, 0.0_real64, &
       0.0_real64,-1.0_real64, 2.0_real64,-1.0_real64, &
       0.0_real64, 0.0_real64,-1.0_real64, 3.0_real64], [numnod,numnod])
  av = matmul(a_over_k,v)
  mv = parameters%dz*v
  eig_residual = maxval(abs(av-eig0*mv))
  bound = fp_bound(max(maxval(abs(av)),maxval(abs(eig0*mv))))
  call require(eig_residual<=bound,'generalized eigenpair precheck')
  call require(abs(lambda-(kval/cap)*eig0)<=fp_bound(lambda),'lambda construction')
  write(*,'(A,ES24.15E3,A,ES24.15E3)') 'FSI23_C1B_EIGENPAIR:RESIDUAL=',eig_residual,':BOUND=',bound

  u0=amplitude*v
  h0=h_eq+u0
  call constitutive%evaluate(h0,theta0,conductivity,capacity,dkdh)
  initial_state%active_nodes=numnod
  allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
  initial_state%pressure_head=h0
  initial_state%water_content=theta0
  initial_state%ponding_depth=0.0_real64
  initial_state%groundwater_level=-2.0_real64
  storage0=sum(theta0*parameters%dz)
  hdot_n=-lambda*u0

  prev_observer=huge(1.0_real64)
  prev_error=huge(1.0_real64)
  prev_rho=huge(1.0_real64)

  do i=1,ndt
    call require(abs(lambda*dts(i)-xs(i))<=fp_bound(xs(i)),'frozen lambda-dt identity')
    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%base_state=initial_state
    request%step_duration=dts(i)
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=5
    request%boundary%top_flux=-kval
    request%boundary%top_head=h0(1)
    request%boundary%bottom_flux=12345.678_real64
    request%boundary%bottom_head=h_eq
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=8
    request%numerical%max_backtracking=4
    request%numerical%conductivity_implicit_mode=0
    request%numerical%conductivity_mean_method=1
    request%numerical%min_step_duration=1.0e-6_real64
    request%numerical%compartment_balance_tolerance=1.0e-12_real64
    request%numerical%total_balance_tolerance=1.0e-12_real64
    request%numerical%head_abs_tolerance=1.0e-12_real64
    request%numerical%head_rel_tolerance=1.0e-12_real64
    request%numerical%ponding_tolerance=1.0e-12_real64
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    request%evaluation%top_boundary=>top_provider

    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_CONVERGED,'HeadCalc manufactured eigenmode converged')

    u_be=u0/(1.0_real64+xs(i))
    h_be=h_eq+u_be
    u_exact=u0*exp(-xs(i))
    h_exact=h_eq+u_exact
    endpoint_diff=maxval(abs(result%candidate_state%pressure_head-h_be))
    bound=fp_bound(max(maxval(abs(result%candidate_state%pressure_head)),maxval(abs(h_be))))
    call require(endpoint_diff<=bound,'computed endpoint matches analytic backward Euler')

    hdot_np1=(result%candidate_state%pressure_head-h0)/dts(i)
    observer=0.5_real64*dts(i)*(hdot_np1-hdot_n)
    observer_analytic=0.5_real64*u0*xs(i)*xs(i)/(1.0_real64+xs(i))
    observer_diff=maxval(abs(observer-observer_analytic))
    bound=fp_bound(max(maxval(abs(observer)),maxval(abs(observer_analytic))))
    call require(observer_diff<=bound,'computed observer matches analytic derivative difference')

    observer_mag=maxval(abs(observer))
    exact_error=maxval(abs(result%candidate_state%pressure_head-h_exact))
    call require(observer_mag>0.0_real64 .and. exact_error>0.0_real64,'positive observer and exact error')
    rho=observer_mag/exact_error
    call require(ieee_is_finite(rho) .and. rho>1.0_real64,'conservative manufactured rho greater than one')
    if (i>1) then
      call require(observer_mag<prev_observer,'observer decreases under refinement')
      call require(exact_error<prev_error,'exact local error decreases under refinement')
      call require(rho<prev_rho,'rho decreases toward one under refinement')
    end if

    storage1=sum(result%candidate_state%water_content*parameters%dz)+result%candidate_state%ponding_depth
    discrete_mass_residual=(storage1-storage0)-dts(i)*(result%bottom_flux-result%top_flux)
    call require(abs(discrete_mass_residual)<=fp_bound(max(storage0,storage1)),'discrete manufactured mass ledger')
    call require(abs(result%top_flux+kval)<=fp_bound(kval),'manufactured top gravity flux')

    exact_storage_delta=cap*sum(parameters%dz*(u_exact-u0))
    exact_qdiff_integral=-(kval/(0.5_real64*parameters%dz(numnod)))*u0(numnod)*(1.0_real64-exp(-xs(i)))/lambda
    exact_mass_residual=exact_storage_delta-exact_qdiff_integral
    call require(abs(exact_mass_residual)<=fp_bound(max(abs(exact_storage_delta),abs(exact_qdiff_integral))), &
         'exact manufactured continuous mass identity')

    write(*,'(A,I0,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3)') &
      'FSI23_C1B_POINT:I=',i,':DT=',dts(i),':X=',xs(i),':OBS=',observer_mag,':ERR=',exact_error,':RHO=',rho, &
      ':DMASS=',discrete_mass_residual,':EMASS=',exact_mass_residual

    prev_observer=observer_mag
    prev_error=exact_error
    prev_rho=rho
  end do

  call require(abs(prev_rho-1.0_real64)<abs((0.5_real64*0.4_real64**2/(1.0_real64+0.4_real64))/ &
       (1.0_real64/(1.0_real64+0.4_real64)-exp(-0.4_real64))-1.0_real64),'final rho is closer to one')
  write(*,'(A)') 'FSI23_C1B_HYDRAULIC_EIGENMODE PASS'

contains

  subroutine initialize_geometry_and_providers()
    parameters%parameter_set_id=230231_int64
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z
    parameters%dz=dz
    parameters%node_distance=disnod(1:numnod)
    call require(maxval(abs(parameters%dz-[0.5_real64,0.5_real64,1.0_real64,1.0_real64]))==0.0_real64, &
         'frozen dz geometry')
    call require(all(abs(parameters%node_distance-1.0_real64)==0.0_real64),'frozen internal distance geometry')

    constitutive%equilibrium_head=h_eq
    constitutive%theta_equilibrium=theta_eq
    constitutive%capacity=cap
    constitutive%conductivity=kval

    allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod))
    drainage=0.0_real64
    subsurface=0.0_real64
    root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)
    if (.not.same_type_as(top_provider,top_provider)) error stop 'F-SI23 C1B invalid top provider type'
  end subroutine initialize_geometry_and_providers

  pure real(real64) function fp_bound(scale) result(bound_value)
    real(real64), intent(in) :: scale
    bound_value=65536.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(scale))
  end function fp_bound

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'FSI23_C1B_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi23_gate_c1b_hydraulic_eigenmode
