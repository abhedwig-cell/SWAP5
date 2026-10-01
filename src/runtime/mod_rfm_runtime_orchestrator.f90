module mod_rfm_runtime_orchestrator
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_rfm_physical_state, only: rfm_physical_state_t, copy_rfm_physical_state
  use mod_rfm_preferential_router, only: rfm_preferential_routing_result_t, RFM_PREF_ROUTER_AVAILABLE
  use mod_rfm_endpoint_release, only: rfm_endpoint_release_request_t, rfm_endpoint_release_result_t, &
       evaluate_rfm_endpoint_release
  use mod_rfm_mb_wall_deep_fate, only: rfm_mb_fate_request_t, rfm_mb_fate_result_t, &
       evaluate_rfm_mb_wall_deep_fate
  use mod_rfm_whole_column_candidate_ledger, only: rfm_whole_column_candidate_request_t, &
       rfm_whole_column_candidate_result_t, evaluate_rfm_whole_column_candidate_ledger
  implicit none
  private

  type, public :: rfm_runtime_orchestrator_request_t
    real(real64) :: step_duration_day=0.0_real64
    real(real64) :: effective_supply_rate_cm_per_day=0.0_real64
    real(real64) :: matrix_supply_rate_cm_per_day=0.0_real64
    integer, allocatable :: endpoint_node_index(:)
    integer :: mb_wall_node_index=0
    real(real64), allocatable :: node_thickness_cm(:)
    type(rfm_endpoint_release_request_t) :: endpoint_release
    type(rfm_mb_fate_request_t) :: mb_fate
  end type

  type, public :: rfm_runtime_orchestrator_result_t
    logical :: valid=.false.
    type(rfm_physical_state_t) :: candidate_rfm
    real(real64), allocatable :: matrix_source_rate_per_day(:)
    type(rfm_endpoint_release_result_t) :: endpoint_release
    type(rfm_mb_fate_result_t) :: mb_fate
    type(rfm_whole_column_candidate_result_t) :: ledger
    real(real64) :: deep_receipt_cm=0.0_real64
  end type

  public :: compose_rfm_runtime_candidate

contains

  subroutine compose_rfm_runtime_candidate(accepted, routing, request, tolerance, result)
    type(rfm_physical_state_t),intent(in)::accepted
    type(rfm_preferential_routing_result_t),intent(in)::routing
    type(rfm_runtime_orchestrator_request_t),intent(in)::request
    real(real64),intent(in)::tolerance
    type(rfm_runtime_orchestrator_result_t),intent(out)::result

    type(rfm_endpoint_release_request_t)::er
    type(rfm_whole_column_candidate_request_t)::ledger_request
    real(real64),allocatable::endpoint_input_cm(:)
    real(real64)::effective_cm,matrix_cm,ic_cm,mb_cm
    logical::ok
    integer::i,n,node

    result=rfm_runtime_orchestrator_result_t()
    if(.not.accepted%ready())return
    if(routing%status/=RFM_PREF_ROUTER_AVAILABLE)return
    if(.not.ieee_is_finite(request%step_duration_day).or.request%step_duration_day<=0.0_real64)return
    if(.not.ieee_is_finite(tolerance).or.tolerance<0.0_real64)return
    if(.not.allocated(routing%endpoint_amount))return
    n=accepted%endpoint_count
    if(size(routing%endpoint_amount)/=n)return
    if(.not.allocated(request%endpoint_node_index).or.size(request%endpoint_node_index)/=n)return
    if(.not.allocated(request%node_thickness_cm).or.size(request%node_thickness_cm)<=0)return
    if(any(request%node_thickness_cm<=0.0_real64).or.any(.not.ieee_is_finite(request%node_thickness_cm)))return
    if(any(request%endpoint_node_index<1).or.any(request%endpoint_node_index>size(request%node_thickness_cm)))return
    if(request%mb_wall_node_index<1.or.request%mb_wall_node_index>size(request%node_thickness_cm))return

    effective_cm=request%effective_supply_rate_cm_per_day*request%step_duration_day
    matrix_cm=request%matrix_supply_rate_cm_per_day*request%step_duration_day
    ic_cm=sum(routing%endpoint_amount)*request%step_duration_day
    mb_cm=routing%mb_amount*request%step_duration_day
    if(min(effective_cm,matrix_cm,ic_cm,mb_cm)<0.0_real64)return
    if(abs(effective_cm-matrix_cm-ic_cm-mb_cm)>tolerance)return

    allocate(endpoint_input_cm(n))
    endpoint_input_cm=routing%endpoint_amount*request%step_duration_day

    er=request%endpoint_release
    if(.not.allocated(er%accepted_wall_age_day))allocate(er%accepted_wall_age_day(n))
    if(.not.allocated(er%wall_sorptivity_cm_sqrt_day))allocate(er%wall_sorptivity_cm_sqrt_day(n))
    if(size(er%accepted_wall_age_day)/=n.or.size(er%wall_sorptivity_cm_sqrt_day)/=n)return
    er%accepted_wall_age_day=accepted%wall_age_day
    er%wall_sorptivity_cm_sqrt_day=accepted%wall_sorptivity_cm_sqrt_day
    if(.not.allocated(er%accepted_storage_cm))allocate(er%accepted_storage_cm(n))
    if(size(er%accepted_storage_cm)/=n)return
    er%accepted_storage_cm=accepted%endpoint_water_cm+endpoint_input_cm
    er%step_duration_day=request%step_duration_day
    call evaluate_rfm_endpoint_release(er,tolerance,result%endpoint_release)
    if(.not.result%endpoint_release%valid)return

    result%mb_fate=rfm_mb_fate_result_t()
    block
      type(rfm_mb_fate_request_t)::mbreq
      mbreq=request%mb_fate
      mbreq%mb_input_cm=mb_cm
      mbreq%step_duration_day=request%step_duration_day
      call evaluate_rfm_mb_wall_deep_fate(mbreq,tolerance,result%mb_fate)
    end block
    if(.not.result%mb_fate%valid)return

    call copy_rfm_physical_state(accepted,result%candidate_rfm,ok)
    if(.not.ok)return
    result%candidate_rfm%endpoint_water_cm=result%endpoint_release%candidate_storage_cm
    result%candidate_rfm%wall_age_day=result%endpoint_release%candidate_wall_age_day
    result%candidate_rfm%wall_sorptivity_cm_sqrt_day=result%endpoint_release%candidate_wall_sorptivity_cm_sqrt_day
    result%candidate_rfm%mb_water_cm=0.0_real64

    allocate(result%matrix_source_rate_per_day(size(request%node_thickness_cm)))
    result%matrix_source_rate_per_day=0.0_real64
    do i=1,n
      node=request%endpoint_node_index(i)
      result%matrix_source_rate_per_day(node)=result%matrix_source_rate_per_day(node)+ &
        result%endpoint_release%release_to_matrix_cm(i)/(request%node_thickness_cm(node)*request%step_duration_day)
    end do
    ! MB wall exchange uses an explicit caller-owned matrix-node mapping.
    node=request%mb_wall_node_index
    result%matrix_source_rate_per_day(node)=result%matrix_source_rate_per_day(node)+ &
      result%mb_fate%wall_to_matrix_cm/(request%node_thickness_cm(node)*request%step_duration_day)

    ledger_request%effective_input_cm=effective_cm
    ledger_request%matrix_input_cm=matrix_cm
    ledger_request%ic_input_cm=ic_cm
    ledger_request%mb_input_cm=mb_cm
    ledger_request%endpoint_storage_start_cm=sum(accepted%endpoint_water_cm)
    ledger_request%endpoint_to_matrix_cm=result%endpoint_release%release_total_cm
    ledger_request%endpoint_storage_end_cm=sum(result%candidate_rfm%endpoint_water_cm)
    ledger_request%mb_wall_to_matrix_cm=result%mb_fate%wall_to_matrix_cm
    ledger_request%mb_deep_receipt_cm=result%mb_fate%deep_receipt_cm
    ledger_request%mb_storage_end_cm=result%candidate_rfm%mb_water_cm
    call evaluate_rfm_whole_column_candidate_ledger(ledger_request,tolerance,result%ledger)
    if(.not.result%ledger%valid)return

    result%deep_receipt_cm=result%mb_fate%deep_receipt_cm
    result%valid=.true.
  end subroutine
end module mod_rfm_runtime_orchestrator
