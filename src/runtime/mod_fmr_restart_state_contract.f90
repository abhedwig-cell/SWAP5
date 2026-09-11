module mod_fmr_restart_state_contract
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_temporal_indicator_state_t
  implicit none
  private

  public :: fmr_restart_state_matches_template

contains

  logical function fmr_restart_state_matches_template(state, template) result(matches)
    class(transaction_state_t), intent(in) :: state
    type(fmr_template_t), intent(in) :: template

    matches = .false.

    select case (template%compatible_backend_id)
    case (FMR_BACKEND_SERIALIZED_REFERENCE)
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

    matches = .true.
    if (.not. allocated(state%soil_temperature)) return
    matches = template%optional_state_layout_id > 0 .and. .not. allocated(state%snow) .and. &
         state%soil_temperature%ready() .and. state%soil_temperature%node_count() == state%active_nodes
  end function thermal_optional_state_matches

end module mod_fmr_restart_state_contract
