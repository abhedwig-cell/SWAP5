program tabhyd_typed_reference_richards_dynamic
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
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

  integer, parameter :: NSTEPS=16, NROUND=8, NREPEAT=250
  real(real64), parameter :: factors(NSTEPS)=[0.80_real64,0.60_real64,1.20_real64,1.40_real64, &
       0.70_real64,0.50_real64,1.10_real64,1.35_real64,0.90_real64,0.65_real64,1.25_real64, &
       1.50_real64,0.75_real64,0.55_real64,1.15_real64,1.30_real64]

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: apar
  type(b110_default_mvg_provider_t), target :: analytic
  type(tabhyd_raw_provider_t), target :: table
  type(b110_source_sink_provider_t), target :: terms
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver_a, solver_t
  type(reference_richards_legacy_workspace_t) :: work_a, work_t
  real(real64), allocatable, target :: drainage(:,:), source(:), root(:)
  real(real64), allocatable :: cofgen(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64), allocatable :: hv(:),ta(:),ka(:),ca(:),da(:),tt(:),kt(:),ct(:),dtb(:)
  real(real64) :: ha(numnod,NSTEPS),ht(numnod,NSTEPS),tha(numnod,NSTEPS),tht(numnod,NSTEPS)
  real(real64) :: ma(NSTEPS),mt(NSTEPS),ia(NSTEPS),it(NSTEPS)
  integer :: nlia(NSTEPS),nlit(NSTEPS),lina(NSTEPS),lint(NSTEPS)
  real(real64) :: atime(NROUND),ttime(NROUND),checksum_a,checksum_t
  real(real64) :: hmax,hrmse,tmax,trmse,mmax,imax,meda,medt,step_duration,qeq
  real(real64) :: ores,osat,alpha,npar,ksat,lexp,henpr,mpar
  character(len=512) :: path
  character(len=32) :: soil
  integer :: nt,nodes,i,j,r,iu,ios

  if(command_argument_count()<1) error stop 'usage: typed-richards-dynamic INPUT'
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
  parameters%parameter_set_id=92001; parameters%active_nodes=nodes
  allocate(parameters%z(nodes),parameters%dz(nodes),parameters%node_distance(nodes))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:nodes)
  allocate(drainage(1,nodes),source(nodes),root(nodes),hv(nodes),ta(nodes),ka(nodes),ca(nodes),da(nodes), &
       tt(nodes),kt(nodes),ct(nodes),dtb(nodes))
  drainage=0.0_real64; source=0.0_real64; root=0.0_real64
  call bind_b110_source_sink_provider(terms,drainage,source,root)

  hv=-75.0_real64
  call analytic%evaluate(hv,ta,ka,ca,da)
  qeq=-ka(1)

  call run_trajectory(.true.,ha,tha,ma,ia,nlia,lina,checksum_a)
  call run_trajectory(.false.,ht,tht,mt,it,nlit,lint,checksum_t)

  hmax=maxval(abs(ht-ha)); hrmse=sqrt(sum((ht-ha)**2)/real(size(ht),real64))
  tmax=maxval(abs(tht-tha)); trmse=sqrt(sum((tht-tha)**2)/real(size(tht),real64))
  mmax=maxval(abs(mt-ma)); imax=maxval(abs(it-ia))

  write(*,'(a,es24.16)') 'DYNAMIC_HEAD_MAX=',hmax
  write(*,'(a,es24.16)') 'DYNAMIC_HEAD_RMSE=',hrmse
  write(*,'(a,es24.16)') 'DYNAMIC_THETA_MAX=',tmax
  write(*,'(a,es24.16)') 'DYNAMIC_THETA_RMSE=',trmse
  write(*,'(a,es24.16)') 'DYNAMIC_NATIVE_MASS_DIFF_MAX=',mmax
  write(*,'(a,es24.16)') 'DYNAMIC_INTEGRATED_MASS_DIFF_MAX=',imax
  write(*,'(a,i0)') 'DYNAMIC_ANALYTIC_NONLINEAR_TOTAL=',sum(nlia)
  write(*,'(a,i0)') 'DYNAMIC_TABLE_NONLINEAR_TOTAL=',sum(nlit)
  write(*,'(a,i0)') 'DYNAMIC_ANALYTIC_LINEAR_TOTAL=',sum(lina)
  write(*,'(a,i0)') 'DYNAMIC_TABLE_LINEAR_TOTAL=',sum(lint)

  do r=1,NROUND
    if(mod(r,2)==1) then
      call time_trajectory(.true.,atime(r),checksum_a)
      call time_trajectory(.false.,ttime(r),checksum_t)
    else
      call time_trajectory(.false.,ttime(r),checksum_t)
      call time_trajectory(.true.,atime(r),checksum_a)
    end if
    write(*,'(a,i0,a,es16.8,a,es16.8)') 'DYNAMIC_BLOCK round=',r,' analytic_s=',atime(r),' table_s=',ttime(r)
  end do
  meda=median_small(atime); medt=median_small(ttime)
  write(*,'(a,es24.16)') 'DYNAMIC_ANALYTIC_MEDIAN_S=',meda
  write(*,'(a,es24.16)') 'DYNAMIC_TABLE_MEDIAN_S=',medt
  write(*,'(a,f14.8)') 'DYNAMIC_TABLE_DELTA_PCT=',100.0_real64*(medt/meda-1.0_real64)
  write(*,'(a)') 'DYNAMIC_TYPED_RICHARDS_COMPLETED'

contains

  subroutine run_trajectory(use_analytic,hist_h,hist_t,mass_native,mass_int,nlit,lins,checksum)
    logical,intent(in) :: use_analytic
    real(real64),intent(out) :: hist_h(numnod,NSTEPS),hist_t(numnod,NSTEPS),mass_native(NSTEPS),mass_int(NSTEPS)
    integer,intent(out) :: nlit(NSTEPS),lins(NSTEPS)
    real(real64),intent(inout) :: checksum
    type(soil_water_solve_request_t) :: req
    type(soil_water_solve_result_t) :: res
    real(real64) :: h0(numnod),theta0(numnod),k0(numnod),c0(numnod),d0(numnod)
    integer :: s
    h0=-75.0_real64
    if(use_analytic) then
      call analytic%evaluate(h0,theta0,k0,c0,d0)
    else
      call table%evaluate(h0,theta0,k0,c0,d0)
    end if
    call prepare_request(req,use_analytic,h0,theta0)
    do s=1,NSTEPS
      req%boundary%top_flux=factors(s)*qeq
      req%boundary%bottom_flux=qeq
      if(use_analytic) then
        call solver_a%solve(req,work_a,res)
      else
        call solver_t%solve(req,work_t,res)
      end if
      if(res%status/=SW_SOLVE_CONVERGED) error stop 'dynamic solve failed'
      if(.not. res%native_balance_rate_residual_available .or. .not. res%integrated_mass_balance_residual_available) &
        error stop 'dynamic mass diagnostics unavailable'
      hist_h(:,s)=res%candidate_state%pressure_head
      hist_t(:,s)=res%candidate_state%water_content
      mass_native(s)=res%native_balance_rate_residual_cm_per_day
      mass_int(s)=res%integrated_mass_balance_residual_cm
      nlit(s)=res%diagnostics%nonlinear_iterations
      lins(s)=res%diagnostics%linear_solves
      checksum=checksum+sum(hist_h(:,s))+sum(hist_t(:,s))+mass_int(s)
      req%base_state=res%candidate_state
    end do
  end subroutine run_trajectory

  subroutine prepare_request(req,use_analytic,h0,t0v)
    type(soil_water_solve_request_t),intent(out) :: req
    logical,intent(in) :: use_analytic
    real(real64),intent(in) :: h0(:),t0v(:)
    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%base_state%active_nodes=nodes
    allocate(req%base_state%pressure_head(nodes),req%base_state%water_content(nodes))
    req%base_state%pressure_head=h0; req%base_state%water_content=t0v
    req%base_state%ponding_depth=0.0_real64; req%base_state%groundwater_level=-200.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=2
    req%boundary%top_flux=qeq; req%boundary%bottom_flux=qeq; req%boundary%bottom_head=h0(nodes)
    req%numerical%max_iterations=12; req%numerical%max_backtracking=6
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-6_real64
    req%numerical%compartment_balance_tolerance=1.0e-10_real64
    req%numerical%total_balance_tolerance=1.0e-10_real64
    req%numerical%head_abs_tolerance=1.0e-10_real64; req%numerical%head_rel_tolerance=1.0e-10_real64
    req%numerical%ponding_tolerance=1.0e-10_real64; req%step_duration=step_duration
    if(use_analytic) then
      req%evaluation%constitutive=>analytic
    else
      req%evaluation%constitutive=>table
    end if
    req%evaluation%source_sink=>terms; req%evaluation%top_boundary=>top
  end subroutine prepare_request

  subroutine time_trajectory(use_analytic,seconds,checksum)
    logical,intent(in) :: use_analytic
    real(real64),intent(out) :: seconds
    real(real64),intent(inout) :: checksum
    real(real64) :: hh(numnod,NSTEPS),thh(numnod,NSTEPS),mn(NSTEPS),mi(NSTEPS),a,b
    integer :: ni(NSTEPS),li(NSTEPS),rr
    call cpu_time(a)
    do rr=1,NREPEAT
      call run_trajectory(use_analytic,hh,thh,mn,mi,ni,li,checksum)
    end do
    call cpu_time(b)
    seconds=b-a
  end subroutine time_trajectory

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

end program tabhyd_typed_reference_richards_dynamic
