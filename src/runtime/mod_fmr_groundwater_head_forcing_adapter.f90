module mod_fmr_groundwater_head_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_forcing_t
  use mod_kernel_transactions, only: kernel_parameters_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, &
       interface_head_m_to_swap_pressure_head_cm, GW_INTERFACE_OK
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t, &
       GW_SWAP_FORCING_OK, GW_SWAP_FORCING_PROFILE_NOT_ADMITTED, GW_SWAP_FORCING_INVALID_HEAD, &
       GW_SWAP_FORCING_NOT_READY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t
  implicit none
  private

  type, extends(groundwater_swap_forcing_materializer_t), public :: fmr_groundwater_head_forcing_materializer_t
    private
    logical :: initialized = .false.
    type(fmr_b110_physical_forcing_t) :: base_forcing
  contains
    procedure, public :: initialize => fmr_groundwater_forcing_initialize
    procedure, public :: profile_admitted => fmr_groundwater_profile_admitted
    procedure, public :: materialize => fmr_groundwater_forcing_materialize
  end type fmr_groundwater_head_forcing_materializer_t

contains

  subroutine fmr_groundwater_forcing_initialize(self, base_forcing)
    class(fmr_groundwater_head_forcing_materializer_t), intent(inout) :: self
    type(fmr_b110_physical_forcing_t), intent(in) :: base_forcing

    self%base_forcing = base_forcing
    self%initialized = .true.
  end subroutine fmr_groundwater_forcing_initialize

  logical function fmr_groundwater_profile_admitted(self, parameters) result(admitted)
    class(fmr_groundwater_head_forcing_materializer_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    admitted = .false.
    if (.not. self%initialized) return
    select type (typed_parameters => parameters)
    type is (fmr_b110_physical_parameters_t)
      admitted = typed_parameters%bottom_mode == 5
    class default
      admitted = .false.
    end select
  end function fmr_groundwater_profile_admitted

  subroutine fmr_groundwater_forcing_materialize(self, interface_head_m, datum, forcing, status)
    class(fmr_groundwater_head_forcing_materializer_t), intent(in) :: self
    real(real64), intent(in) :: interface_head_m
    type(groundwater_head_datum_t), intent(in) :: datum
    class(canonical_forcing_t), allocatable, intent(out) :: forcing
    integer, intent(out) :: status
    real(real64) :: pressure_head_cm
    integer :: mapping_status

    if (allocated(forcing)) deallocate(forcing)
    status = GW_SWAP_FORCING_NOT_READY
    if (.not. self%initialized) return

    status = GW_SWAP_FORCING_INVALID_HEAD
    if (.not. ieee_is_finite(interface_head_m) .or. .not. datum%valid()) return
    call interface_head_m_to_swap_pressure_head_cm(interface_head_m, datum, pressure_head_cm, mapping_status)
    if (mapping_status /= GW_INTERFACE_OK .or. .not. ieee_is_finite(pressure_head_cm)) return

    allocate(fmr_b110_physical_forcing_t :: forcing)
    select type (typed_forcing => forcing)
    type is (fmr_b110_physical_forcing_t)
      typed_forcing = self%base_forcing
      typed_forcing%bottom_head = pressure_head_cm
      status = GW_SWAP_FORCING_OK
    class default
      status = GW_SWAP_FORCING_PROFILE_NOT_ADMITTED
    end select
  end subroutine fmr_groundwater_forcing_materialize

end module mod_fmr_groundwater_head_forcing_adapter
