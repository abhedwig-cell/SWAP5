module mod_macropore_single_column_runtime
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_physical_state_t, &
       source_sink_provider_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, &
       copy_macropore_continuation_state
  use mod_macropore_exchange_overlay_provider, only: macropore_exchange_overlay_provider_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, macropore_geometry_result_t, &
       evaluate_macropore_geometry
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, &
       macropore_standard_candidate_receipt_t, derive_macropore_standard_storage_view, &
       build_macropore_standard_candidate
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t, &
       prepare_standard_macropore_rate_request, prepare_standard_sorptivity_history_request
  use mod_macropore_surface_top_input, only: macropore_surface_forcing_t, macropore_surface_geometry_t, &
       macropore_surface_request_result_t, derive_macropore_surface_request
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t, &
       macropore_rate_bundle_result_t, evaluate_macropore_rate_bundle
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t, &
       apply_sorptivity_history_update
  use mod_ppa_wu05a6_vertical_flux_reconstruction, only: vertical_flux_reconstruction_request_t, &
       vertical_flux_reconstruction_result_t, reconstruct_vertical_flux
  implicit none
  private

  integer,parameter,public::MACRO_RUNTIME_NOT_RUN=0
  integer,parameter,public::MACRO_RUNTIME_INACTIVE=1
  integer,parameter,public::MACRO_RUNTIME_CONVERGED=2
  integer,parameter,public::MACRO_RUNTIME_RETRY=3
  integer,parameter,public::MACRO_RUNTIME_FAILED=4

  type, public :: macropore_runtime_policy_t
    logical :: enabled=.false.
    integer :: max_correctors=40
    real(real64) :: exchange_relative_tolerance=1.0e-8_real64
    real(real64) :: exchange_floor=1.0e-12_real64
    real(real64) :: damping_previous_weight=0.5_real64
    real(real64) :: solver_mass_tolerance_cm=1.0e-10_real64
    real(real64) :: internal_exchange_tolerance_cm=1.0e-10_real64
    real(real64) :: surface_return_tolerance_cm=1.0e-10_real64
  contains
    procedure,public::valid=>runtime_policy_valid
  end type macropore_runtime_policy_t

  type, public :: macropore_runtime_result_t
    integer :: status=MACRO_RUNTIME_NOT_RUN
    logical :: retry_advised=.false.
    integer :: predictor_solves=0
    integer :: corrector_solves=0
    integer :: outer_iterations=0
    real(real64) :: final_relative_exchange_change=huge(1.0_real64)
    real(real64) :: returned_surface_cm=0.0_real64
    real(real64) :: rapid_external_outflow_cm=0.0_real64
    real(real64) :: internal_exchange_residual_cm=huge(1.0_real64)
    real(real64) :: macro_balance_residual_cm=huge(1.0_real64)
    real(real64) :: surface_external_input_cm=0.0_real64
    real(real64) :: surface_partition_residual_cm=0.0_real64
    type(soil_water_solve_result_t) :: matrix_result
    type(macropore_continuation_state_t) :: macropore_candidate
    type(vertical_flux_reconstruction_result_t) :: vertical_flux
    real(real64),allocatable :: exchange_rate_domain_cp(:,:)
    real(real64),allocatable :: exchange_rate_node(:)
  end type macropore_runtime_result_t

  type, public :: macropore_single_column_runtime_t
  contains
    procedure,public::execute=>runtime_execute
  end type macropore_single_column_runtime_t

contains

  pure logical function runtime_policy_valid(self) result(ok)
    class(macropore_runtime_policy_t),intent(in)::self
    ok=self%max_correctors>0 .and. self%exchange_relative_tolerance>0.0_real64 .and. &
       self%exchange_floor>0.0_real64 .and. self%damping_previous_weight>=0.0_real64 .and. &
       self%damping_previous_weight<1.0_real64 .and. self%solver_mass_tolerance_cm>0.0_real64 .and. &
       self%internal_exchange_tolerance_cm>0.0_real64 .and. self%surface_return_tolerance_cm>=0.0_real64
  end function runtime_policy_valid

  subroutine runtime_execute(self,solver,workspace,base_request,accepted_macro,geometry_config,rate_template, &
       history_request,policy,result,surface_forcing,surface_geometry)
    class(macropore_single_column_runtime_t),intent(inout)::self
    class(soil_water_solver_t),intent(inout)::solver
    class(soil_water_solver_workspace_base_t),intent(inout)::workspace
    type(soil_water_solve_request_t),intent(in)::base_request
    type(macropore_continuation_state_t),intent(in)::accepted_macro
    type(macropore_geometry_config_t),intent(in)::geometry_config
    type(macropore_rate_bundle_request_t),intent(in)::rate_template
    type(sorptivity_history_update_request_t),intent(in)::history_request
    type(macropore_runtime_policy_t),intent(in)::policy
    type(macropore_runtime_result_t),intent(out)::result
    type(macropore_surface_forcing_t),intent(in),optional::surface_forcing
    type(macropore_surface_geometry_t),intent(in),optional::surface_geometry

    type(soil_water_solve_request_t)::request
    type(soil_water_solve_result_t)::predictor,corrector
    type(macropore_exchange_overlay_provider_t),target::overlay
    type(macropore_geometry_result_t)::geometry
    type(macropore_rate_bundle_request_t)::rate_request
    type(macropore_rate_bundle_result_t)::current_rates,raw_rates
    type(macropore_standard_candidate_receipt_t)::receipt
    type(macropore_standard_storage_view_t)::accepted_view,candidate_view
    type(matrix_saturated_zone_view_t)::matrix_view
    type(vertical_flux_reconstruction_request_t)::vertical_request
    type(sorptivity_history_update_request_t)::history_local
    type(macropore_surface_request_result_t)::surface_request
    real(real64),allocatable::current_domain(:,:),next_domain(:,:),current_node(:)
    real(real64)::numerator,denominator,dt,expected_matrix_top_flux,surface_scale
    logical::ok,surface_active
    integer::iter,nd,n

    result=macropore_runtime_result_t()
    if(.not.policy%valid())then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    if(.not.associated(base_request%parameters))then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if

    request=base_request
    request%physical%macropore_active=.false.
    surface_active=present(surface_forcing) .or. present(surface_geometry)
    if(surface_active)then
      if(.not.present(surface_forcing) .or. .not.present(surface_geometry))then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
    end if
    overlay%base=>base_request%evaluation%source_sink
    request%evaluation%source_sink=>overlay

    if(.not.policy%enabled)then
      call solver%solve(request,workspace,result%matrix_result)
      if(result%matrix_result%status/=SW_SOLVE_CONVERGED)then
        result%retry_advised=result%matrix_result%retry_advised .or. &
             result%matrix_result%status==SW_SOLVE_RETRY_ADVISED
        result%status=merge(MACRO_RUNTIME_RETRY,MACRO_RUNTIME_FAILED,result%retry_advised)
        return
      end if
      call copy_macropore_continuation_state(accepted_macro,result%macropore_candidate,ok)
      if(.not.ok)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
      result%status=MACRO_RUNTIME_INACTIVE
      result%internal_exchange_residual_cm=0.0_real64
      result%macro_balance_residual_cm=0.0_real64
      return
    end if

    if(.not.accepted_macro%ready())then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    dt=base_request%step_duration
    if(dt<=0.0_real64)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if

    if(surface_active)then
      call derive_macropore_surface_request(surface_forcing,surface_geometry,dt,surface_request)
      if(.not.surface_request%valid)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
      expected_matrix_top_flux = -(surface_request%matrix_direct_supply_total_cm + &
           surface_request%runon_total_cm)/dt
      surface_scale=max(1.0_real64,abs(expected_matrix_top_flux),abs(base_request%boundary%top_flux))
      if(abs(base_request%boundary%top_flux-expected_matrix_top_flux) > &
           64.0_real64*epsilon(1.0_real64)*surface_scale)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
      result%surface_external_input_cm=surface_request%direct_supply_total_cm+surface_request%runon_total_cm
      result%surface_partition_residual_cm=surface_request%source_partition_residual_cm
    end if

    call evaluate_macropore_geometry(geometry_config,accepted_macro%dynamic_volume_cp,geometry)
    if(.not.geometry%valid)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    if(maxval(abs(geometry%volume_domain_cp-accepted_macro%volume_domain_cp))>1.0e-10_real64 .or. &
       any(geometry%bottom_domain/=accepted_macro%icp_bottom_domain))then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if

    call derive_macropore_standard_storage_view(accepted_macro,geometry_config%top_node, &
         base_request%parameters%z,base_request%parameters%dz,accepted_view)
    if(.not.accepted_view%valid)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    if(maxval(abs(accepted_view%normalized_water_cm-accepted_macro%water_domain_cp))>1.0e-10_real64)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if

    nd=accepted_macro%num_domains
    n=accepted_macro%num_nodes
    allocate(current_domain(nd,n),next_domain(nd,n),current_node(n),overlay%exchange_rate(n))
    overlay%exchange_rate=0.0_real64

    call solver%solve(request,workspace,predictor)
    result%predictor_solves=1
    if(predictor%status/=SW_SOLVE_CONVERGED)then
      result%retry_advised=predictor%retry_advised .or. predictor%status==SW_SOLVE_RETRY_ADVISED
      result%status=merge(MACRO_RUNTIME_RETRY,MACRO_RUNTIME_FAILED,result%retry_advised)
      return
    end if

    if(surface_active)then
      call prepare_standard_macropore_rate_request(rate_template,accepted_macro,geometry,accepted_view, &
           predictor%candidate_state,base_request%parameters%z,base_request%parameters%dz,dt,rate_request,matrix_view,ok, &
           surface_request=surface_request)
    else
      call prepare_standard_macropore_rate_request(rate_template,accepted_macro,geometry,accepted_view, &
           predictor%candidate_state,base_request%parameters%z,base_request%parameters%dz,dt,rate_request,matrix_view,ok)
    end if
    if(.not.ok)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    call evaluate_macropore_rate_bundle(rate_request,current_rates)
    if(.not.current_rates%valid)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    current_domain=current_rates%qexc_to_matrix_rate

    do iter=1,policy%max_correctors
      current_node=sum(current_domain,dim=1)
      overlay%exchange_rate=current_node
      request%base_state=base_request%base_state
      call solver%solve(request,workspace,corrector)
      result%corrector_solves=result%corrector_solves+1
      result%outer_iterations=iter

      if(corrector%status/=SW_SOLVE_CONVERGED)then
        result%retry_advised=corrector%retry_advised .or. corrector%status==SW_SOLVE_RETRY_ADVISED
        result%status=merge(MACRO_RUNTIME_RETRY,MACRO_RUNTIME_FAILED,result%retry_advised)
        return
      end if

      if(surface_active)then
        call prepare_standard_macropore_rate_request(rate_template,accepted_macro,geometry,accepted_view, &
             corrector%candidate_state,base_request%parameters%z,base_request%parameters%dz,dt,rate_request,matrix_view,ok, &
             surface_request=surface_request)
      else
        call prepare_standard_macropore_rate_request(rate_template,accepted_macro,geometry,accepted_view, &
             corrector%candidate_state,base_request%parameters%z,base_request%parameters%dz,dt,rate_request,matrix_view,ok)
      end if
      if(.not.ok)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
      call evaluate_macropore_rate_bundle(rate_request,raw_rates)
      if(.not.raw_rates%valid)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if

      next_domain=policy%damping_previous_weight*current_domain + &
           (1.0_real64-policy%damping_previous_weight)*raw_rates%qexc_to_matrix_rate
      numerator=maxval(abs(next_domain-current_domain))
      denominator=max(maxval(abs(current_domain)),policy%exchange_floor)
      result%final_relative_exchange_change=numerator/denominator
      if(result%final_relative_exchange_change<=policy%exchange_relative_tolerance)exit
      if(iter<policy%max_correctors)current_domain=next_domain
    end do

    if(result%final_relative_exchange_change>policy%exchange_relative_tolerance)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if

    ! Use the exact exchange vector injected into the converged corrector for mass identity.
    current_node=sum(current_domain,dim=1)
    result%matrix_result=corrector

    if(surface_active)then
      result%returned_surface_cm=raw_rates%top_partition%returned_surface_cm
      result%surface_partition_residual_cm = &
           surface_request%matrix_direct_supply_total_cm + surface_request%runon_total_cm + &
           raw_rates%top_partition%accepted_total_cm + raw_rates%top_partition%returned_surface_cm - &
           result%surface_external_input_cm
      if(abs(surface_request%lateral_requested_total_cm)>policy%surface_return_tolerance_cm)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
      if(raw_rates%top_partition%returned_surface_cm>policy%surface_return_tolerance_cm)then
        result%retry_advised=.true.
        result%status=MACRO_RUNTIME_RETRY
        return
      end if
      if(abs(result%surface_partition_residual_cm)>policy%surface_return_tolerance_cm)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
    end if

    call build_macropore_standard_candidate(accepted_macro,geometry,raw_rates%top_partition,current_domain, &
         raw_rates%rapid_outflow_cp_cm,dt,geometry_config%top_node,base_request%parameters%z, &
         base_request%parameters%dz,result%macropore_candidate,candidate_view,receipt,ok)
    if(.not.ok .or. .not.receipt%valid)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if

    call prepare_standard_sorptivity_history_request(history_request,geometry,candidate_view,matrix_view,dt,history_local,ok)
    if(.not.ok)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    call apply_sorptivity_history_update(history_local,accepted_macro,raw_rates%unsaturated, &
         result%macropore_candidate,ok)
    if(.not.ok)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if

    result%returned_surface_cm=receipt%returned_surface_cm
    result%rapid_external_outflow_cm=receipt%rapid_external_outflow_cm
    result%internal_exchange_residual_cm=sum(current_node)*dt - receipt%internal_exchange_to_matrix_cm
    result%macro_balance_residual_cm=receipt%macro_balance_residual_cm
    allocate(result%exchange_rate_domain_cp(nd,n),result%exchange_rate_node(n))
    result%exchange_rate_domain_cp=current_domain
    result%exchange_rate_node=current_node

    if(abs(result%internal_exchange_residual_cm)>policy%internal_exchange_tolerance_cm .or. &
       abs(result%macro_balance_residual_cm)>policy%internal_exchange_tolerance_cm)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    if(result%matrix_result%integrated_mass_balance_residual_available)then
      if(abs(result%matrix_result%integrated_mass_balance_residual_cm)>policy%solver_mass_tolerance_cm)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
    end if

    call prepare_vertical_request(accepted_macro,result%macropore_candidate,raw_rates,current_domain, &
         dt,vertical_request,ok)
    if(.not.ok)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    call reconstruct_vertical_flux(vertical_request,result%vertical_flux)
    if(.not.result%vertical_flux%valid)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if

    result%status=MACRO_RUNTIME_CONVERGED
    if(.not.same_type_as(self,self))result%status=MACRO_RUNTIME_FAILED
  end subroutine runtime_execute



  subroutine prepare_vertical_request(previous,current,rates,qexc,dt,request,ok)
    type(macropore_continuation_state_t),intent(in)::previous,current
    type(macropore_rate_bundle_result_t),intent(in)::rates
    real(real64),intent(in)::qexc(:,:),dt
    type(vertical_flux_reconstruction_request_t),intent(out)::request
    logical,intent(out)::ok
    integer::nd,n

    ok=.false.
    if(.not.previous%ready() .or. .not.current%ready() .or. .not.rates%valid)return
    nd=current%num_domains
    n=current%num_nodes
    if(.not.all(shape(qexc)==[nd,n]))return

    request%num_domains=nd
    request%num_nodes=n
    request%top_node=rates%top_partition%top_node
    request%step_duration=dt
    allocate(request%bottom_domain(nd),request%top_inflow_rate(nd),request%previous_water_cm(nd,n), &
         request%current_water_cm(nd,n),request%exchange_to_matrix_rate(nd,n), &
         request%external_outflow_rate(nd,n))
    request%bottom_domain=current%icp_bottom_domain
    request%top_inflow_rate=(rates%top_partition%accepted_vertical_cm+rates%top_partition%accepted_lateral_cm)/dt
    request%previous_water_cm=previous%water_domain_cp
    request%current_water_cm=current%water_domain_cp
    request%exchange_to_matrix_rate=qexc
    request%external_outflow_rate=0.0_real64
    request%external_outflow_rate(1,:)=rates%rapid_outflow_cp_cm/dt
    ok=request%valid()
  end subroutine prepare_vertical_request

end module mod_macropore_single_column_runtime
