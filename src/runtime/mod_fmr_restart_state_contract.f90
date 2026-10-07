module mod_fmr_restart_state_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_SNOW, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE, fmr_optional_state_layout_known
  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER, &
       FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION, FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION, &
       FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_MACROPORE, &
       FMR_OPTIONAL_STATE_LAYOUT_RUTTER_BOESTEN_MACROPORE, &
       FMR_OPTIONAL_STATE_LAYOUT_MACROPORE, FMR_OPTIONAL_STATE_LAYOUT_RUTTER, FMR_SOLUTE_STATE_LAYOUT_NONE, &
       FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED, FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE, &
       FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_SORBED_POND, &
       fmr_solute_state_layout_known
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_temporal_indicator_state_t, &
       fmr_b110_macropore_reduction_state_t, &
       fmr_b110_fixed_weir_surface_water_state_t, fmr_b110_black_evaporation_state_t, &
       fmr_b110_sol01_state_t, &
       fmr_b110_boesten_evaporation_state_t, fmr_b110_boesten_macropore_state_t
  implicit none
  private

  public :: fmr_restart_state_matches_template

contains

  logical function fmr_restart_state_matches_template(state, template) result(matches)
    class(transaction_state_t), intent(in) :: state
    type(fmr_template_t), intent(in) :: template

    matches = .false.
    if (.not. fmr_solute_state_layout_known(template%solute_state_layout_id)) return
    ! Rutter state is admitted only under its own optional-state layout.
    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      if (allocated(physical%rutter) .and. template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_RUTTER .and. &
          template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_RUTTER_BOESTEN_MACROPORE) return
    end select
    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      select case (template%solute_state_layout_id)
      case (FMR_SOLUTE_STATE_LAYOUT_NONE)
        select type (sol01 => physical)
        type is (fmr_b110_sol01_state_t)
          ! SOL01 state requires explicit solute layout identity even if a
          ! partially constructed object happens not to carry dissolved salt.
          return
        class default
        end select
        if (allocated(physical%salt)) return
      case (FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED)
        select type (sol01 => physical)
        type is (fmr_b110_sol01_state_t)
          ! Never reinterpret persistent sorbed/pond stores as the legacy
          ! dissolved-only restart topology.
          return
        class default
        end select
        if (.not. allocated(physical%salt)) return
        if (.not. physical%salt%ready(physical%active_nodes)) return
      case (FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE)
        if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_MACROPORE) return
        if (.not. allocated(physical%macropore)) return
        if (.not. physical%macropore%ready()) return
        if (physical%macropore%num_nodes /= physical%active_nodes) return
        if (.not. allocated(physical%salt)) return
        if (.not. physical%salt%ready(physical%active_nodes,physical%macropore%num_domains)) return
      case (FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_SORBED_POND)
        if (allocated(physical%macropore)) return
        if (.not. allocated(physical%salt)) return
        if (.not. physical%salt%ready(physical%active_nodes)) return
        select type (sol01 => physical)
        type is (fmr_b110_sol01_state_t)
          if (.not. sol01%solute_companion%ready(sol01%active_nodes)) return
        class default
          return
        end select
      case default
        return
      end select
    class default
      if (template%solute_state_layout_id /= FMR_SOLUTE_STATE_LAYOUT_NONE) return
    end select

    select case (template%compatible_backend_id)
    case (FMR_BACKEND_SERIALIZED_REFERENCE)
      if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER) then
        ! D7 is deliberately a separate physical optional-state topology.  It
        ! cannot be inferred from a payload or combined with Richards temporal
        ! continuation under the first restricted candidate.
        if (template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
        select type (state)
        type is (fmr_b110_fixed_weir_surface_water_state_t)
          matches = .true.
        class default
          matches = .false.
        end select
        return
      end if

      if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION) then
        ! PPA-WU04-A is option-discriminated restart continuation.  LDWET is
        ! persisted exactly and may not be reconstructed from hydraulic state.
        if (template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
        select type (state)
        type is (fmr_b110_black_evaporation_state_t)
          matches = .not. allocated(state%snow) .and. .not. allocated(state%soil_temperature)
        class default
          matches = .false.
        end select
        return
      end if

      if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION) then
        ! PPA-WU04-B persists SPEV/SAEV as one option-discriminated pair.
        if (template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
        select type (state)
        type is (fmr_b110_boesten_evaporation_state_t)
          matches = .not. allocated(state%snow) .and. .not. allocated(state%soil_temperature)
        class default
          matches = .false.
        end select
        return
      end if

      if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_MACROPORE) then
        ! MIGMAC10 keeps Boesten history and the A9 macropore state in one
        ! explicit restart identity; neither component may be reconstructed.
        if (template%solute_state_layout_id /= FMR_SOLUTE_STATE_LAYOUT_NONE) return
        if (template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
        select type (state)
        type is (fmr_b110_boesten_macropore_state_t)
          matches = .not. allocated(state%snow) .and. .not. allocated(state%soil_temperature) .and. &
               allocated(state%macropore) .and. state%macropore%ready() .and. &
               state%macropore%num_nodes == state%active_nodes .and. &
               ieee_is_finite(state%boesten_evaporation%spev) .and. state%boesten_evaporation%spev >= 0.0_real64 .and. &
               ieee_is_finite(state%boesten_evaporation%saev) .and. state%boesten_evaporation%saev >= 0.0_real64
        class default
          matches = .false.
        end select
        return
      end if

      if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RUTTER_BOESTEN_MACROPORE) then
        if (template%solute_state_layout_id /= FMR_SOLUTE_STATE_LAYOUT_NONE) return
        if (template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
        select type (state)
        type is (fmr_b110_boesten_macropore_state_t)
          matches = allocated(state%rutter) .and. allocated(state%macropore) .and. state%macropore%ready() .and. &
               state%macropore%num_nodes == state%active_nodes .and. &
               ieee_is_finite(state%boesten_evaporation%spev) .and. state%boesten_evaporation%spev >= 0.0_real64 .and. &
               ieee_is_finite(state%boesten_evaporation%saev) .and. state%boesten_evaporation%saev >= 0.0_real64 .and. &
               .not. allocated(state%snow) .and. .not. allocated(state%soil_temperature)
        class default
          matches = .false.
        end select
        return
      end if

      if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_RUTTER) then
        if (template%solute_state_layout_id /= FMR_SOLUTE_STATE_LAYOUT_NONE) return
        if (template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
        select type (state)
        type is (fmr_b110_physical_state_t)
        matches = allocated(state%rutter) .and. .not. allocated(state%snow) .and. &
               .not. allocated(state%soil_temperature) .and. .not. allocated(state%macropore)
        class default
          matches = .false.
        end select
        return
      end if

      select case (template%numerical_continuation_layout_id)
      case (FMR_NUMERICAL_CONTINUATION_NONE)
        select type (state)
        type is (fmr_b110_physical_state_t)
          matches = thermal_optional_state_matches(state, template)
        class default
          matches = .false.
        end select
      case (FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
        select type (state)
        type is (fmr_b110_temporal_indicator_state_t)
          matches = thermal_optional_state_matches(state, template)
        class default
          matches = .false.
        end select
      case (FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION)
        if(template%optional_state_layout_id/=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE)return
        select type(state)
        type is(fmr_b110_macropore_reduction_state_t)
          matches=state%reduction_continuation%valid() .and. thermal_optional_state_matches(state,template)
        class default
          matches=.false.
        end select
      case default
        matches = .false.
      end select
    case default
      ! A restart state family must be registered explicitly before it can be
      ! reconstructed through this production boundary. Unknown backends are
      ! deliberately fail-closed rather than inferred from the payload itself.
      matches = .false.
    end select
  end function fmr_restart_state_matches_template

  logical function thermal_optional_state_matches(state, template) result(matches)
    class(fmr_b110_physical_state_t), intent(in) :: state
    type(fmr_template_t), intent(in) :: template

    matches = .false.
    if (.not. fmr_optional_state_layout_known(template%optional_state_layout_id)) return
    if (allocated(state%snow) .and. allocated(state%soil_temperature)) return
    if (allocated(state%macropore) .and. (allocated(state%snow) .or. allocated(state%soil_temperature))) return

    select case (template%optional_state_layout_id)
      case (FMR_OPTIONAL_STATE_LAYOUT_BASE)
        matches = .not. allocated(state%snow) .and. .not. allocated(state%soil_temperature) .and. &
           .not. allocated(state%macropore) .and. .not. allocated(state%rutter)
    case (FMR_OPTIONAL_STATE_LAYOUT_SNOW)
      matches = .not. allocated(state%soil_temperature) .and. .not. allocated(state%macropore)
    case (FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE)
      if (allocated(state%snow) .or. allocated(state%macropore)) return
      if (.not. allocated(state%soil_temperature)) then
        matches = .true.
      else
        matches = state%soil_temperature%ready() .and. &
             state%soil_temperature%node_count() == state%active_nodes
      end if
    case (FMR_OPTIONAL_STATE_LAYOUT_MACROPORE)
      if (allocated(state%snow) .or. allocated(state%soil_temperature)) return
      if (.not. allocated(state%macropore)) then
        matches = .true.
      else
        matches = state%macropore%ready() .and. state%macropore%num_nodes == state%active_nodes
      end if
    case default
      matches = .false.
    end select
  end function thermal_optional_state_matches

end module mod_fmr_restart_state_contract
