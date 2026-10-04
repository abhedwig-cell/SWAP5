64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = scale * 1.0e-5_real64 * real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -scale * 2.0e-6_real64 * real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
           forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine initialize_state_and_forcing

  subroutine make_predictor(input, tile, cell, href, slot)
    type(groundwater_tile_predictor_input_t), intent(out) :: input
    type(groundwater_topology_tile_t), intent(in) :: tile
    type(groundwater_topology_cell_t), intent(in) :: cell
    real(real64), intent(in) :: href
    integer, intent(in) :: slot

    type(modflow6_swap_predictor_lineage_t) :: lineage
    type(modflow6_derivative_coverage_t) :: coverage
    type(groundwater_coupling_window_t) :: window
    integer :: local_status

    input%tile_id = tile%tile_id
    window%t0 = T0
    window%t1 = T1
    lineage%coupling_id = cell%coupling_id
    lineage%swap_lineage_id = tile%swap_lineage_id
    lineage%swap_origin_revision = 0_int64
    lineage%groundwater_service_id = cell%groundwater_service_id
    lineage%groundwater_lineage_id = cell%groundwater_lineage_id
    lineage%groundwater_origin_revision = 0_int64
    coverage%lower_face_head_semantics_covered = .true.
    coverage%richards_hydraulic_response_covered = .true.
    coverage%constitutive_response_covered = .true.
    call compose_modflow6_swap_predictor_response(window, lineage, 0.001_real64, href, &
         href + real(slot, real64) * 0.001_real64, 0.25_real64, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, &
         coverage, 'ppa-wu01', 'typed-production-bootstrap', input%response, local_status)
    call require(local_status == MODFLOW6_PREDICTOR_OK .and. input%response%valid, 'predictor response')
  end subroutine make_predictor

  subroutine compute_reference_head(p, datum, head_m, local_status)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(groundwater_head_datum_t), intent(in) :: datum
    real(real64), intent(out) :: head_m
    integer, intent(out) :: local_status

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    type(modflow6_prescribed_qbot_bottom_face_t) :: face
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = H0_CM
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod), conductivity(numnod), PREDICTOR_QBOT, &
         0.5_real64 * p%dz(numnod), datum, face, local_status)
    if (local_status == MODFLOW6_BOTTOM_FACE_OK) then
      head_m = face%hydraulic_head_m
    else
      head_m = 0.0_real64
    end if
  end subroutine compute_reference_head

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU01_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu01_production_application_bootstrap
