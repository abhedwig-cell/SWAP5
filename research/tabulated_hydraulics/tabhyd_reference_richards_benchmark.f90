program tabhyd_reference_richards_benchmark
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, soil_water_parameter_set_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_physical_state_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider, &
       TABHYD_RAW_TABLE_N
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use MOD_grid, only: numnod, z, dz, disnod
  implicit none

  integer, parameter :: NROUNDS=8, NSTEPS=240
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: apar
  type(b110_default_mvg_provider_t), target :: analytic
  type(tabhyd_raw_provider_t), target :: table
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(b110_source_sink_provider_t), target :: source_provider
  real(real64), allocatable, target :: drainage(:,:), subsource(:), rootsink(:)
  real(real64), allocatable :: cofgen(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64), allocatable :: init_h(:), init_theta(:), tmp_k(:), tmp_c(:), tmp_d(:)
  real(real64) :: step_duration
  real(real64) :: atime(NROUNDS), ttime(NROUNDS), aiter(NROUNDS), titer(NROUNDS)
  real(real64) :: afinal_h(numnod), tfinal_h(numnod), afinal_t(numnod), tfinal_t(numnod)
  real(real64) :: med_a, med_t, max_h, max_theta
  integer :: nt, nodes, i, j, r, iu, ios
  character(len=512) :: path
  character(len=32) :: soil
  real(real64) :: ores, osat, alpha, npar, ksat, lexp, henpr

  if (command_argument_count() < 1) error stop 'usage: benchmark INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if (ios /= 0) error stop 'cannot open input'
  read(iu,*,iostat=ios) nodes, nt, step_duration
  if (ios /= 0 .or. nodes /= numnod .or. nt /= TABHYD_RAW_TABLE_N) error stop 'invalid input header'

  allocate(cofgen(24,numnod), headtab(nt,numnod), thetatab(nt,numnod), ktab(nt,numnod))
  cofgen = 0.0_real64
  do i=1,numnod
    read(iu,*,iostat=ios) soil, ores, osat, alpha, npar, ksat, lexp, henpr
    if (ios /= 0) error stop 'invalid material row'
    cofgen(1,i)=ores; cofgen(2,i)=osat; cofgen(3,i)=ksat; cofgen(4,i)=alpha
    cofgen(5,i)=lexp; cofgen(6,i)=npar; cofgen(7,i)=1.0_real64-1.0_real64/npar
    cofgen(8,i)=alpha; cofgen(9,i)=henpr; cofgen(10,i)=ksat
    cofgen(11,i)=0.999_real64; cofgen(12,i)=0.99_real64*ksat
    cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
    do j=1,nt
      read(iu,*,iostat=ios) headtab(j,i), thetatab(j,i), ktab(j,i)
      if (ios /= 0) error stop 'invalid table row'
    end do
  end do
  close(iu)

  parameters%parameter_set_id = 991001
  parameters%active_nodes = numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z = z
  parameters%dz = dz
  parameters%node_distance = disnod(1:numnod)

  call initialize_b110_default_mvg_parameters(apar,cofgen)
  call bind_b110_default_mvg_provider(analytic,apar,step_duration)
  call initialize_tabhyd_raw_provider(table,headtab,thetatab,ktab,cofgen,step_duration)

  allocate(drainage(1,numnod),subsource(numnod),rootsink(numnod))
  drainage=0.0_real64; subsource=0.0_real64; rootsink=0.0_real64
  call bind_b110_source_sink_provider(source_provider,drainage,subsource,rootsink)

  allocate(init_h(numnod),init_theta(numnod),tmp_k(numnod),tmp_c(numnod),tmp_d(numnod))
  do i=1,numnod
    init_h(i) = -35.0_real64 - 2.0_real64*real(i-1,real64)
  end do
  call analytic%evaluate(init_h,init_theta,tmp_k,tmp_c,tmp_d)

  ! Warm-up both routes outside timed blocks.
  call run_sequence(analytic,init_h,init_theta,afinal_h,afinal_t,aiter(1))
  call run_sequence(table,init_h,init_theta,tfinal_h,tfinal_t,titer(1))

  do r=1,NROUNDS
    if (mod(r,2)==1) then
      call timed_route(analytic,init_h,init_theta,atime(r),aiter(r),afinal_h,afinal_t)
      call timed_route(table,init_h,init_theta,ttime(r),titer(r),tfinal_h,tfinal_t)
    else
      call timed_route(table,init_h,init_theta,ttime(r),titer(r),tfinal_h,tfinal_t)
      call timed_route(analytic,init_h,init_theta,atime(r),aiter(r),afinal_h,afinal_t)
    end if
    write(*,'(a,i0,a,es16.8,a,es16.8,a,f12.3,a,f12.3)') 'RICHARDS_BLOCK round=',r, &
         ' analytic_s=',atime(r),' table_s=',ttime(r),' analytic_iters=',aiter(r),' table_iters=',titer(r)
  end do

  med_a=median_small(atime)
  med_t=median_small(ttime)
  max_h=maxval(abs(tfinal_h-afinal_h))
  max_theta=maxval(abs(tfinal_t-afinal_t))
  write(*,'(a,es24.16)') 'RICHARDS_ANALYTIC_MEDIAN_S=',med_a
  write(*,'(a,es24.16)') 'RICHARDS_TABLE_MEDIAN_S=',med_t
  write(*,'(a,f14.8)') 'RICHARDS_TABLE_DELTA_PCT=',100.0_real64*(med_t/med_a-1.0_real64)
  write(*,'(a,es24.16)') 'RICHARDS_FINAL_HEAD_MAX_ABS=',max_h
  write(*,'(a,es24.16)') 'RICHARDS_FINAL_THETA_MAX_ABS=',max_theta
  write(*,'(a,f14.4)') 'RICHARDS_ANALYTIC_ITER_MEDIAN=',median_small(aiter)
  write(*,'(a,f14.4)') 'RICHARDS_TABLE_ITER_MEDIAN=',median_small(titer)
  write(*,'(a)') 'RICHARDS_TYPED_PROVIDER_INTEGRATION_COMPLETED'

contains

  subroutine timed_route(provider,h0,t0,seconds,iters,hfinal,tfinal)
    class(constitutive_hydraulics_provider_t), target, intent(in) :: provider
    real(real64), intent(in) :: h0(:), t0(:)
    real(real64), intent(out) :: seconds,iters,hfinal(:),tfinal(:)
    real(real64) :: a,b
    call cpu_time(a)
    call run_sequence(provider,h0,t0,hfinal,tfinal,iters)
    call cpu_time(b)
    seconds=b-a
  end subroutine timed_route

  subroutine run_sequence(provider,h0,t0,hfinal,tfinal,iters)
    class(constitutive_hydraulics_provider_t), target, intent(in) :: provider
    real(real64), intent(in) :: h0(:), t0(:)
    real(real64), intent(out) :: hfinal(:), tfinal(:), iters
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_physical_state_t) :: state
    real(real64) :: phase
    integer :: step

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=h0
    state%water_content=t0
    state%ponding_depth=0.0_real64
    state%groundwater_level=-200.0_real64
    iters=0.0_real64

    do step=1,NSTEPS
      request=soil_water_solve_request_t()
      request%parameters => parameters
      request%base_state=state
      request%step_duration=step_duration
      request%physical%macropore_active=.false.
      request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
      request%boundary%bottom_mode=2
      phase=6.283185307179586_real64*real(mod(step-1,48),real64)/48.0_real64
      request%boundary%top_flux=-0.025_real64 - 0.020_real64*sin(phase)
      if (mod(step,37)==0) request%boundary%top_flux=-0.12_real64
      request%boundary%bottom_flux=0.0_real64
      request%boundary%top_head=0.0_real64
      request%boundary%bottom_head=-100.0_real64
      request%numerical%max_iterations=12
      request%numerical%max_backtracking=6
      request%numerical%conductivity_implicit_mode=0
      request%numerical%conductivity_mean_method=1
      request%numerical%min_step_duration=1.0e-6_real64
      request%numerical%compartment_balance_tolerance=1.0e-10_real64
      request%numerical%total_balance_tolerance=1.0e-10_real64
      request%numerical%head_abs_tolerance=1.0e-8_real64
      request%numerical%head_rel_tolerance=1.0e-8_real64
      request%numerical%ponding_tolerance=1.0e-10_real64
      request%evaluation%constitutive => provider
      request%evaluation%source_sink => source_provider
      request%evaluation%top_boundary => top_provider
      call solver%solve(request,workspace,result)
      if (result%status /= SW_SOLVE_CONVERGED) then
        write(*,'(a,i0,a,i0,a,a)') 'RICHARDS_ROUTE_FAIL step=',step,' status=',result%status,' route=',trim(result%diagnostics%route)
        error stop 2
      end if
      iters=iters+real(result%diagnostics%nonlinear_iterations,real64)
      state=result%candidate_state
    end do
    hfinal=state%pressure_head
    tfinal=state%water_content
  end subroutine run_sequence

  real(real64) function median_small(values) result(med)
    real(real64), intent(in) :: values(:)
    real(real64) :: x(size(values)),tmp
    integer :: a,b
    x=values
    do a=1,size(x)-1
      do b=a+1,size(x)
        if(x(b)<x(a)) then
          tmp=x(a); x(a)=x(b); x(b)=tmp
        end if
      end do
    end do
    if(mod(size(x),2)==0) then
      med=0.5_real64*(x(size(x)/2)+x(size(x)/2+1))
    else
      med=x((size(x)+1)/2)
    end if
  end function median_small

end program tabhyd_reference_richards_benchmark
