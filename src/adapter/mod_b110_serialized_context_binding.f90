module mod_b110_serialized_context_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solve_request_t
  use MOD_swap_base, only: swmacro
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_snow, only: melt
  use variables, only: dt, swbotb, swkimpl, swkmean, dtmin, maxit, maxbacktr, &
       CritDevBalCp, CritDevBalTot, critdevh2cp, critdevh1cp, critdevponddt, &
       fldtmin, qtop, qbot, hbot, qrot
  implicit none
  private

  public :: bind_b110_serialized_legacy_context

contains

  subroutine bind_b110_serialized_legacy_context(request, ok)
    type(soil_water_solve_request_t), intent(in) :: request
    logical, intent(out) :: ok
    integer :: n

    ok = .false.
    if (.not. associated(request%parameters)) return
    n = request%parameters%active_nodes
    if (n /= numnod .or. n <= 0) return
    if (.not. allocated(request%parameters%z) .or. .not. allocated(request%parameters%dz) .or. &
        .not. allocated(request%parameters%node_distance)) return
    if (size(request%parameters%z) /= n .or. size(request%parameters%dz) /= n .or. &
        size(request%parameters%node_distance) /= n) return
    if (maxval(abs(request%parameters%z-z(1:n))) > 0.0_real64) return
    if (maxval(abs(request%parameters%dz-dz(1:n))) > 0.0_real64) return
    if (maxval(abs(request%parameters%node_distance-disnod(1:n))) > 0.0_real64) return

    ! The legacy global qrot is an admission guard only for the root-inactive route.
    ! Once an explicit F-SI11 root provider is bound, root extraction is carried by
    ! request%evaluation%root_sink and the global qrot must be irrelevant/poisonable.
    if (swmacro /= 0) return
    if (.not. associated(request%evaluation%root_sink)) then
      if (any(abs(qrot(1:n)) > 0.0_real64)) return
    end if
    if (abs(melt) > 0.0_real64) return
    if (request%numerical%conductivity_implicit_mode /= 0) return
    if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2) return
    if (request%step_duration <= 0.0_real64) return

    ! Pure legacy-call binding. These assignments mirror explicit request/configuration
    ! into the old call context; no physics formula or transaction state is changed.
    dt = request%step_duration
    swbotb = request%boundary%bottom_mode
    swkimpl = request%numerical%conductivity_implicit_mode
    swkmean = request%numerical%conductivity_mean_method
    dtmin = request%numerical%min_step_duration
    maxit = request%numerical%max_iterations
    maxbacktr = request%numerical%max_backtracking
    CritDevBalCp = request%numerical%compartment_balance_tolerance
    CritDevBalTot = request%numerical%total_balance_tolerance
    critdevh2cp = request%numerical%head_abs_tolerance
    critdevh1cp = request%numerical%head_rel_tolerance
    critdevponddt = request%numerical%ponding_tolerance
    fldtmin = .false.
    qtop = request%boundary%top_flux
    qbot = request%boundary%bottom_flux
    hbot = request%boundary%bottom_head
    ok = .true.
  end subroutine bind_b110_serialized_legacy_context

end module mod_b110_serialized_context_binding
