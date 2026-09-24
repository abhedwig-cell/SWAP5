program test_ahl04_fsi24_provider_replay
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_ahl04_hybrid_lookup_provider, only: ahl04_hybrid_lookup_provider_t, &
       bind_ahl04_hybrid_lookup_provider
  implicit none

  real(real64), parameter :: dt=0.25_real64, mass_gate=1.0e-12_real64
  real(real64), parameter :: h0=-75.0_real64, hbot=-60.0_real64
  real(real64), parameter :: head_gate=5.0e-2_real64, theta_gate=1.0e-5_real64
  real(real64), parameter :: flux_gate=1.0e-4_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: analytical
  type(ahl04_hybrid_lookup_provider_t), target :: lookup
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: wa, wl
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: req_a, req_l
  type(soil_water_solve_result_t) :: res_a, res_l
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: k0, max_dh, max_dt, dtop, dbot, mass_a, mass_l
  character(len=512) :: table_path, label
  logical :: ok
  integer :: i

  if (command_argument_count()/=2) error stop 'usage: test TABLE LABEL'
  call get_command_argument(1,table_path)
  call get_command_argument(2,label)

  call configure_problem(parameters,hp,analytical,source_sink,top_provider,initial_state, &
       drainage,subsurface,root_sink,cofgen,k0)

  call build_request(req_a,parameters,initial_state,analytical,source_sink,top_provider,k0)
  call solver%solve(req_a,wa,res_a)
  call require(res_a%status==SW_SOLVE_CONVERGED,'analytical solve converged')

  call bind_ahl04_hybrid_lookup_provider(lookup,hp,dt,trim(table_path),ok)
  call require(ok,'lookup provider bound')
  call build_request(req_l,parameters,initial_state,lookup,source_sink,top_provider,k0)
  call solver%solve(req_l,wl,res_l)
  call require(res_l%status==SW_SOLVE_CONVERGED,'lookup solve converged')

  max_dh=maxval(abs(res_l%candidate_state%pressure_head-res_a%candidate_state%pressure_head))
  max_dt=maxval(abs(res_l%candidate_state%water_content-res_a%candidate_state%water_content))
  dtop=abs(res_l%top_flux-res_a%top_flux)
  dbot=abs(res_l%bottom_flux-res_a%bottom_flux)
  mass_a=abs(res_a%integrated_mass_balance_residual_cm)
  mass_l=abs(res_l%integrated_mass_balance_residual_cm)

  write(*,'(A,1X,A,1X,A,ES24.16)') 'AHL04',trim(label),'MAX_DH_CM',max_dh
  write(*,'(A,1X,A,1X,A,ES24.16)') 'AHL04',trim(label),'MAX_DTHETA',max_dt
  write(*,'(A,1X,A,1X,A,ES24.16)') 'AHL04',trim(label),'DTOP_FLUX',dtop
  write(*,'(A,1X,A,1X,A,ES24.16)') 'AHL04',trim(label),'DBOTTOM_FLUX',dbot
  write(*,'(A,1X,A,1X,A,I0)') 'AHL04',trim(label),'ITER_ANALYTICAL',res_a%diagnostics%nonlinear_iterations
  write(*,'(A,1X,A,1X,A,I0)') 'AHL04',trim(label),'ITER_LOOKUP',res_l%diagnostics%nonlinear_iterations
  write(*,'(A,1X,A,1X,A,ES24.16)') 'AHL04',trim(label),'MASS_ANALYTICAL',mass_a
  write(*,'(A,1X,A,1X,A,ES24.16)') 'AHL04',trim(label),'MASS_LOOKUP',mass_l

  if (trim(label)=='adaptive') then
    call require(max_dh<=head_gate,'adaptive head gate')
    call require(max_dt<=theta_gate,'adaptive theta gate')
    call require(max(dtop,dbot)<=flux_gate,'adaptive flux gate')
    call require(abs(res_l%diagnostics%nonlinear_iterations-res_a%diagnostics%nonlinear_iterations)<=1, &
         'adaptive iteration gate')
    call require(mass_a<=mass_gate .and. mass_l<=mass_gate,'adaptive mass gate')
    write(*,'(A)') 'AHL04_ADAPTIVE_STAGE_A=PASS'
  end if

contains

  subroutine build_request(req,p,state,constitutive,sp,tp,k)
    use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
    type(soil_water_solve_request_t), intent(out) :: req
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(soil_water_physical_state_t), intent(in) :: state
    class(constitutive_hydraulics_provider_t), target, intent(in) :: constitutive
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    real(real64), intent(in) :: k

    req=soil_water_solve_request_t()
    req%parameters=>p
    req%base_state=state
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=5
    req%boundary%top_flux=-k
    req%boundary%top_head=h0
    req%boundary%bottom_flux=12345.678_real64
    req%boundary%bottom_head=hbot
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=8
    req%numerical%max_backtracking=4
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    req%numerical%compartment_balance_tolerance=mass_gate
    req%numerical%total_balance_tolerance=mass_gate
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>sp
    req%evaluation%top_boundary=>tp
  end subroutine build_request

  subroutine configure_problem(p,hp0,cp,sp,tp,state,qdra,qssdi,qrot,c,k0)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp0
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(out) :: tp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    integer :: k

    p%parameter_set_id=240242_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)

    allocate(c(24,numnod)); c=0.0_real64
    do k=1,numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp0,c)
    call bind_b110_default_mvg_provider(cp,hp0,dt)
    heads=h0
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
    if (.not.same_type_as(tp,tp)) error stop 'invalid top provider'
  end subroutine configure_problem

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'AHL04_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ahl04_fsi24_provider_replay
