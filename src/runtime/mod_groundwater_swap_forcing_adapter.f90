module mod_groundwater_swap_forcing_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_forcing_t
  use mod_kernel_transactions, only: kernel_parameters_t
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  implicit none
  private

  integer, parameter, public :: GW_SWAP_FORCING_OK = 0
  integer, parameter, public :: GW_SWAP_FORCING_PROFILE_NOT_ADMITTED = 1
  integer, parameter, public :: GW_SWAP_FORCING_INVALID_HEAD = 2
  integer, parameter, public :: GW_SWAP_FORCING_NOT_READY = 3

  ! Narrow runtime seam between the generic groundwater-window orchestrator and
  ! a concrete SWAP forcing representation.  The orchestrator owns coupling
  ! semantics; implementations only certify the restricted prescribed-head
  ! profile and materialize one immutable trial forcing for a typed interface
  ! hydraulic head.  No solver-private state or HeadCalc arrays cross this seam.
  type, abstract, public :: groundwater_swap_forcing_materializer_t
  contains
    procedure(gw_swap_profile_admitted_iface), deferred, public :: profile_admitted
    procedure(gw_swap_materialize_iface), deferred, public :: materialize
  end type groundwater_swap_forcing_materializer_t

  abstract interface
    logical function gw_swap_profile_admitted_iface(self, parameters)
      import :: groundwater_swap_forcing_materializer_t, kernel_parameters_t
      class(groundwater_swap_forcing_materializer_t), intent(in) :: self
      class(kernel_parameters_t), intent(in) :: parameters
    end function gw_swap_profile_admitted_iface

    subroutine gw_swap_materialize_iface(self, interface_head_m, datum, forcing, status)
      import :: groundwater_swap_forcing_materializer_t, groundwater_head_datum_t, canonical_forcing_t, real64
      class(groundwater_swap_forcing_materializer_t), intent(in) :: self
      real(real64), intent(in) :: interface_head_m
      type(groundwater_head_datum_t), intent(in) :: datum
      class(canonical_forcing_t), allocatable, intent(out) :: forcing
      integer, intent(out) :: status
    end subroutine gw_swap_materialize_iface
  end interface

end module mod_groundwater_swap_forcing_adapter
