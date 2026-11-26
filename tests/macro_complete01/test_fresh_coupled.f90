module macro_complete_test_provider
 use iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:macropore_exchange_provider_t
 implicit none
 type,extends(macropore_exchange_provider_t)::exchange_t
  real(real64)::strength=.1d0,loading=.5d0
 contains
  procedure::evaluate_rate=>rate
  procedure::evaluate_derivative=>derivative
 end type
contains
 subroutine rate(self,pressure_head,water_content,exchange_flux,active,surface_area_fraction)
  class(exchange_t),intent(in)::self
  real(real64),intent(in)::pressure_head(:),water_content(:)
  real(real64),intent(out)::exchange_flux(:)
  logical,intent(out)::active
  real(real64),optional,intent(out)::surface_area_fraction
  exchange_flux=self%loading-self%strength*(pressure_head+100d0)
  active=.true.
  if(present(surface_area_fraction))surface_area_fraction=0d0
 end subroutine
 subroutine derivative(self,pressure_head,water_content,capacity,dexchange_dhead,derivative_available,active)
  class(exchange_t),intent(in)::self
  real(real64),intent(in)::pressure_head(:),water_content(:),capacity(:)
  real(real64),intent(out)::dexchange_dhead(:)
  logical,intent(out)::derivative_available,active
  dexchange_dhead=-self%strength;derivative_available=.true.;active=.true.
 end subroutine
end module
program test_macro_complete_fresh
 use iso_fortran_env,only:real64,int64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_soil_water_solver_contract
 use mod_b110_default_mvg_provider
 use mod_b110_source_sink_provider
 use mod_b110_root_sink_provider
 use mod_fixed_flux_top_boundary_provider
 use mod_reference_richards_state_binding,only:FSI_TOP_MODE_EXPLICIT_FLUX
 use mod_reference_richards_legacy_binding
 use macro_complete_test_provider
 implicit none
 type(soil_water_parameter_set_t),target::p
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(b110_source_sink_provider_t),target::source
 type(b110_root_sink_provider_t),target::root
 type(fixed_flux_top_boundary_provider_t),target::top
 type(exchange_t),target::macro
 type(reference_richards_legacy_solver_t)::solver
 type(reference_richards_legacy_workspace_t)::workspace
 type(soil_water_solve_request_t)::r
 type(soil_water_solve_result_t)::v
 real(real64)::cof(24,4),kk(4),cc(4),dd(4),step,flux(5),eq(4),exc(4),h0(4),theta0(4)
 real(real64),target::drain(1,4),irrigation(4),qroot(4)
 logical::active
 integer::i
 call configure_parameters(p,cof)
 call initialize_b110_default_mvg_parameters(hp,cof)
 drain=0d0;irrigation=0d0;qroot=0d0
 call bind_b110_source_sink_provider(source,drain,irrigation,irrigation)
 call bind_b110_root_sink_provider(root,qroot)
 r%parameters=>p;r%base_state%active_nodes=4
 allocate(r%base_state%pressure_head(4),r%base_state%water_content(4))
 r%base_state%pressure_head=-100d0;r%base_state%groundwater_level=-1000d0
 r%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;r%boundary%bottom_mode=7
 r%physical%macropore_active=.true.;r%physical%matrix_area_fraction=[1d0,1d0,1d0,1d0]
 r%numerical%max_iterations=30;r%numerical%max_backtracking=8
 r%numerical%conductivity_mean_method=1;r%numerical%min_step_duration=1d-8
 r%numerical%compartment_balance_tolerance=1d-10;r%numerical%total_balance_tolerance=1d-10
 r%numerical%head_abs_tolerance=1d-12;r%numerical%head_rel_tolerance=1d-12;r%numerical%ponding_tolerance=1d-12
 r%evaluation%constitutive=>hyd;r%evaluation%source_sink=>source;r%evaluation%root_sink=>root;r%evaluation%top_boundary=>top
 r%evaluation%macropore=>macro
 step=.002d0;r%step_duration=step
 call bind_b110_default_mvg_provider(hyd,hp,step)
 call hyd%evaluate(r%base_state%pressure_head,r%base_state%water_content,kk,cc,dd)
 r%boundary%top_flux=-kk(1);h0=r%base_state%pressure_head;theta0=r%base_state%water_content
 call solver%solve(r,workspace,v)
 if(any(r%base_state%pressure_head/=h0).or.any(r%base_state%water_content/=theta0))error stop 'accepted origin mutated'
 if(v%status==SW_SOLVE_CONVERGED)then
  call macro%evaluate_rate(v%candidate_state%pressure_head,v%candidate_state%water_content,exc,active)
  flux(1)=v%top_flux;flux(5)=v%bottom_flux
  do i=2,4
   flux(i)=-.5d0*(kk(i-1)+kk(i))*((v%candidate_state%pressure_head(i-1)-v%candidate_state%pressure_head(i))/p%node_distance(i)+1d0)
  end do
  eq=(v%candidate_state%water_content-theta0)*p%dz/step+flux(1:4)-flux(2:5)-exc
  write(*,'(a,2i5,3es25.16)')'FRESH',v%status,v%diagnostics%nonlinear_iterations,maxval(abs(eq)),sum(eq),v%unrounded_mass_balance_residual
  if(maxval(abs(eq))>r%numerical%compartment_balance_tolerance.or.abs(sum(eq))>r%numerical%total_balance_tolerance)error stop 'accepted stale coupled residual'
 else
  write(*,*)'REJECTED',v%status
  if(.not.v%retry_advised)error stop 'failed solve missing refusal'
 end if
 print *, 'MACRO_COMPLETE_FRESH_CONTRACT_PASS'
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
