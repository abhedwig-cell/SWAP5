program test_fpe_nlglob14z43a_reference_solvability
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_fpe_timeint03_reference_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: nstep=4000
  integer :: timeint02_mode
  real(8) :: timeint02_thetam2(1000)
  common /timeint02_history_common/ timeint02_mode, timeint02_thetam2

  type(soil_water_parameter_set_t), target :: pfull
  type(b110_default_mvg_parameters_t), target :: hpfull
  type(b110_default_mvg_provider_t), target :: constitutive_full
  type(b110_source_sink_provider_t), target :: source_full
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state
  type(soil_water_solve_request_t) :: req
  type(soil_water_solve_result_t) :: res
  real(real64), allocatable, target :: qdra(:,:), qssdi(:), qrot(:)
  real(real64), allocatable :: cof(:,:), theta_tmp(:), k_tmp(:), cap_tmp(:), dk_tmp(:)
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt,ledger,maxledger
  integer :: initial_tail,step,last_accepted,tail_start
  character(len=32) :: case_id

  call get_command_argument(1,case_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_int(8,initial_tail)
  dt=0.00125_real64
  call require((numnod==64 .and. initial_tail==49) .or. (numnod==32 .and. initial_tail==25), &
       'frozen geometry mismatch')

  call setup()
  call initialize_state()
  call build_request()

  last_accepted=0
  maxledger=0.0_real64
  do step=1,nstep
     req%base_state=state
     call set_history(state)
     call solver%solve(req,ws,res)
     if(res%status/=SW_SOLVE_CONVERGED)then
        write(*,'(*(g0))') 'F_PE_NLGLOB14Z43A_CASE|CASE=',trim(case_id),'|COMPLETE=0|FAIL_STEP=',step, &
             '|LAST_ACCEPTED=',last_accepted,'|STATUS=',res%status,'|RETRY=',merge(1,0,res%retry_advised), &
             '|NL=',res%diagnostics%nonlinear_iterations,'|JAC=',res%diagnostics%jacobian_builds, &
             '|LINEAR=',res%diagnostics%linear_solves,'|BACKTRACK=',res%diagnostics%backtracking_attempts, &
             '|INTERNAL_RETRIES=',res%diagnostics%internal_retries,'|ROUTE=',trim(res%diagnostics%route), &
             '|MAX_LEDGER=',maxledger,'|TAIL=',tail_identity(state)
        write(*,'(a)') 'F_PE_NLGLOB14Z43A=PASS'
        stop
     end if
     if(.not.all(ieee_is_finite(res%candidate_state%pressure_head)) .or. &
        .not.all(ieee_is_finite(res%candidate_state%water_content)))then
        write(*,'(*(g0))') 'F_PE_NLGLOB14Z43A_CASE|CASE=',trim(case_id),'|COMPLETE=0|FAIL_STEP=',step, &
             '|LAST_ACCEPTED=',last_accepted,'|STATUS=-1|RETRY=0|NL=',res%diagnostics%nonlinear_iterations, &
             '|JAC=',res%diagnostics%jacobian_builds,'|LINEAR=',res%diagnostics%linear_solves, &
             '|BACKTRACK=',res%diagnostics%backtracking_attempts,'|INTERNAL_RETRIES=',res%diagnostics%internal_retries, &
             '|ROUTE=nonfinite|MAX_LEDGER=',maxledger,'|TAIL=',tail_identity(state)
        write(*,'(a)') 'F_PE_NLGLOB14Z43A=PASS'
        stop
     end if
     ledger=sum((res%candidate_state%water_content-state%water_content)*pfull%dz) + &
          dt*(res%top_flux-res%bottom_flux)
     maxledger=max(maxledger,abs(ledger))
     state=res%candidate_state
     last_accepted=step
  end do

  tail_start=tail_identity(state)
  write(*,'(*(g0))') 'F_PE_NLGLOB14Z43A_CASE|CASE=',trim(case_id),'|COMPLETE=1|FAIL_STEP=0', &
       '|LAST_ACCEPTED=',last_accepted,'|STATUS=',res%status,'|RETRY=',merge(1,0,res%retry_advised), &
       '|NL=',res%diagnostics%nonlinear_iterations,'|JAC=',res%diagnostics%jacobian_builds, &
       '|LINEAR=',res%diagnostics%linear_solves,'|BACKTRACK=',res%diagnostics%backtracking_attempts, &
       '|INTERNAL_RETRIES=',res%diagnostics%internal_retries,'|ROUTE=',trim(res%diagnostics%route), &
       '|MAX_LEDGER=',maxledger,'|TAIL=',tail_start
  write(*,'(a)') 'F_PE_NLGLOB14Z43A=PASS'

contains
  subroutine read_real(iarg,x)
    integer,intent(in)::iarg
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(iarg,s); read(s,*)x
  end subroutine
  subroutine read_int(iarg,x)
    integer,intent(in)::iarg
    integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(iarg,s); read(s,*)x
  end subroutine
  subroutine fill_cof()
    integer::j
    real(real64)::mm
    allocate(cof(24,numnod)); cof=0.0_real64
    mm=1.0_real64-1.0_real64/nvg
    do j=1,numnod
       cof(1,j)=tr; cof(2,j)=ts; cof(3,j)=ksat; cof(4,j)=alpha; cof(5,j)=lambda
       cof(6,j)=nvg; cof(7,j)=mm; cof(8,j)=alpha; cof(9,j)=0.0_real64
       cof(10,j)=ksat; cof(11,j)=0.999_real64; cof(12,j)=0.99_real64*ksat
       cof(22,j)=-1.0e6_real64; cof(23,j)=1.0e-12_real64
    end do
  end subroutine
  subroutine setup()
    pfull%parameter_set_id=4301_int64; pfull%active_nodes=numnod
    allocate(pfull%z(numnod),pfull%dz(numnod),pfull%node_distance(numnod))
    pfull%z=z; pfull%dz=dz; pfull%node_distance=disnod(1:numnod)
    call fill_cof()
    call initialize_b110_default_mvg_parameters(hpfull,cof)
    call bind_b110_default_mvg_provider(constitutive_full,hpfull,dt)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(source_full,qdra,qssdi,qrot)
  end subroutine
  subroutine initialize_state()
    real(real64)::heads(numnod)
    integer::j
    allocate(theta_tmp(numnod),k_tmp(numnod),cap_tmp(numnod),dk_tmp(numnod))
    do j=1,numnod
       heads(j)=10.0_real64*real(j-initial_tail,real64)
    end do
    call constitutive_full%evaluate(heads,theta_tmp,k_tmp,cap_tmp,dk_tmp)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=theta_tmp
    state%ponding_depth=0.0_real64
    state%groundwater_level=-10.0_real64*real(initial_tail-1,real64)
  end subroutine
  subroutine build_request()
    req%parameters=>pfull; req%base_state=state
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux=-0.01_real64
    req%boundary%bottom_mode=2; req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=8; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    req%numerical%compartment_balance_tolerance=1.0e-12_real64
    req%numerical%total_balance_tolerance=1.0e-12_real64
    req%numerical%head_abs_tolerance=1.0e-9_real64
    req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive_full
    req%evaluation%source_sink=>source_full
    req%evaluation%top_boundary=>top
  end subroutine
  subroutine set_history(s)
    type(soil_water_physical_state_t),intent(in)::s
    timeint02_mode=1; timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:numnod)=s%water_content
  end subroutine
  integer function tail_identity(s) result(first)
    type(soil_water_physical_state_t),intent(in)::s
    logical::sat(numnod)
    integer::j
    sat=.false.
    do j=1,numnod
       sat(j)=s%pressure_head(j)>=0.0_real64 .and. abs(s%water_content(j)-ts)<=1e-10_real64
    end do
    first=numnod+1
    do j=numnod,1,-1
       if(sat(j))then; first=j; else; exit; end if
    end do
    if(first<=numnod .and. first>1)then
       if(any(sat(1:first-1))) first=-1
    end if
  end function
  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
       write(*,'(A,1X,A)') 'F_PE_NLGLOB14Z43A_FAIL',trim(msg)
       error stop 1
    end if
  end subroutine
end program test_fpe_nlglob14z43a_reference_solvability
