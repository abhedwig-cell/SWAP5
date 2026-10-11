module mod_ppa_wu05a6_saturated_sources
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t, &
       saturated_exchange_result_t, evaluate_saturated_exchange
  implicit none
  private

  type, public :: saturated_sources_result_t
    logical :: valid = .false.
    real(real64), allocatable :: qin_interflow_rate(:,:)
    real(real64), allocatable :: qin_matrix_sat_rate(:,:)
    real(real64), allocatable :: qout_matrix_sat_rate(:,:)
    real(real64), allocatable :: qexc_sat_to_matrix_rate(:,:)
  end type saturated_sources_result_t

  public :: evaluate_saturated_sources

contains

  subroutine evaluate_saturated_sources(interflow_request, matrix_request, result)
    type(saturated_exchange_request_t), intent(in) :: interflow_request
    type(saturated_exchange_request_t), intent(in) :: matrix_request
    type(saturated_sources_result_t), intent(out) :: result

    type(saturated_exchange_result_t) :: interflow, matrix
    integer :: nd,n

    result = saturated_sources_result_t()
    if (.not. interflow_request%valid() .or. .not. matrix_request%valid()) return
    if (interflow_request%num_domains /= matrix_request%num_domains .or. &
        interflow_request%num_nodes /= matrix_request%num_nodes) return

    call evaluate_saturated_exchange(interflow_request,interflow)
    call evaluate_saturated_exchange(matrix_request,matrix)
    if (.not. interflow%valid .or. .not. matrix%valid) return

    nd=matrix_request%num_domains
    n=matrix_request%num_nodes
    allocate(result%qin_interflow_rate(nd,n),result%qin_matrix_sat_rate(nd,n), &
         result%qout_matrix_sat_rate(nd,n),result%qexc_sat_to_matrix_rate(nd,n))

    result%qin_interflow_rate = interflow%matrix_to_macro_amount_cm/interflow_request%step_duration
    result%qin_matrix_sat_rate = matrix%matrix_to_macro_amount_cm/matrix_request%step_duration
    result%qout_matrix_sat_rate = matrix%macro_to_matrix_amount_cm/matrix_request%step_duration
    result%qexc_sat_to_matrix_rate = result%qout_matrix_sat_rate - &
         result%qin_interflow_rate - result%qin_matrix_sat_rate
    result%valid=.true.
  end subroutine evaluate_saturated_sources

end module mod_ppa_wu05a6_saturated_sources
