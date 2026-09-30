module mod_ppa_wu05a5_macropore_restart
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  implicit none
  private

  integer(int64), parameter, public :: PPA_WU05A5_RESTART_SCHEMA = 5055001_int64

  type, public :: macropore_restart_payload_t
    integer(int64) :: schema = 0_int64
    integer :: num_domains = 0
    integer :: num_nodes = 0
    integer, allocatable :: integer_payload(:)
    real(real64), allocatable :: real_payload(:)
  contains
    procedure, public :: valid => restart_payload_valid
  end type macropore_restart_payload_t

  public :: encode_macropore_restart
  public :: decode_macropore_restart

contains

  pure logical function restart_payload_valid(self) result(ok)
    class(macropore_restart_payload_t), intent(in) :: self
    integer :: expected_real

    ok = self%schema == PPA_WU05A5_RESTART_SCHEMA .and. self%num_domains > 0 .and. self%num_nodes > 0
    if (.not. ok) return
    ok = allocated(self%integer_payload) .and. allocated(self%real_payload)
    if (.not. ok) return
    expected_real = 5*self%num_domains*self%num_nodes + self%num_nodes
    ok = size(self%integer_payload) == self%num_domains .and. size(self%real_payload) == expected_real
  end function restart_payload_valid

  subroutine encode_macropore_restart(state, payload, ok)
    type(macropore_continuation_state_t), intent(in) :: state
    type(macropore_restart_payload_t), intent(out) :: payload
    logical, intent(out) :: ok

    integer :: nd, n, cursor, count2

    payload = macropore_restart_payload_t()
    ok = .false.
    if (.not. state%ready()) return

    nd = state%num_domains
    n = state%num_nodes
    count2 = nd*n
    payload%schema = PPA_WU05A5_RESTART_SCHEMA
    payload%num_domains = nd
    payload%num_nodes = n
    allocate(payload%integer_payload(nd), payload%real_payload(5*count2+n))

    payload%integer_payload = state%icp_bottom_domain
    cursor = 1
    payload%real_payload(cursor:cursor+count2-1) = reshape(state%sorptivity,[count2])
    cursor = cursor+count2
    payload%real_payload(cursor:cursor+count2-1) = reshape(state%theta_sorption_ref,[count2])
    cursor = cursor+count2
    payload%real_payload(cursor:cursor+count2-1) = reshape(state%absorption_time,[count2])
    cursor = cursor+count2
    payload%real_payload(cursor:cursor+count2-1) = reshape(state%volume_domain_cp,[count2])
    cursor = cursor+count2
    payload%real_payload(cursor:cursor+count2-1) = reshape(state%water_domain_cp,[count2])
    cursor = cursor+count2
    payload%real_payload(cursor:cursor+n-1) = state%dynamic_volume_cp

    ok = payload%valid()
  end subroutine encode_macropore_restart

  subroutine decode_macropore_restart(payload, state, ok)
    type(macropore_restart_payload_t), intent(in) :: payload
    type(macropore_continuation_state_t), intent(inout) :: state
    logical, intent(out) :: ok

    integer :: nd, n, cursor, count2

    ok = .false.
    if (.not. payload%valid()) return
    nd = payload%num_domains
    n = payload%num_nodes
    count2 = nd*n

    call state%initialize(nd,n,ok)
    if (.not. ok) return

    state%icp_bottom_domain = payload%integer_payload
    cursor = 1
    state%sorptivity = reshape(payload%real_payload(cursor:cursor+count2-1),[nd,n])
    cursor = cursor+count2
    state%theta_sorption_ref = reshape(payload%real_payload(cursor:cursor+count2-1),[nd,n])
    cursor = cursor+count2
    state%absorption_time = reshape(payload%real_payload(cursor:cursor+count2-1),[nd,n])
    cursor = cursor+count2
    state%volume_domain_cp = reshape(payload%real_payload(cursor:cursor+count2-1),[nd,n])
    cursor = cursor+count2
    state%water_domain_cp = reshape(payload%real_payload(cursor:cursor+count2-1),[nd,n])
    cursor = cursor+count2
    state%dynamic_volume_cp = payload%real_payload(cursor:cursor+n-1)

    ok = state%ready()
  end subroutine decode_macropore_restart

end module mod_ppa_wu05a5_macropore_restart
