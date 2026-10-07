module mod_macropore_single_column_runtime
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solver_t, soil_water_solver_workspace_base_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_physical_state_t, &
       source_sink_provider_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, &
       copy_macropore_continuation_state
  use mod_macropore_exchange_overlay_provider, only: macropore_exchange_overlay_provider_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, macropore_geometry_result_t, &
       evaluate_macropore_geometry, evaluate_macropore_geometry_return
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, &
       macropore_standard_candidate_receipt_t, derive_macropore_standard_storage_view, &
       build_macropore_standard_candidate, apply_internal_covered_top_transfer
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t, &
       prepare_standard_macropore_rate_request, prepare_standard_sorptivity_history_request
  use mod_fmr_macropore_top_input, only: fmr_macropore_top_input_forcing_t, prepare_fmr_macropore_top_input
  use mod_macropore_covering_layer_input, only: covering_layer_input_request_t, evaluate_covering_layer_input
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t, &
       macropore_rate_bundle_result_t, evaluate_macropore_rate_bundle
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t, &
       apply_sorptivity_history_update
  use mod_ppa_wu05a6_vertical_flux_reconstruction, only: vertical_flux_reconstruction_request_t, &
       vertical_flux_reconstruction_result_t, reconstruct_vertical_flux
  use mod_ppa_wu05a16_inner_macropore_provider, only: ppa_wu05a16_inner_macropore_provider_t
  use mod_macropore_dynamic_shrinkage, only: dynamic_shrinkage_config_t
  use mod_ppa_wu05_perch19_reduction_controller, only: macropore_reduction_continuation_t, &
       reduction_after_retry, reduction_after_accept
  implicit none
  private

  integer,parameter,public::MACRO_RUNTIME_NOT_RUN=0
  integer,parameter,public::MACRO_RUNTIME_INACTIVE=1
  integer,parameter,public::MACRO_RUNTIME_CONVERGED=2
  integer,parameter,public::MACRO_RUNTIME_RETRY=3
  integer,parameter,public::MACRO_RUNTIME_FAILED=4

  type, public :: macropore_runtime_policy_t
    logical :: enabled=.false.
    logical :: inner_richards_exchange_enabled=.false.
    logical :: source_reduction_retry_enabled=.false.
    integer :: max_correctors=40
    real(real64) :: exchange_relative_tolerance=1.0e-8_real64
    real(real64) :: exchange_floor=1.0e-12_real64
    real(real64) :: damping_previous_weight=0.5_real64
    real(real64) :: solver_mass_tolerance_cm=1.0e-10_real64
    real(real64) :: internal_exchange_tolerance_cm=1.0e-10_real64
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
    real(real64) :: requested_top_input_cm=0.0_real64
    real(real64) :: accepted_top_input_cm=0.0_real64
    real(real64) :: returned_surface_cm=0.0_real64
    real(real64) :: rapid_external_outflow_cm=0.0_real64
    real(real64) :: covered_internal_transfer_cm=0.0_real64
    logical :: inner_richards_exchange_used=.false.
    logical :: matrix_source_area_partition_used=.false.
    real(real64) :: inner_initial_exchange_rate_cm_per_day=0.0_real64
    real(real64) :: inner_final_exchange_rate_cm_per_day=0.0_real64
    integer :: source_reduction_attempts=0
    real(real64) :: accepted_source_reduction_factor=1.0_real64
    type(macropore_reduction_continuation_t) :: reduction_candidate
    real(real64) :: internal_exchange_residual_cm=huge(1.0_real64)
    real(real64) :: macro_balance_residual_cm=huge(1.0_real64)
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
       self%internal_exchange_tolerance_cm>0.0_real64
  end function runtime_policy_valid

  subroutine runtime_execute(self,solver,workspace,base_request,accepted_macro,geometry_config,rate_template, &
       history_request,policy,result,top_input,reduction_accepted,covering_minimum_polygon_diameter_cm,covering_ksat_cm_per_day, &
       shrinkage_config,matrix_area_fraction)
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
    type(fmr_macropore_top_input_forcing_t),intent(in),optional::top_input
    type(macropore_reduction_continuation_t),intent(in),optional::reduction_accepted
    real(real64),intent(in),optional::covering_minimum_polygon_diameter_cm,covering_ksat_cm_per_day
    type(dynamic_shrinkage_config_t),intent(in),optional::shrinkage_config
    real(real64),intent(in),optional::matrix_area_fraction(:)

    type(soil_water_solve_request_t)::request
    type(soil_water_solve_result_t)::predictor,corrector
    type(macropore_exchange_overlay_provider_t),target::overlay
    type(ppa_wu05a16_inner_macropore_provider_t),target::inner_provider
    type(macropore_geometry_result_t)::geometry
    type(macropore_rate_bundle_request_t)::rate_request,rate_template_step,rate_template_attempt
    type(macropore_rate_bundle_result_t)::current_rates,raw_rates
    type(macropore_standard_candidate_receipt_t)::receipt
    type(macropore_standard_storage_view_t)::accepted_view,candidate_view
    type(matrix_saturated_zone_view_t)::matrix_view
    type(vertical_flux_reconstruction_request_t)::vertical_request
    type(sorptivity_history_update_request_t)::history_local
    real(real64),allocatable::current_domain(:,:),next_domain(:,:),current_node(:)
    real(real64),allocatable::requested_top_vertical(:),requested_top_lateral(:),covered_domain_cm(:)
    real(real64),allocatable::candidate_top_vertical(:),candidate_top_lateral(:)
    real(real64),allocatable::geometry_return(:,:)
    type(fmr_macropore_top_input_forcing_t)::top_input_local
    type(covering_layer_input_request_t)::covering_request
    real(real64)::numerator,denominator,dt
    logical::ok,can_reduce
    integer::iter,nd,n
    type(macropore_reduction_continuation_t)::reduction_attempt,reduction_next

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
    if(present(shrinkage_config))then
      if(shrinkage_config%enabled .and. .not.policy%inner_richards_exchange_enabled)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
    end if

    call evaluate_macropore_geometry(geometry_config,accepted_macro%dynamic_volume_cp,geometry)
    if(.not.geometry%valid)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    write(*,'(*(g0))') 'MIGMAC01_RUNTIME_PRE|GEOM_DIFF=',maxval(abs(geometry%volume_domain_cp-accepted_macro%volume_domain_cp)), &
         '|BOTTOM_MATCH=',all(geometry%bottom_domain==accepted_macro%icp_bottom_domain)
    if(maxval(abs(geometry%volume_domain_cp-accepted_macro%volume_domain_cp))>1.0e-10_real64 .or. &
       any(geometry%bottom_domain/=accepted_macro%icp_bottom_domain))then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if

    top_input_local=fmr_macropore_top_input_forcing_t()
    if(present(top_input))top_input_local=top_input
    if(geometry_config%top_node==1)then
      call prepare_fmr_macropore_top_input(top_input_local,geometry_config,geometry,dt, &
           requested_top_vertical,requested_top_lateral,ok)
    else
      allocate(requested_top_vertical(geometry%num_domains),requested_top_lateral(geometry%num_domains))
      requested_top_vertical=0.0_real64
      requested_top_lateral=0.0_real64
      ok=top_input_local%valid() .and. .not.top_input_local%supplied
    end if
    write(*,'(*(g0))') 'MIGMAC01_RUNTIME_PRE|TOP_OK=',ok
    if(.not.ok)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
    rate_template_step=rate_template
    rate_template_step%limiter%potential_top_vertical_cm=requested_top_vertical
    rate_template_step%limiter%potential_top_lateral_cm=requested_top_lateral
    result%requested_top_input_cm=sum(requested_top_vertical)+sum(requested_top_lateral)
    if(geometry_config%top_node>1 .and. result%requested_top_input_cm>1.0e-14_real64)then
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

    if(policy%inner_richards_exchange_enabled)then
      write(*,'(a)') 'PPA_WU05A18_RUNTIME_STAGE=INNER_ENTER'
      reduction_attempt=macropore_reduction_continuation_t()
      if(present(reduction_accepted))reduction_attempt=reduction_accepted
      if(.not.reduction_attempt%valid())then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if

      ! Record the accepted-state inner rate for attribution only. This is not
      ! injected separately; HeadCalc obtains its own current-iterate rate from
      ! the provider.
      rate_template_attempt=rate_template_step
      if(policy%source_reduction_retry_enabled)then
        rate_template_attempt%unsaturated%sorptivity%flow_reduction=reduction_attempt%factor()
        rate_template_attempt%interflow_sat%flow_reduction=reduction_attempt%factor()
        rate_template_attempt%matrix_sat%flow_reduction=reduction_attempt%factor()
        rate_template_attempt%rapid%flow_reduction=reduction_attempt%factor()
      end if
      call prepare_standard_macropore_rate_request(rate_template_attempt,accepted_macro,geometry,accepted_view, &
           base_request%base_state,base_request%parameters%z,base_request%parameters%dz,dt, &
           rate_request,matrix_view,ok)
      if(.not.ok)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
      write(*,'(a)') 'PPA_WU05A18_RUNTIME_STAGE=INITIAL_REQUEST_READY'
      call evaluate_macropore_rate_bundle(rate_request,current_rates)
      write(*,'(a)') 'PPA_WU05A18_RUNTIME_STAGE=INITIAL_RATE_EVALUATED'
      if(.not.current_rates%valid)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
      result%inner_initial_exchange_rate_cm_per_day=sum(current_rates%qexc_to_matrix_rate)

      do
        rate_template_attempt=rate_template_step
        if(policy%source_reduction_retry_enabled)then
          rate_template_attempt%unsaturated%sorptivity%flow_reduction=reduction_attempt%factor()
          rate_template_attempt%interflow_sat%flow_reduction=reduction_attempt%factor()
          rate_template_attempt%matrix_sat%flow_reduction=reduction_attempt%factor()
          rate_template_attempt%rapid%flow_reduction=reduction_attempt%factor()
        end if

        call inner_provider%configure(accepted_macro,geometry,rate_template_attempt,base_request%parameters%z, &
             base_request%parameters%dz,dt,base_request%base_state%ponding_depth, &
             base_request%base_state%groundwater_level,ok,covering_minimum_polygon_diameter_cm,covering_ksat_cm_per_day, &
             geometry_config,shrinkage_config,base_request%base_state%water_content,matrix_area_fraction,top_input_local, &
             base_request%boundary%bottom_mode)
        if(.not.ok)then
          result%status=MACRO_RUNTIME_FAILED
          return
        end if

        request=base_request
        request%physical%macropore_active=.true.
        request%evaluation%macropore=>inner_provider
        ! Keep direct atmospheric input and the macro top receipt on the same
        ! residual candidate geometry. HeadCalc asks this provider for the
        ! candidate area before evaluating the dynamic top boundary.
        if(associated(request%evaluation%dynamic_top_boundary))then
          ! The dynamic top provider itself decides whether the candidate macro
          ! surface fraction changes the atmospheric matrix source. Do not infer
          ! that physical option from geometry existence alone.
          if(top_input_local%supplied)request%boundary%matrix_source_area_partition=.true.
        end if
        result%matrix_source_area_partition_used=request%boundary%matrix_source_area_partition
        call solver%solve(request,workspace,corrector)
        result%matrix_result=corrector
        result%source_reduction_attempts=result%source_reduction_attempts+1
        result%corrector_solves=result%corrector_solves+1
        result%outer_iterations=0
        result%final_relative_exchange_change=0.0_real64
        result%inner_richards_exchange_used=.true.

        if(corrector%status==SW_SOLVE_CONVERGED)exit
        result%retry_advised=corrector%retry_advised .or. corrector%status==SW_SOLVE_RETRY_ADVISED
        if(.not.policy%source_reduction_retry_enabled .or. .not.result%retry_advised)then
          result%status=merge(MACRO_RUNTIME_RETRY,MACRO_RUNTIME_FAILED,result%retry_advised)
          return
        end if
        call reduction_after_retry(reduction_attempt,dt,reduction_next,can_reduce)
        if(.not.can_reduce)then
          result%status=MACRO_RUNTIME_RETRY
          return
        end if
        reduction_attempt=reduction_next
      end do

      if(policy%source_reduction_retry_enabled)then
        call reduction_after_accept(reduction_attempt,dt,result%reduction_candidate)
        result%accepted_source_reduction_factor=reduction_attempt%factor()
      else
        result%reduction_candidate=reduction_attempt
        result%accepted_source_reduction_factor=rate_template_attempt%interflow_sat%flow_reduction
      end if

      result%matrix_result=corrector
      if(associated(request%evaluation%macropore))then
        block
          real(real64)::candidate_pond_lateral_cm
          candidate_pond_lateral_cm=request%evaluation%macropore%candidate_pond_lateral()
          if(candidate_pond_lateral_cm>0.0_real64)then
            rate_template_attempt%limiter%potential_top_lateral_cm= &
                 rate_template_attempt%limiter%potential_top_lateral_cm+ &
                 geometry_config%domain_fraction(:,geometry%top_node)*candidate_pond_lateral_cm
            result%requested_top_input_cm=sum(rate_template_attempt%limiter%potential_top_vertical_cm)+ &
                 sum(rate_template_attempt%limiter%potential_top_lateral_cm)
          end if
        end block
      end if
      if(present(shrinkage_config))then
        if(shrinkage_config%enabled)then
          call inner_provider%evaluate_trial_geometry(corrector%candidate_state%water_content,geometry,ok, &
               corrector%candidate_state%pressure_head)
          if(.not.ok)then
            result%status=MACRO_RUNTIME_FAILED
            return
          end if
          if(top_input_local%supplied)then
            call prepare_fmr_macropore_top_input(top_input_local,geometry_config,geometry,dt, &
                 candidate_top_vertical,candidate_top_lateral,ok)
            if(.not.ok)then
              result%status=MACRO_RUNTIME_FAILED
              return
            end if
            rate_template_attempt%limiter%potential_top_vertical_cm=candidate_top_vertical
            rate_template_attempt%limiter%potential_top_lateral_cm=candidate_top_lateral
            if(associated(request%evaluation%macropore))then
              block
                real(real64)::candidate_pond_lateral_cm
                candidate_pond_lateral_cm=request%evaluation%macropore%candidate_pond_lateral()
                if(candidate_pond_lateral_cm>0.0_real64) &
                     rate_template_attempt%limiter%potential_top_lateral_cm= &
                     rate_template_attempt%limiter%potential_top_lateral_cm+ &
                     geometry_config%domain_fraction(:,geometry%top_node)*candidate_pond_lateral_cm
              end block
            end if
            result%requested_top_input_cm=sum(rate_template_attempt%limiter%potential_top_vertical_cm)+ &
                 sum(rate_template_attempt%limiter%potential_top_lateral_cm)
          end if
        end if
      end if

      call prepare_standard_macropore_rate_request(rate_template_attempt,accepted_macro,geometry,accepted_view, &
           corrector%candidate_state,base_request%parameters%z,base_request%parameters%dz,dt, &
           rate_request,matrix_view,ok)
      if(.not.ok)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
      call evaluate_macropore_rate_bundle(rate_request,raw_rates)
      if(.not.raw_rates%valid)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if

      if(present(shrinkage_config))then
        if(shrinkage_config%enabled)then
          call evaluate_macropore_geometry_return(accepted_macro,geometry,geometry_return,ok)
          if(.not.ok)then
            result%status=MACRO_RUNTIME_FAILED
            return
          end if
          raw_rates%qexc_to_matrix_rate=raw_rates%qexc_to_matrix_rate+geometry_return/dt
        end if
      end if

      allocate(current_domain(nd,n),current_node(n))
      current_domain=raw_rates%qexc_to_matrix_rate
      current_node=sum(current_domain,dim=1)
      result%inner_final_exchange_rate_cm_per_day=sum(current_domain)

      call build_macropore_standard_candidate(accepted_macro,geometry,raw_rates%top_partition,current_domain, &
           raw_rates%rapid_outflow_cp_cm,dt,geometry_config%top_node,base_request%parameters%z, &
           base_request%parameters%dz,result%macropore_candidate,candidate_view,receipt,ok)
      if(.not.ok .or. .not.receipt%valid)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if
      if(geometry_config%top_node>1)then
        if(.not.present(covering_minimum_polygon_diameter_cm) .or. .not.present(covering_ksat_cm_per_day))then
          result%status=MACRO_RUNTIME_FAILED
          return
        end if
        covering_request%top_node=geometry_config%top_node
        covering_request%step_duration_day=dt
        covering_request%matrix_head_above_cm=corrector%candidate_state%pressure_head(geometry_config%top_node-1)
        covering_request%dz_above_cm=base_request%parameters%dz(geometry_config%top_node-1)
        covering_request%minimum_polygon_diameter_cm=covering_minimum_polygon_diameter_cm
        covering_request%covering_layer_ksat_cm_per_day=covering_ksat_cm_per_day
        covering_request%total_macropore_volume_top_cm=sum(geometry%volume_domain_cp(:,geometry_config%top_node))
        covering_request%domain_top_volume_cm=geometry%volume_domain_cp(:,geometry_config%top_node)
        call evaluate_covering_layer_input(covering_request,covered_domain_cm,ok)
        if(.not.ok)then
          result%status=MACRO_RUNTIME_FAILED
          return
        end if
        result%covered_internal_transfer_cm=sum(covered_domain_cm)
        call apply_internal_covered_top_transfer(result%macropore_candidate,geometry,geometry_config%top_node, &
             covered_domain_cm,base_request%parameters%z,base_request%parameters%dz,candidate_view,ok)
        if(.not.ok)then
          result%status=MACRO_RUNTIME_FAILED
          return
        end if
        current_node(geometry_config%top_node-1)=current_node(geometry_config%top_node-1)- &
             sum(covered_domain_cm)/dt
        receipt%internal_exchange_to_matrix_cm=receipt%internal_exchange_to_matrix_cm-sum(covered_domain_cm)
        receipt%macro_storage_change_cm=receipt%macro_storage_change_cm+sum(covered_domain_cm)
        receipt%macro_balance_residual_cm=receipt%macro_storage_change_cm - &
             (receipt%accepted_top_cm-receipt%internal_exchange_to_matrix_cm-receipt%rapid_external_outflow_cm)
        receipt%valid=abs(receipt%macro_balance_residual_cm)<=1.0e-10_real64
        if(.not.receipt%valid)then
          result%status=MACRO_RUNTIME_FAILED
          return
        end if
      end if

      call prepare_standard_sorptivity_history_request(history_request,geometry,candidate_view,matrix_view,dt, &
           history_local,ok)
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

      result%accepted_top_input_cm=raw_rates%top_partition%accepted_total_cm
      result%returned_surface_cm=receipt%returned_surface_cm
      result%rapid_external_outflow_cm=receipt%rapid_external_outflow_cm
      if(abs(result%accepted_top_input_cm+result%returned_surface_cm-result%requested_top_input_cm)> &
         policy%internal_exchange_tolerance_cm)then
        result%status=MACRO_RUNTIME_FAILED
        return
      end if

      result%internal_exchange_residual_cm=sum(current_node)*dt-receipt%internal_exchange_to_matrix_cm
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
      return
    end if

    allocate(current_domain(nd,n),next_domain(nd,n),current_node(n),overlay%exchange_rate(n))
    overlay%base=>base_request%evaluation%source_sink
    request%evaluation%source_sink=>overlay
    request%physical%macropore_active=.false.
    overlay%exchange_rate=0.0_real64

    call solver%solve(request,workspace,predictor)
    result%predictor_solves=1
    if(predictor%status/=SW_SOLVE_CONVERGED)then
      result%retry_advised=predictor%retry_advised .or. predictor%status==SW_SOLVE_RETRY_ADVISED
      result%status=merge(MACRO_RUNTIME_RETRY,MACRO_RUNTIME_FAILED,result%retry_advised)
      return
    end if

    call prepare_standard_macropore_rate_request(rate_template_step,accepted_macro,geometry,accepted_view, &
         predictor%candidate_state,base_request%parameters%z,base_request%parameters%dz,dt,rate_request,matrix_view,ok)
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

      call prepare_standard_macropore_rate_request(rate_template_step,accepted_macro,geometry,accepted_view, &
           corrector%candidate_state,base_request%parameters%z,base_request%parameters%dz,dt,rate_request,matrix_view,ok)
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
    if(present(shrinkage_config))then
      if(shrinkage_config%enabled)then
        call inner_provider%evaluate_trial_geometry(corrector%candidate_state%water_content,geometry,ok, &
             corrector%candidate_state%pressure_head)
        if(.not.ok)then
          result%status=MACRO_RUNTIME_FAILED
          return
        end if
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

    result%accepted_top_input_cm=raw_rates%top_partition%accepted_total_cm
    result%returned_surface_cm=receipt%returned_surface_cm
    result%rapid_external_outflow_cm=receipt%rapid_external_outflow_cm
    if(abs(result%accepted_top_input_cm+result%returned_surface_cm-result%requested_top_input_cm)> &
       policy%internal_exchange_tolerance_cm)then
      result%status=MACRO_RUNTIME_FAILED
      return
    end if
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
