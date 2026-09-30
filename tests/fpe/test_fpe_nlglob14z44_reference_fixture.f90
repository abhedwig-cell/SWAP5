program test_fpe_nlglob14z44_reference_fixture
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
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ws
  type(soil_water_physical_state_t) :: state
  type(soil_water_solve_request_t) :: req
  type(soil_water_solve_result_t) :: res

  real(real64), allocatable, target :: qdra(:,:), qssdi(:), qrot(:)
  real(real64), allocatable :: cof(:,:), theta_tmp(:), k_tmp(:), cap_tmp(:), dk_tmp(:)
  real(real64) :: tr,ts,alpha,nvg,ksat,lambda,dt,ledger,maxledger,origin_leak
  integer :: tail_start,i,k,old_tail,new_tail,accepted
  character(len=64) :: material_id,reason
  logical :: valid

  call get_command_argument(1,material_id)
  call read_real(2,tr); call read_real(3,ts); call read_real(4,alpha); call read_real(5,nvg)
  call read_real(6,ksat); call read_real(7,lambda); call read_int(8,tail_start); call read_real(9,dt)

  if(numnod/=64) then
     write(*,'(a)') 'F_PE_NLGLOB14Z44_CASE|VALID=0|REASON=GEOMETRY_NOT_64'
     stop
  end if

  call setup()
  call initialize_state()
  call build_request()

  valid=.true.
  reason='complete'
  accepted=0
  maxledger=0.0_real64
  origin_leak=0.0_real64

  do i=1,nstep
     old_tail=tail_identity(state)
     if(old_tail<1) then
        valid=.false.; reason='NONCONTIGUOUS_ORIGIN_TAIL'; exit
     end if

     call copy_state_to_request()
     origin_leak=max(origin_leak,request_origin_leak())
     call set_history()
     call solver%solve(req,ws,res)
     if(res%status/=SW_SOLVE_CONVERGED) then
        valid=.false.; reason='FULL_SOLVE_FAILED'; exit
     end if
     if(.not.all(ieee_is_finite(res%candidate_state%pressure_head)) .or. &
        .not.all(ieee_is_finite(res%candidate_state%water_content))) then
        valid=.false.; reason='NONFINITE_STATE'; exit
     end if

     ledger=step_ledger(res)
     maxledger=max(maxledger,abs(ledger))
     if(abs(ledger)>5e-8_real64) then
        valid=.false.; reason='LEDGER_GATE'; exit
     end if

     new_tail=tail_identity(res%candidate_state)
     if(new_tail<1) then
        valid=.false.; reason='NONCONTIGUOUS_CANDIDATE_TAIL'; exit
     end if
     if(abs(new_tail-old_tail)>1) then
        valid=.false.; reason='OWNERSHIP_JUMP'; exit
     end if

     call accept_state(res%candidate_state)
     accepted=accepted+1
  end do

  if(origin_leak>1e-15_real64) then
     valid=.false.; reason='ORIGIN_MUTATION'
  end if

  write(*,'(*(g0))') 'F_PE_NLGLOB14Z44_CASE|MATERIAL=',trim(material_id), &
       '|TAIL_START=',tail_start,'|DT=',dt,'|VALID=',merge(1,0,valid), &
       '|ACCEPTED=',accepted,'|FINAL_TAIL=',tail_identity(state), &
       '|MAX_LEDGER=',maxledger,'|ORIGIN_LEAK=',origin_leak,'|REASON=',trim(reason)
  write(*,'(a)') 'F_PE_NLGLOB14Z44=PASS'

contains

  subroutine read_real(iarg,x)
    integer,intent(in)::iarg
    real(real64),intent(out)::x
    character(len=64)::s
    call get_command_argument(iarg,s); read(s,*)x
  end subroutine read_real

  subroutine read_int(iarg,x)
    integer,intent(in)::iarg
    integer,intent(out)::x
    character(len=64)::s
    call get_command_argument(iarg,s); read(s,*)x
  end subroutine read_int

  subroutine fill_cof()
    real(real64)::mm
    mm=1.0_real64-1.0_real64/nvg
    cof=0.0_real64
    do k=1,numnod
       cof(1,k)=tr; cof(2,k)=ts; cof(3,k)=ksat; cof(4,k)=alpha; cof(5,k)=lambda
       cof(6,k)=nvg; cof(7,k)=mm; cof(8,k)=alpha; cof(9,k)=0.0_real64
       cof(10,k)=ksat; cof(11,k)=0.999_real64; cof(12,k)=0.99_real64*ksat
       cof(22,k)=-1.0e6_real64; cof(23,k)=1.0e-12_real64
    end do
  end subroutine fill_cof

  subroutine setup()
    pfull%parameter_set_id=4401_int64
    pfull%active_nodes=numnod
    allocate(pfull%z(numnod),pfull%dz(numnod),pfull%node_distance(numnod))
    pfull%z=z; pfull%dz=dz; pfull%node_distance=disnod(1:numnod)
    allocate(cof(24,numnod))
    call fill_cof()
    call initialize_b110_default_mvg_parameters(hpfull,cof)
    call bind_b110_default_mvg_provider(constitutive,hpfull,dt)
    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
    call bind_b110_source_sink_provider(source,qdra,qssdi,qrot)
  end subroutine setup

  subroutine initialize_state()
    real(real64)::heads(numnod)
    allocate(theta_tmp(numnod),k_tmp(numnod),cap_tmp(numnod),dk_tmp(numnod))
    do k=1,numnod
       heads(k)=10.0_real64*real(k-tail_start,real64)
    end do
    call constitutive%evaluate(heads,theta_tmp,k_tmp,cap_tmp,dk_tmp)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=theta_tmp
    state%ponding_depth=0.0_real64
    state%groundwater_level=-10.0_real64*real(tail_start-1,real64)
  end subroutine initialize_state

  subroutine configure_request()
    req%parameters=>pfull
    req%step_duration=dt
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux=-0.01_real64
    req%boundary%bottom_mode=2
    req%boundary%bottom_flux=0.0_real64
    req%numerical%max_iterations=8
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    req%numerical%compartment_balance_tolerance=1.0e-12_real64
    req%numerical%total_balance_tolerance=1.0e-12_real64
    req%numerical%head_abs_tolerance=1.0e-9_real64
    req%numerical%head_rel_tolerance=1.0e-9_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source
    req%evaluation%top_boundary=>top
  end subroutine configure_request

  subroutine build_request()
    call configure_request()
    req%base_state=state
  end subroutine build_request

  subroutine copy_state_to_request()
    req%base_state%active_nodes=numnod
    req%base_state%pressure_head=state%pressure_head
    req%base_state%water_content=state%water_content
    req%base_state%ponding_depth=state%ponding_depth
    req%base_state%groundwater_level=state%groundwater_level
  end subroutine copy_state_to_request

  subroutine set_history()
    timeint02_mode=1
    timeint02_thetam2=0.0_real64
    timeint02_thetam2(1:numnod)=state%water_content
  end subroutine set_history

  real(real64) function request_origin_leak() result(v)
    v=max(maxval(abs(req%base_state%pressure_head-state%pressure_head)), &
          maxval(abs(req%base_state%water_content-state%water_content)))
  end function request_origin_leak

  real(real64) function step_ledger(r) result(v)
    type(soil_water_solve_result_t),intent(in)::r
    v=sum((r%candidate_state%water_content-state%water_content)*pfull%dz) + &
         dt*(r%top_flux-r%bottom_flux)
  end function step_ledger

  subroutine accept_state(candidate)
    type(soil_water_physical_state_t),intent(in)::candidate
    state%pressure_head=candidate%pressure_head
    state%water_content=candidate%water_content
    state%ponding_depth=candidate%ponding_depth
    state%groundwater_level=candidate%groundwater_level
  end subroutine accept_state

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
       if(sat(j))then
          first=j
       else
          exit
       end if
    end do
    if(first<=numnod .and. first>1)then
       if(any(sat(1:first-1))) first=-1
    end if
  end function tail_identity

end program test_fpe_nlglob14z44_reference_fixture
