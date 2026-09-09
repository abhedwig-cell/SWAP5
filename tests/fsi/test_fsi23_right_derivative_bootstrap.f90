program test_fsi23_right_derivative_bootstrap
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
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
  implicit none

  integer, parameter :: nstates=3, nstim=2, ndt=5
  real(real64), parameter :: states(nstates)=[-25.0_real64,-75.0_real64,-250.0_real64]
  real(real64), parameter :: bottom_jumps(nstim)=[-0.05_real64,0.05_real64]
  real(real64), parameter :: top_fracs(nstim)=[-0.05_real64,0.05_real64]
  real(real64), parameter :: dts(ndt)=[1.0e-3_real64,5.0e-4_real64,2.5e-4_real64, &
       1.25e-4_real64,6.25e-5_real64]
  integer :: is, ip, case_id

  case_id=0
  do is=1,nstates
    do ip=1,nstim
      case_id=case_id+1
      call run_case(case_id,'BOTTOM',states(is),bottom_jumps(ip))
    end do
  end do
  do is=1,nstates
    do ip=1,nstim
      case_id=case_id+1
      call run_case(case_id,'TOP',states(is),top_fracs(ip))
    end do
  end do
  call require(case_id==12,'frozen case count')
  write(*,'(A)') 'FSI23_RIGHT_DERIVATIVE_BOOTSTRAP PASS'

contains

  subroutine run_case(cid,kind,h0,stimulus)
    integer, intent(in) :: cid
    character(len=*), intent(in) :: kind
    real(real64), intent(in) :: h0, stimulus
    type(soil_water_parameter_set_t), target :: parameters
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t), target :: constitutive
    type(b110_source_sink_provider_t), target :: source_sink
    type(fmr04_fixed_flux_top_provider_t), target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_physical_state_t) :: initial_state
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
    real(real64), allocatable :: cofgen(:,:)
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: static_residual(numnod), hdot_boot(numnod), slope(numnod), errors(ndt)
    real(real64) :: qtop, hbot, k0, storage0, storage1, total_in, total_out, mass_residual
    real(real64) :: smallest_slope, smallest_boot
    integer :: k, idt, inode

    call configure_problem(h0,parameters,hydraulic_parameters,constitutive,source_sink,top_provider, &
         initial_state,drainage,subsurface,root_sink,cofgen,k0)
    heads=h0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    do k=1,numnod
      call require(ieee_is_finite(capacity(k)) .and. capacity(k)>0.0_real64,'positive finite capacity')
      call require(ieee_is_finite(conductivity(k)) .and. conductivity(k)>0.0_real64,'positive finite conductivity')
      call require(abs(conductivity(k)-k0)<=16.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(k0)), &
           'uniform conductivity')
    end do

    qtop=-k0
    hbot=h0
    static_residual=0.0_real64
    select case(trim(kind))
    case('BOTTOM')
      hbot=h0+stimulus
      inode=numnod
      static_residual(numnod)=k0*(h0-hbot)/(0.5_real64*parameters%dz(numnod))
    case('TOP')
      qtop=-k0*(1.0_real64+stimulus)
      inode=1
      static_residual(1)=k0+qtop
    case default
      error stop 'unknown F-SI23 stimulus kind'
    end select
    hdot_boot=-static_residual/(capacity*dz(1:numnod))
    call require(ieee_is_finite(hdot_boot(inode)) .and. abs(hdot_boot(inode))>0.0_real64, &
         'nonzero finite stimulated derivative')

    storage0=sum(initial_state%water_content*parameters%dz)
    do idt=1,ndt
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dts(idt))
      request=soil_water_solve_request_t()
      request%parameters=>parameters
      request%base_state=initial_state
      request%step_duration=dts(idt)
      request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
      request%boundary%bottom_mode=5
      request%boundary%top_flux=qtop
      request%boundary%top_head=h0
      request%boundary%bottom_flux=12345.678_real64
      request%boundary%bottom_head=hbot
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
      call require(result%status==SW_SOLVE_CONVERGED,'direct backward-Euler bootstrap reference converged')
      slope=(result%candidate_state%pressure_head-h0)/dts(idt)
      errors(idt)=maxval(abs(slope-hdot_boot))
      call require(ieee_is_finite(errors(idt)),'finite slope error')
      storage1=sum(result%candidate_state%water_content*parameters%dz)+result%candidate_state%ponding_depth
      total_in=max(0.0_real64,-result%top_flux)*dts(idt)+max(0.0_real64,result%bottom_flux)*dts(idt)
      total_out=max(0.0_real64,result%top_flux)*dts(idt)+max(0.0_real64,-result%bottom_flux)*dts(idt)
      mass_residual=storage1-storage0-(total_in-total_out)
      call require(abs(mass_residual)<=1.0e-12_real64,'hard external mass gate')
      write(*,'(A,I0,A,A,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3)') &
           'FSI23_BOOTSTRAP_POINT:CASE=',cid,':KIND=',trim(kind),':H0=',h0,':STIM=',stimulus, &
           ':DT=',dts(idt),':BOOT=',hdot_boot(inode),':SLOPE=',slope(inode),':ERR=',errors(idt),':MASS=',mass_residual
      if (idt==ndt) then
        smallest_slope=slope(inode)
        smallest_boot=hdot_boot(inode)
      end if
    end do

    do idt=1,ndt-1
      call require(errors(idt+1)<errors(idt),'strict derivative convergence over frozen dt sequence')
    end do
    call require(errors(ndt)<errors(1),'smallest-dt derivative error improves over largest dt')
    call require(smallest_slope*smallest_boot>0.0_real64,'stimulated derivative sign agreement')
    write(*,'(A,I0,A,A,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3,A,ES24.15E3)') &
         'FSI23_BOOTSTRAP_CASE:CASE=',cid,':KIND=',trim(kind),':H0=',h0,':STIM=',stimulus, &
         ':ERR_LARGE_DT=',errors(1),':ERR_SMALL_DT=',errors(ndt)
  end subroutine run_case

  subroutine configure_problem(h0,p,hp,cp,sp,tp,state,qdra,qssdi,qrot,c,k0)
    real(real64), intent(in) :: h0
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(out) :: tp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id=230023_int64
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
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,dts(1))
    heads=h0
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
    if (.not.same_type_as(tp,tp)) error stop 'unreachable top provider type'
  end subroutine configure_problem

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'FSI23_BOOTSTRAP_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fsi23_right_derivative_bootstrap
