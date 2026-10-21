program test_weather_surface_desaturation
 use iso_fortran_env,only:real64,int64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_soil_water_solver_contract
 use mod_b110_default_mvg_provider
 use mod_b110_source_sink_provider
 use mod_b110_root_sink_provider
 use mod_b110_dynamic_top_boundary_solver_adapter
 use mod_reference_richards_state_binding,only:FSI_TOP_MODE_DYNAMIC_PROVIDER
 use mod_reference_richards_legacy_binding
 implicit none
 type(soil_water_parameter_set_t),target::p
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(b110_source_sink_provider_t),target::source
 type(b110_root_sink_provider_t),target::root
 type(b110_dynamic_top_boundary_solver_provider_t),target::top
 type(reference_richards_legacy_solver_t)::solver
 type(reference_richards_legacy_workspace_t)::workspace
 type(soil_water_solve_request_t)::r
 type(soil_water_solve_result_t)::v
 real(real64)::cof(24,4),kk(4),cc(4),dd(4),step
 real(real64),target::drain(1,4),irrigation(4),qroot(4)
 integer::j
 call configure_parameters(p,cof)
 call initialize_b110_default_mvg_parameters(hp,cof)
 hp%continuous_saturation_conductivity=.true.
 drain=0d0;irrigation=0d0;qroot=[.012646582580739821d0,.012646582580739821d0,.025293165161479642d0,.025293165161479645d0]
 call bind_b110_source_sink_provider(source,drain,irrigation,irrigation)
 call bind_b110_root_sink_provider(root,qroot)
 r%parameters=>p;r%base_state%active_nodes=4
 allocate(r%base_state%pressure_head(4),r%base_state%water_content(4))
 r%base_state%pressure_head=[.22883381555844240d0,.16227285460717916d0,.082399701465663375d0,.029150932704653389d0]
 r%base_state%ponding_depth=.26877039212919984d0;r%base_state%groundwater_level=-2d0
 r%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER;r%boundary%bottom_mode=7
 r%numerical%consistent_provider_conductivity=.true.
 r%numerical%max_iterations=20;r%numerical%max_backtracking=8
 r%numerical%conductivity_mean_method=1;r%numerical%min_step_duration=1d-10
 r%numerical%compartment_balance_tolerance=1d-10;r%numerical%total_balance_tolerance=1d-10
 r%numerical%head_abs_tolerance=1d-9;r%numerical%head_rel_tolerance=1d-9;r%numerical%ponding_tolerance=1d-12
 r%evaluation%constitutive=>hyd;r%evaluation%source_sink=>source;r%evaluation%root_sink=>root;r%evaluation%dynamic_top_boundary=>top
 do j=0,4
 step=.0078125d0/2d0**j
 call bind_b110_default_mvg_provider(hyd,hp,step)
 call hyd%evaluate(r%base_state%pressure_head,r%base_state%water_content,kk,cc,dd)
 call bind_b110_dynamic_top_boundary_solver_provider(top,p,hp,1,r%base_state%ponding_depth,step,.72d0,0d0,0d0,0d0,.0040205045155610863d0,.0040205045155610863d0,0d0,1d0,1d0,implicit_conductivity=.true.)
 r%step_duration=step
 call solver%solve(r,workspace,v)
 if(v%status/=SW_SOLVE_CONVERGED)error stop 'desaturation did not converge'
 if(abs(v%unrounded_mass_balance_residual)>1d-12)error stop 'direct solver mass criterion'
 if(j==0.and.v%candidate_state%pressure_head(4)>=0d0)error stop 'drying discriminator inactive'
 print *, 'DESAT',j,v%status,v%diagnostics%nonlinear_iterations,v%unrounded_mass_balance_residual
 if(v%status==SW_SOLVE_CONVERGED)print *, 'HEAD',v%candidate_state%pressure_head
 end do
 print *, 'WEATHER_SURFACE_DESATURATION_PASS'
contains
 subroutine configure_parameters(parameters, cofgen)
    type(soil_water_parameter_set_t), target, intent(out) :: parameters
    real(real64), intent(out) :: cofgen(24,numnod)
    integer :: i

    parameters%parameter_set_id = 380038_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    cofgen = 0.0_real64
    do i = 1, numnod
      cofgen(1,i)=0.032_real64; cofgen(2,i)=0.423_real64; cofgen(3,i)=4.75_real64
      cofgen(4,i)=0.0135_real64; cofgen(5,i)=0.365_real64; cofgen(6,i)=1.455_real64
      cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i); cofgen(8,i)=cofgen(4,i)
      cofgen(9,i)=0.0_real64; cofgen(10,i)=cofgen(3,i); cofgen(11,i)=0.999_real64
      cofgen(12,i)=0.99_real64*cofgen(3,i); cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
    end do
 end subroutine configure_parameters
end program
