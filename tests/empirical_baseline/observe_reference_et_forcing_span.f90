program observe_reference_et_forcing_span
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_reference_et_demand_process
  use mod_fmr_reference_et_demand_binding
  implicit none

  type(reference_et_demand_parameters_t) :: parameters
  type(reference_et_demand_canopy_view_t) :: canopy
  type(fmr_reference_et_forcing_span_t) :: forcing_span

  parameters%pond_evaporation_factor = 1.2_real64
  canopy%crop_emerged = .true.
  canopy%vegetation_cover_fraction = 0.65_real64
  canopy%crop_factor = 1.1_real64
  canopy%co2_transpiration_factor = 0.9_real64
  forcing_span%t0 = 2700.0_real64
  forcing_span%t1 = 2701.0_real64
  forcing_span%reference_et_mm_per_day = 5.2_real64

  write(*,'(A)') 'case_id,status,process_status,duration,process_called,result_produced,ptra_cm_per_day,peva_cm_per_day,epond_cm_per_day'

  call emit_case('contained_quarter', 2700.125_real64, 2700.375_real64, forcing_span, parameters, canopy)
  call emit_case('contained_late', 2700.600_real64, 2700.950_real64, forcing_span, parameters, canopy)
  call emit_case('left_not_covered', 2699.900_real64, 2700.100_real64, forcing_span, parameters, canopy)
  call emit_invalid_span('invalid_zero_span', 2700.200_real64, 2700.300_real64, forcing_span, parameters, canopy)
  call emit_negative_et('negative_et', 2700.200_real64, 2700.300_real64, forcing_span, parameters, canopy)
  call emit_nonemerged('nonemerged_cover', 2700.400_real64, 2700.600_real64, forcing_span, parameters, canopy)

contains

  subroutine emit_case(case_id, t0, t1, span, pars, view)
    character(len=*), intent(in) :: case_id
    real(real64), intent(in) :: t0, t1
    type(fmr_reference_et_forcing_span_t), intent(in) :: span
    type(reference_et_demand_parameters_t), intent(in) :: pars
    type(reference_et_demand_canopy_view_t), intent(in) :: view
    type(canonical_interval_t) :: interval
    type(reference_et_demand_result_t) :: result
    type(reference_et_demand_diagnostics_t) :: process_diagnostics
    type(fmr_reference_et_binding_diagnostics_t) :: diagnostics

    interval%t0 = t0
    interval%t1 = t1
    call fmr_evaluate_reference_et_demand(interval, span, pars, view, result, process_diagnostics, diagnostics)
    call print_row(case_id, diagnostics, result)
  end subroutine emit_case

  subroutine emit_invalid_span(case_id, t0, t1, span, pars, view)
    character(len=*), intent(in) :: case_id
    real(real64), intent(in) :: t0, t1
    type(fmr_reference_et_forcing_span_t), intent(in) :: span
    type(reference_et_demand_parameters_t), intent(in) :: pars
    type(reference_et_demand_canopy_view_t), intent(in) :: view
    type(fmr_reference_et_forcing_span_t) :: local_span

    local_span = span
    local_span%t1 = local_span%t0
    call emit_case(case_id, t0, t1, local_span, pars, view)
  end subroutine emit_invalid_span

  subroutine emit_negative_et(case_id, t0, t1, span, pars, view)
    character(len=*), intent(in) :: case_id
    real(real64), intent(in) :: t0, t1
    type(fmr_reference_et_forcing_span_t), intent(in) :: span
    type(reference_et_demand_parameters_t), intent(in) :: pars
    type(reference_et_demand_canopy_view_t), intent(in) :: view
    type(fmr_reference_et_forcing_span_t) :: local_span

    local_span = span
    local_span%reference_et_mm_per_day = -1.0_real64
    call emit_case(case_id, t0, t1, local_span, pars, view)
  end subroutine emit_negative_et

  subroutine emit_nonemerged(case_id, t0, t1, span, pars, view)
    character(len=*), intent(in) :: case_id
    real(real64), intent(in) :: t0, t1
    type(fmr_reference_et_forcing_span_t), intent(in) :: span
    type(reference_et_demand_parameters_t), intent(in) :: pars
    type(reference_et_demand_canopy_view_t), intent(in) :: view
    type(reference_et_demand_canopy_view_t) :: local_view

    local_view = view
    local_view%crop_emerged = .false.
    local_view%vegetation_cover_fraction = 0.30_real64
    local_view%crop_factor = 7.0_real64
    local_view%co2_transpiration_factor = 8.0_real64
    call emit_case(case_id, t0, t1, span, pars, local_view)
  end subroutine emit_nonemerged

  subroutine print_row(case_id, diagnostics, result)
    character(len=*), intent(in) :: case_id
    type(fmr_reference_et_binding_diagnostics_t), intent(in) :: diagnostics
    type(reference_et_demand_result_t), intent(in) :: result

    write(*,'(A,",",I0,",",I0,",",ES25.17E3,",",L1,",",L1,3(",",ES25.17E3))') &
      trim(case_id), diagnostics%status, diagnostics%process_status, diagnostics%interval_duration, &
      diagnostics%process_called, diagnostics%result_produced, result%potential_transpiration_cm_per_day, &
      result%potential_soil_evaporation_cm_per_day, result%potential_pond_evaporation_cm_per_day
  end subroutine print_row

end program observe_reference_et_forcing_span
