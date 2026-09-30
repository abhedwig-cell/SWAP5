program test_fpe_elastic59_mode7_typed_mass
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: MASS_TOL=1.0e-12_real64
  real(real64), parameter :: h_values(2)=[-75.0_real64,-20.0_real64]
  real(real64), parameter :: delta_factors(3)=[-0.01_real64,0.0_real64,0.01_real64]
  real(real64), parameter :: dt_values(2)=[0.01_real64,0.001_real64]
  integer :: ih,iq,idt,count

  count=0
  do ih=1,size(h_values)
    do iq=1,size(delta_factors)
      do idt=1,size(dt_values)
        call run_case(h_values(ih),delta_factors(iq),dt_values(idt))
        count=count+1
      end do
    end do
  end do
  call require(count==12,'complete qualification matrix')
  call run_retry_case()
  write(*,'(A,I0)') 'ELASTIC59_CASE_COUNT=',count
  write(*,'(A)') 'F_PE_ELASTIC59_A1_TYPED_MODE7=PASS'
  write(*,'(A)') 'F_PE_ELASTIC59_A2_RESIDUAL_IDENTITY=PASS'
  write(*,'(A)') 'F_PE_ELASTIC59_A3_INTEGRATED_IDENTITY=PASS'
  write(*,'(A)') 'F_PE_ELASTIC59_A4_PHYSICAL_LEDGER=PASS'
  write(*,'(A)') 'F_PE_ELASTIC59_A5_QBOT_OWNER=PASS'
  write(*,'(A)') 'F_PE_ELASTIC59_A6_RETRY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'F_PE_ELASTIC59_MODE7_TYPED_MASS=PASS'

contains

  subroutine run_case(h0,delta_factor,step_dt)
    real(real64),intent(in)::h0,delta_factor,step_dt
    type(soil_water_parameter_set_t),target::parameters
    type(b110_default_mvg_parameters_t),target::hydraulic_parameters
    type(b110_default_mvg_provider_t),target::constitutive
    type(b110_source_sink_provider_t),target::source_sink
    type(fixed_flux_top_boundary_provider_t),target::top
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::workspace
    type(soil_water_solve_request_t)::request
    type(soil_water_solve_result_t)::result
    real(real64),target::drainage(1,numnod),irrigation(numnod),root_sink(numnod)
    real(real64)::cofgen(24,numnod),heads(numnod),water(numnod),cond(numnod),cap(numnod),dk(numnod)
    real(real64)::candidate_water(numnod),candidate_k(numnod),candidate_cap(numnod),candidate_dk(numnod)
    real(real64)::k0,qeq,delta,storage0,storage1,total_in,total_out,ledger,expected_native
    integer(int64)::bits_a,bits_b

    call configure(parameters,cofgen)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,step_dt)
    heads=h0
    call constitutive%evaluate(heads,water,cond,cap,dk)
    call require(all(ieee_is_finite(water)).and.all(ieee_is_finite(cond)).and.all(cond>0.0_real64),'initial constitutive')

    k0=cond(1);qeq=-k0;delta=delta_factor*k0
    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    call init_request(request,parameters,constitutive,source_sink,top,heads,water,h0,qeq+delta,step_dt)

    storage0=sum(water*parameters%dz)
    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_CONVERGED,'mode7 qualification solve converged')
    call require(result%native_balance_rate_residual_available,'native residual available')
    call require(result%integrated_mass_balance_residual_available,'integrated residual available')

    expected_native=sum(workspace%richards%residual(1:numnod))
    bits_a=transfer(result%native_balance_rate_residual_cm_per_day,bits_a)
    bits_b=transfer(expected_native,bits_b)
    call require(bits_a==bits_b,'native residual exact worker sum')
    bits_a=transfer(result%integrated_mass_balance_residual_cm,bits_a)
    bits_b=transfer(step_dt*expected_native,bits_b)
    call require(bits_a==bits_b,'integrated residual exact dt product')

    storage1=sum(result%candidate_state%water_content*parameters%dz)+result%candidate_state%ponding_depth
    total_in=max(0.0_real64,-result%top_flux)*step_dt + max(0.0_real64,result%bottom_flux)*step_dt
    total_out=max(0.0_real64,result%top_flux)*step_dt + max(0.0_real64,-result%bottom_flux)*step_dt
    ledger=storage1-storage0-(total_in-total_out)
    call require(ieee_is_finite(ledger).and.abs(ledger)<=MASS_TOL,'physical interval ledger')

    call constitutive%evaluate(result%candidate_state%pressure_head,candidate_water,candidate_k,candidate_cap,candidate_dk)
    call require(abs(result%bottom_flux+candidate_k(numnod)) <= &
         64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(result%bottom_flux),abs(candidate_k(numnod))), &
         'free drainage qbot equals minus candidate K')
    call require(result%bottom_flux /= request%boundary%bottom_flux,'caller qbot sentinel not published')

    write(*,'(*(g0))') 'ELASTIC59_ROW|h0=',h0,'|delta_factor=',delta_factor,'|dt=',step_dt, &
         '|native=',result%native_balance_rate_residual_cm_per_day, &
         '|integrated=',result%integrated_mass_balance_residual_cm,'|ledger=',ledger, &
         '|qtop=',result%top_flux,'|qbot=',result%bottom_flux
  end subroutine

  subroutine run_retry_case()
    type(soil_water_parameter_set_t),target::parameters
    type(b110_default_mvg_parameters_t),target::hydraulic_parameters
    type(b110_default_mvg_provider_t),target::constitutive
    type(b110_source_sink_provider_t),target::source_sink
    type(fixed_flux_top_boundary_provider_t),target::top
    type(reference_richards_legacy_solver_t)::solver
    type(reference_richards_legacy_workspace_t)::workspace
    type(soil_water_solve_request_t)::request
    type(soil_water_solve_result_t)::result
    real(real64),target::drainage(1,numnod),irrigation(numnod),root_sink(numnod)
    real(real64)::cofgen(24,numnod),heads(numnod),water(numnod),cond(numnod),cap(numnod),dk(numnod)

    call configure(parameters,cofgen)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,0.1_real64)
    heads=-75.0_real64
    call constitutive%evaluate(heads,water,cond,cap,dk)
    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    call init_request(request,parameters,constitutive,source_sink,top,heads,water,-75.0_real64,1000.0_real64,0.1_real64)
    request%numerical%max_iterations=1
    request%numerical%max_backtracking=1
    call solver%solve(request,workspace,result)
    call require(result%status/=SW_SOLVE_CONVERGED,'retry probe does not converge')
    call require(.not.result%native_balance_rate_residual_available,'retry native unavailable')
    call require(.not.result%integrated_mass_balance_residual_available,'retry integrated unavailable')
  end subroutine

  subroutine configure(parameters,cofgen)
    type(soil_water_parameter_set_t),target,intent(out)::parameters
    real(real64),intent(out)::cofgen(24,numnod)
    integer::i
    parameters%parameter_set_id=590059_int64;parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
    parameters%z=z;parameters%dz=dz;parameters%node_distance=disnod(1:numnod)
    cofgen=0.0_real64
    do i=1,numnod
      cofgen(1,i)=0.032_real64;cofgen(2,i)=0.423_real64;cofgen(3,i)=4.75_real64
      cofgen(4,i)=0.0135_real64;cofgen(5,i)=0.365_real64;cofgen(6,i)=1.455_real64
      cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i);cofgen(8,i)=cofgen(4,i)
      cofgen(9,i)=0.0_real64;cofgen(10,i)=cofgen(3,i);cofgen(11,i)=0.999_real64
      cofgen(12,i)=0.99_real64*cofgen(3,i);cofgen(22,i)=-1.0e6_real64;cofgen(23,i)=1.0e-12_real64
    end do
  end subroutine

  subroutine init_request(req,parameters,constitutive,source_sink,top,heads,water,h0,qtop,step_dt)
    type(soil_water_solve_request_t),intent(out)::req
    type(soil_water_parameter_set_t),target,intent(in)::parameters
    type(b110_default_mvg_provider_t),target,intent(in)::constitutive
    type(b110_source_sink_provider_t),target,intent(in)::source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in)::top
    real(real64),intent(in)::heads(numnod),water(numnod),h0,qtop,step_dt
    req%parameters=>parameters
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=heads;req%base_state%water_content=water
    req%base_state%ponding_depth=0.0_real64;req%base_state%groundwater_level=-2.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;req%boundary%bottom_mode=7
    req%boundary%top_flux=qtop;req%boundary%top_head=h0
    req%boundary%bottom_flux=777.123456789_real64;req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16;req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0;req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-12_real64
    req%numerical%compartment_balance_tolerance=MASS_TOL
    req%numerical%total_balance_tolerance=MASS_TOL
    req%numerical%head_abs_tolerance=MASS_TOL;req%numerical%head_rel_tolerance=MASS_TOL
    req%numerical%ponding_tolerance=MASS_TOL
    req%step_duration=step_dt
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top
  end subroutine

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(A,1X,A)') 'F_PE_ELASTIC59_FAIL',trim(label)
      error stop 1
    end if
  end subroutine

end program test_fpe_elastic59_mode7_typed_mass
