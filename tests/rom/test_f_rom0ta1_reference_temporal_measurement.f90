program test_f_rom0ta1_reference_temporal_measurement
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_temporal_indicator_request_t, &
       soil_water_temporal_indicator_result_t, SW_SOLVE_CONVERGED, SW_TEMPORAL_INDICATOR_AVAILABLE
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: epsilon_fraction=0.01_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  real(real64), parameter :: full_dt_values(2)=[0.0016_real64,0.0008_real64]
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=12), parameter :: cases(2)=[character(len=12) :: 'TOP_PLUS','TOP_MINUS']

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  real(real64), target :: drainage(1,numnod), irrigation(numnod), root_sink(numnod)
  real(real64) :: cofgen(24,numnod)
  integer :: imat,icase,idt,rows

  call require(numnod==16,'geometry frozen at 16 nodes')
  drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
  call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

  rows=0
  do imat=1,size(materials)
    call configure_material(trim(materials(imat)),parameters,cofgen)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    do icase=1,size(cases)
      do idt=1,size(full_dt_values)
        call run_row(trim(materials(imat)),trim(cases(icase)),full_dt_values(idt))
        rows=rows+1
      end do
    end do
  end do
  call require(rows==8,'complete preregistered matrix')
  write(*,'(A,I0)') 'F_ROM0TA1_ROWS=',rows
  write(*,'(A)') 'F_ROM0TA1_GATE=PASS'

contains

  subroutine run_row(material_id,case_id,full_dt)
    character(len=*),intent(in) :: material_id,case_id
    real(real64),intent(in) :: full_dt
    type(reference_richards_legacy_workspace_t) :: ws_full,ws_half1,ws_half2
    real(real64) :: half_dt,h0,k0,qeq,qtop
    real(real64) :: seed_h(numnod),seed_theta(numnod),seed_k(numnod),seed_c(numnod),seed_dkdh(numnod)
    real(real64) :: full_h(numnod),full_theta(numnod),half1_h(numnod),half1_theta(numnod),half2_h(numnod),half2_theta(numnod)
    real(real64),allocatable :: deriv_full(:),deriv_half1(:),deriv_half2(:)
    real(real64) :: zero_prev(numnod)
    real(real64) :: full_pond,half1_pond,half2_pond,full_top,full_bottom,half1_top,half1_bottom,half2_top,half2_bottom
    real(real64) :: full_mass,half1_mass,half2_mass,full_binf,half1_binf,half2_binf
    real(real64) :: s0,sfull,shalf,actual_dh,actual_dtheta,dstorage,dqtop,dqbot
    real(real64) :: full_in,full_out,h1_in,h1_out,h2_in,h2_out,two_half_mass,guard,ratio
    integer :: full_nl,full_bt,full_lin,h1_nl,h1_bt,h1_lin,h2_nl,h2_bt,h2_lin,conservative

    half_dt=0.5_real64*full_dt
    call seed_state(h0,k0,seed_h,seed_theta,seed_k,seed_c,seed_dkdh)
    qeq=-k0
    select case(trim(case_id))
    case('TOP_PLUS')
      qtop=qeq+epsilon_fraction*k0
    case('TOP_MINUS')
      qtop=qeq-epsilon_fraction*k0
    case default
      call require(.false.,'known perturbation case')
    end select
    zero_prev=0.0_real64

    call solve_measure(seed_h,seed_theta,0.0_real64,full_dt,qtop,qeq,zero_prev,ws_full, &
         full_h,full_theta,full_pond,full_top,full_bottom,full_mass,full_binf,deriv_full, &
         full_nl,full_bt,full_lin)

    call solve_measure(seed_h,seed_theta,0.0_real64,half_dt,qtop,qeq,zero_prev,ws_half1, &
         half1_h,half1_theta,half1_pond,half1_top,half1_bottom,half1_mass,half1_binf,deriv_half1, &
         h1_nl,h1_bt,h1_lin)

    call solve_measure(half1_h,half1_theta,half1_pond,half_dt,qtop,qeq,deriv_half1,ws_half2, &
         half2_h,half2_theta,half2_pond,half2_top,half2_bottom,half2_mass,half2_binf,deriv_half2, &
         h2_nl,h2_bt,h2_lin)

    s0=sum(seed_theta*parameters%dz)
    sfull=sum(full_theta*parameters%dz)+full_pond
    shalf=sum(half2_theta*parameters%dz)+half2_pond
    actual_dh=maxval(abs(full_h-half2_h))
    actual_dtheta=maxval(abs(full_theta-half2_theta))
    dstorage=sfull-shalf
    dqtop=full_top-half2_top
    dqbot=full_bottom-half2_bottom

    call flux_ledger(full_top,full_bottom,full_dt,full_in,full_out)
    call flux_ledger(half1_top,half1_bottom,half_dt,h1_in,h1_out)
    call flux_ledger(half2_top,half2_bottom,half_dt,h2_in,h2_out)
    two_half_mass=shalf-s0-((h1_in+h2_in)-(h1_out+h2_out))

    call require(abs(full_mass)<=hard_mass_gate,'full solver hard mass gate')
    call require(abs(half1_mass)<=hard_mass_gate,'half1 solver hard mass gate')
    call require(abs(half2_mass)<=hard_mass_gate,'half2 solver hard mass gate')
    call require(abs(sfull-s0-(full_in-full_out))<=hard_mass_gate,'full ledger hard mass gate')
    call require(abs(two_half_mass)<=hard_mass_gate,'two-half ledger hard mass gate')
    call require(all(ieee_is_finite(full_h)).and.all(ieee_is_finite(half2_h)),'finite heads')
    call require(all(ieee_is_finite(full_theta)).and.all(ieee_is_finite(half2_theta)),'finite theta')
    call require(ieee_is_finite(actual_dh).and.ieee_is_finite(actual_dtheta).and.ieee_is_finite(dstorage),'finite differences')

    guard=65536.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(full_binf),abs(actual_dh))
    conservative=merge(1,0,full_binf+guard>=actual_dh)
    if(actual_dh>guard) then
      ratio=full_binf/actual_dh
    else if(full_binf<=guard) then
      ratio=1.0_real64
    else
      ratio=huge(1.0_real64)
    end if

    write(*,'(*(g0))') 'F_ROM0TA1_ROW|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|FULL_DT=',full_dt,'|HALF_DT=',half_dt,'|H0=',h0,'|K0=',k0,'|QEQ=',qeq,'|QTOP=',qtop, &
         '|BINF_FULL=',full_binf,'|BINF_HALF1=',half1_binf,'|BINF_HALF2=',half2_binf, &
         '|DH=',actual_dh,'|DTHETA=',actual_dtheta,'|DSTORAGE=',dstorage,'|DQTOP=',dqtop,'|DQBOT=',dqbot, &
         '|MASS_FULL=',full_mass,'|MASS_TWO_HALF=',two_half_mass, &
         '|FULL_NL=',full_nl,'|HALF_NL=',h1_nl+h2_nl,'|FULL_BT=',full_bt,'|HALF_BT=',h1_bt+h2_bt, &
         '|FULL_LINEAR=',full_lin,'|HALF_LINEAR=',h1_lin+h2_lin,'|RATIO_BINF_DH=',ratio,'|CONSERVATIVE=',conservative
  end subroutine run_row

  subroutine solve_measure(base_h,base_theta,base_pond,step_dt,qtop,qbot,previous_derivative,workspace, &
                           out_h,out_theta,out_pond,out_top,out_bottom,out_mass,out_binf,current_derivative, &
                           nonlinear,backtracks,linears)
    real(real64),intent(in) :: base_h(:),base_theta(:),base_pond,step_dt,qtop,qbot,previous_derivative(:)
    type(reference_richards_legacy_workspace_t),intent(inout) :: workspace
    real(real64),intent(out) :: out_h(:),out_theta(:),out_pond,out_top,out_bottom,out_mass,out_binf
    real(real64),allocatable,intent(out) :: current_derivative(:)
    integer,intent(out) :: nonlinear,backtracks,linears
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_temporal_indicator_request_t) :: indicator_request
    type(soil_water_temporal_indicator_result_t) :: indicator

    call require(size(base_h)==numnod.and.size(base_theta)==numnod,'solve base shape')
    call require(size(previous_derivative)==numnod,'solve predecessor derivative shape')
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,step_dt)

    request=soil_water_solve_request_t()
    request%parameters=>parameters
    request%base_state%active_nodes=numnod
    allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
    request%base_state%pressure_head=base_h
    request%base_state%water_content=base_theta
    request%base_state%ponding_depth=base_pond
    request%base_state%groundwater_level=-999.0_real64
    request%step_duration=step_dt
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=2
    request%boundary%top_flux=qtop
    request%boundary%top_head=base_h(1)
    request%boundary%bottom_flux=qbot
    request%boundary%bottom_head=-999999.0_real64
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=16
    request%numerical%max_backtracking=8
    request%numerical%conductivity_implicit_mode=0
    request%numerical%conductivity_mean_method=1
    request%numerical%min_step_duration=1.0e-8_real64
    request%numerical%compartment_balance_tolerance=hard_mass_gate
    request%numerical%total_balance_tolerance=hard_mass_gate
    request%numerical%head_abs_tolerance=hard_mass_gate
    request%numerical%head_rel_tolerance=hard_mass_gate
    request%numerical%ponding_tolerance=hard_mass_gate
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    request%evaluation%top_boundary=>top_provider

    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_CONVERGED,'direct Reference solve converged')
    call require(result%candidate_state%active_nodes==numnod,'candidate node count')
    call require(allocated(result%candidate_state%pressure_head).and.allocated(result%candidate_state%water_content), &
         'candidate arrays allocated')

    indicator_request%previous_right_derivative_available=.true.
    allocate(indicator_request%previous_right_derivative(numnod))
    indicator_request%previous_right_derivative=previous_derivative
    call solver%evaluate_temporal_indicator(request,result,indicator_request,workspace,indicator)
    call require(indicator%status==SW_TEMPORAL_INDICATOR_AVAILABLE.and.indicator%available,'F-SI38 indicator available')
    call require(allocated(indicator%current_right_derivative),'current derivative materialized')
    call require(size(indicator%current_right_derivative)==numnod,'current derivative shape')
    call require(all(ieee_is_finite(indicator%current_right_derivative)),'finite current derivative')
    call require(ieee_is_finite(indicator%head_inf_bound).and.indicator%head_inf_bound>=0.0_real64,'finite Binf')

    out_h=result%candidate_state%pressure_head
    out_theta=result%candidate_state%water_content
    out_pond=result%candidate_state%ponding_depth
    out_top=result%top_flux
    out_bottom=result%bottom_flux
    out_mass=result%unrounded_mass_balance_residual
    out_binf=indicator%head_inf_bound
    allocate(current_derivative(numnod))
    current_derivative=indicator%current_right_derivative
    nonlinear=result%diagnostics%nonlinear_iterations
    backtracks=result%diagnostics%backtracking_attempts
    linears=result%diagnostics%linear_solves
  end subroutine solve_measure

  subroutine flux_ledger(top_flux,bottom_flux,dt,total_in,total_out)
    real(real64),intent(in) :: top_flux,bottom_flux,dt
    real(real64),intent(out) :: total_in,total_out
    total_in=max(0.0_real64,-top_flux)*dt+max(0.0_real64,bottom_flux)*dt
    total_out=max(0.0_real64,top_flux)*dt+max(0.0_real64,-bottom_flux)*dt
  end subroutine flux_ledger

  subroutine seed_state(h0,k0,heads,water,conductivity,capacity,dkdh)
    real(real64),intent(out) :: h0,k0
    real(real64),intent(out) :: heads(:),water(:),conductivity(:),capacity(:),dkdh(:)
    real(real64) :: m
    m=1.0_real64-1.0_real64/cofgen(6,1)
    h0=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/cofgen(6,1))/cofgen(4,1)
    heads=h0
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,full_dt_values(1))
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)).and.all(ieee_is_finite(conductivity)), &
         'finite R1 seed')
  end subroutine seed_state

  subroutine configure_material(id,p,c)
    character(len=*),intent(in) :: id
    type(soil_water_parameter_set_t),target,intent(inout) :: p
    real(real64),intent(out) :: c(24,numnod)
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: i
    if(allocated(p%z)) deallocate(p%z)
    if(allocated(p%dz)) deallocate(p%dz)
    if(allocated(p%node_distance)) deallocate(p%node_distance)
    select case(trim(id))
    case('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64
      nn=1.734737_real64; ks=31.225016_real64; lam=0.98087_real64
    case('B14')
      tr=0.01_real64; ts=0.416774_real64; alpha=0.00541_real64
      nn=1.301528_real64; ks=0.895023_real64; lam=-0.334926_real64
    case default
      call require(.false.,'known material')
      tr=0.0_real64; ts=0.0_real64; alpha=0.0_real64; nn=2.0_real64; ks=0.0_real64; lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=930001_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod)
    c=0.0_real64
    do i=1,numnod
      c(1,i)=tr; c(2,i)=ts; c(3,i)=ks; c(4,i)=alpha; c(5,i)=lam; c(6,i)=nn
      c(7,i)=mm; c(8,i)=alpha; c(9,i)=0.0_real64; c(10,i)=ks
      c(11,i)=0.999_real64; c(12,i)=0.99_real64*ks
      c(22,i)=-1.0e6_real64; c(23,i)=1.0e-12_real64
    end do
  end subroutine configure_material

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'F_ROM0TA1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_f_rom0ta1_reference_temporal_measurement
