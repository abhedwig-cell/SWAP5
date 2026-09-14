program test_fpm14_drainage_response_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_hooghoudt_equivalent_depth, only: hooghoudt_equivalent_depth_geometry_t, &
       hooghoudt_equivalent_depth_diagnostics_t, prepare_hooghoudt_equivalent_depth, EQDEPTH_OK
  use mod_drainage_ernst_ipos45_preparation, only: ernst_ipos4_geometry_t, ernst_ipos5_geometry_t, &
       ernst_preparation_diagnostics_t, prepare_ernst_ipos4, prepare_ernst_ipos5, ERNST_PREP_OK
  use mod_fmr_drainage_response_binding
  implicit none

  type(process_hydraulic_view_t) :: view
  type(fmr_drainage_response_level_parameters_t), allocatable :: parameters(:)
  type(fmr_drainage_response_level_control_t), allocatable :: controls(:)
  type(fmr_drainage_response_diagnostics_t) :: diagnostics
  type(hooghoudt_equivalent_depth_geometry_t) :: eq_geometry
  type(hooghoudt_equivalent_depth_diagnostics_t) :: eq_diagnostics
  type(ernst_ipos4_geometry_t) :: ernst4_geometry
  type(ernst_ipos5_geometry_t) :: ernst5_geometry
  type(ernst_preparation_diagnostics_t) :: ernst_diagnostics
  real(real64), allocatable :: qdra(:,:)
  real(real64) :: ordered_total
  integer :: i

  view%active_nodes = 3
  allocate(view%pressure_head(3), view%water_content(3))
  view%pressure_head = [-20.0_real64, -5.0_real64, 5.0_real64]
  view%water_content = [0.25_real64, 0.30_real64, 0.35_real64]
  view%ponding_depth = 0.0_real64
  view%groundwater_level = 10.0_real64

  allocate(parameters(8), controls(8), qdra(8,3))

  parameters(1)%variant = FMR_DRAIN_VARIANT_LINEAR
  parameters(1)%linear%drainage_resistance = 100.0_real64
  controls(1)%drain_head_supplied = .true.
  controls(1)%drain_head = 0.0_real64

  parameters(2)%variant = FMR_DRAIN_VARIANT_TABULATED
  allocate(parameters(2)%tabulated%groundwater_depth(2), parameters(2)%tabulated%signed_exchange_rate(2))
  parameters(2)%tabulated%groundwater_depth = [0.0_real64, 20.0_real64]
  parameters(2)%tabulated%signed_exchange_rate = [0.2_real64, 0.0_real64]

  parameters(3)%variant = FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS1
  parameters(3)%hooghoudt_ipos1%drain_spacing = 100.0_real64
  parameters(3)%hooghoudt_ipos1%shape_factor = 1.0_real64
  parameters(3)%hooghoudt_ipos1%drain_bottom_level = 0.0_real64
  parameters(3)%hooghoudt_ipos1%horizontal_conductivity_top = 10.0_real64
  parameters(3)%hooghoudt_ipos1%entry_resistance = 1.0_real64

  eq_geometry%drain_spacing = 100.0_real64
  eq_geometry%drain_bottom_level = 0.0_real64
  eq_geometry%impermeable_base_level = -25.0_real64
  eq_geometry%wetted_perimeter = 1.0_real64
  call prepare_hooghoudt_equivalent_depth(eq_geometry, parameters(4)%hooghoudt_prepared, eq_diagnostics)
  call require(eq_diagnostics%status == EQDEPTH_OK, 'Hooghoudt immutable preparation')
  parameters(5)%hooghoudt_prepared = parameters(4)%hooghoudt_prepared

  parameters(4)%variant = FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS2
  parameters(4)%hooghoudt_ipos2%shape_factor = 1.0_real64
  parameters(4)%hooghoudt_ipos2%horizontal_conductivity_top = 10.0_real64
  parameters(4)%hooghoudt_ipos2%entry_resistance = 1.0_real64

  parameters(5)%variant = FMR_DRAIN_VARIANT_HOOGHOUDT_IPOS3
  parameters(5)%hooghoudt_ipos3%shape_factor = 1.0_real64
  parameters(5)%hooghoudt_ipos3%horizontal_conductivity_top = 10.0_real64
  parameters(5)%hooghoudt_ipos3%horizontal_conductivity_bottom = 5.0_real64
  parameters(5)%hooghoudt_ipos3%entry_resistance = 1.0_real64

  ernst4_geometry%drain_spacing = 100.0_real64
  ernst4_geometry%shape_factor = 1.0_real64
  ernst4_geometry%drain_bottom_level = 0.0_real64
  ernst4_geometry%impermeable_base_level = -25.0_real64
  ernst4_geometry%interface_level = 5.0_real64
  ernst4_geometry%horizontal_conductivity_bottom = 10.0_real64
  ernst4_geometry%vertical_conductivity_top = 5.0_real64
  ernst4_geometry%vertical_conductivity_bottom = 2.0_real64
  ernst4_geometry%wetted_perimeter = 1.0_real64
  ernst4_geometry%entry_resistance = 1.0_real64
  call prepare_ernst_ipos4(ernst4_geometry, parameters(6)%ernst_ipos4_prepared, ernst_diagnostics)
  call require(ernst_diagnostics%status == ERNST_PREP_OK, 'Ernst IPOS4 immutable preparation')
  parameters(6)%variant = FMR_DRAIN_VARIANT_ERNST_IPOS4

  ernst5_geometry%drain_spacing = 100.0_real64
  ernst5_geometry%shape_factor = 1.0_real64
  ernst5_geometry%drain_bottom_level = 0.0_real64
  ernst5_geometry%impermeable_base_level = -25.0_real64
  ernst5_geometry%interface_level = -5.0_real64
  ernst5_geometry%horizontal_conductivity_top = 10.0_real64
  ernst5_geometry%horizontal_conductivity_bottom = 5.0_real64
  ernst5_geometry%vertical_conductivity_top = 5.0_real64
  ernst5_geometry%wetted_perimeter = 1.0_real64
  ernst5_geometry%geometry_factor = 1.0_real64
  ernst5_geometry%entry_resistance = 1.0_real64
  call prepare_ernst_ipos5(ernst5_geometry, parameters(7)%ernst_ipos5_prepared, ernst_diagnostics)
  call require(ernst_diagnostics%status == ERNST_PREP_OK, 'Ernst IPOS5 immutable preparation')
  parameters(7)%variant = FMR_DRAIN_VARIANT_ERNST_IPOS5

  parameters(8)%variant = FMR_DRAIN_VARIANT_EMPIRICAL_INTERFLOW
  parameters(8)%empirical%coefficient = 0.1_real64
  parameters(8)%empirical%exponent = 1.0_real64
  controls(8)%drain_head_supplied = .true.
  controls(8)%drain_head = 0.0_real64

  call evaluate_fmr_drainage_response_bottom_lumped(parameters, controls, view, qdra, diagnostics)
  call require(diagnostics%status == FMR_DRAIN_BIND_OK, 'all frozen response families evaluate')
  call require(diagnostics%evaluated, 'binding evaluated')
  call require(all(qdra(:,1:2) == 0.0_real64), 'SWDIVD=0 only bottom node receives transfer')
  call require(all(qdra(:,3) >= 0.0_real64), 'positive reference fixture drains soil')
  call require(all(diagnostics%level%flux_defined), 'all per-level transfers defined')
  call require(.not. diagnostics%transfer_booked_here, 'binding does not book mass')
  call require(diagnostics%aggregate_is_derived_view_only, 'aggregate is derived only')

  ordered_total = 0.0_real64
  do i = 1, size(qdra,1)
    ordered_total = ordered_total + qdra(i,3)
  end do
  call require(same_bits(ordered_total, diagnostics%aggregate%signed_soil_to_drain_rate), &
       'legacy-order derived total equals per-level bottom-node transfers')
  print '(a)', 'FPM14_ALL_RESPONSE_FAMILIES_BOTTOM_LUMPED=PASS'
  print '(a)', 'FPM14_MULTILEVEL_DERIVED_TOTAL_SINGLE_BOOKING=PASS'

  parameters(1)%variant = 999
  qdra = 123.0_real64
  call evaluate_fmr_drainage_response_bottom_lumped(parameters, controls, view, qdra, diagnostics)
  call require(diagnostics%status == FMR_DRAIN_BIND_UNSUPPORTED_VARIANT, 'unsupported response fails closed')
  call require(all(qdra == 0.0_real64), 'failed binding publishes no transfer')
  print '(a)', 'FPM14_UNSUPPORTED_VARIANT_FAIL_CLOSED=PASS'

  print '(a)', 'FPM14_DRAINAGE_RESPONSE_BINDING_OWNER_TEST PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FPM14_OWNER_TEST_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

  pure logical function same_bits(a, b) result(same)
    use, intrinsic :: iso_fortran_env, only: int64
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

end program test_fpm14_drainage_response_binding
