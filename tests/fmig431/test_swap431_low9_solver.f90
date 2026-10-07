program test_swap431_low9_solver
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_FAILED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  call run_case(0.0_real64, 0.25_real64)
  call run_case(1.0e-10_real64, 1.0e-4_real64)
  call reject_implicit_k()
  print '(a)', 'SW431_LOW9_TYPED_SOLVER=PASS'

contains

  subroutine run_case(q, step_dt)
    real(real64), intent(in) :: q, step_dt
    type(soil_water_parameter_set_t), target :: parameters
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64), target :: drainage(1,numnod), irrigation(numnod), roots(numnod)
    real(real64) :: cofgen(24,numnod), heads(numnod), water(numnod), k(numnod), cap(numnod), dkdh(numnod)
    real(real64) :: boundary_heads(numnod), boundary_water(numnod), boundary_k(numnod), boundary_cap(numnod), boundary_dkdh(numnod)
    real(real64) :: reset_heads(numnod), reset_water(numnod), reset_k(numnod), reset_cap(numnod), reset_dkdh(numnod)
    real(real64) :: kbot, expected_last, scale
    integer :: i

    call configure(parameters,cofgen)
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,step_dt)

    ! Hydrostatic interior referenced to total head -2.5 cm. Poison the final
    ! node so the mode-9 precondition must replace it before HeadCalc.
    heads = -2.5_real64 - parameters%z
    heads(numnod) = -10.0_real64
    call constitutive%evaluate(heads,water,k,cap,dkdh)

    drainage=0.0_real64; irrigation=0.0_real64; roots=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,roots)

    request%parameters=>parameters
    request%base_state%active_nodes=numnod
    allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
    request%base_state%pressure_head=heads
    request%base_state%water_content=water
    request%base_state%ponding_depth=0.0_real64
    request%base_state%groundwater_level=-2.5_real64
    request%step_duration=step_dt
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%top_flux=q
    request%boundary%top_head=heads(1)
    request%boundary%bottom_mode=9
    request%boundary%bottom_flux=q
    request%boundary%bottom_head=0.5_real64
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=32
    request%numerical%max_backtracking=16
    request%numerical%conductivity_implicit_mode=0
    request%numerical%conductivity_mean_method=1
    request%numerical%min_step_duration=1.0e-12_real64
    request%numerical%compartment_balance_tolerance=1.0e-10_real64
    request%numerical%total_balance_tolerance=1.0e-10_real64
    request%numerical%head_abs_tolerance=1.0e-10_real64
    request%numerical%head_rel_tolerance=1.0e-10_real64
    request%numerical%ponding_tolerance=1.0e-10_real64
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    request%evaluation%top_boundary=>top

    boundary_heads=heads
    boundary_heads(numnod)=request%boundary%bottom_head
    call constitutive%evaluate(boundary_heads,boundary_water,boundary_k,boundary_cap,boundary_dkdh)
    kbot=boundary_k(numnod)
    call require(kbot>0.0_real64.and.ieee_is_finite(kbot),'positive K(hbot)')
    expected_last=request%boundary%bottom_head-(q/kbot+1.0_real64)*(0.5_real64*parameters%dz(numnod))
    reset_heads=heads; reset_heads(numnod)=expected_last
    call constitutive%evaluate(reset_heads,reset_water,reset_k,reset_cap,reset_dkdh)

    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_CONVERGED,'mode9 solve converged')
    call require(transfer(result%bottom_flux,0_int64)==transfer(q,0_int64),'mode9 qbot exact identity')
    scale=max(1.0_real64,abs(expected_last),abs(result%candidate_state%pressure_head(numnod)))
    call require(abs(result%candidate_state%pressure_head(numnod)-expected_last)<=64.0_real64*epsilon(1.0_real64)*scale, &
         'mode9 final-node head reset')
    scale=max(1.0_real64,abs(reset_water(numnod)),abs(result%candidate_state%water_content(numnod)))
    call require(abs(result%candidate_state%water_content(numnod)-reset_water(numnod))<=256.0_real64*epsilon(1.0_real64)*scale, &
         'mode9 final-node theta reset')
    call require(ieee_is_finite(result%unrounded_mass_balance_residual),'mode9 finite equation residual')
    print '(a,es16.8e3,a,es26.17e3)', 'SW431_LOW9_ROW q=',q,' hlast=',result%candidate_state%pressure_head(numnod)
  end subroutine

  subroutine reject_implicit_k()
    type(soil_water_parameter_set_t), target :: parameters
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t), target :: constitutive
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: cofgen(24,numnod), heads(numnod), water(numnod), k(numnod), cap(numnod), dkdh(numnod)

    call configure(parameters,cofgen)
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,0.25_real64)
    heads=-2.5_real64-parameters%z
    call constitutive%evaluate(heads,water,k,cap,dkdh)
    request%parameters=>parameters
    request%base_state%active_nodes=numnod
    allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
    request%base_state%pressure_head=heads;request%base_state%water_content=water
    request%step_duration=0.25_real64
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;request%boundary%top_flux=0.0_real64
    request%boundary%bottom_mode=9;request%boundary%bottom_flux=0.0_real64;request%boundary%bottom_head=0.5_real64
    request%numerical%conductivity_implicit_mode=1
    request%numerical%conductivity_mean_method=1
    request%numerical%max_iterations=8;request%numerical%max_backtracking=4
    request%numerical%min_step_duration=1.0e-12_real64
    request%numerical%compartment_balance_tolerance=1.0e-10_real64
    request%numerical%total_balance_tolerance=1.0e-10_real64
    request%numerical%head_abs_tolerance=1.0e-10_real64
    request%numerical%head_rel_tolerance=1.0e-10_real64
    request%numerical%ponding_tolerance=1.0e-10_real64
    request%evaluation%constitutive=>constitutive;request%evaluation%top_boundary=>top
    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_FAILED,'mode9 implicit-K remains fail closed')
  end subroutine

  subroutine configure(parameters,cofgen)
    type(soil_water_parameter_set_t),target,intent(out)::parameters
    real(real64),intent(out)::cofgen(24,numnod)
    integer::i
    parameters%parameter_set_id=900009_int64;parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z;parameters%dz=dz;parameters%node_distance=disnod(1:numnod)
    cofgen=0.0_real64
    do i=1,numnod
      cofgen(1,i)=0.032_real64;cofgen(2,i)=0.423_real64;cofgen(3,i)=4.75_real64
      cofgen(4,i)=0.0135_real64;cofgen(5,i)=0.365_real64;cofgen(6,i)=1.455_real64
      cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i);cofgen(8,i)=cofgen(4,i)
      cofgen(10,i)=cofgen(3,i);cofgen(11,i)=0.999_real64;cofgen(12,i)=0.99_real64*cofgen(3,i)
      cofgen(22,i)=-1.0e6_real64;cofgen(23,i)=1.0e-12_real64
    end do
  end subroutine

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'LOW9_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program
