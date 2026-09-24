program test_ahl12d_local_jacobian_diagnostic
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
  use mod_ahl11_decoupled_provider, only: ahl11_decoupled_provider_t, bind_ahl11_decoupled_provider
  implicit none

  real(real64), parameter :: total_dt=0.01_real64, mass_gate=1.0e-12_real64
  real(real64), parameter :: prescribed_qbot=1.0e-6_real64
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: analytical
  type(ahl11_decoupled_provider_t), target :: lookup
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
  real(real64) :: h0, tr, ts, alpha, nvg, ksat, lambda
  character(len=512) :: ret_path, k_path, label, material, arg
  logical :: valid
  integer :: k

  if (command_argument_count() /= 5) error stop 'usage: test RET_TABLE K_TABLE MATERIAL REGIME H0'
  call get_command_argument(1,ret_path)
  call get_command_argument(2,k_path)
  call get_command_argument(3,material)
  call get_command_argument(4,label)
  call get_command_argument(5,arg); read(arg,*) h0

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

  heads(1)=h0
  do k=2,numnod
    heads(k)=heads(k-1)+parameters%node_distance(k)
  end do
  call analytical%evaluate(heads,water,conductivity,capacity,dkdh)

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
  request%boundary%top_flux=prescribed_qbot
  request%boundary%top_head=heads(1)
  request%boundary%bottom_flux=prescribed_qbot
  request%boundary%bottom_head=777777.0_real64
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

  call bind_ahl11_decoupled_provider(lookup,hp,total_dt,trim(ret_path),trim(k_path),valid)
  call require(valid,'lookup provider bound')
  request%evaluation%constitutive=>lookup
  request%base_state=initial_state
  call solver_candidate%solve(request,workspace_candidate,candidate_result)
  call require(candidate_result%status==SW_SOLVE_CONVERGED,'lookup solve converged')

  call report_and_gate(trim(label),reference_result,candidate_result)

contains

  subroutine report_and_gate(name,ref,cand)
    character(len=*), intent(in) :: name
    type(soil_water_solve_result_t), intent(in) :: ref,cand
    real(real64) :: aw0(numnod),ak0(numnod),ac0(numnod),ad0(numnod)
    real(real64) :: cw0(numnod),ck0(numnod),cc0(numnod),cd0(numnod)
    real(real64) :: awr(numnod),akr(numnod),acr(numnod),adr(numnod)
    real(real64) :: cwr(numnod),ckr(numnod),ccr(numnod),cdr(numnod)
    real(real64) :: dh,dw,mass
    integer :: i

    call analytical%evaluate(initial_state%pressure_head,aw0,ak0,ac0,ad0)
    call lookup%evaluate(initial_state%pressure_head,cw0,ck0,cc0,cd0)
    call analytical%evaluate(ref%candidate_state%pressure_head,awr,akr,acr,adr)
    call lookup%evaluate(ref%candidate_state%pressure_head,cwr,ckr,ccr,cdr)

    dh=maxval(abs(cand%candidate_state%pressure_head-ref%candidate_state%pressure_head))
    dw=maxval(abs(cand%candidate_state%water_content-ref%candidate_state%water_content))
    if (cand%integrated_mass_balance_residual_available) then
      mass=abs(cand%integrated_mass_balance_residual_cm)
    else
      mass=abs(cand%unrounded_mass_balance_residual)
    end if

    write(*,'(A,1X,A,1X,A,ES14.6,1X,A,ES14.6,1X,A,ES14.6,1X,A,I0,1X,A,I0)') &
         'AHL12D_SUMMARY',trim(name),'MAX_DH=',dh,'MAX_DTHETA=',dw,'MASS=',mass, &
         'REF_ITER=',ref%diagnostics%nonlinear_iterations,'CAND_ITER=',cand%diagnostics%nonlinear_iterations
    do i=1,numnod
      write(*,'(A,1X,A,1X,I0,1X,A,ES16.8,1X,A,ES16.8,1X,A,ES16.8,1X,A,ES16.8,1X,A,ES16.8)') &
           'AHL12D_INITIAL',trim(name),i,'H=',initial_state%pressure_head(i), &
           'DTHETA=',cw0(i)-aw0(i),'DLOGC=',log(cc0(i)/ac0(i)), &
           'DMASSW=',(cc0(i)-ac0(i))*parameters%dz(i)/total_dt,'DLOGK=',log(ck0(i)/ak0(i))
      write(*,'(A,1X,A,1X,I0,1X,A,ES16.8,1X,A,ES16.8,1X,A,ES16.8,1X,A,ES16.8,1X,A,ES16.8,1X,A,ES16.8)') &
           'AHL12D_FINALREF',trim(name),i,'HREF=',ref%candidate_state%pressure_head(i), &
           'HCAND=',cand%candidate_state%pressure_head(i),'DHEAD=',cand%candidate_state%pressure_head(i)-ref%candidate_state%pressure_head(i), &
           'DTHETA_AT_REFH=',cwr(i)-awr(i),'DLOGC_AT_REFH=',log(ccr(i)/acr(i)), &
           'DMASSW_AT_REFH=',(ccr(i)-acr(i))*parameters%dz(i)/total_dt
    end do
    write(*,'(A,1X,A,1X,A)') 'AHL12D',trim(name),'MEASURED'
  end subroutine report_and_gate

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition) then
      write(*,'(A,1X,A)') 'AHL12D_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ahl12d_local_jacobian_diagnostic
