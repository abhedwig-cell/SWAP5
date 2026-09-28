module mod_ppa_atm02_pmdirect_prescribed_root_sink
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, &
       CROP_ROOT_INPUT_OK
  use mod_pmdirect_swetr0_process, only: pmdirect_swetr0_interval_result_t, pmdirect_swetr0_diagnostics_t, &
       PMDIRECT_SWETR0_OK
  implicit none
  private

  integer, parameter, public :: PPA_ATM02_ROOT_SINK_OK = 0
  integer, parameter, public :: PPA_ATM02_ROOT_SINK_UPSTREAM_REJECTED = 1
  integer, parameter, public :: PPA_ATM02_ROOT_SINK_GEOMETRY_REJECTED = 2
  integer, parameter, public :: PPA_ATM02_ROOT_SINK_INVALID_RESULT = 3

  type, public :: ppa_atm02_root_sink_diagnostics_t
    integer :: status = PPA_ATM02_ROOT_SINK_UPSTREAM_REJECTED
    integer :: crop_input_status = CROP_ROOT_INPUT_OK
    logical :: result_produced = .false.
  end type ppa_atm02_root_sink_diagnostics_t

  public :: materialize_ppa_atm02_prescribed_root_sink

contains

  subroutine materialize_ppa_atm02_prescribed_root_sink(base_input, active_nodes, pmdirect_result, pmdirect_diagnostics, &
      root_sink, diagnostics)
    type(crop_root_uptake_input_t), intent(in) :: base_input
    integer, intent(in) :: active_nodes
    type(pmdirect_swetr0_interval_result_t), intent(in) :: pmdirect_result
    type(pmdirect_swetr0_diagnostics_t), intent(in) :: pmdirect_diagnostics
    real(real64), allocatable, intent(out) :: root_sink(:)
    type(ppa_atm02_root_sink_diagnostics_t), intent(out) :: diagnostics
    integer :: i

    diagnostics = ppa_atm02_root_sink_diagnostics_t()
    allocate(root_sink(0))
    if (pmdirect_diagnostics%status /= PMDIRECT_SWETR0_OK .or. .not. pmdirect_diagnostics%interval_result_produced) return
    call validate_crop_root_uptake_input(base_input, active_nodes, diagnostics%crop_input_status)
    if (diagnostics%crop_input_status /= CROP_ROOT_INPUT_OK) then
      diagnostics%status = PPA_ATM02_ROOT_SINK_GEOMETRY_REJECTED
      return
    end if
    deallocate(root_sink)
    allocate(root_sink(active_nodes))
    root_sink = 0.0_real64
    if (base_input%crop_emerged .and. base_input%rooted_nodes > 0) then
      do i = 1, base_input%rooted_nodes
        root_sink(i) = pmdirect_result%potential_transpiration_cm_per_day * &
          (base_input%cumulative_root_fraction(i + 1) - base_input%cumulative_root_fraction(i))
      end do
    end if
    if (any(.not. ieee_is_finite(root_sink)) .or. any(root_sink < 0.0_real64)) then
      deallocate(root_sink)
      allocate(root_sink(0))
      diagnostics%status = PPA_ATM02_ROOT_SINK_INVALID_RESULT
      return
    end if
    diagnostics%status = PPA_ATM02_ROOT_SINK_OK
    diagnostics%result_produced = .true.
  end subroutine materialize_ppa_atm02_prescribed_root_sink

end module mod_ppa_atm02_pmdirect_prescribed_root_sink
