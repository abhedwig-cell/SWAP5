module mod_ppa_wu05a6_rate_bundle
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a5_top_partition, only: macropore_top_partition_result_t
  use mod_ppa_wu05a6_unsat_absorption_rate, only: unsat_absorption_request_t, &
       unsat_absorption_result_t, evaluate_unsat_absorption
  use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
  use mod_ppa_wu05a6_saturated_sources, only: saturated_sources_result_t, evaluate_saturated_sources
  use mod_ppa_wu05a6_rapid_drain_rate, only: rapid_drain_request_t, rapid_drain_result_t, &
       evaluate_rapid_drain
  use mod_ppa_wu05a6_top_inflow_limiter, only: standard_inflow_limit_request_t, &
       standard_inflow_limit_result_t, evaluate_standard_inflow_limit
  implicit none
  private

  type, public :: macropore_rate_bundle_request_t
    type(unsat_absorption_request_t) :: unsaturated
    type(saturated_exchange_request_t) :: interflow_sat
    type(saturated_exchange_request_t) :: matrix_sat
    type(rapid_drain_request_t) :: rapid
    type(standard_inflow_limit_request_t) :: limiter
    integer :: top_node = 1
    logical :: perched_detection_enabled = .false.
    real(real64) :: critical_under_saturated_volume_cm = 0.0_real64
  end type macropore_rate_bundle_request_t

  type, public :: macropore_rate_bundle_result_t
    logical :: valid = .false.
    type(unsat_absorption_result_t) :: unsaturated
    type(saturated_sources_result_t) :: saturated
    type(rapid_drain_result_t) :: rapid
    type(standard_inflow_limit_result_t) :: limiter
    type(macropore_top_partition_result_t) :: top_partition
    real(real64), allocatable :: qout_unsat_rate(:,:)
    real(real64), allocatable :: qout_sat_rate(:,:)
    real(real64), allocatable :: qin_interflow_rate(:,:)
    real(real64), allocatable :: qin_matrix_sat_rate(:,:)
    real(real64), allocatable :: qexc_to_matrix_rate(:,:)
    real(real64), allocatable :: rapid_outflow_cp_cm(:)
  end type macropore_rate_bundle_result_t

  public :: evaluate_macropore_rate_bundle

contains

  subroutine evaluate_macropore_rate_bundle(request,result)
    type(macropore_rate_bundle_request_t),intent(in)::request
    type(macropore_rate_bundle_result_t),intent(out)::result

    type(standard_inflow_limit_request_t) :: limiter_request
    integer :: nd,n,id
    real(real64) :: dt

    result=macropore_rate_bundle_result_t()

    if(.not.request%unsaturated%valid())return
    if(.not.request%interflow_sat%valid() .or. .not.request%matrix_sat%valid())return
    if(.not.request%rapid%valid())return
    if(.not.request%limiter%valid())return

    nd=request%unsaturated%sorptivity%num_domains
    n=request%unsaturated%sorptivity%num_nodes
    dt=request%unsaturated%sorptivity%step_duration

    if(request%interflow_sat%num_domains/=nd .or. request%matrix_sat%num_domains/=nd .or. &
       request%interflow_sat%num_nodes/=n .or. request%matrix_sat%num_nodes/=n)return
    if(request%limiter%num_domains/=nd)return
    if(abs(request%interflow_sat%step_duration-dt)>1.0e-14_real64 .or. &
       abs(request%matrix_sat%step_duration-dt)>1.0e-14_real64 .or. &
       abs(request%rapid%step_duration-dt)>1.0e-14_real64)return

    call evaluate_unsat_absorption(request%unsaturated,result%unsaturated)
    if(.not.result%unsaturated%valid)return

    call evaluate_saturated_sources(request%interflow_sat,request%matrix_sat,result%saturated)
    if(.not.result%saturated%valid)return

    call evaluate_rapid_drain(request%rapid,result%rapid)
    if(.not.result%rapid%valid)return

    call copy_limiter_request(request%limiter,limiter_request)
    limiter_request%potential_interflow_sat_cm = sum(result%saturated%qin_interflow_rate,dim=2)*dt
    limiter_request%potential_matrix_sat_cm = sum(result%saturated%qin_matrix_sat_rate,dim=2)*dt
    limiter_request%potential_outflow_cm = &
         sum(result%saturated%qout_matrix_sat_rate+result%unsaturated%selected_rate_cm_per_day,dim=2)*dt
    limiter_request%potential_outflow_cm(1) = limiter_request%potential_outflow_cm(1) + &
         result%rapid%total_amount_cm

    call evaluate_standard_inflow_limit(limiter_request,result%limiter)
    if(.not.result%limiter%valid)return

    allocate(result%qout_unsat_rate(nd,n),result%qout_sat_rate(nd,n), &
         result%qin_interflow_rate(nd,n),result%qin_matrix_sat_rate(nd,n), &
         result%qexc_to_matrix_rate(nd,n),result%rapid_outflow_cp_cm(n))

    do id=1,nd
      result%qout_unsat_rate(id,:) = result%limiter%outflow_fraction(id) * &
           result%unsaturated%selected_rate_cm_per_day(id,:)
      result%qout_sat_rate(id,:) = result%limiter%outflow_fraction(id) * &
           result%saturated%qout_matrix_sat_rate(id,:)
      result%qin_interflow_rate(id,:) = result%limiter%inflow_fraction(id) * &
           result%saturated%qin_interflow_rate(id,:)
      result%qin_matrix_sat_rate(id,:) = result%limiter%inflow_fraction(id) * &
           result%saturated%qin_matrix_sat_rate(id,:)
    end do

    result%qexc_to_matrix_rate = result%qout_sat_rate + result%qout_unsat_rate - &
         result%qin_interflow_rate - result%qin_matrix_sat_rate

    result%rapid_outflow_cp_cm = result%limiter%outflow_fraction(1) * result%rapid%amount_cp_cm

    call build_top_partition(request,result%limiter,result%top_partition)
    if(.not.result%top_partition%valid)return

    result%valid=.true.
  end subroutine evaluate_macropore_rate_bundle

  subroutine copy_limiter_request(source,target)
    type(standard_inflow_limit_request_t),intent(in)::source
    type(standard_inflow_limit_request_t),intent(out)::target
    integer::nd

    nd=source%num_domains
    target%num_domains=nd
    allocate(target%accepted_storage_cm(nd),target%maximum_storage_cm(nd),target%minimum_storage_cm(nd), &
         target%potential_top_vertical_cm(nd),target%potential_top_lateral_cm(nd), &
         target%potential_interflow_sat_cm(nd),target%potential_matrix_sat_cm(nd), &
         target%potential_outflow_cm(nd),target%redistribution_capacity_cm(nd), &
         target%top_domain_fraction(nd))
    target%accepted_storage_cm=source%accepted_storage_cm
    target%maximum_storage_cm=source%maximum_storage_cm
    target%minimum_storage_cm=source%minimum_storage_cm
    target%potential_top_vertical_cm=source%potential_top_vertical_cm
    target%potential_top_lateral_cm=source%potential_top_lateral_cm
    target%potential_interflow_sat_cm=source%potential_interflow_sat_cm
    target%potential_matrix_sat_cm=source%potential_matrix_sat_cm
    target%potential_outflow_cm=source%potential_outflow_cm
    target%redistribution_capacity_cm=source%redistribution_capacity_cm
    target%top_domain_fraction=source%top_domain_fraction
  end subroutine copy_limiter_request

  subroutine build_top_partition(request,limiter,top)
    type(macropore_rate_bundle_request_t),intent(in)::request
    type(standard_inflow_limit_result_t),intent(in)::limiter
    type(macropore_top_partition_result_t),intent(out)::top
    integer::nd

    top=macropore_top_partition_result_t()
    nd=request%limiter%num_domains
    top%num_domains=nd
    top%top_node=request%top_node
    allocate(top%requested_vertical_cm(nd),top%requested_lateral_cm(nd), &
         top%accepted_vertical_cm(nd),top%accepted_lateral_cm(nd),top%redistributed_cm(nd))
    top%requested_vertical_cm=request%limiter%potential_top_vertical_cm
    top%requested_lateral_cm=request%limiter%potential_top_lateral_cm
    top%accepted_vertical_cm=limiter%accepted_top_vertical_cm
    top%accepted_lateral_cm=limiter%accepted_top_lateral_cm
    top%redistributed_cm=limiter%redistributed_top_cm
    top%requested_total_cm=sum(top%requested_vertical_cm)+sum(top%requested_lateral_cm)
    top%accepted_total_cm=sum(top%accepted_vertical_cm)+sum(top%accepted_lateral_cm)
    top%redistributed_total_cm=sum(top%redistributed_cm)
    top%returned_surface_cm=limiter%returned_surface_cm
    top%receipt_residual_cm=top%accepted_total_cm+top%returned_surface_cm-top%requested_total_cm
    top%valid=abs(top%receipt_residual_cm)<=1.0e-12_real64
  end subroutine build_top_partition

end module mod_ppa_wu05a6_rate_bundle
