program tabhyd_kx06_solver_gate
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_tabhyd_raw_typed_provider_research, only: TABHYD_RAW_TABLE_N
  use mod_tabhyd_kx03_typed_provider_research, only: tabhyd_kx03_provider_t, initialize_tabhyd_kx03_provider
  use mod_tabhyd_kx05_typed_provider_research, only: tabhyd_kx05_provider_t, initialize_tabhyd_kx05_provider
  implicit none

  integer, parameter :: NROUNDS=8, NREPEAT=300
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: analytic
  type(tabhyd_kx03_provider_t), target :: kx03
  type(tabhyd_kx05_provider_t), target :: kx05
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  type(reference_richards_legacy_solver_t) :: solver_a, solver_3, solver_5
  type(reference_richards_legacy_workspace_t) :: workspace_a, workspace_3, workspace_5
  type(soil_water_solve_request_t) :: req_a, req_3, req_5
  type(soil_water_solve_result_t) :: res_a, res_3, res_5
  real(real64), allocatable :: cofgen(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64), target :: drainage(1,numnod), subsurface(numnod), root_sink(numnod)
  real(real64) :: h0a(numnod), h03(numnod), h05(numnod)
  real(real64) :: tha(numnod), th3(numnod), th5(numnod), ka(numnod), k3(numnod), k5(numnod)
  real(real64) :: ca(numnod), c3(numnod), c5(numnod), da(numnod), d3(numnod), d5(numnod)
  real(real64) :: initial_head, step_duration, top_flux, bottom_flux, bottom_head, help, term1
  integer :: bottom_mode
  real(real64) :: h3max,h5max,t3max,t5max,m3diff,m5diff
  real(real64) :: atime(NROUNDS),t3time(NROUNDS),t5time(NROUNDS)
  real(real64) :: meda,med3,med5,csuma,csum3,csum5,t0,t1
  character(len=512) :: path
  character(len=32) :: soil
  integer :: iu,ios,i,j,r,rep

  if(command_argument_count()/=1) error stop 'usage: kx06 INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open input'
  read(iu,*,iostat=ios) i,j,step_duration,initial_head,top_flux,bottom_flux,bottom_mode,bottom_head
  if(ios/=0 .or. i/=numnod .or. j/=TABHYD_RAW_TABLE_N) error stop 'invalid input header'

  allocate(cofgen(24,numnod),headtab(TABHYD_RAW_TABLE_N,numnod), &
       thetatab(TABHYD_RAW_TABLE_N,numnod),ktab(TABHYD_RAW_TABLE_N,numnod))
  cofgen=0.0_real64
  do i=1,numnod
    read(iu,*,iostat=ios) soil,cofgen(1,i),cofgen(2,i),cofgen(4,i),cofgen(6,i),cofgen(3,i),cofgen(5,i), &
         cofgen(9,i),cofgen(10,i)
    if(ios/=0) error stop 'invalid material row'
    cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i)
    cofgen(8,i)=cofgen(4,i)
    help=abs((-2.0_real64)*cofgen(4,i))**cofgen(6,i)
    help=(1.0_real64+help)**cofgen(7,i)
    cofgen(11,i)=1.0_real64/help
    term1=(1.0_real64-cofgen(11,i)**(1.0_real64/cofgen(7,i)))**cofgen(7,i)
    cofgen(12,i)=cofgen(3,i)*(cofgen(11,i)**cofgen(5,i))*(1.0_real64-term1)*(1.0_real64-term1)
    cofgen(22,i)=-1.0e6_real64
    cofgen(23,i)=1.0e-12_real64
    do j=1,TABHYD_RAW_TABLE_N
      read(iu,*,iostat=ios) headtab(j,i),thetatab(j,i),ktab(j,i)
      if(ios/=0) error stop 'invalid table row'
    end do
  end do
  close(iu)

  parameters%parameter_set_id=991006_int64
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod)

  call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen,enable_ksatexm_extension=.true.)
  call bind_b110_default_mvg_provider(analytic,hydraulic_parameters,step_duration)
  call initialize_tabhyd_kx03_provider(kx03,headtab,thetatab,ktab,cofgen,step_duration)
  call initialize_tabhyd_kx05_provider(kx05,headtab,thetatab,ktab,cofgen,step_duration)

  h0a=initial_head; h03=initial_head; h05=initial_head
  call analytic%evaluate(h0a,tha,ka,ca,da)
  call kx03%evaluate(h03,th3,k3,c3,d3)
  call kx05%evaluate(h05,th5,k5,c5,d5)
  call require(all(ieee_is_finite(tha)) .and. all(ieee_is_finite(th3)) .and. all(ieee_is_finite(th5)),'initial theta finite')
  call require(all(ka>0.0_real64) .and. all(k3>0.0_real64) .and. all(k5>0.0_real64),'initial K positive')

  drainage=0.0_real64; subsurface=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)
  call build_request(req_a,analytic,tha)
  call build_request(req_3,kx03,th3)
  call build_request(req_5,kx05,th5)

  call solver_a%solve(req_a,workspace_a,res_a)
  call solver_3%solve(req_3,workspace_3,res_3)
  call solver_5%solve(req_5,workspace_5,res_5)
  call require(res_a%status==SW_SOLVE_CONVERGED,'analytic solve')
  call require(res_3%status==SW_SOLVE_CONVERGED,'KX03 solve')
  call require(res_5%status==SW_SOLVE_CONVERGED,'KX05 solve')
  call compare_one(res_3,h3max,t3max,m3diff,'KX03')
  call compare_one(res_5,h5max,t5max,m5diff,'KX05')
  call require(res_a%diagnostics%nonlinear_iterations==res_3%diagnostics%nonlinear_iterations,'KX03 nonlinear count')
  call require(res_a%diagnostics%nonlinear_iterations==res_5%diagnostics%nonlinear_iterations,'KX05 nonlinear count')
  call require(res_a%diagnostics%linear_solves==res_3%diagnostics%linear_solves,'KX03 linear count')
  call require(res_a%diagnostics%linear_solves==res_5%diagnostics%linear_solves,'KX05 linear count')

  do rep=1,20
    call solver_a%solve(req_a,workspace_a,res_a)
    call solver_3%solve(req_3,workspace_3,res_3)
    call solver_5%solve(req_5,workspace_5,res_5)
  end do

  csuma=0.0_real64; csum3=0.0_real64; csum5=0.0_real64
  do r=1,NROUNDS
    select case(mod(r-1,3))
    case(0)
      call time_a(atime(r)); call time_3(t3time(r)); call time_5(t5time(r))
    case(1)
      call time_5(t5time(r)); call time_a(atime(r)); call time_3(t3time(r))
    case default
      call time_3(t3time(r)); call time_5(t5time(r)); call time_a(atime(r))
    end select
    write(*,'(a,i0,3(a,es16.8))') 'KX06_BLOCK round=',r,' analytic_s=',atime(r),' kx03_s=',t3time(r),' kx05_s=',t5time(r)
  end do

  meda=median_small(atime); med3=median_small(t3time); med5=median_small(t5time)
  write(*,'(a,es24.16)') 'KX06_KX03_DH_MAX=',h3max
  write(*,'(a,es24.16)') 'KX06_KX05_DH_MAX=',h5max
  write(*,'(a,es24.16)') 'KX06_KX03_DTHETA_MAX=',t3max
  write(*,'(a,es24.16)') 'KX06_KX05_DTHETA_MAX=',t5max
  write(*,'(a,es24.16)') 'KX06_KX03_DMASS=',m3diff
  write(*,'(a,es24.16)') 'KX06_KX05_DMASS=',m5diff
  write(*,'(a,i0)') 'KX06_ANALYTIC_NONLINEAR_ITERS=',res_a%diagnostics%nonlinear_iterations
  write(*,'(a,i0)') 'KX06_KX03_NONLINEAR_ITERS=',res_3%diagnostics%nonlinear_iterations
  write(*,'(a,i0)') 'KX06_KX05_NONLINEAR_ITERS=',res_5%diagnostics%nonlinear_iterations
  write(*,'(a,i0)') 'KX06_ANALYTIC_LINEAR_SOLVES=',res_a%diagnostics%linear_solves
  write(*,'(a,i0)') 'KX06_KX03_LINEAR_SOLVES=',res_3%diagnostics%linear_solves
  write(*,'(a,i0)') 'KX06_KX05_LINEAR_SOLVES=',res_5%diagnostics%linear_solves
  write(*,'(a,es24.16)') 'KX06_ANALYTIC_MEDIAN_S=',meda
  write(*,'(a,es24.16)') 'KX06_KX03_MEDIAN_S=',med3
  write(*,'(a,es24.16)') 'KX06_KX05_MEDIAN_S=',med5
  write(*,'(a,f14.8)') 'KX06_KX03_DELTA_VS_ANALYTIC_PCT=',100.0_real64*(med3/meda-1.0_real64)
  write(*,'(a,f14.8)') 'KX06_KX05_DELTA_VS_ANALYTIC_PCT=',100.0_real64*(med5/meda-1.0_real64)
  write(*,'(a,f14.8)') 'KX06_KX05_DELTA_VS_KX03_PCT=',100.0_real64*(med5/med3-1.0_real64)
  write(*,'(a)') 'KX06_TYPED_RICHARDS=PASS'

contains
  subroutine build_request(req,provider,theta0)
    type(soil_water_solve_request_t), intent(out) :: req
    class(*), target, intent(inout) :: provider
    real(real64), intent(in) :: theta0(:)
    req=soil_water_solve_request_t()
    req%parameters=>parameters
    req%base_state%active_nodes=numnod
    allocate(req%base_state%pressure_head(numnod),req%base_state%water_content(numnod))
    req%base_state%pressure_head=initial_head
    req%base_state%water_content=theta0
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=bottom_mode
    req%boundary%top_flux=top_flux
    req%boundary%bottom_flux=bottom_flux
    req%boundary%top_head=initial_head
    req%boundary%bottom_head=bottom_head
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=1.0e-10_real64
    req%numerical%total_balance_tolerance=1.0e-10_real64
    req%numerical%head_abs_tolerance=1.0e-10_real64
    req%numerical%head_rel_tolerance=1.0e-10_real64
    req%numerical%ponding_tolerance=1.0e-10_real64
    req%step_duration=step_duration
    req%request_interface_sensitivity=.false.
    select type(provider)
    type is (b110_default_mvg_provider_t)
      req%evaluation%constitutive=>provider
    type is (tabhyd_kx03_provider_t)
      req%evaluation%constitutive=>provider
    type is (tabhyd_kx05_provider_t)
      req%evaluation%constitutive=>provider
    class default
      error stop 'KX06 unsupported provider'
    end select
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_boundary
  end subroutine build_request

  subroutine compare_one(res,hmax,tmax,mdiff,label)
    type(soil_water_solve_result_t), intent(in) :: res
    real(real64), intent(out) :: hmax,tmax,mdiff
    character(len=*), intent(in) :: label
    hmax=maxval(abs(res%candidate_state%pressure_head-res_a%candidate_state%pressure_head))
    tmax=maxval(abs(res%candidate_state%water_content-res_a%candidate_state%water_content))
    mdiff=abs(res%integrated_mass_balance_residual_cm-res_a%integrated_mass_balance_residual_cm)
    call require(hmax<=5.0e-2_real64,trim(label)//' head fidelity')
    call require(tmax<=2.0e-2_real64,trim(label)//' theta fidelity')
    call require(abs(res%integrated_mass_balance_residual_cm)<=1.0e-8_real64,trim(label)//' mass')
  end subroutine compare_one

  subroutine time_a(x)
    real(real64),intent(out)::x
    integer::q
    call cpu_time(t0)
    do q=1,NREPEAT
      call solver_a%solve(req_a,workspace_a,res_a)
      csuma=csuma+res_a%candidate_state%pressure_head(1)
    end do
    call cpu_time(t1); x=t1-t0
  end subroutine time_a

  subroutine time_3(x)
    real(real64),intent(out)::x
    integer::q
    call cpu_time(t0)
    do q=1,NREPEAT
      call solver_3%solve(req_3,workspace_3,res_3)
      csum3=csum3+res_3%candidate_state%pressure_head(1)
    end do
    call cpu_time(t1); x=t1-t0
  end subroutine time_3

  subroutine time_5(x)
    real(real64),intent(out)::x
    integer::q
    call cpu_time(t0)
    do q=1,NREPEAT
      call solver_5%solve(req_5,workspace_5,res_5)
      csum5=csum5+res_5%candidate_state%pressure_head(1)
    end do
    call cpu_time(t1); x=t1-t0
  end subroutine time_5

  real(real64) function median_small(v) result(m)
    real(real64),intent(in)::v(:)
    real(real64)::x(size(v)),tmp
    integer::a,b
    x=v
    do a=1,size(x)-1
      do b=a+1,size(x)
        if(x(b)<x(a)) then
          tmp=x(a);x(a)=x(b);x(b)=tmp
        end if
      end do
    end do
    if(mod(size(x),2)==0) then
      m=0.5_real64*(x(size(x)/2)+x(size(x)/2+1))
    else
      m=x((size(x)+1)/2)
    end if
  end function median_small

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok) then
      write(*,'(a,1x,a)') 'KX06_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program tabhyd_kx06_solver_gate
