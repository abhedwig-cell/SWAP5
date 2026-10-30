! Read-only physical water receipt shared by water and reactive transport owners.
! This contract contains no serialized solver/backend dependency or new state.
module mod_fmr_water_flux_trace_contract
  use iso_fortran_env,only:real64
  use mod_solute_mobile_macro_salt_transport,only:mobile_macro_salt_receipt_t
  implicit none
  private
  type, public :: fmr_water_flux_substep_trace_t
    real(real64) :: t0 = 0.0_real64, t1 = 0.0_real64
    real(real64) :: top_flux = 0.0_real64, bottom_flux = 0.0_real64
    logical :: pond_storage_available = .false.
    real(real64) :: pond_start_cm = 0.0_real64, pond_end_cm = 0.0_real64
    ! Read-only converged diagnostics, NOT yet an accepted gross-flux receipt.
    logical :: converged_surface_available = .false.
    real(real64) :: converged_bare_soil_evaporation_cm_day = 0.0_real64
    real(real64) :: converged_pond_evaporation_cm_day = 0.0_real64
    real(real64) :: converged_runoff_depth_cm = 0.0_real64
    logical :: converged_gross_sources_available = .false.
    real(real64) :: converged_rain_rate_cm_day = 0.0_real64
    real(real64) :: converged_irrigation_rate_cm_day = 0.0_real64
    real(real64) :: converged_snowmelt_rate_cm_day = 0.0_real64
    real(real64) :: converged_runon_rate_cm_day = 0.0_real64
    ! Observation only: amounts cm/column area, rates cm/day. No new state.
    logical :: macropore_surface_receipt_available = .false.
    integer :: macropore_top_node=1,covered_donor_node=0
    real(real64),allocatable :: covered_top_input_domain_cm(:)
    real(real64) :: macropore_requested_cm=0.0_real64,macropore_accepted_cm=0.0_real64,macropore_returned_cm=0.0_real64
    real(real64) :: macropore_pond_requested_cm=0.0_real64,macropore_pond_accepted_cm=0.0_real64
    real(real64) :: macropore_pond_returned_cm=0.0_real64,macropore_external_top_cm=0.0_real64
    real(real64) :: macropore_rapid_outflow_cm=0.0_real64
    real(real64),allocatable :: macropore_external_outflow_rate(:,:),matrix_area_fraction(:)
    type(mobile_macro_salt_receipt_t), allocatable :: salt_receipt
    real(real64), allocatable :: water_start(:), water_end(:), subsurface_source(:), drainage_sink(:), drainage_sink_by_level(:,:), &
         root_sink(:), macropore_matrix_exchange(:), macropore_matrix_exchange_domain(:,:), &
         macropore_water_start(:,:), macropore_water_end(:,:), macropore_vertical_face_rate(:,:), net_node_source(:)
    real(real64) :: converged_surface_net_potential_cm_day=0.0_real64,macropore_surface_return_cm=0.0_real64
    real(real64) :: converged_soil_evaporation_cm_day = 0.0_real64
    logical :: substep_root_available = .false.
    real(real64) :: root_potential_cm_day = 0.0_real64
    real(real64) :: root_drought_reduction_cm_day = 0.0_real64
    real(real64) :: root_oxygen_reduction_cm_day = 0.0_real64
    real(real64) :: deepest_root_oxygen_factor = 1.0_real64
    real(real64)::root_salinity_reduction_cm_day=0d0,rootzone_drought_uptake_factor=0d0
    real(real64),allocatable::potential_root_sink(:),root_sink_reduction(:)
    real(real64), allocatable :: root_pressure_head_start(:)
    logical::rutter_reservoir_available=.false.
    real(real64)::rutter_canopy_start_cm=0.0_real64,rutter_canopy_end_cm=0.0_real64
    real(real64)::rutter_gross_rain_rate_cm_day=0.0_real64,rutter_gross_irrigation_rate_cm_day=0.0_real64
    real(real64)::rutter_evaporation_cm=0.0_real64,rutter_reservoir_residual_cm=0.0_real64
    logical :: reactive_chemical_available=.false.
    real(real64)::chemical_mass_before=0.0_real64,chemical_mass_after=0.0_real64
    real(real64)::chemical_external_in=0.0_real64,chemical_external_out=0.0_real64
    real(real64)::chemical_decay_out=0.0_real64,chemical_residual=0.0_real64
  end type fmr_water_flux_substep_trace_t
end module mod_fmr_water_flux_trace_contract
