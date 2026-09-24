program test_ahl14a_b01wet
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
  use mod_ahl09_dc_provider, only: ahl09_dc_provider_t, bind_ahl09_dc_provider
  implicit none

  real(real64), parameter :: total_dt=0.25_real64, mass_gate=1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: analytical
  type(ahl09_dc_provider_t), target :: lookup
  type(b110_source_sink_provider_t), target :: source_sink
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(soil_water_physical_state_t) :: initial_state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: reference_result, candidate_result
  type(reference_richards_legacy_solver_t) :: solver_ref, solver_candidate
  type(reference_richards_legacy_workspace_t) :: workspace_ref, workspace_candidate
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64) :: k0, h0, hbot, tr, ts, alpha, nvg, ksat, lambda
  character(len=512) :: table_path, label, material, arg
  logical :: valid
  integer :: k

  if (command_argument_count() /= 5) error stop 'usage: test TABLE_PATH MATERIAL REGIME H0 HBOT'
  call get_command_argument(1,table_path)
  call get_command_argument(2,material)
  call get_command_argument(3,label)
  call get_command_argument(4,arg); read(arg,*) h0
  call get_command_argument(5,arg); read(arg,*) hbot

  select case(trim(material))
  case('B01')
    tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64; nvg=1.734737_real64
    ksat=31.225016_real64; lambda=0.98087_real64
  case('B12')
    tr=0.01_real64; ts=0.529749_real64; alpha=0.016562_real64; nvg=1.090671_real64
    ksat=2.245895_real64; lambda=-4.493581_real64
  case('O05')
    tr=0.01_real64; ts=0.336701_real64; alpha=0.030304_real64; nvg=2.887502_real64
    ksat=17.418504_real64; lambda=0.0736_real64
  case('O14')
    tr=0.01_real64; ts=0.393878_real64; alpha=0.003288_real64; nvg=1.616573_real64
    ksat=2.495984_real64; lambda=0.514012_real64
  case default
    error stop 'unknown material'
  end select

  parameters%parameter_set_id=404001_int64
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)

  allocate(cofgen(24,numnod)); cofgen=0.0_real64
  do k=1,numnod
    cofgen(1,k)=tr; cofgen(2,k)=ts; cofgen(3,k)=ksat
    cofgen(4,k)=alpha; cofgen(5,k)=lambda; cofgen(6,k)=nvg
    cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k); cofgen(8,k)=cofgen(4,k)
    cofgen(9,k)=0.0_real64; cofgen(10,k)=cofgen(3,k); cofgen(11,k)=0.999_real64
    cofgen(12,k)=0.99_real64*cofgen(3,k); cofgen(22,k)=-1.0e6_real64; cofgen(23,k)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytical,hp,total_dt)

  heads=h0
  call analytical%evaluate(heads,water,conductivity,capacity,dkdh)
  k0=conductivity(1)

  initial_state%active_nodes=numnod
  allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
  initial_state%pressure_head=heads; initial_state%water_content=water
  initial_state%ponding_depth=0.0_real64; initial_state%groundwater_level=-2.0_real64

  allocate(drainage(1,numnod),subsurface(numnod),root_sink(numnod))
  drainage=0.0_real64; subsurface=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)

  request=soil_water_solve_request_t()
  request%parameters=>parameters
  request%base_state=initial_state
  request%step_duration=total_dt
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=5
  request%boundary%top_flux=-k0
  request%boundary%top_head=h0
  request%boundary%bottom_flux=0.0_real64
  request%boundary%bottom_head=hbot
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=8
  request%numerical%max_backtracking=4
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-6_real64
  request%numerical%compartment_balance_tolerance=mass_gate
  request%numerical%total_balance_tolerance=mass_gate
  request%numerical%head_abs_tolerance=1.0e-12_real64
  request%numerical%head_rel_tolerance=1.0e-12_real64
  request%numerical%ponding_tolerance=1.0e-12_real64
  request%evaluation%source_sink=>source_sink
  request%evaluation%top_boundary=>top_provider

  request%evaluation%constitutive=>analytical
  call solver_ref%solve(request,workspace_ref,reference_result)
  call require(reference_result%status==SW_SOLVE_CONVERGED,'analytical solve converged')

  call bind_ahl09_dc_provider(lookup,hp,total_dt,trim(table_path),valid)
  call require(valid,'lookup provider bound')
  request%evaluation%constitutive=>lookup
  request%base_state=initial_state
  call solver_candidate%solve(request,workspace_candidate,candidate_result)
  call require(candidate_result%status==SW_SOLVE_CONVERGED,'lookup solve converged')

  write(*,'(A,1X,ES18.10,1X,ES18.10,1X,ES18.10,1X,ES18.10)') &
       'AHL14A_HEAD_ENVELOPE', minval(reference_result%candidate_state%pressure_head), &
       maxval(reference_result%candidate_state%pressure_head), &
       minval(candidate_result%candidate_state%pressure_head), &
       maxval(candidate_result%candidate_state%pressure_head)
  do k=1,numnod
    write(*,'(A,1X,I0,1X,ES18.10,1X,ES18.10)') 'AHL14A_NODE',k, &
         reference_result%candidate_state%pressure_head(k), candidate_result%candidate_state%pressure_head(k)
  end do
  call report_and_gate(trim(label),reference_result,candidate_result)

contains

  subroutine report_and_gate(name,ref,cand)
    character(len=*), intent(in) :: name
    type(soil_water_solve_result_t), intent(in) :: ref,cand
    real(real64) :: dh,dw,dtf,dbf,mass
    integer :: diter, dbt
    dh=maxval(abs(cand%candidate_state%pressure_head-ref%candidate_state%pressure_head))
    dw=maxval(abs(cand%candidate_state%water_content-ref%candidate_state%water_content))
    dtf=abs(cand%top_flux-ref%top_flux)
    dbf=abs(cand%bottom_flux-ref%bottom_flux)
    diter=abs(cand%diagnostics%nonlinear_iterations-ref%diagnostics%nonlinear_iterations)
    dbt=abs(cand%diagnostics%backtracking_attempts-ref%diagnostics%backtracking_attempts)
    if (cand%integrated_mass_balance_residual_available) then
      mass=abs(cand%integrated_mass_balance_residual_cm)
    else
      mass=abs(cand%unrounded_mass_balance_residual)
    end if

    ! Measurement only. The preregistered F-AHL04A contract is applied after
    ! all three candidates have executed, so an early baseline failure cannot
    ! hide later candidate evidence and gate values cannot drift in this test.
    write(*,'(A,1X,A,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,I0,1X,A,I0)') &
         'AHL10_METRIC',trim(material)//':'//trim(name),'MAX_DH_CM=',dh,'MAX_DTHETA=',dw,'DTOP=',dtf,'DBOTTOM=',dbf,'MASS=',mass, &
         'ITER_DELTA=',diter,'BACKTRACK_DELTA=',dbt
    write(*,'(A,1X,A,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0)') &
         'AHL10_DIAG',trim(material)//':'//trim(name),'REF_ITER=',ref%diagnostics%nonlinear_iterations, &
         'CAND_ITER=',cand%diagnostics%nonlinear_iterations,'REF_BACKTRACK=',ref%diagnostics%backtracking_attempts, &
         'CAND_BACKTRACK=',cand%diagnostics%backtracking_attempts
    call require(dh<=0.05_real64,'pressure-head gate')
    call require(dw<=1.0e-4_real64,'water-content gate')
    call require(dtf<=1.0e-5_real64,'top-flux gate')
    call require(dbf<=1.0e-5_real64,'bottom-flux gate')
    call require(mass<=mass_gate,'mass gate')
    call require(cand%diagnostics%nonlinear_iterations==ref%diagnostics%nonlinear_iterations,'same nonlinear iterations')
    call require(cand%diagnostics%backtracking_attempts==ref%diagnostics%backtracking_attempts,'same backtracking count')
    write(*,'(A,1X,A,1X,A)') 'AHL10',trim(material)//':'//trim(name),'PASS'
  end subroutine report_and_gate

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition) then
      write(*,'(A,1X,A)') 'AHL10_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ahl14a_b01wet
