program test_sw_rib_pa01_owner_contract
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER, FMR_OPTIONAL_STATE_LAYOUT_SNOW
  use mod_fmr_surface_water_owner_contract, only: FMR_SURFACE_OWNER_NONE, &
       FMR_SURFACE_OWNER_SWAP_FIXED_WEIR, FMR_SURFACE_OWNER_EXTERNAL_RIBASIM, &
       FMR_SURFACE_OWNER_OK, FMR_SURFACE_OWNER_INVALID_MODE, FMR_SURFACE_OWNER_CONFLICT, &
       FMR_SURFACE_OWNER_LAYOUT_MISMATCH, fmr_surface_water_owner_status
  implicit none

  call require(fmr_surface_water_owner_status(FMR_SURFACE_OWNER_EXTERNAL_RIBASIM, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE) == FMR_SURFACE_OWNER_OK, 'external/base')
  call require(fmr_surface_water_owner_status(FMR_SURFACE_OWNER_EXTERNAL_RIBASIM, &
       FMR_OPTIONAL_STATE_LAYOUT_SNOW) == FMR_SURFACE_OWNER_OK, 'external/non-fixed-weir optional state')
  call require(fmr_surface_water_owner_status(FMR_SURFACE_OWNER_EXTERNAL_RIBASIM, &
       FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER) == FMR_SURFACE_OWNER_CONFLICT, &
       'external/internal fixed-weir conflict')
  call require(fmr_surface_water_owner_status(FMR_SURFACE_OWNER_SWAP_FIXED_WEIR, &
       FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER) == FMR_SURFACE_OWNER_OK, 'internal/fixed-weir')
  call require(fmr_surface_water_owner_status(FMR_SURFACE_OWNER_SWAP_FIXED_WEIR, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE) == FMR_SURFACE_OWNER_LAYOUT_MISMATCH, 'internal/missing state')
  call require(fmr_surface_water_owner_status(FMR_SURFACE_OWNER_NONE, &
       FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER) == FMR_SURFACE_OWNER_LAYOUT_MISMATCH, 'none/fixed state')
  call require(fmr_surface_water_owner_status(99, FMR_OPTIONAL_STATE_LAYOUT_BASE) == &
       FMR_SURFACE_OWNER_INVALID_MODE, 'invalid mode')

  write(*,'(A)') 'SW_RIB_PA01_OWNER_XOR_CONTRACT=PASS'
contains
  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'SW_RIB_PA01_OWNER_CONTRACT_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_sw_rib_pa01_owner_contract
