program test_ahl41a_fsi38_prescribed_qbot
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
  use mod_b110_adaptive_hydraulic_provider, only: b110_adaptive_hydraulic_provider_t, &
       bind_b110_adaptive_hydraulic_provider
  implicit none

  real(real64), parameter :: total_dt=0.01_real64, mass_gate=1.0e-12_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: analytical
  type(b110_adaptive_hydraulic_provider_t), target :: lookup
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
  real(real64) :: k0, h0, qbot, tr, ts, alpha, npar, ksat, lambda, bottom_node_delta
  character(len=512) :: label, material, arg
  logical :: valid, cache_hit
  integer :: k

  if (command_argument_count() /= 4) error stop 'usage: test MATERIAL H0 QBOT LABEL'
  call get_command_argument(1,material)
  call get_command_argument(2,arg); read(arg,*) h0
  call get_command_argument(3,arg); read(arg,*) qbot
  call get_command_argument(4,label)
  call material_parameters(trim(material),tr,ts,alpha,npar,ksat,lambda)

  parameters%parameter_set_id=404001_int64
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)

  allocate(cofgen(24,numnod)); cofgen=0.0_real64
  do k=1,numnod
    cofgen(1,k)=tr; cofgen(2,k)=ts; cofgen(3,k)=ksat
    cofgen(4,k)=alpha; cofgen(5,k)=lambda; cofgen(6,k)=npar
    cofgen(7,k)=1.0_real64-1.0_real64/npar; cofgen(8,k)=alpha
    cofgen(9,k)=0.0_real64; cofgen(10,k)=ksat; cofgen(11,k)=0.999_real64
    cofgen(12,k)=0.99_real64*ksat; cofgen(22,k)=-1.0e6_real64; cofgen(23,k)=1.0e-12_real64
  end do
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(analytical,hp,total_dt)

  heads(1)=h0
  do k=2,numnod
    heads(k)=heads(k-1)+parameters%node_distance(k)
  end do
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
  request%boundary%bottom_mode=2
  request%boundary%top_flux=qbot
  request%boundary%top_head=h0
  request%boundary%bottom_flux=qbot
  request%boundary%bottom_head=0.0_real64
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=16
  request%numerical%max_backtracking=8
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-12_real64
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

  call bind_b110_adaptive_hydraulic_provider(lookup,hp,total_dt,valid,cache_hit)
  call require(valid,'adaptive provider bound')
  request%evaluation%constitutive=>lookup
  request%base_state=initial_state
  call solver_candidate%solve(request,workspace_candidate,candidate_result)
  call require(candidate_result%status==SW_SOLVE_CONVERGED,'lookup solve converged')

  call report_and_gate(trim(material)//':'//trim(label),reference_result,candidate_result)

contains

  subroutine material_parameters(id,tr,ts,alpha,npar,ksat,lambda)
    character(len=*),intent(in)::id
    real(real64),intent(out)::tr,ts,alpha,npar,ksat,lambda
    select case(id)
    case('B01')
      tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64;npar=1.734737_real64;ksat=31.225016_real64;lambda=0.98087_real64
    case('B12')
      tr=0.01_real64;ts=0.529749_real64;alpha=0.016562_real64;npar=1.090671_real64;ksat=2.245895_real64;lambda=-4.493581_real64
    case('O05')
      tr=0.01_real64;ts=0.336701_real64;alpha=0.030304_real64;npar=2.887502_real64;ksat=17.418504_real64;lambda=0.0736_real64
    case('O14')
      tr=0.01_real64;ts=0.393878_real64;alpha=0.003288_real64;npar=1.616573_real64;ksat=2.495984_real64;lambda=0.514012_real64
    case default
      error stop 'unknown F-AHL10 material'
    end select
  end subroutine material_parameters

  subroutine report_and_gate(name,ref,cand)
    character(len=*), intent(in) :: name
    type(soil_water_solve_result_t), intent(in) :: ref,cand
    real(real64) :: dh,dw,dbf,mass,href,hcand
    integer :: diter,dbt,n
    dh=maxval(abs(cand%candidate_state%pressure_head-ref%candidate_state%pressure_head))
    dw=maxval(abs(cand%candidate_state%water_content-ref%candidate_state%water_content))
    dbf=abs(cand%bottom_flux-ref%bottom_flux)
    diter=abs(cand%diagnostics%nonlinear_iterations-ref%diagnostics%nonlinear_iterations)
    dbt=abs(cand%diagnostics%backtracking_attempts-ref%diagnostics%backtracking_attempts)
    n=size(ref%candidate_state%pressure_head)
    href=ref%candidate_state%pressure_head(n)
    hcand=cand%candidate_state%pressure_head(n)
    bottom_node_delta=abs(hcand-href)
    if (cand%integrated_mass_balance_residual_available) then
      mass=abs(cand%integrated_mass_balance_residual_cm)
    else
      mass=abs(cand%unrounded_mass_balance_residual)
    end if

    write(*,'(A,1X,A,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6)') &
         'AHL41A_METRIC',trim(name),'K0=',k0,'QBOT=',qbot,'MAX_DH=',dh,'BOTTOM_DH=',bottom_node_delta, &
         'MAX_DTHETA=',dw,'DBOTTOM_FLUX=',dbf
    write(*,'(A,1X,A,1X,A,ES18.10,1X,A,ES18.10,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,I0,1X,A,ES14.6)') &
         'AHL41A_DIAG',trim(name),'HREF_BOTTOM=',href,'HCAND_BOTTOM=',hcand, &
         'REF_ITER=',ref%diagnostics%nonlinear_iterations,'CAND_ITER=',cand%diagnostics%nonlinear_iterations, &
         'REF_BACKTRACK=',ref%diagnostics%backtracking_attempts,'CAND_BACKTRACK=',cand%diagnostics%backtracking_attempts, &
         'MASS=',mass

    call require(dh<=0.05_real64,'profile head gate')
    call require(bottom_node_delta<=0.02_real64,'bottom node head gate')
    call require(dw<=1.0e-4_real64,'water content gate')
    call require(dbf<=1.0e-10_real64,'bottom flux identity gate')
    call require(mass<=mass_gate,'mass gate')
    call require(cand%diagnostics%nonlinear_iterations==ref%diagnostics%nonlinear_iterations,'iteration identity')
    call require(cand%diagnostics%backtracking_attempts==ref%diagnostics%backtracking_attempts,'backtracking identity')
    write(*,'(A,1X,A,1X,A)') 'AHL41A',trim(name),'PASS'
  end subroutine report_and_gate

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition) then
      write(*,'(A,1X,A)') 'AHL41A_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ahl41a_fsi38_prescribed_qbot
