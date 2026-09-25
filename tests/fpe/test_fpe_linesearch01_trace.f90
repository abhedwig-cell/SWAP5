program test_fpe_linesearch01_trace
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS
  type(soil_water_parameter_set_t),target :: parameters
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(rossfast_d3r_material_t) :: material
  type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
  type(b110_default_mvg_provider_t),target :: constitutive
  type(b110_source_sink_provider_t),target :: source_sink
  type(fixed_flux_top_boundary_provider_t),target :: top_boundary
  real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
  real(real64) :: cofgen(24,n),heads(n),theta0(n),conductivity(n),capacity(n),dkdh(n)
  real(real64) :: h0,k0,dt,top_factor,bottom_factor,checksum
  character(len=32) :: mode,arg
  integer :: calls,i
  logical :: found

  call get_command_argument(1,mode)
  call get_command_argument(2,arg); read(arg,*) calls
  if(calls<=0) error stop 'NEWTON-CANDIDATE01 calls must be positive'
  select case(trim(mode))
  case('easy')
    dt=0.0016_real64; top_factor=0.010_real64; bottom_factor=-0.004_real64
  case('hard')
    dt=0.0001_real64; top_factor=-0.005_real64; bottom_factor=-0.019_real64
  case default
    error stop 'NEWTON-CANDIDATE01 mode must be easy or hard'
  end select

  call rossfast_d3r_material_from_id('B01',material,found)
  if(.not.found) error stop 'B01 unavailable'
  h0=head_from_effective_saturation(0.65_real64,material)
  call initialize_parameter_contract(parameters,cofgen,material)
  call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
  call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
  heads=h0
  call constitutive%evaluate(heads,theta0,conductivity,capacity,dkdh)
  k0=conductivity(1)
  drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
  call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta0,h0,top_factor*k0,bottom_factor*k0,dt)

  checksum=0.0_real64
  do i=1,calls
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
    call solver%solve(request,workspace,result)
    checksum=checksum+real(result%diagnostics%backtracking_attempts+result%diagnostics%nonlinear_iterations,real64)
  end do
  write(*,'(*(g0))') 'LINESEARCH01_SUMMARY|MODE=',trim(mode),'|CALLS=',calls,'|STATUS=',result%status, &
       '|ITER=',result%diagnostics%nonlinear_iterations,'|JAC=',result%diagnostics%jacobian_builds, &
       '|LIN=',result%diagnostics%linear_solves,'|BACKTRACK=',result%diagnostics%backtracking_attempts, &
       '|CONST=',result%diagnostics%constitutive_evaluations,'|CONST_DEMAND=', &
       result%diagnostics%constitutive_candidate_demand_evaluations,'|CHECKSUM=',checksum
contains
  pure real(real64) function head_from_effective_saturation(se,mat) result(head_cm)
    real(real64),intent(in)::se
    type(rossfast_d3r_material_t),intent(in)::mat
    real(real64)::m
    m=1.0_real64-1.0_real64/mat%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/mat%n)/mat%alpha_per_cm
  end function
  subroutine initialize_parameter_contract(p,c,mat)
    type(soil_water_parameter_set_t),target,intent(out)::p
    real(real64),intent(out)::c(24,n)
    type(rossfast_d3r_material_t),intent(in)::mat
    real(real64)::m
    integer::k
    m=1.0_real64-1.0_real64/mat%n
    p%parameter_set_id=931101; p%active_nodes=n
    allocate(p%z(n),p%dz(n),p%node_distance(n))
    do k=1,n; p%z(k)=-ROSSFAST_D3R_DZ_CM*(real(k,real64)-0.5_real64); end do
    p%dz=ROSSFAST_D3R_DZ_CM; p%node_distance=ROSSFAST_D3R_DZ_CM
    c=0.0_real64
    do k=1,n
      c(1,k)=mat%theta_r; c(2,k)=mat%theta_s; c(3,k)=mat%ksatfit_cm_per_day
      c(4,k)=mat%alpha_per_cm; c(5,k)=mat%lambda; c(6,k)=mat%n; c(7,k)=m
      c(8,k)=mat%alpha_per_cm; c(9,k)=mat%h_enpr_cm; c(10,k)=mat%ksatfit_cm_per_day
      c(11,k)=0.999_real64; c(12,k)=0.99_real64*mat%ksatfit_cm_per_day
      c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
  end subroutine
  subroutine initialize_request(req,p,hyd,ss,top,theta,h,qtop,qbot,step)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::p
    type(b110_default_mvg_provider_t),target,intent(in)::hyd
    type(b110_source_sink_provider_t),target,intent(in)::ss
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::top
    real(real64),intent(in)::theta(n),h,qtop,qbot,step
    req%parameters=>p; req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=h; req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64; req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop; req%boundary%top_head=h; req%boundary%bottom_flux=qbot
    req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-12_real64
    req%numerical%total_balance_tolerance=1.0e-12_real64
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=step; req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hyd; req%evaluation%source_sink=>ss; req%evaluation%top_boundary=>top
  end subroutine
end program test_fpe_linesearch01_trace
