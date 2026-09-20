program tabhyd_typed_richards_benchmark
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, constitutive_hydraulics_provider_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider, &
       TABHYD_RAW_TABLE_N
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NROUNDS=8, NREPEAT=4000
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: apar
  type(b110_default_mvg_provider_t), target :: analytic
  type(tabhyd_raw_provider_t), target :: table
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: wa, wt
  type(soil_water_solve_request_t) :: ra, rt
  type(soil_water_solve_result_t) :: resa, rest
  real(real64), allocatable :: cofgen(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), root_sink(:)
  real(real64), allocatable :: h0(:), ta(:),ka(:),ca(:),da(:), tt(:),kt(:),ct(:),dtbl(:)
  real(real64) :: step_duration, hbase, bottom_jump, top_flux
  real(real64) :: ores,osat,alpha,npar,ksat,lexp,henpr,mpar
  real(real64) :: atime(NROUNDS), ttime(NROUNDS), checksum_a, checksum_t
  real(real64) :: max_h_diff,max_theta_diff,flux_diff,mass_diff
  real(real64) :: med_a,med_t
  integer :: nodes,nt,i,j,iu,ios,r
  character(len=32) :: soil
  character(len=512) :: path

  if(command_argument_count()<1) error stop 'usage: typed-richards-benchmark INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open input'
  read(iu,*,iostat=ios) nodes,nt,step_duration,hbase,bottom_jump
  if(ios/=0 .or. nodes/=numnod .or. nt/=TABHYD_RAW_TABLE_N) error stop 'invalid benchmark header'
  allocate(cofgen(24,nodes),headtab(nt,nodes),thetatab(nt,nodes),ktab(nt,nodes))
  cofgen=0.0_real64
  do i=1,nodes
    read(iu,*,iostat=ios) soil,ores,osat,alpha,npar,ksat,lexp,henpr
    if(ios/=0) error stop 'invalid material row'
    mpar=1.0_real64-1.0_real64/npar
    cofgen(1,i)=ores; cofgen(2,i)=osat; cofgen(3,i)=ksat
    cofgen(4,i)=alpha; cofgen(5,i)=lexp; cofgen(6,i)=npar
    cofgen(7,i)=mpar; cofgen(9,i)=henpr
    do j=1,nt
      read(iu,*,iostat=ios) headtab(j,i),thetatab(j,i),ktab(j,i)
      if(ios/=0) error stop 'invalid table row'
    end do
  end do
  close(iu)

  call initialize_b110_default_mvg_parameters(apar,cofgen)
  call bind_b110_default_mvg_provider(analytic,apar,step_duration)
  call initialize_tabhyd_raw_provider(table,headtab,thetatab,ktab,cofgen,step_duration)

  parameters%parameter_set_id=551001_int64
  parameters%active_nodes=nodes
  allocate(parameters%z(nodes),parameters%dz(nodes),parameters%node_distance(nodes))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:nodes)

  allocate(drainage(1,nodes),subsurface(nodes),root_sink(nodes))
  drainage=0.0_real64; subsurface=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)

  allocate(h0(nodes),ta(nodes),ka(nodes),ca(nodes),da(nodes),tt(nodes),kt(nodes),ct(nodes),dtbl(nodes))
  do i=1,nodes
    h0(i)=hbase + 0.15_real64*real(i-1,real64)
  end do
  call analytic%evaluate(h0,ta,ka,ca,da)
  call table%evaluate(h0,tt,kt,ct,dtbl)
  top_flux=-0.97_real64*ka(1)

  call configure_request(ra,analytic,h0,ta,top_flux)
  call configure_request(rt,table,h0,tt,top_flux)

  call solver%solve(ra,wa,resa)
  call solver%solve(rt,wt,rest)
  call require(resa%status==SW_SOLVE_CONVERGED,'analytic solve did not converge')
  call require(rest%status==SW_SOLVE_CONVERGED,'table solve did not converge')

  max_h_diff=maxval(abs(rest%candidate_state%pressure_head-resa%candidate_state%pressure_head))
  max_theta_diff=maxval(abs(rest%candidate_state%water_content-resa%candidate_state%water_content))
  flux_diff=max(abs(rest%top_flux-resa%top_flux),abs(rest%bottom_flux-resa%bottom_flux))
  mass_diff=abs(rest%integrated_mass_balance_residual_cm-resa%integrated_mass_balance_residual_cm)
  write(*,'(a,es24.16)') 'RICHARDS_HEAD_MAX_DIFF=',max_h_diff
  write(*,'(a,es24.16)') 'RICHARDS_THETA_MAX_DIFF=',max_theta_diff
  write(*,'(a,es24.16)') 'RICHARDS_FLUX_MAX_DIFF=',flux_diff
  write(*,'(a,es24.16)') 'RICHARDS_MASS_RESIDUAL_DIFF=',mass_diff
  write(*,'(a,i0)') 'RICHARDS_ANALYTIC_ITERATIONS=',resa%diagnostics%nonlinear_iterations
  write(*,'(a,i0)') 'RICHARDS_TABLE_ITERATIONS=',rest%diagnostics%nonlinear_iterations

  call require(max_h_diff<=5.0e-2_real64,'head fidelity gate')
  call require(max_theta_diff<=1.0e-3_real64,'theta fidelity gate')
  call require(flux_diff<=2.0e-2_real64,'flux fidelity gate')

  checksum_a=0.0_real64; checksum_t=0.0_real64
  do r=1,NROUNDS
    if(mod(r,2)==1) then
      call time_route(ra,wa,atime(r),checksum_a)
      call time_route(rt,wt,ttime(r),checksum_t)
    else
      call time_route(rt,wt,ttime(r),checksum_t)
      call time_route(ra,wa,atime(r),checksum_a)
    end if
    write(*,'(a,i0,a,es16.8,a,es16.8)') 'RICHARDS_BLOCK round=',r,' analytic_s=',atime(r),' table_s=',ttime(r)
  end do
  med_a=median_small(atime); med_t=median_small(ttime)
  write(*,'(a,es24.16)') 'RICHARDS_ANALYTIC_MEDIAN_S=',med_a
  write(*,'(a,es24.16)') 'RICHARDS_TABLE_MEDIAN_S=',med_t
  write(*,'(a,f14.8)') 'RICHARDS_TABLE_DELTA_PCT=',100.0_real64*(med_t/med_a-1.0_real64)
  write(*,'(a,es24.16)') 'RICHARDS_ANALYTIC_CHECKSUM=',checksum_a
  write(*,'(a,es24.16)') 'RICHARDS_TABLE_CHECKSUM=',checksum_t
  write(*,'(a)') 'TABHYD_TYPED_RICHARDS_BENCHMARK_PASS'

contains

  subroutine configure_request(req,provider,heads,water,forcing_top)
    type(soil_water_solve_request_t), intent(out) :: req
    class(constitutive_hydraulics_provider_t), target, intent(in) :: provider
    real(real64), intent(in) :: heads(:),water(:),forcing_top
    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%base_state%active_nodes=nodes
    allocate(req%base_state%pressure_head(nodes),req%base_state%water_content(nodes))
    req%base_state%pressure_head=heads
    req%base_state%water_content=water
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-100.0_real64
    req%step_duration=step_duration
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=5
    req%boundary%top_flux=forcing_top
    req%boundary%top_head=heads(1)
    req%boundary%bottom_flux=0.0_real64
    req%boundary%bottom_head=heads(nodes)+bottom_jump
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=20
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-7_real64
    req%numerical%total_balance_tolerance=1.0e-7_real64
    req%numerical%head_abs_tolerance=1.0e-6_real64
    req%numerical%head_rel_tolerance=1.0e-6_real64
    req%numerical%ponding_tolerance=1.0e-8_real64
    req%evaluation%constitutive=>provider
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_provider
  end subroutine configure_request

  subroutine time_route(req,workspace,seconds,checksum)
    type(soil_water_solve_request_t), intent(in) :: req
    type(reference_richards_legacy_workspace_t), intent(inout) :: workspace
    real(real64), intent(out) :: seconds
    real(real64), intent(inout) :: checksum
    type(soil_water_solve_result_t) :: result
    real(real64) :: a,b
    integer :: q
    call cpu_time(a)
    do q=1,NREPEAT
      call solver%solve(req,workspace,result)
      if(result%status/=SW_SOLVE_CONVERGED) error stop 'timed route failed to converge'
      checksum=checksum+result%candidate_state%pressure_head(1)+result%bottom_flux
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

  subroutine require(ok,label)
    logical,intent(in) :: ok
    character(len=*),intent(in) :: label
    if(.not.ok) then
      write(*,'(a,1x,a)') 'TABHYD_TYPED_RICHARDS_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program tabhyd_typed_richards_benchmark
