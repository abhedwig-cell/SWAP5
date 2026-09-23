program test_sw_rib_pa01_bootstrap_profile
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_surface_water_owner_contract, only: FMR_SURFACE_OWNER_EXTERNAL_RIBASIM
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED, FMR_DRAIN_VARIANT_LINEAR
  use mod_drainage_extended_exchange, only: EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_tile_config_t, &
       fmr_external_ribasim_surface_tile_profile_valid
  implicit none

  type(fmr_production_application_tile_config_t) :: tile

  call make_valid(tile)
  call require(fmr_external_ribasim_surface_tile_profile_valid(tile), 'valid external Ribasim profile')

  tile%template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  call require(.not. fmr_external_ribasim_surface_tile_profile_valid(tile), 'fixed-weir state conflict')

  call make_valid(tile)
  tile%parameters%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_LINEAR
  call require(.not. fmr_external_ribasim_surface_tile_profile_valid(tile), 'non-extended variant rejected')

  call make_valid(tile)
  tile%base_forcing%drainage_response_controls(1)%resolved_surface_water_head_supplied = .false.
  call require(.not. fmr_external_ribasim_surface_tile_profile_valid(tile), 'missing external head rejected')

  call make_valid(tile)
  tile%parameters%drainage_response_active = .false.
  call require(.not. fmr_external_ribasim_surface_tile_profile_valid(tile), 'inactive response rejected')

  write(*,'(A)') 'SW_RIB_PA01_BOOTSTRAP_PROFILE_CONTRACT=PASS'

contains

  subroutine make_valid(value)
    type(fmr_production_application_tile_config_t), intent(out) :: value

    value%surface_water_owner_mode = FMR_SURFACE_OWNER_EXTERNAL_RIBASIM
    value%template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_BASE
    value%parameters%active_nodes = 1
    value%parameters%drainage_response_active = .true.
    allocate(value%parameters%drainage_response_levels(1))
    value%parameters%drainage_response_levels(1)%variant = FMR_DRAIN_VARIANT_EXTENDED_SIGNED
    value%parameters%drainage_response_levels(1)%extended%zbotdr_cm = -100.0_real64
    value%parameters%drainage_response_levels(1)%extended%drain_type = EXT_DRAIN_TUBE
    value%parameters%drainage_response_levels(1)%extended%spacing_cm = 1000.0_real64
    value%parameters%drainage_response_levels(1)%extended%rdrain_day = 1000.0_real64
    value%parameters%drainage_response_levels(1)%extended%rinfi_day = 1000.0_real64
    value%parameters%drainage_response_levels(1)%extended%rentry_day = 0.0_real64
    value%parameters%drainage_response_levels(1)%extended%rexit_day = 0.0_real64
    value%parameters%drainage_response_levels(1)%extended%gwlinf_cm = -200.0_real64
    value%parameters%drainage_response_levels(1)%extended%pondmx_cm = 1000.0_real64
    value%parameters%drainage_response_levels(1)%extended%highest_level = .false.
    value%parameters%drainage_response_levels(1)%extended%highest_surface_mode = EXT_DRAIN_TOP_NONE
    allocate(value%base_forcing%drainage_response_controls(1))
    value%base_forcing%drainage_response_controls(1)%resolved_surface_water_head_supplied = .true.
    value%base_forcing%drainage_response_controls(1)%resolved_surface_water_head_cm = -25.0_real64
  end subroutine make_valid

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'SW_RIB_PA01_BOOTSTRAP_PROFILE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_sw_rib_pa01_bootstrap_profile
