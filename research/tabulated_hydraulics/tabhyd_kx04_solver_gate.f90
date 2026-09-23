program tabhyd_kx04_solver_gate
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
  implicit none

  integer, parameter :: NROUNDS=10, NREPEAT=300
  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: analytic
  type(tabhyd_kx03_provider_t), target :: table
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_boundary
  type(reference_richards_legacy_solver_t) :: solver_a, solver_t
  type(reference_richards_legacy_workspace_t) :: workspace_a, workspace_t
  type(soil_water_solve_request_t) :: req_a, req_t
  type(soil_water_solve_result_t) :: res_a, res_t
  real(real64), allocatable :: cofgen(:,:), headtab(:,:), thetatab(:,:), ktab(:,:)
  real(real64), target :: drainage(1,numnod), subsurface(numnod), root_sink(numnod)
  real(real64) :: ha(numnod), ht(numnod), tha(numnod), tht(numnod), ka(numnod), kt(numnod)
  real(real64) :: ca(numnod), ct(numnod), da(numnod), dtbl(numnod)
  real(real64) :: initial_head, step_duration, top_flux, bottom_flux, bottom_head, help, term1
  integer :: bottom_mode
  real(real64) :: max_h, rms_h, max_theta, rms_theta, dtop, dbot, dmass
  real(real64) :: atime(NROUNDS), ttime(NROUNDS), med_a, med_t, checksum_a, checksum_t
  real(real64) :: t0,t1
  character(len=512) :: path
  character(len=32) :: soil
  integer :: iu,ios,i,j,r,rep
  integer :: iter_a, iter_t, lin_a, lin_t

  if (command_argument_count()/=1) error stop 'usage: typed-solver-integration INPUT'
  call get_command_argument(1,path)
  open(newunit=iu,file=trim(path),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'cannot open integration input'
  read(iu,*,iostat=ios) i, j, step_duration, initial_head, top_flux, bottom_flux, bottom_mode, bottom_head
  if(ios/=0 .or. i/=numnod .or. j/=TABHYD_RAW_TABLE_N) error stop 'invalid integration header'

  allocate(cofgen(24,numnod),headtab(TABHYD_RAW_TABLE_N,numnod), &
       thetatab(TABHYD_RAW_TABLE_N,numnod),ktab(TABHYD_RAW_TABLE_N,numnod))
  cofgen=0.0_real64
  do i=1,numnod
    read(iu,*,iostat=ios) soil, cofgen(1,i),cofgen(2,i),cofgen(4,i),cofgen(6,i),cofgen(3,i),cofgen(5,i), &
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

  parameters%parameter_set_id=991001_int64
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z
  parameters%dz=dz
  parameters%node_distance=disnod(1:numnod)

  call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen,enable_ksatexm_extension=.true.)
  call bind_b110_default_mvg_provider(analytic,hydraulic_parameters,step_duration)
  call initialize_tabhyd_kx03_provider(table,headtab,thetatab,ktab,cofgen,step_duration)

  ha=initial_head
  ht=initial_head
  call analytic%evaluate(ha,tha,ka,ca,da)
  call table%evaluate(ht,tht,kt,ct,dtbl)
  call require(all(ieee_is_finite(tha)) .and. all(ieee_is_finite(tht)),'initial theta finite')
  call require(all(ka>0.0_real64) .and. all(kt>0.0_real64),'initial K positive')

  drainage=0.0_real64; subsurface=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,subsurface,root_sink)

  call build_request(req_a,analytic,tha)
  call build_request(req_t,table,tht)

  call solver_a%solve(req_a,workspace_a,res_a)
  call solver_t%solve(req_t,workspace_t,res_t)
  call require(res_a%status==SW_SOLVE_CONVERGED,'analytic solve converged')
  call require(res_t%status==SW_SOLVE_CONVERGED,'table solve converged')
  call compare_results()

  iter_a=res_a%diagnostics%nonlinear_iterations
  iter_t=res_t%diagnostics%nonlinear_iterations
  lin_a=res_a%diagnostics%linear_solves
  lin_t=res_t%diagnostics%linear_solves

  ! Warm-up.
  do rep=1,20
    call solver_a%solve(req_a,workspace_a,res_a)
    call solver_t%solve(req_t,workspace_t,res_t)
  end do

  checksum_a=0.0_real64; checksum_t=0.0_real64
  do r=1,NROUNDS
    if(mod(r,2)==1) then
      call cpu_time(t0)
      do rep=1,NREPEAT
        call solver_a%solve(req_a,workspace_a,res_a)
        checksum_a=checksum_a+res_a%candidate_state%pressure_head(1)+res_a%candidate_state%water_content(numnod)
      end do
      call cpu_time(t1); atime(r)=t1-t0

      call cpu_time(t0)
      do rep=1,NREPEAT
        call solver_t%solve(req_t,workspace_t,res_t)
        checksum_t=checksum_t+res_t%candidate_state%pressure_head(1)+res_t%candidate_state%water_content(numnod)
      end do
      call cpu_time(t1); ttime(r)=t1-t0
    else
      call cpu_time(t0)
      do rep=1,NREPEAT
        call solver_t%solve(req_t,workspace_t,res_t)
        checksum_t=checksum_t+res_t%candidate_state%pressure_head(1)+res_t%candidate_state%water_content(numnod)
      end do
      call cpu_time(t1); ttime(r)=t1-t0

      call cpu_time(t0)
      do rep=1,NREPEAT
        call solver_a%solve(req_a,workspace_a,res_a)
        checksum_a=checksum_a+res_a%candidate_state%pressure_head(1)+res_a%candidate_state%water_content(numnod)
      end do
      call cpu_time(t1); atime(r)=t1-t0
    end if
    write(*,'(a,i0,a,es16.8,a,es16.8)') 'KX04_SOLVER_BLOCK round=',r,' analytic_s=',atime(r),' table_s=',ttime(r)
  end do

  med_a=median_small(atime)
  med_t=median_small(ttime)
  write(*,'(a,es24.16)') 'KX04_SOLVER_DH_MAX=',max_h
  write(*,'(a,es24.16)') 'KX04_SOLVER_DH_RMS=',rms_h
  write(*,'(a,es24.16)') 'KX04_SOLVER_DTHETA_MAX=',max_theta
  write(*,'(a,es24.16)') 'KX04_SOLVER_DTHETA_RMS=',rms_theta
  write(*,'(a,es24.16)') 'KX04_SOLVER_DQTOP=',dtop
  write(*,'(a,es24.16)') 'KX04_SOLVER_DQBOT=',dbot
  write(*,'(a,es24.16)') 'KX04_SOLVER_DMASS=',dmass
  write(*,'(a,i0)') 'KX04_SOLVER_ANALYTIC_NONLINEAR_ITERS=',iter_a
  write(*,'(a,i0)') 'KX04_SOLVER_TABLE_NONLINEAR_ITERS=',iter_t
  write(*,'(a,i0)') 'KX04_SOLVER_ANALYTIC_LINEAR_SOLVES=',lin_a
  write(*,'(a,i0)') 'KX04_SOLVER_TABLE_LINEAR_SOLVES=',lin_t
  write(*,'(a,es24.16)') 'KX04_SOLVER_ANALYTIC_MEDIAN_S=',med_a
  write(*,'(a,es24.16)') 'KX04_SOLVER_TABLE_MEDIAN_S=',med_t
  write(*,'(a,f14.8)') 'KX04_SOLVER_TABLE_DELTA_PCT=',100.0_real64*(med_t/med_a-1.0_real64)
  write(*,'(a,es24.16)') 'KX04_SOLVER_ANALYTIC_CHECKSUM=',checksum_a
  write(*,'(a,es24.16)') 'KX04_SOLVER_TABLE_CHECKSUM=',checksum_t
  write(*,'(a)') 'KX04_TYPED_RICHARDS=PASS'

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
    class default
      error stop 'unsupported provider type'
    end select
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_boundary
  end subroutine build_request

  subroutine compare_results()
    real(real64) :: dh(numnod),dtheta(numnod)
    dh=res_t%candidate_state%pressure_head-res_a%candidate_state%pressure_head
    dtheta=res_t%candidate_state%water_content-res_a%candidate_state%water_content
    max_h=maxval(abs(dh))
    rms_h=sqrt(sum(dh*dh)/real(numnod,real64))
    max_theta=maxval(abs(dtheta))
    rms_theta=sqrt(sum(dtheta*dtheta)/real(numnod,real64))
    dtop=abs(res_t%top_flux-res_a%top_flux)
    dbot=abs(res_t%bottom_flux-res_a%bottom_flux)
    dmass=abs(res_t%integrated_mass_balance_residual_cm-res_a%integrated_mass_balance_residual_cm)
    call require(max_h<=5.0e-2_real64,'head fidelity')
    call require(rms_h<=1.0e-2_real64,'head rms fidelity')
    call require(max_theta<=2.0e-2_real64,'theta fidelity')
    call require(abs(res_a%integrated_mass_balance_residual_cm)<=1.0e-8_real64,'analytic mass')
    call require(abs(res_t%integrated_mass_balance_residual_cm)<=1.0e-8_real64,'table mass')
  end subroutine compare_results

  real(real64) function median_small(v) result(m)
    real(real64), intent(in) :: v(:)
    real(real64) :: x(size(v)),tmp
    integer :: a,b
    x=v
    do a=1,size(x)-1
      do b=a+1,size(x)
        if(x(b)<x(a)) then
          tmp=x(a); x(a)=x(b); x(b)=tmp
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
      write(*,'(a,1x,a)') 'KX04_SOLVER_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program tabhyd_kx04_solver_gate
