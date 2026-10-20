program swap5_perf01_column
  use, intrinsic :: iso_fortran_env, only: int64,real64,error_unit
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_soil_water_solver_contract
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t,bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  implicit none
  real(real64),parameter :: total_dt=.005_real64,hard_mass_gate=1.e-12_real64
  type(soil_water_parameter_set_t),target :: p
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: cp
  type(b110_source_sink_provider_t),target :: sp
  type(fixed_flux_top_boundary_provider_t),target :: tp
  type(b110_root_sink_provider_t),target :: rp
  real(real64),allocatable,target :: roots(:)
  integer :: case_id, series_unit
  real(real64) :: initial_head, validation_cpu0, validation_cpu=0.0_real64
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: state
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  real(real64),allocatable,target :: qdra(:,:),qssdi(:),qrot(:)
  real(real64),allocatable :: c(:,:)
  real(real64) :: k0,t,horizon,dt,storage0,storage1,mass,cumin,cumout,inflow,outflow,maxmass
  integer :: step,attempts,retries,nl,jac,linear,constitutive,back,i
  integer(int64) :: tick,end_tick,dt_ticks,clock0,clock1,clock_rate
  real(real64) :: cpu0,cpu1,solver_cpu=0.0_real64,solver_wall=0.0_real64
  character(len=64) :: arg
  call get_command_argument(1,arg);read(arg,*)horizon
  call get_command_argument(2,arg);read(arg,*)case_id
  call require(case_id>=1.and.case_id<=8,"case id")
  call require(horizon>0.0_real64,'positive horizon')
  tick=0_int64;end_tick=nint(horizon/1.e-6_real64,int64)
  initial_head=-75.0_real64
  if(case_id==3)initial_head=-500.0_real64
  if(case_id==4)initial_head=-10.0_real64
  call configure_problem(initial_head,p,hp,cp,sp,tp,state,qdra,qssdi,qrot,c,k0)
  request%parameters=>p
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=2
  request%boundary%bottom_flux=-.05_real64
  request%numerical%max_iterations=80;request%numerical%max_backtracking=20
  request%numerical%conductivity_implicit_mode=0;request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.e-6_real64
  request%numerical%compartment_balance_tolerance=hard_mass_gate
  request%numerical%total_balance_tolerance=hard_mass_gate
  request%numerical%head_abs_tolerance=hard_mass_gate
  request%numerical%head_rel_tolerance=hard_mass_gate
  request%numerical%ponding_tolerance=hard_mass_gate
  request%evaluation%constitutive=>cp;request%evaluation%source_sink=>sp
  request%evaluation%top_boundary=>tp
  allocate(roots(numnod));roots=0.0_real64
  if(case_id==2)then
    roots(1:20)=.05_real64/20.0_real64
    call bind_b110_root_sink_provider(rp,roots)
    request%evaluation%root_sink=>rp
  end if
  if(case_id==4)then
    request%boundary%bottom_mode=5
    request%boundary%bottom_head=-10.0_real64
  end if
  if(case_id==6)qdra(1,20:40)=.02_real64/21.0_real64
  open(newunit=series_unit,file='trajectory.bin',access='stream',form='unformatted',status='replace')
  t=0.0_real64;step=0;attempts=0;retries=0;nl=0;jac=0;linear=0;constitutive=0;back=0
  cumin=0.0_real64;cumout=0.0_real64;maxmass=0.0_real64
  do while(tick<end_tick)
    dt_ticks=min(5000_int64,end_tick-tick)
    t=real(tick,real64)*1.e-6_real64
    dt=real(dt_ticks,real64)*1.e-6_real64
    request%boundary%top_flux=-(.1_real64+.08_real64*sin(6.283185307179586_real64*t))
    if(case_id==3)request%boundary%top_flux=-.01_real64
    if(case_id==5.and.mod(t,1.0_real64)<.1_real64)request%boundary%top_flux=-5.0_real64
    if(case_id==7)request%boundary%top_flux=-.05_real64
    request%base_state=state
    storage0=sum(state%water_content*p%dz)+state%ponding_depth
    do
      call bind_b110_default_mvg_provider(cp,hp,dt)
      request%step_duration=dt
      call cpu_time(cpu0);call system_clock(clock0,clock_rate)
      call solver%solve(request,workspace,result)
      call system_clock(clock1);call cpu_time(cpu1)
      solver_cpu=solver_cpu+(cpu1-cpu0)
      solver_wall=solver_wall+real(clock1-clock0,real64)/real(clock_rate,real64)
      attempts=attempts+1
      nl=nl+result%diagnostics%nonlinear_iterations
      jac=jac+result%diagnostics%jacobian_builds
      linear=linear+result%diagnostics%linear_solves
      constitutive=constitutive+result%diagnostics%constitutive_evaluations
      back=back+result%diagnostics%backtracking_attempts
      if(result%status==SW_SOLVE_CONVERGED)exit
      retries=retries+1;dt_ticks=dt_ticks/2_int64
      dt=real(dt_ticks,real64)*1.e-6_real64
      call require(dt>=request%numerical%min_step_duration,'retry floor')
    end do
    call cpu_time(validation_cpu0)
    call require(all(ieee_is_finite(result%candidate_state%pressure_head)),'finite pressure heads')
    storage1=sum(result%candidate_state%water_content*p%dz)+result%candidate_state%ponding_depth
    inflow=(max(0.0_real64,-result%top_flux)+max(0.0_real64,result%bottom_flux))*dt
    outflow=(max(0.0_real64,result%top_flux)+max(0.0_real64,-result%bottom_flux))*dt
    outflow=outflow+(sum(roots)+sum(qdra))*dt
    mass=storage1-storage0-inflow+outflow
    call require(abs(mass)<=hard_mass_gate,'independent hard mass balance')
    maxmass=max(maxmass,abs(mass));cumin=cumin+inflow;cumout=cumout+outflow
    state=result%candidate_state;tick=tick+dt_ticks;step=step+1
    write(series_unit) step,dt,result%diagnostics%nonlinear_iterations,retries,mass, &
      state%pressure_head,state%water_content,state%ponding_depth,state%groundwater_level, &
      result%top_flux,result%bottom_flux,sum(roots)*dt,sum(qdra)*dt
    call cpu_time(cpu1);validation_cpu=validation_cpu+(cpu1-validation_cpu0)
  end do
  write(*,'(*(g0))')'RICHARDS_AUDIT_RESULT|HORIZON=',horizon,'|NODES=',numnod,'|STEPS=',step, &
      '|ATTEMPTS=',attempts,'|RETRIES=',retries,'|NL=',nl,'|JAC=',jac,'|LINEAR=',linear, &
      '|CONSTITUTIVE=',constitutive,'|BACK=',back,'|MAX_MASS=',maxmass,'|IN=',cumin,'|OUT=',cumout
  close(series_unit)
  write(*,'(A)')'RICHARDS_AUDIT_SCIENCE=PASS'
  write(error_unit,'(A,ES24.16)')'VALIDATION_AND_SERIES_CPU=',validation_cpu
  write(error_unit,'(A,ES24.16,A,ES24.16)')'RICHARDS_SOLVER_TIME CPU=',solver_cpu,' WALL=',solver_wall
contains
  subroutine configure_problem(initial_head,p,hp,cp,sp,tp,state,qdra,qssdi,qrot,c,k0)
    real(real64), intent(in) :: initial_head
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fixed_flux_top_boundary_provider_t), target, intent(out) :: tp
    type(soil_water_physical_state_t), intent(out) :: state
    real(real64), allocatable, target, intent(out) :: qdra(:,:),qssdi(:),qrot(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    real(real64), intent(out) :: k0
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id = 250251_int64
    p%active_nodes = numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)

    allocate(c(24,numnod))
    c = 0.0_real64
    do k = 1, numnod
       c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
       c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
       c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
       if(case_id==8.and.k>25)c(3,k)=2.5_real64
       c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
       c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,total_dt)
    heads = initial_head
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    do k = 2, numnod
       if(case_id/=8)call require(transfer(conductivity(k),0_int64) == transfer(conductivity(1),0_int64), &
            'uniform initial K configure')
    end do
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qrot)
  end subroutine configure_problem
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,*)'RICHARDS_AUDIT_FAIL ',label
      error stop 1
    end if
  end subroutine
end program
