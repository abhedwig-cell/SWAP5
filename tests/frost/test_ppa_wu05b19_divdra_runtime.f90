program test_b19_divdra_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_serialized_reference_backend, only: fmr_frost_divdra_forcing_valid
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_temperature_contract, only: initialize_soil_temperature_state
  use mod_restricted_soil_temperature, only: initialize_soil_temperature_parameters
  use mod_soil_temperature_contract, only: copy_soil_temperature_profile
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK
  use mod_fmr_committed_restart, only: fmr_restart_template_identity_matches
  use mod_fmr_production_application_bootstrap
  use mod_frost_hydraulic_effect, only: frost_hydraulic_parameters_t, evaluate_frost_hydraulic_factor
  use mod_frost_divdra_drainage_effect, only: frost_divdra_parameters_t, frost_divdra_result_t, &
       compose_single_level_signed_frost_divdra, valid_frost_divdra_parameters
  use mod_frost_geometry_effect, only: frost_geometry_result_t, evaluate_legacy_bracketed_frost_geometry
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  real(real64),parameter::h0=-75._real64,equilibrium_dt=.25_real64,upward_dt=1.e-4_real64
  real(real64),parameter::hard_mass_gate=1.e-12_real64,qualification_head_budget=2.5e-11_real64
  integer(int64),parameter::column_id=440044_int64
  type(fmr_b110_physical_parameters_t)::p,badp
  type(fmr_b110_physical_forcing_t)::f,badf
  type(fmr_b110_physical_state_t)::initial,final,again,direct,next,restart_a,restart_b
  type(fmr_serialized_column_result_t)::out,repeated,fine
  type(fmr_serialized_physical_observation_t)::obs
  type(kernel_committed_state_t)::captured,restored(1),registry(1)
  type(fmr_logical_column_t)::columns(1)
  type(fmr_template_t)::templates(1)
  type(fmr_committed_restart_bundle_t)::bundle
  real(real64),allocatable::ta(:),tb(:)
  real(real64)::scalar,bottom,duration,dt,integrated,head_error,temp_error,expected_sum
  integer::air,signum,separate,blocking,status,i,nfine,invalid,case_count,requested_case,bsign
  logical::ok,low_air_expected
  character(len=16)::arg
  requested_case=0;call get_command_argument(1,arg)
  if(len_trim(arg)>0)read(arg,*)requested_case
  call get_command_argument(2,arg)
  nfine=8192
  if(len_trim(arg)>0)read(arg,*)nfine
  case_count=0;duration=1.e-4_real64
  do air=1,2
  do signum=-1,1
  do separate=0,1
    if(signum>=0.and.separate==1)cycle
  do blocking=0,1
    if(air==1.and.blocking==1)cycle
  do bsign=-1,1,2
    case_count=case_count+1
    if(requested_case/=0.and.case_count/=requested_case)cycle
    call configure_case(p,f,initial,air,signum,separate,blocking)
    f%bottom_flux=.001_real64*real(bsign,real64)
    scalar=f%frost_divdra_scalar_cm_per_day;bottom=f%bottom_flux
    low_air_expected=air==2
    call run(p,f,initial,0._real64,duration,out,obs,final,captured)
    print *, 'B19_DEBUG',case_count,out%completed,out%committed,out%admitted, &
         out%accepted_substeps,out%solver_rejections,out%temporal_rejections, &
         obs%solver_executed,obs%frost_divdra_executed,obs%frost_divdra%status,obs%frost_divdra%low_air
    call require(out%completed.and.out%committed,'signed DIVDRA runtime commits')
    call require(obs%frost_divdra_executed.and.obs%frost_divdra%available,'actual component execution')
    call require(obs%frost_divdra%low_air.eqv.low_air_expected,'normal versus low-air branch')
    call require(obs%frost_divdra%blocked.eqv.(blocking==1),'strict bottom-depth blockage branch')
    call require(obs%frost_divdra_mass_accounted_in_trial,'one nodal accounting provenance')
    call require(obs%frost_divdra_raw_scalar==scalar,'raw scalar provenance')
    call require(out%mass%complete.and.abs(out%mass%residual)<=hard_mass_gate,'hard mass gate')
    print '(A,I0,A,ES24.16)', 'B19_HARD_MASS case=',case_count,' residual=',out%mass%residual
    call require(out%temporal_rejections>0,'actual full-half refinement')
    call run(p,f,initial,0._real64,duration,repeated,obs,again)
    call require(repeated%committed.and.all(final%pressure_head==again%pressure_head),'fresh worker replay')
    call require(out%mass%total_in==repeated%mass%total_in.and.out%mass%total_out==repeated%mass%total_out,'replay accounting')
    direct=initial;integrated=0._real64;dt=duration/real(nfine,real64)
    do i=1,nfine
      call run(p,f,direct,real(i-1,real64)*dt,dt,fine,obs,next)
      call require(fine%committed,'direct fine continuation')
      call require(obs%frost_divdra_start_gwl==direct%groundwater_level,'immutable start GWL')
      expected_sum=independent_total(p,f,direct)
      ! Last observation is the second half trial, hence differs from the
      ! original-start proposal only by the predeclared local physical error.
      call require(abs(obs%frost_divdra%final_scalar-expected_sum)<=1.e-8_real64,'independent literal scalar oracle')
      call require(abs(fine%mass%storage_change-(obs%bottom_flux-expected_sum)*dt)<=hard_mass_gate,'independent storage oracle')
      call require(abs(obs%frost_divdra_signed_exchange_native-sum(obs%frost_divdra%final_nodal_sink)*obs%frost_divdra_trial_duration)<=hard_mass_gate, &
           'native receipt uses final nodes and actual trial duration')
      integrated=integrated+(obs%bottom_flux-expected_sum)*dt
      direct=next
    end do
    call copy_soil_temperature_profile(final%soil_temperature,ta,status)
    call require(status==0,'accepted thermal state')
    call copy_soil_temperature_profile(direct%soil_temperature,tb,status)
    call require(status==0,'fine thermal state')
    head_error=maxval(abs(final%pressure_head-direct%pressure_head));temp_error=maxval(abs(ta-tb))
    call require(head_error<=1.e-6_real64.and.temp_error<=1.e-4_real64,'fine cumulative envelope')
    call require(abs(out%mass%storage_change-integrated)<=1.e-10_real64,'fine integrated storage and drainage')
    print '(A,I0,A,ES14.6,A,ES14.6,A,I0)','B19_FINE_COMPARISON case=',case_count,' head=',head_error, &
         ' temperature=',temp_error,' retries=',out%temporal_rejections
    call identities(columns(1),templates(1))
    registry(1)=captured
    call fmr_export_committed_restart(columns,templates,registry,p%parameter_set_id,bundle,ok,status)
    call require(ok.and.status==FMR_RESTART_OK,'actual committed restart export')
    restored=kernel_committed_state_t()
    call fmr_restore_committed_restart(bundle,p%parameter_set_id,columns,templates,restored,ok,status)
    call require(ok.and.status==FMR_RESTART_OK,'restart restore empty registry')
    call run(p,f,final,duration,duration,out,obs,restart_a,resumed=captured)
    call run(p,f,final,duration,duration,repeated,obs,restart_b,resumed=restored(1))
    call require(out%committed.and.repeated%committed,'restart continuation')
    call require(all(restart_a%pressure_head==restart_b%pressure_head),'restart pressure bit identity')
    call require(out%mass%storage_change==repeated%mass%storage_change,'restart accounting bit identity')
    call application(p,f,initial)
    print '(A,I0,A)','B19_CASE_',case_count,'_RUNTIME=PASS'
  end do
  end do
  end do
  end do
  end do
  if(requested_case==0.or.requested_case==1)then
    call configure_case(p,f,initial,1,1,0,0)
    do invalid=1,28
      badp=p;badf=f
      select case(invalid)
      case(1)
        badp%frost_divdra_active=.false.
      case(2)
        allocate(badf%drainage_flux_by_level(1,4));badf%drainage_flux_by_level=0._real64
      case(3)
        allocate(badf%drainage_response_controls(1))
      case(4)
        badf%frost_divdra_scalar_cm_per_day=ieee_value(0._real64,ieee_quiet_nan)
      case(5)
        badf%frost_divdra_scalar_cm_per_day=1.e-10_real64
      case(6)
        badf%frost_divdra_scalar_cm_per_day=-1.e-10_real64
      case(7)
        badp%frost_divdra%distribution%dz(2)=1._real64
      case(8)
        badp%frost_divdra%distribution%zbotcp(2)=-1.1_real64
      case(9)
        badp%frost_divdra%distribution%saturated_conductivity(2)=1._real64
      case(10)
        badp%ksatexm_extension_active=.true.
      case(11)
        badp%elasticity_active=.true.
      case(12)
        badp%root_extraction_active=.true.
      case(13)
        badp%frost_bottom%active=.true.
      case(14)
        badp%frost_low_air_drainage%active=.true.
      case(15)
        badp%frost_response_drainage_active=.true.
      case(16)
        badp%frost_drainage%head_budget_cm=0._real64
      case(17)
        badp%node_distance(2)=1._real64
      case(18)
        badp%frost_divdra%distribution%active_nodes=3
      case(19)
        badp%frost_divdra%distribution%horizontal_anisotropy_factor(2)=0._real64
      case(20)
        badf%subsurface_irrigation_source(1)=1.e-3_real64
      case(21)
        badf%root_extraction_sink(1)=1.e-3_real64
      case(22)
        badp%drainage_qbot_smooth_freatic_projection=.true.
      case(23)
        badp%bottom_mode=7
      case(24)
        badf%frost_divdra_scalar_cm_per_day=1.e6_real64+1._real64
      case(25)
        allocate(badf%legacy_swbotb2_control)
        call badf%legacy_swbotb2_control%initialize_table(0._real64,0._real64, &
             [0._real64,1._real64],[.002_real64,.004_real64],status)
        call require(status==0.and.badf%legacy_swbotb2_control%ready(),'valid dynamic bottom fixture')
      case(26)
        allocate(badf%legacy_swbotb4_qgwl_control)
      case(27)
        allocate(badf%legacy_swbotb3_implicit_control)
      case(28)
        allocate(badf%legacy_swbotb5_control)
      end select
      if(invalid>=25)call require(.not.fmr_frost_divdra_forcing_valid(.true.,badf), &
           'mixed dynamic bottom ownership held by shared preflight')
      call run(badp,badf,initial,0._real64,1.e-8_real64,out,obs,final)
      call require(.not.out%committed.and..not.obs%solver_executed,'invalid owner/domain rejects before solver')
      call require(all(final%pressure_head==initial%pressure_head).and.all(final%water_content==initial%water_content), &
           'rejected physical state unchanged')
      call application_rejects(badp,badf,initial)
    end do
    print '(A)','B19_INVALID_OWNER_DOMAIN_CASES=28'
    call initialize_soil_temperature_state([-4._real64,-4._real64,-4._real64,-4._real64],initial%soil_temperature,status)
    call run(p,f,initial,0._real64,1.e-8_real64,out,obs,final)
    call require(.not.out%committed.and..not.obs%solver_executed,'unbracketed geometry fails closed')
    call require(all(final%pressure_head==initial%pressure_head),'unbracketed rejection preserves state')
    print '(A)','B19_GEOMETRY_REJECTION=PASS'
  end if
contains
  subroutine configure_case(p,f,state,air,signum,separate,blocking)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    type(fmr_b110_physical_forcing_t),intent(out)::f
    type(fmr_b110_physical_state_t),intent(out)::state
    integer,intent(in)::air,signum,separate,blocking
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::w(4),k(4),c(4),dk(4)
    integer::status
    call initialize_parameters(p,2);call enable_bounded_frost(p)
    p%frost_divdra_active=.true.;p%frost_drainage%active=.true.
    p%frost_drainage%head_budget_cm=3.e-11_real64;p%frost_drainage%temperature_budget_c=1.e-7_real64
    p%frost_divdra%distribution%active_nodes=4
    p%frost_divdra%distribution%dz=p%dz
    p%frost_divdra%distribution%zbotcp=[-.5_real64,-1._real64,-2._real64,-3._real64]
    p%frost_divdra%distribution%saturated_conductivity=p%cofgen(3,:)
    p%frost_divdra%distribution%horizontal_anisotropy_factor=[1._real64,2._real64,.5_real64,1.5_real64]
    p%frost_divdra%distribution%drain_spacing=8._real64
    p%frost_divdra%drain_bottom_cm=-2._real64
    if(blocking==1)p%frost_divdra%drain_bottom_cm=-.5_real64
    p%frost_divdra%separate_infiltration=separate==1
    p%frost_divdra%surface_water_level_cm=-.1_real64
    p%frost_divdra%infiltration_depth_factor=.5_real64
    call initialize_physical_state(p,.true.,state,1._real64)
    state%groundwater_level=-.8_real64
    if(air==2)then
      call initialize_b110_default_mvg_parameters(hp,p%cofgen)
      call bind_b110_default_mvg_provider(provider,hp,upward_dt)
      state%pressure_head=-5._real64+p%z(1)-p%z
      call provider%evaluate(state%pressure_head,w,k,c,dk);state%water_content=w
    end if
    call initialize_soil_temperature_state([-4._real64,-4._real64,-1._real64,1._real64],state%soil_temperature,status)
    call require(status==0,'bracketed fixture')
    call initialize_forcing(f,0._real64,1.e-3_real64,-999999._real64)
    if(mod(signum,2)==0)f%bottom_flux=-f%bottom_flux
    deallocate(f%drainage_flux_by_level)
    f%frost_divdra_scalar_cm_per_day=.01_real64*real(signum,real64)
    allocate(f%soil_temperature);f%soil_temperature%prescribed_surface_temperature_c=-4._real64
  end subroutine

  real(real64) function independent_total(p,f,state) result(total)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_forcing_t),intent(in)::f
    type(fmr_b110_physical_state_t),intent(in)::state
    real(real64),allocatable::t(:),fac(:)
    real(real64)::air,freeze_bottom,scalar,water,finish,thickness,kh(4),invk(4),span,kdh,kdv
    real(real64)::top,bot,overlap,nodal(4),denom
    integer::status,i,last
    call copy_soil_temperature_profile(state%soil_temperature,t,status)
    fac=max(0._real64,min(1._real64,(t+2._real64)/2._real64))
    ! B1.11 uses a piecewise linear factor; the strong-frost residual is zero
    ! except in the constitutive hydraulic decorator, not the DIVDRA factor.
    air=0._real64
    do i=4,1,-1
      air=air+max(0._real64,p%cofgen(2,i)-state%water_content(i))*p%dz(i)
      if(i==1)exit
      if(fac(i-1)<=.01_real64)exit
    end do
    scalar=f%frost_divdra_scalar_cm_per_day
    if(air<.01_real64)then
      freeze_bottom=p%z(3)+p%node_distance(3)*(-2._real64-t(3))/(t(2)-t(3))
      if(freeze_bottom<p%frost_divdra%drain_bottom_cm)scalar=0._real64
      if(abs(scalar)<1.e-6_real64)then
        if(freeze_bottom>=p%frost_divdra%drain_bottom_cm)scalar=f%bottom_flux
      else
        scalar=scalar*(1._real64+f%bottom_flux/scalar)
      end if
      total=scalar;return
    end if
    ! Independent normal-air saturated overlap weights. Separate infiltration
    ! is checked against the actual corrected reference by the B18 replay.
    if(p%frost_divdra%separate_infiltration.and.scalar<0._real64)then
      total=normal_separate_total(p,state,scalar,fac);return
    end if
    water=-min(state%groundwater_level,0._real64);thickness=3._real64-water
    kh=p%cofgen(3,:)*p%frost_divdra%distribution%horizontal_anisotropy_factor;invk=1._real64/p%cofgen(3,:)
    kdh=0._real64;kdv=0._real64;top=0._real64
    do i=1,4
      bot=-p%frost_divdra%distribution%zbotcp(i);overlap=max(0._real64,bot-max(water,top))
      kdh=kdh+kh(i)*overlap;kdv=kdv+invk(i)*overlap;top=bot
    end do
    span=.25_real64*p%frost_divdra%distribution%drain_spacing*sqrt((thickness/kdv)/(kdh/thickness))
    finish=min(3._real64,water+span);nodal=0._real64;denom=0._real64;top=0._real64
    do i=1,4
      bot=-p%frost_divdra%distribution%zbotcp(i)
      nodal(i)=kh(i)*max(0._real64,min(finish,bot)-max(water,top));denom=denom+nodal(i);top=bot
    end do
    nodal=nodal*scalar/denom;last=maxloc(abs(nodal),dim=1)
    ! Rounding closure is immaterial at the independent 1e-12 storage gate.
    total=sum(nodal*fac)
  end function

  real(real64) function normal_separate_total(p,state,scalar,fac) result(total)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_state_t),intent(in)::state
    real(real64),intent(in)::scalar,fac(:)
    ! Piecewise integral evaluated by a distinct exact quadrature over each
    ! compartment. The integral of the linear transmissivity weighting is
    ! exact with its midpoint, including partial first and final intervals.
    real(real64)::water,surface,finish,kh(4),inverse_k(4),kdh,kdv,thickness,span
    real(real64)::uns,sat,top,bot,a,b,mid,trans,part
    integer::i
    water=-min(state%groundwater_level,0._real64);surface=-p%frost_divdra%surface_water_level_cm
    kh=p%cofgen(3,:)*p%frost_divdra%distribution%horizontal_anisotropy_factor
    inverse_k=1._real64/p%cofgen(3,:);thickness=3._real64-water
    kdh=b19_integral(p,kh,water,3._real64);kdv=b19_integral(p,inverse_k,water,3._real64)
    span=.25_real64*p%frost_divdra%distribution%drain_spacing*sqrt((thickness/kdv)/(kdh/thickness))
    span=span*max(p%frost_divdra%infiltration_depth_factor,(1._real64-water)/span)
    finish=min(3._real64,water+span);uns=b19_integral(p,kh,surface,water);sat=b19_integral(p,kh,water,finish)
    total=0._real64;top=0._real64
    do i=1,4
      bot=-p%frost_divdra%distribution%zbotcp(i);part=0._real64
      a=max(surface,top);b=min(water,bot)
      if(b>a)then
        mid=.5_real64*(a+b);trans=b19_integral(p,kh,surface,mid)
        part=scalar/(uns+sat)*2._real64*trans/uns*kh(i)*(b-a)
      end if
      a=max(water,top);b=min(finish,bot)
      if(b>a)then
        mid=.5_real64*(a+b);trans=b19_integral(p,kh,mid,finish)
        part=part+scalar/(uns+sat)*2._real64*trans/sat*kh(i)*(b-a)
      end if
      total=total+part*fac(i);top=bot
    end do
  end function normal_separate_total

  real(real64) function b19_integral(p,k,a,b) result(v)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(in)::k(:),a,b
    real(real64)::top,bot
    integer::j
    v=0._real64;top=0._real64
    do j=1,4
      bot=-p%frost_divdra%distribution%zbotcp(j)
      v=v+k(j)*max(0._real64,min(b,bot)-max(a,top));top=bot
    end do
  end function b19_integral

  subroutine identities(column,template)
    type(fmr_logical_column_t),intent(out)::column
    type(fmr_template_t),intent(out)::template
    template%template_id=440001_int64;template%physics_topology_id=440002_int64
    template%vertical_layout_id=440003_int64;template%state_layout_id=440004_int64
    template%solver_interface_id=440005_int64
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=column_id;column%template_id=template%template_id;column%parameter_ref=1_int64
    column%state_handle=1_int64;column%forcing_handle=1_int64;column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine
  subroutine run(p,f,initial,t0,dt,out,obs,final,captured,resumed)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_forcing_t),intent(in)::f
    type(fmr_b110_physical_state_t),intent(in)::initial
    real(real64),intent(in)::t0,dt
    type(fmr_serialized_column_result_t),intent(out)::out
    type(fmr_serialized_physical_observation_t),intent(out)::obs
    type(fmr_b110_physical_state_t),intent(out)::final
    type(kernel_committed_state_t),intent(out),optional::captured
    type(kernel_committed_state_t),intent(in),optional::resumed
    type(fmr_serialized_reference_backend_t)::backend
    type(kernel_executor_t)::transaction_control
    type(kernel_committed_state_t)::committed
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(canonical_numerical_config_t)::config
    type(fmr_column_diagnostics_t)::diagnostic
    type(fmr_serialized_batch_diagnostics_t)::runtime
    type(fixed_flux_top_boundary_provider_t),target::top
    class(transaction_state_t),allocatable::snapshot
    integer::calls
    logical::ok
    call identities(column,template)
    call fmr_new_b110_committed_state(committed,column_id,initial,t0,ok)
    call require(ok,'initialize actual committed state')
    if(present(resumed))committed=resumed
    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1._real64;config%transaction%max_retries=20
    config%transaction%mass_tolerance=hard_mass_gate;config%transaction%retry_scale=.5_real64
    config%max_committed_substeps=100000;config%progress_tolerance=0._real64
    out=fmr_serialized_column_result_t();out%column_id=column_id;out%requested_t0=t0;out%requested_t1=t0+dt
    diagnostic%column_id=column_id;calls=0
    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend,transaction_control,column,template,p,f,committed, &
         config,t0,t0+dt,out,diagnostic,runtime,calls)
    obs=backend%observation()
    if(present(captured))captured=committed
    call committed%snapshot(snapshot,ok);call require(ok,'snapshot after trial')
    select type(state=>snapshot)
    type is(fmr_b110_physical_state_t)
      final=state
    class default
      call require(.false.,'physical snapshot type')
    end select
  end subroutine
  subroutine application_rejects(p,f,state)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_forcing_t),intent(in)::f
    type(fmr_b110_physical_state_t),intent(in)::state
    type(fmr_production_application_config_t)::cfg
    type(fmr_production_application_bootstrap_t)::app
    integer::status
    allocate(cfg%tiles(1));cfg%tiles(1)%tile_id=column_id;cfg%tiles(1)%ledger_id=440045_int64
    call identities(columns(1),cfg%tiles(1)%template)
    cfg%tiles(1)%parameters=p;cfg%tiles(1)%initial_state=state;cfg%tiles(1)%base_forcing=f
    call app%initialize(cfg,status)
    call require(status/=FMR_APP_BOOT_OK,'invalid application parameter/forcing preflight')
  end subroutine application_rejects

  subroutine application(p,f,state)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_forcing_t),intent(in)::f
    type(fmr_b110_physical_state_t),intent(in)::state
    type(fmr_production_application_config_t)::cfg,bad
    type(fmr_production_application_bootstrap_t)::app,rejected
    type(fmr_serialized_column_result_t),allocatable::results(:)
    type(fmr_serialized_batch_diagnostics_t)::diagnostics
    integer::status,n
    logical::ok
    allocate(cfg%tiles(1));cfg%tiles(1)%tile_id=column_id;cfg%tiles(1)%ledger_id=440045_int64
    call identities(columns(1),cfg%tiles(1)%template)
    cfg%tiles(1)%parameters=p;cfg%tiles(1)%initial_state=state;cfg%tiles(1)%base_forcing=f
    cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%numerical%transaction%temporal_tolerance=1._real64;cfg%numerical%transaction%max_retries=20
    cfg%numerical%transaction%mass_tolerance=hard_mass_gate;cfg%numerical%transaction%retry_scale=.5_real64
    cfg%numerical%max_committed_substeps=100000
    call app%initialize(cfg,status);call require(status==FMR_APP_BOOT_OK,'actual application initialize')
    call app%run_standalone(0._real64,1.e-8_real64,results,status)
    call require(status==FMR_APP_BOOT_OK.and.size(results)==1,'application window results')
    call require(results(1)%committed.and.abs(results(1)%mass%residual)<=hard_mass_gate,'application committed hard mass')
    call app%close(status);call require(status==FMR_APP_BOOT_OK,'actual application shutdown')
    bad=cfg;allocate(bad%tiles(1)%base_forcing%drainage_flux_by_level(1,4));bad%tiles(1)%base_forcing%drainage_flux_by_level=0._real64
    call rejected%initialize(bad,status);call require(status/=FMR_APP_BOOT_OK,'application mixed nodal owner rejected')
    print '(A)','B19_APPLICATION=PASS'
  end subroutine
  subroutine initialize_parameters(parameters, bottom_mode)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    integer, intent(in) :: bottom_mode
    integer :: k
    parameters%parameter_set_id = 440044_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode = bottom_mode
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%max_iterations = 16
    parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = 1.0e-12_real64
    parameters%total_balance_tolerance = 1.0e-12_real64
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
  end subroutine initialize_parameters

  subroutine enable_bounded_frost(parameters)
    type(fmr_b110_physical_parameters_t), intent(inout) :: parameters
    real(real64) :: theta_sat(numnod), quartz(numnod), clay(numnod), organic(numnod)
    integer :: status
    parameters%frost_active = .true.
    parameters%frost_hydraulic%active = .true.
    parameters%frost_hydraulic%reduction_start_c = 0.0_real64
    parameters%frost_hydraulic%reduction_end_c = -2.0_real64
    parameters%soil_temperature_active = .true.
    allocate(parameters%soil_temperature)
    theta_sat = 0.45_real64
    quartz = 0.60_real64
    clay = 0.20_real64
    organic = 0.05_real64
    call initialize_soil_temperature_parameters(parameters%dz, parameters%node_distance, theta_sat, quartz, clay, &
         organic, parameters%soil_temperature, status)
    call require(status == 0, 'sensible-temperature parameter fixture')
  end subroutine enable_bounded_frost

  subroutine initialize_committed(committed, parameters, hydrostatic, ok, frost_temperature, initial_time)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: hydrostatic
    logical, intent(out) :: ok
    real(real64), intent(in), optional :: frost_temperature
    real(real64), intent(in), optional :: initial_time
    type(fmr_b110_physical_state_t) :: state
    call initialize_physical_state(parameters, hydrostatic, state, frost_temperature)
    if (present(initial_time)) then
      call fmr_new_b110_committed_state(committed, column_id, state, initial_time, ok)
    else
      call fmr_new_b110_committed_state(committed, column_id, state, 0.0_real64, ok)
    end if
  end subroutine initialize_committed

  subroutine initialize_temporal_committed(committed, parameters, hydrostatic, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: hydrostatic
    logical, intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: accepted_predecessor_right_derivative(numnod)
    call initialize_physical_state(parameters, hydrostatic, state)
    call require(hydrostatic, 'certificate fixture must use hydrostatic predecessor')
    accepted_predecessor_right_derivative = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed, column_id, state, 0.0_real64, ok, &
         accepted_predecessor_right_derivative)
  end subroutine initialize_temporal_committed

  subroutine initialize_physical_state(parameters, hydrostatic, state, frost_temperature)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: hydrostatic
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(in), optional :: frost_temperature
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: gradient
    integer :: i
    real(real64) :: initial_temperature

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, merge(upward_dt,equilibrium_dt,hydrostatic))
    if (hydrostatic) then
      heads(1) = h0
      do i = 2, numnod
        heads(i) = heads(i-1) + parameters%node_distance(i)
        gradient = (heads(i-1)-heads(i))/parameters%node_distance(i) + 1.0_real64
        call require(abs(gradient) <= 16.0_real64*epsilon(1.0_real64), 'hydrostatic zero internal gradient')
      end do
    else
      heads = h0
    end if
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    if (parameters%soil_temperature_active) then
      initial_temperature = -4.0_real64
      if (present(frost_temperature)) initial_temperature = frost_temperature
      allocate(state%soil_temperature)
      call initialize_soil_temperature_state([initial_temperature,initial_temperature,initial_temperature,initial_temperature], &
           state%soil_temperature, i)
      call require(i == 0, 'initial soil-temperature state')
    end if
  end subroutine initialize_physical_state

  subroutine initialize_forcing(forcing, top_flux, bottom_flux, bottom_head)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: top_flux, bottom_flux, bottom_head
    forcing%top_flux = top_flux
    forcing%top_head = h0
    forcing%bottom_flux = bottom_flux
    forcing%bottom_head = bottom_head
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine determine_initial_conductivity(k)
    real(real64), intent(out) :: k
    type(fmr_b110_physical_parameters_t) :: parameters
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    call initialize_parameters(parameters, 2)
    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, equilibrium_dt)
    heads = h0
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    k = conductivity(1)
  end subroutine determine_initial_conductivity

  pure logical function same_bits(a, b)
    real(real64), intent(in) :: a, b
    same_bits = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR44R_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_b19_divdra_runtime
