module mod_canonical_result_text_adapter
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_result_t
  implicit none
  private

  public :: serialize_canonical_result_text

contains

  ! Bounded M1 output adapter. This is deliberately not a stable public file
  ! format. It consumes only the already-published typed canonical result and
  ! has no physical-state, solver, parser, path or file-unit authority.
  subroutine serialize_canonical_result_text(result, text)
    type(canonical_result_t), intent(in) :: result
    character(len=:), allocatable, intent(out) :: text

    text = 'SWAP5_CANONICAL_RESULT_SNAPSHOT' // new_line('a')
    call append_integer(text, 'status=', result%status)
    call append_logical(text, 'completed=', result%completed)
    call append_real(text, 'requested_t0=', result%requested_t0)
    call append_real(text, 'requested_t1=', result%requested_t1)
    call append_real(text, 'completed_t=', result%completed_t)

    call append_logical(text, 'mass_complete=', result%mass%complete)
    call append_real(text, 'mass_interval_t0=', result%mass%interval_t0)
    call append_real(text, 'mass_interval_t1=', result%mass%interval_t1)
    call append_int64(text, 'mass_origin_lineage_id=', result%mass%origin_lineage_id)
    call append_int64(text, 'mass_origin_revision=', result%mass%origin_revision)
    call append_integer(text, 'mass_accepted_transaction_count=', result%mass%accepted_transaction_count)
    call append_int64(text, 'mass_missing_contribution_mask=', result%mass%missing_contribution_mask)
    call append_real(text, 'mass_storage_start=', result%mass%storage_start)
    call append_real(text, 'mass_storage_end=', result%mass%storage_end)
    call append_real(text, 'mass_storage_change=', result%mass%storage_change)
    call append_real(text, 'mass_total_in=', result%mass%total_in)
    call append_real(text, 'mass_total_out=', result%mass%total_out)
    call append_real(text, 'mass_residual=', result%mass%residual)

    call append_integer(text, 'diagnostics_transaction_calls=', result%diagnostics%transaction_calls)
    call append_integer(text, 'diagnostics_committed_substeps=', result%diagnostics%committed_substeps)
    call append_integer(text, 'diagnostics_external_commits=', result%diagnostics%external_commits)
    call append_integer(text, 'diagnostics_attempts=', result%diagnostics%attempts)
    call append_integer(text, 'diagnostics_retries=', result%diagnostics%retries)
    call append_integer(text, 'diagnostics_rollbacks=', result%diagnostics%rollbacks)
    call append_real(text, 'diagnostics_max_abs_step_mass_residual=', &
                     result%diagnostics%max_abs_step_mass_residual)
    call append_real(text, 'diagnostics_max_temporal_indicator=', &
                     result%diagnostics%max_temporal_indicator)
    call append_real(text, 'diagnostics_min_accepted_substep_duration=', &
                     result%diagnostics%min_accepted_substep_duration)
    call append_real(text, 'diagnostics_max_accepted_substep_duration=', &
                     result%diagnostics%max_accepted_substep_duration)

    call append_logical(text, 'interface_sensitivity_available=', result%interface_sensitivity%available)
    call append_integer(text, 'interface_sensitivity_semantic=', result%interface_sensitivity%semantic)
    call append_real(text, 'interface_sensitivity_dh_bottom_dq_bottom=', &
                     result%interface_sensitivity%dh_bottom_dq_bottom)
    call append_logical(text, 'interface_sensitivity_covers_requested_interval=', &
                        result%interface_sensitivity%covers_requested_interval)

    call append_logical(text, 'accepted_trajectory_direction_requested=', &
                        result%accepted_trajectory_direction%requested)
    call append_logical(text, 'accepted_trajectory_direction_available=', &
                        result%accepted_trajectory_direction%available)
    call append_integer(text, 'accepted_trajectory_direction_accepted_steps=', &
                        result%accepted_trajectory_direction%accepted_steps)
    call append_real(text, 'accepted_trajectory_direction_origin_t0=', &
                     result%accepted_trajectory_direction%origin_t0)
    call append_real(text, 'accepted_trajectory_direction_accepted_t1=', &
                     result%accepted_trajectory_direction%accepted_t1)

    call append_logical(text, 'bottom_interface_exchange_available=', result%bottom_interface_exchange_available)
    call append_real(text, 'bottom_outward_exchange_native=', result%bottom_outward_exchange_native)
    call append_real(text, 'terminal_bottom_outward_flux_native=', result%terminal_bottom_outward_flux_native)
  end subroutine serialize_canonical_result_text

  subroutine append_integer(text, key, value)
    character(len=:), allocatable, intent(inout) :: text
    character(len=*), intent(in) :: key
    integer, intent(in) :: value
    character(len=48) :: buffer

    write(buffer, '(I0)') value
    call append_line(text, key // trim(buffer))
  end subroutine append_integer

  subroutine append_int64(text, key, value)
    character(len=:), allocatable, intent(inout) :: text
    character(len=*), intent(in) :: key
    integer(int64), intent(in) :: value
    character(len=48) :: buffer

    write(buffer, '(I0)') value
    call append_line(text, key // trim(buffer))
  end subroutine append_int64

  subroutine append_real(text, key, value)
    character(len=:), allocatable, intent(inout) :: text
    character(len=*), intent(in) :: key
    real(real64), intent(in) :: value
    character(len=48) :: buffer

    write(buffer, '(ES26.17E3)') value
    call append_line(text, key // trim(adjustl(buffer)))
  end subroutine append_real

  subroutine append_logical(text, key, value)
    character(len=:), allocatable, intent(inout) :: text
    character(len=*), intent(in) :: key
    logical, intent(in) :: value

    if (value) then
      call append_line(text, key // 'true')
    else
      call append_line(text, key // 'false')
    end if
  end subroutine append_logical

  subroutine append_line(text, line)
    character(len=:), allocatable, intent(inout) :: text
    character(len=*), intent(in) :: line

    text = text // trim(line) // new_line('a')
  end subroutine append_line

end module mod_canonical_result_text_adapter
