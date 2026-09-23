program tabhyd_typed_reference_richards_benchmark
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabhyd_raw_typed_provider_research, only: tabhyd_raw_provider_t, initialize_tabhyd_raw_provider, TABHYD_RAW_TABLE_N
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use MOD_grid, only: numnod, z, dz, disnod
  implicit none

  integer, parameter :: NHEAD=12, NROUND=10, NREPEAT=1500
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: apar
  type(b110_default_mvg_provider_t), target :: analytic
  type(tabhyd_raw_provider_t), target :: table
  type(b110_source_sink_provider_t), target :: terms
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver_a, solver_t
  type(reference_richards_legacy_workspace_t) :: work_a, work_t
  type(soil_water_solve_request_t) :: req_a, req_t
  type(soil_water_solve_result_t) :: res
  real(real64), allocatable, target :: drainage(:,:), source(:), root(:)
  real(real64), allocatable :: cofgen(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64), allocatable :: hvec(:), theta_a(:), k_a(:), c_a(:), d_a(:), theta_t(:), k_t(:), c_t(:), d_t(:)
  real(real64) :: heads(NHEAD), time_a(NROUND), time_t(NROUND), t0,t1,checksum_a,checksum_t
  real(real64) :: max_hdiff,max_tdiff,step_duration, med_a,med_t
  real(real64) :: ores,osat,alpha,npar,ksat,lexp,henpr,mpar
  character(len=512) :: path
  character(len=32) :: soil
  integer :: nt,nodes,i,j,q,r,rep,iu,ios

  if (command_argument_count()<1) error stop 'usage: typed-richards-benchmark INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open input'
  read(iu,*,iostat=ios) nodes,nt,step_duration
  if(ios/=0 .or. nodes/=numnod .or. nt/=TABHYD_RAW_TABLE_N) error stop 'input dimensions mismatch'

  allocate(cofgen(24,nodes),headtab(nt,nodes),thetatab(nt,nodes),ktab(nt,nodes))
  cofgen=0.0_real64
  do i=1,nodes
    read(iu,*,iostat=ios) soil,ores,osat,alpha,npar,ksat,lexp,henpr
    if(ios/=0) error stop 'invalid material row'
    mpar=1.0_real64-1.0_real64/npar
    cofgen(1,i)=ores; cofgen(2,i)=osat; cofgen(3,i)=ksat; cofgen(4,i)=alpha
    cofgen(5,i)=lexp; cofgen(6,i)=npar; cofgen(7,i)=mpar; cofgen(9,i)=henpr
    do j=1,nt
      read(iu,*,iostat=ios) headtab(j,i),thetatab(j,i),ktab(j,i)
      if(ios/=0) error stop 'invalid table row'
    end do
  end do
  close(iu)

  call initialize_b110_default_mvg_parameters(apar,cofgen)
  call bind_b110_default_mvg_provider(analytic,apar,step_duration)
  call initialize_tabhyd_raw_provider(table,headtab,thetatab,ktab,cofgen,step_duration)

  parameters%parameter_set_id=91001
  parameters%active_nodes=nodes
  allocate(parameters%z(nodes),parameters%dz(nodes),parameters%node_distance(nodes))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:nodes)

  allocate(drainage(1,nodes),source(nodes),root(nodes))
  drainage=0.0_real64; source=0.0_real64; root=0.0_real64
  call bind_b110_source_sink_provider(terms,drainage,source,root)

  allocate(hvec(nodes),theta_a(nodes),k_a(nodes),c_a(nodes),d_a(nodes),theta_t(nodes),k_t(nodes),c_t(nodes),d_t(nodes))
  heads=[-2.0_real64,-5.0_real64,-10.0_real64,-20.0_real64,-40.0_real64,-75.0_real64, &
         -120.0_real64,-250.0_real64,-500.0_real64,-1000.0_real64,-2500.0_real64,-10000.0_real64]

  max_hdiff=0.0_real64; max_tdiff=0.0_real64
  do q=1,NHEAD
    hvec=heads(q)
    call analytic%evaluate(hvec,theta_a,k_a,c_a,d_a)
    call table%evaluate(hvec,theta_t,k_t,c_t,d_t)
    call prepare_request(req_a,analytic,hvec,theta_a,k_a)
    call prepare_request(req_t,table,hvec,theta_t,k_t)
    call solver_a%solve(req_a,work_a,res)
    if(res%status/=SW_SOLVE_CONVERGED) error stop 'analytic integration solve failed'
    max_hdiff=max(max_hdiff,maxval(abs(res%candidate_state%pressure_head-hvec)))
    call solver_t%solve(req_t,work_t,res)
    if(res%status/=SW_SOLVE_CONVERGED) error stop 'table integration solve failed'
    max_hdiff=max(max_hdiff,maxval(abs(res%candidate_state%pressure_head-hvec)))
    max_tdiff=max(max_tdiff,maxval(abs(theta_t-theta_a)))
  end do
  write(*,'(a,es24.16)') 'TYPED_RICHARDS_EQUILIBRIUM_HEAD_MAX=',max_hdiff
  write(*,'(a,es24.16)') 'TYPED_RICHARDS_INPUT_THETA_MAX=',max_tdiff

  ! Warm-up.
  call time_route(.true.,1,checksum_a)
  call time_route(.false.,1,checksum_t)

  checksum_a=0.0_real64; checksum_t=0.0_real64
  do r=1,NROUND
    if(mod(r,2)==1) then
      call timed_block(.true.,time_a(r),checksum_a)
      call timed_block(.false.,time_t(r),checksum_t)
    else
      call timed_block(.false.,time_t(r),checksum_t)
      call timed_block(.true.,time_a(r),checksum_a)
    end if
    write(*,'(a,i0,a,es16.8,a,es16.8)') 'TYPED_RICHARDS_BLOCK round=',r,' analytic_s=',time_a(r),' table_s=',time_t(r)
  end do

  med_a=median_small(time_a); med_t=median_small(time_t)
  write(*,'(a,es24.16)') 'TYPED_RICHARDS_ANALYTIC_MEDIAN_S=',med_a
  write(*,'(a,es24.16)') 'TYPED_RICHARDS_TABLE_MEDIAN_S=',med_t
  write(*,'(a,f14.8)') 'TYPED_RICHARDS_TABLE_DELTA_PCT=',100.0_real64*(med_t/med_a-1.0_real64)
  write(*,'(a,es24.16)') 'TYPED_RICHARDS_ANALYTIC_CHECKSUM=',checksum_a
  write(*,'(a,es24.16)') 'TYPED_RICHARDS_TABLE_CHECKSUM=',checksum_t
  write(*,'(a)') 'TYPED_RICHARDS_INTEGRATION_COMPLETED'

contains

  subroutine prepare_request(req,provider,h0,t0v,k0v)
    use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
    type(soil_water_solve_request_t), intent(out) :: req
    class(constitutive_hydraulics_provider_t), target, intent(in) :: provider
    real(real64), intent(in) :: h0(:),t0v(:),k0v(:)
    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%base_state%active_nodes=nodes
    allocate(req%base_state%pressure_head(nodes),req%base_state%water_content(nodes))
    req%base_state%pressure_head=h0; req%base_state%water_content=t0v
    req%base_state%ponding_depth=0.0_real64; req%base_state%groundwater_level=-200.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=2
    req%boundary%top_flux=-k0v(1)
    req%boundary%bottom_flux=-k0v(nodes)
    req%boundary%bottom_head=h0(nodes)
    req%numerical%max_iterations=12
    req%numerical%max_backtracking=6
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    req%numerical%compartment_balance_tolerance=1.0e-10_real64
    req%numerical%total_balance_tolerance=1.0e-10_real64
    req%numerical%head_abs_tolerance=1.0e-10_real64
    req%numerical%head_rel_tolerance=1.0e-10_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%step_duration=step_duration
    req%evaluation%constitutive=>provider
    req%evaluation%source_sink=>terms
    req%evaluation%top_boundary=>top
  end subroutine prepare_request

  subroutine timed_block(use_analytic,seconds,checksum)
    logical,intent(in) :: use_analytic
    real(real64),intent(out) :: seconds
    real(real64),intent(inout) :: checksum
    call cpu_time(t0)
    call time_route(use_analytic,NREPEAT,checksum)
    call cpu_time(t1)
    seconds=t1-t0
  end subroutine timed_block

  subroutine time_route(use_analytic,repeats,checksum)
    logical,intent(in) :: use_analytic
    integer,intent(in) :: repeats
    real(real64),intent(inout) :: checksum
    integer :: rr,qq
    do rr=1,repeats
      do qq=1,NHEAD
        hvec=heads(qq)
        if(use_analytic) then
          call analytic%evaluate(hvec,theta_a,k_a,c_a,d_a)
          call prepare_request(req_a,analytic,hvec,theta_a,k_a)
          call solver_a%solve(req_a,work_a,res)
        else
          call table%evaluate(hvec,theta_t,k_t,c_t,d_t)
          call prepare_request(req_t,table,hvec,theta_t,k_t)
          call solver_t%solve(req_t,work_t,res)
        end if
        if(res%status/=SW_SOLVE_CONVERGED) error stop 'timed integration solve failed'
        checksum=checksum+res%candidate_state%pressure_head(1)+res%candidate_state%water_content(nodes)+res%top_flux
      end do
    end do
  end subroutine time_route

  real(real64) function median_small(x) result(m)
    real(real64),intent(in) :: x(:)
    real(real64) :: y(size(x)),tmp
    integer :: a,b
    y=x
    do a=1,size(y)-1
      do b=a+1,size(y)
        if(y(b)<y(a)) then; tmp=y(a); y(a)=y(b); y(b)=tmp; end if
      end do
    end do
    if(mod(size(y),2)==0) then
      m=0.5_real64*(y(size(y)/2)+y(size(y)/2+1))
    else
      m=y((size(y)+1)/2)
    end if
  end function median_small

end program tabhyd_typed_reference_richards_benchmark
