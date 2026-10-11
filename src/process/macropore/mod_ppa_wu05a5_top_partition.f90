module mod_ppa_wu05a5_top_partition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  implicit none
  private

  type, public :: macropore_top_partition_request_t
    integer :: num_domains = 0
    integer :: top_node = 1
    real(real64), allocatable :: requested_vertical_cm(:)
    real(real64), allocatable :: requested_lateral_cm(:)
    real(real64), allocatable :: available_capacity_cm(:)
    real(real64), allocatable :: domain_fraction(:)
  contains
    procedure, public :: valid => top_partition_request_valid
  end type macropore_top_partition_request_t

  type, public :: macropore_top_partition_result_t
    logical :: valid = .false.
    integer :: num_domains = 0
    integer :: top_node = 0
    real(real64), allocatable :: requested_vertical_cm(:)
    real(real64), allocatable :: requested_lateral_cm(:)
    real(real64), allocatable :: accepted_vertical_cm(:)
    real(real64), allocatable :: accepted_lateral_cm(:)
    real(real64), allocatable :: redistributed_cm(:)
    real(real64) :: requested_total_cm = 0.0_real64
    real(real64) :: accepted_total_cm = 0.0_real64
    real(real64) :: redistributed_total_cm = 0.0_real64
    real(real64) :: returned_surface_cm = 0.0_real64
    real(real64) :: receipt_residual_cm = huge(1.0_real64)
  end type macropore_top_partition_result_t

  public :: evaluate_macropore_top_partition
  public :: apply_accepted_top_partition

contains

  pure logical function top_partition_request_valid(self) result(ok)
    class(macropore_top_partition_request_t), intent(in) :: self
    real(real64) :: fraction_sum

    ok = self%num_domains > 0 .and. self%top_node > 0
    if (.not. ok) return
    ok = allocated(self%requested_vertical_cm) .and. allocated(self%requested_lateral_cm) .and. &
         allocated(self%available_capacity_cm) .and. allocated(self%domain_fraction)
    if (.not. ok) return
    ok = size(self%requested_vertical_cm) == self%num_domains .and. &
         size(self%requested_lateral_cm) == self%num_domains .and. &
         size(self%available_capacity_cm) == self%num_domains .and. &
         size(self%domain_fraction) == self%num_domains
    if (.not. ok) return
    ok = all(self%requested_vertical_cm >= 0.0_real64) .and. &
         all(self%requested_lateral_cm >= 0.0_real64) .and. &
         all(self%available_capacity_cm >= 0.0_real64) .and. &
         all(self%domain_fraction >= 0.0_real64)
    if (.not. ok) return
    fraction_sum = sum(self%domain_fraction)
    ok = abs(fraction_sum-1.0_real64) <= 1.0e-12_real64
  end function top_partition_request_valid

  subroutine evaluate_macropore_top_partition(request, result)
    type(macropore_top_partition_request_t), intent(in) :: request
    type(macropore_top_partition_result_t), intent(out) :: result

    real(real64), allocatable :: potential(:), accepted(:), deficit(:), deficit_relative(:)
    real(real64) :: excess, potential_i, factor, pp_total, share, transfer
    integer, allocatable :: order(:)
    integer :: i, j, tmp, n

    result = macropore_top_partition_result_t()
    if (.not. request%valid()) return

    n = request%num_domains
    result%num_domains = n
    result%top_node = request%top_node
    allocate(result%requested_vertical_cm(n), result%requested_lateral_cm(n), &
         result%accepted_vertical_cm(n), result%accepted_lateral_cm(n), &
         result%redistributed_cm(n), potential(n), accepted(n), deficit(n), &
         deficit_relative(n), order(n))

    result%requested_vertical_cm = request%requested_vertical_cm
    result%requested_lateral_cm = request%requested_lateral_cm
    result%accepted_vertical_cm = 0.0_real64
    result%accepted_lateral_cm = 0.0_real64
    result%redistributed_cm = 0.0_real64

    potential = request%requested_vertical_cm + request%requested_lateral_cm
    accepted = min(potential, request%available_capacity_cm)

    do i = 1, n
      potential_i = potential(i)
      if (potential_i > 0.0_real64) then
        factor = accepted(i)/potential_i
      else
        factor = 1.0_real64
      end if
      result%accepted_vertical_cm(i) = factor*request%requested_vertical_cm(i)
      result%accepted_lateral_cm(i) = factor*request%requested_lateral_cm(i)
    end do

    excess = sum(potential-accepted)
    deficit = max(0.0_real64, request%available_capacity_cm-accepted)
    do i = 1, n
      if (request%available_capacity_cm(i) > 1.0e-30_real64) then
        deficit_relative(i) = deficit(i)/request%available_capacity_cm(i)
      else
        deficit_relative(i) = 0.0_real64
      end if
      order(i) = i
    end do

    do i = 1, n-1
      do j = i+1, n
        if (deficit_relative(order(i)) > deficit_relative(order(j))) then
          tmp = order(i)
          order(i) = order(j)
          order(j) = tmp
        end if
      end do
    end do

    pp_total = 1.0_real64
    do i = 1, n
      j = order(i)
      potential_i = potential(j)
      if (deficit(j) > 1.0e-12_real64 .and. potential_i > 1.0e-12_real64 .and. excess > 1.0e-12_real64) then
        if (pp_total > 1.0e-30_real64) then
          share = request%domain_fraction(j)/pp_total
        else
          share = 0.0_real64
        end if
        transfer = min(share*excess, deficit(j))
        factor = transfer/potential_i
        result%accepted_vertical_cm(j) = result%accepted_vertical_cm(j) + &
             factor*request%requested_vertical_cm(j)
        result%accepted_lateral_cm(j) = result%accepted_lateral_cm(j) + &
             factor*request%requested_lateral_cm(j)
        result%redistributed_cm(j) = result%redistributed_cm(j) + transfer
        accepted(j) = accepted(j) + transfer
        deficit(j) = max(0.0_real64, deficit(j)-transfer)
        excess = max(0.0_real64, excess-transfer)
      end if
      pp_total = pp_total-request%domain_fraction(j)
    end do

    result%requested_total_cm = sum(potential)
    result%accepted_total_cm = sum(result%accepted_vertical_cm) + sum(result%accepted_lateral_cm)
    result%redistributed_total_cm = sum(result%redistributed_cm)
    result%returned_surface_cm = max(0.0_real64, excess)
    result%receipt_residual_cm = result%accepted_total_cm + result%returned_surface_cm - &
         result%requested_total_cm
    result%valid = abs(result%receipt_residual_cm) <= 1.0e-12_real64
  end subroutine evaluate_macropore_top_partition

  subroutine apply_accepted_top_partition(result, candidate_macro, ok)
    type(macropore_top_partition_result_t), intent(in) :: result
    type(macropore_continuation_state_t), intent(inout) :: candidate_macro
    logical, intent(out) :: ok

    integer :: id
    real(real64) :: amount, available

    ok = .false.
    if (.not. result%valid) return
    if (.not. candidate_macro%ready()) return
    if (candidate_macro%num_domains /= result%num_domains) return
    if (result%top_node < 1 .or. result%top_node > candidate_macro%num_nodes) return

    do id = 1, result%num_domains
      amount = result%accepted_vertical_cm(id) + result%accepted_lateral_cm(id)
      available = max(0.0_real64, candidate_macro%volume_domain_cp(id,result%top_node) - &
           candidate_macro%water_domain_cp(id,result%top_node))
      if (amount > available + 1.0e-10_real64) return
    end do

    do id = 1, result%num_domains
      amount = result%accepted_vertical_cm(id) + result%accepted_lateral_cm(id)
      candidate_macro%water_domain_cp(id,result%top_node) = &
           candidate_macro%water_domain_cp(id,result%top_node) + amount
    end do
    ok = .true.
  end subroutine apply_accepted_top_partition

end module mod_ppa_wu05a5_top_partition
