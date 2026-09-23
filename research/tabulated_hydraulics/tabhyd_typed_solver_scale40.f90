program tabhyd_typed_solver_scale40
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod, z, dz, disnod
  use variables, only: fldtmin
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider, TABHYD_RAW_TABLE_N
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NROUNDS=8, NREPEAT=50
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: apar
  type(b110_default_mvg_provider_t), target :: analytic
  type(tabhyd_raw_provider_t), target :: table
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver_a, solver_t
  type(reference_richards_legacy_workspace_t) :: workspace_a, workspace_t
  type(soil_water_solve_request_t) :: req_a, req_t
  type(soil_water_solve_result_t) :: res_a, res_t
  real(real64), allocatable, target :: drainage(:,:), irrigation(:), roots(:)
  real(real64), allocatable :: cofgen(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64), allocatable :: h0(:), theta0a(:), theta0t(:), ka(:), ca(:), da(:), tt(:), kt(:), ct(:), dtbl(:)
  real(real64) :: step_duration, initial_head, top_flux, bottom_flux, bottom_head, max_h, rms_h, max_theta, rms_theta, dmass, checksum_a, checksum_t
  real(real64) :: t0,t1, atime(NROUNDS), ttime(NROUNDS), med_a, med_t
  integer :: nodes, nt, bottom_mode, i,j,r,rep,iu,ios
  character(len=512) :: path
  character(len=64) :: scenario, soil

  if(command_argument_count()<1) error stop 'usage: typed-solver-scale40 INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open input'
  read(iu,*,iostat=ios) scenario, nodes, nt, step_duration, initial_head, top_flux, bottom_flux, bottom_mode, bottom_head
  if(ios/=0 .or. nodes/=numnod .or. nt/=TABHYD_RAW_TABLE_N) error stop 'invalid header'

  allocate(cofgen(24,nodes),headtab(nt,nodes),thetatab(nt,nodes),ktab(nt,nodes),h0(nodes))
  cofgen=0.0_real64
  do i=1,nodes
    read(iu,*,iostat=ios) soil, cofgen(1,i),cofgen(2,i),cofgen(4,i),cofgen(6,i),cofgen(3,i),cofgen(5,i),cofgen(9,i)
    if(ios/=0) error stop 'invalid node header'
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i)
    cofgen(8,i)=cofgen(4,i)
    cofgen(10,i)=cofgen(3,i)
    cofgen(11,i)=0.999_real64
    cofgen(12,i)=0.99_real64*cofgen(3,i)
    do j=1,nt
      read(iu,*,iostat=ios) headtab(j,i),thetatab(j,i),ktab(j,i)
      if(ios/=0) error stop 'invalid table row'
    end do
  end do
  close(iu)

  h0=initial_head
  fldtmin=.false.

  ! Geometry is owned by the patched 40-node F-SI04 fixture. Do not mutate
  ! its parameter arrays from the benchmark program.
  parameters%parameter_set_id=71001
  parameters%active_nodes=nodes
  allocate(parameters%z(nodes),parameters%dz(nodes),parameters%node_distance(nodes))
  parameters%z=z
  parameters%dz=dz
  parameters%node_distance=disnod(1:nodes)

  call initialize_b110_default_mvg_parameters(apar,cofgen)
  call bind_b110_default_mvg_provider(analytic,apar,step_duration)
  call initialize_tabhyd_raw_provider(table,headtab,thetatab,ktab,cofgen,step_duration)

  allocate(theta0a(nodes),theta0t(nodes),ka(nodes),ca(nodes),da(nodes),tt(nodes),kt(nodes),ct(nodes),dtbl(nodes))
  call analytic%evaluate(h0,theta0a,ka,ca,da)
  call table%evaluate(h0,theta0t,kt,ct,dtbl)

  allocate(drainage(1,nodes),irrigation(nodes),roots(nodes))
  drainage=0.0_real64; irrigation=0.0_real64; roots=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,irrigation,roots)

  call build_request(req_a,.true.)
  call build_request(req_t,.false.)

  call solver_a%solve(req_a,workspace_a,res_a)
  call solver_t%solve(req_t,workspace_t,res_t)
  write(*,'(a,a)') 'SCALE40_SCENARIO=',trim(scenario)
  write(*,'(a,i0)') 'SCALE40_ANALYTIC_STATUS=',res_a%status
  write(*,'(a,i0)') 'SCALE40_TABLE_STATUS=',res_t%status
  write(*,'(a,i0)') 'SCALE40_ANALYTIC_ITERS=',res_a%diagnostics%nonlinear_iterations
  write(*,'(a,i0)') 'SCALE40_TABLE_ITERS=',res_t%diagnostics%nonlinear_iterations
  if(res_a%status/=SW_SOLVE_CONVERGED .or. res_t%status/=SW_SOLVE_CONVERGED) stop 23

  max_h=maxval(abs(res_t%candidate_state%pressure_head-res_a%candidate_state%pressure_head))
  rms_h=sqrt(sum((res_t%candidate_state%pressure_head-res_a%candidate_state%pressure_head)**2)/real(nodes,real64))
  max_theta=maxval(abs(res_t%candidate_state%water_content-res_a%candidate_state%water_content))
  rms_theta=sqrt(sum((res_t%candidate_state%water_content-res_a%candidate_state%water_content)**2)/real(nodes,real64))
  dmass=abs(res_t%integrated_mass_balance_residual_cm-res_a%integrated_mass_balance_residual_cm)
  write(*,'(a,es24.16)') 'SCALE40_HEAD_MAX_ABS=',max_h
  write(*,'(a,es24.16)') 'SCALE40_HEAD_RMS=',rms_h
  write(*,'(a,es24.16)') 'SCALE40_THETA_MAX_ABS=',max_theta
  write(*,'(a,es24.16)') 'SCALE40_THETA_RMS=',rms_theta
  write(*,'(a,es24.16)') 'SCALE40_DMASS=',dmass
  if(max_h>5.0e-2_real64 .or. rms_h>1.0e-2_real64 .or. max_theta>2.0e-2_real64) stop 24
  if(abs(res_a%integrated_mass_balance_residual_cm)>1.0e-8_real64 .or. &
     abs(res_t%integrated_mass_balance_residual_cm)>1.0e-8_real64) stop 25
  if(res_a%diagnostics%nonlinear_iterations/=res_t%diagnostics%nonlinear_iterations) stop 26

  checksum_a=0.0_real64; checksum_t=0.0_real64
  do r=1,NROUNDS
    if(mod(r,2)==1) then
      call time_route(.true.,atime(r),checksum_a)
      call time_route(.false.,ttime(r),checksum_t)
    else
      call time_route(.false.,ttime(r),checksum_t)
      call time_route(.true.,atime(r),checksum_a)
    end if
    write(*,'(a,i0,a,es16.8,a,es16.8)') 'SCALE40_BLOCK round=',r,' analytic_s=',atime(r),' table_s=',ttime(r)
  end do
  med_a=median_small(atime); med_t=median_small(ttime)
  write(*,'(a,es24.16)') 'SCALE40_ANALYTIC_MEDIAN_S=',med_a
  write(*,'(a,es24.16)') 'SCALE40_TABLE_MEDIAN_S=',med_t
  write(*,'(a,f14.8)') 'SCALE40_TABLE_DELTA_PCT=',100.0_real64*(med_t/med_a-1.0_real64)
  write(*,'(a,es24.16)') 'SCALE40_ANALYTIC_CHECKSUM=',checksum_a
  write(*,'(a,es24.16)') 'SCALE40_TABLE_CHECKSUM=',checksum_t
  write(*,'(a)') 'TABHYD_TYPED_SOLVER_SCALE40=PASS'

contains
  subroutine build_request(req,use_analytic)
    type(soil_water_solve_request_t), intent(out) :: req
    logical, intent(in) :: use_analytic
    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%step_duration=step_duration
    req%base_state%active_nodes=nodes
    allocate(req%base_state%pressure_head(nodes),req%base_state%water_content(nodes))
    req%base_state%pressure_head=h0
    if(use_analytic) then
      req%base_state%water_content=theta0a
    else
      req%base_state%water_content=theta0t
    end if
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-200.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%top_flux=top_flux
    req%boundary%bottom_mode=bottom_mode
    req%boundary%bottom_flux=bottom_flux
    req%boundary%bottom_head=bottom_head
    req%numerical%max_iterations=30
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-8_real64
    req%numerical%total_balance_tolerance=1.0e-8_real64
    req%numerical%head_abs_tolerance=1.0e-8_real64
    req%numerical%head_rel_tolerance=1.0e-8_real64
    req%numerical%ponding_tolerance=1.0e-8_real64
    req%physical%macropore_active=.false.
    if(use_analytic) then
      req%evaluation%constitutive=>analytic
    else
      req%evaluation%constitutive=>table
    end if
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top
  end subroutine build_request

  subroutine time_route(use_analytic,seconds,checksum)
    logical, intent(in) :: use_analytic
    real(real64), intent(out) :: seconds
    real(real64), intent(inout) :: checksum
    real(real64) :: a,b
    integer :: rr
    call cpu_time(a)
    do rr=1,NREPEAT
      if(use_analytic) then
        call solver_a%solve(req_a,workspace_a,res_a)
        if(res_a%status/=SW_SOLVE_CONVERGED) error stop 'analytic timing solve failed'
        checksum=checksum+res_a%candidate_state%pressure_head(1)+res_a%candidate_state%water_content(nodes)
      else
        call solver_t%solve(req_t,workspace_t,res_t)
        if(res_t%status/=SW_SOLVE_CONVERGED) error stop 'table timing solve failed'
        checksum=checksum+res_t%candidate_state%pressure_head(1)+res_t%candidate_state%water_content(nodes)
      end if
    end do
    call cpu_time(b)
    seconds=b-a
  end subroutine time_route

  real(real64) function median_small(values) result(med)
    real(real64), intent(in) :: values(:)
    real(real64) :: x(size(values)),tmp
    integer :: a,b
    x=values
    do a=1,size(x)-1
      do b=a+1,size(x)
        if(x(b)<x(a)) then
          tmp=x(a);x(a)=x(b);x(b)=tmp
        end if
      end do
    end do
    if(mod(size(x),2)==0) then
      med=0.5_real64*(x(size(x)/2)+x(size(x)/2+1))
    else
      med=x((size(x)+1)/2)
    end if
  end function median_small
end program tabhyd_typed_solver_scale40
