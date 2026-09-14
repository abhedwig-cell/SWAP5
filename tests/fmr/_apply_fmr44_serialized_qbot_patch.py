from pathlib import Path

changes = [
    (
        Path('src/adapter/mod_b110_serialized_context_binding.f90'),
        """    if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2 .and. &
        request%boundary%bottom_mode /= 5) return
""",
        """    if (request%boundary%bottom_mode /= 7 .and. request%boundary%bottom_mode /= -2 .and. &
        request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2) return
""",
    ),
    (
        Path('src/runtime/mod_fmr_serialized_reference_backend.f90'),
        """      ok = ok .and. (parameters%bottom_mode == 7 .or. parameters%bottom_mode == -2 .or. parameters%bottom_mode == 5) .and. &
""",
        """      ok = ok .and. (parameters%bottom_mode == 7 .or. parameters%bottom_mode == -2 .or. parameters%bottom_mode == 5 .or. &
           parameters%bottom_mode == 2) .and. &
""",
    ),
    (
        Path('src/runtime/mod_fmr_serialized_reference_backend.f90'),
        """    if (self%bottom_mode /= 7 .and. self%bottom_mode /= -2 .and. self%bottom_mode /= 5) then
      value = huge(0.0_real64)
      return
    end if
""",
        """    if (self%bottom_mode /= 7 .and. self%bottom_mode /= -2 .and. self%bottom_mode /= 5 .and. &
        self%bottom_mode /= 2) then
      value = huge(0.0_real64)
      return
    end if
""",
    ),
]

changed = 0
for path, old, new in changes:
    text = path.read_text()
    if new in text:
        print(f'FMR44_ALREADY_PATCHED {path}')
        continue
    if text.count(old) != 1:
        raise SystemExit(f'FMR44_PATCH_ANCHOR_MISMATCH {path} count={text.count(old)}')
    path.write_text(text.replace(old, new, 1))
    changed += 1
    print(f'FMR44_PATCHED {path}')

# Qualification-only fixture shaping and diagnostics. These edits do not touch
# production source. Keep the exact uniform free-drainage equilibrium case as an
# independent mode-2 routing/mass oracle. For the genuinely upward case, however,
# start the certificate state from a hydrostatic predecessor rather than abruptly
# reversing a free-drainage profile. In this four-node fixture disnod=1 cm, so
# h=[-75,-74,-73,-72] cm gives an exactly zero hydraulic gradient at every
# internal face. With qtop=qbot=0 and no sources/sinks that predecessor has zero
# right derivative. The tested positive qtop=qbot is then a local upward
# throughflow perturbation; positive qbot is lower-boundary inflow and positive
# qtop is upper-boundary outflow under the canonical mass convention.
test = Path('tests/fmr/test_fmr44_serialized_prescribed_qbot_runtime.f90')
text = test.read_text()

old_temporal_init = """    call initialize_physical_state(parameters, state)
    ! The same uniform state is independently exercised above as the exact
    ! prescribed-qbot equilibrium. Its accepted predecessor right derivative is
    ! therefore exactly zero. The forcing changes only at this interval boundary.
    accepted_predecessor_right_derivative = 0.0_real64
"""
new_temporal_init = """    call initialize_hydrostatic_physical_state(parameters, state)
    ! The qualification fixture uses an exact hydrostatic predecessor:
    ! (h(i-1)-h(i))/disnod(i)+1 = 0 at every internal face, with no sources
    ! or sinks and qtop=qbot=0. Its accepted predecessor right derivative is
    ! therefore exactly zero. The tested interval applies only a small positive
    ! upward throughflow at the two external faces.
    accepted_predecessor_right_derivative = 0.0_real64
"""
if old_temporal_init in text:
    text = text.replace(old_temporal_init, new_temporal_init, 1)
    print('FMR44_HYDROSTATIC_TEMPORAL_PREDECESSOR=STAGED')
elif new_temporal_init not in text:
    raise SystemExit('FMR44_HYDROSTATIC_TEMPORAL_PREDECESSOR_ANCHOR_MISMATCH')

insert_anchor = """  subroutine initialize_forcing(forcing, top_flux, bottom_flux, bottom_head)
"""
if 'subroutine initialize_hydrostatic_physical_state' not in text:
    hydrostatic_helper = """  subroutine initialize_hydrostatic_physical_state(parameters, state)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: gradient
    integer :: i

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, equilibrium_dt)
    heads(1) = h0
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
      gradient = (heads(i-1)-heads(i))/parameters%node_distance(i) + 1.0_real64
      call require(abs(gradient) <= 16.0_real64*epsilon(1.0_real64), &
           'hydrostatic predecessor zero internal hydraulic gradient')
    end do
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(ieee_is_finite(conductivity)) .and. all(conductivity > 0.0_real64), &
         'hydrostatic predecessor finite positive conductivity')
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    write(*,'(A,4(1X,ES16.8E3))') 'FMR44_HYDROSTATIC_HEADS=', heads
    write(*,'(A)') 'FMR44_HYDROSTATIC_ZERO_DERIVATIVE_PREDECESSOR=PASS'
  end subroutine initialize_hydrostatic_physical_state

"""
    if text.count(insert_anchor) != 1:
        raise SystemExit(f'FMR44_HYDROSTATIC_HELPER_ANCHOR_MISMATCH count={text.count(insert_anchor)}')
    text = text.replace(insert_anchor, hydrostatic_helper + insert_anchor, 1)

# F-SI27 formally qualified prescribed-qbot semantics with a bounded numerical
# policy of 16 Newton iterations and 8 backtracking attempts while retaining the
# same hard 1e-12 head and mass tolerances. Reuse that bounded work budget here;
# do not loosen any acceptance tolerance.
old_solver_budget = """    parameters%max_iterations = 8
    parameters%max_backtracking = 4
"""
new_solver_budget = """    parameters%max_iterations = 16
    parameters%max_backtracking = 8
"""
if old_solver_budget in text:
    text = text.replace(old_solver_budget, new_solver_budget, 1)
    print('FMR44_FSI27_SOLVER_BUDGET_16_8=STAGED')
elif new_solver_budget not in text:
    raise SystemExit('FMR44_SOLVER_BUDGET_ANCHOR_MISMATCH')

anchor = """    call require(output%completed .and. output%committed, 'mode2 equilibrium committed')
"""
if anchor in text and 'FMR44_EQUILIBRIUM_DEBUG' not in text:
    diagnostic = """    if (.not. (output%completed .and. output%committed)) then
      write(*,'(A,L1,A,L1,A,I0,A,I0,A,L1,A,L1,A,A)') 'FMR44_EQUILIBRIUM_DEBUG completed=', output%completed, &
           ' committed=', output%committed, ' kernel_status=', output%kernel_status, ' accepted_substeps=', &
           output%accepted_substeps, ' admission_assessed=', output%admission_assessed, ' admitted=', output%admitted, &
           ' admission_status=', trim(output%admission_status)
      write(*,'(A,L1,A,ES26.17E3,A,I0,A,I0,A,I0)') 'FMR44_EQUILIBRIUM_MASS complete=', output%mass%complete, &
           ' residual=', output%mass%residual, ' attempts=', output%solver_headcalc_calls, ' final_revision=', &
           output%final_revision, ' solver_status=', observation%solver_status
    end if
""" + anchor
    text = text.replace(anchor, diagnostic, 1)

# For the positive prescribed-qbot path, distinguish a pre-solver/state-layout
# return from a Richards solve rejection and from a post-solve certificate issue.
anchor = """      write(*,'(A,L1,A,L1,A,L1,A,ES26.17E3,A,ES26.17E3,A,A)') 'FMR44_CERT_DEBUG enabled=', &
"""
if anchor in text and 'FMR44_ADVANCE_DEBUG' not in text:
    diagnostic = """      write(*,'(A,L1,A,I0,A,I0,A,I0,A,I0,A,I0,A,I0)') 'FMR44_ADVANCE_DEBUG solver_executed=', &
           observation%solver_executed, ' solver_status=', observation%solver_status, ' headcalc_calls=', &
           output%solver_headcalc_calls, ' final_revision=', output%final_revision, ' nonlinear=', &
           output%solver_nonlinear_iterations, ' internal_retries=', output%solver_internal_retries, &
           ' backtracking=', output%solver_backtracking_attempts
""" + anchor
    text = text.replace(anchor, diagnostic, 1)

test.write_text(text)
print('FMR44_QUALIFICATION_DIAGNOSTICS=INSTRUMENTED')
print(f'FMR44_PRODUCTION_ADMISSION_PATCH_COUNT={changed}')
