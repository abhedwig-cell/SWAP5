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

# Diagnostic instrumentation belongs only to the qualification working tree.
# It is not added to the production-source commit and does not change any gate.
test = Path('tests/fmr/test_fmr44_serialized_prescribed_qbot_runtime.f90')
text = test.read_text()
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
    diagnostic = """      write(*,'(A,L1,A,I0,A,I0,A,I0)') 'FMR44_ADVANCE_DEBUG solver_executed=', observation%solver_executed, &
           ' solver_status=', observation%solver_status, ' headcalc_calls=', output%solver_headcalc_calls, &
           ' final_revision=', output%final_revision
""" + anchor
    text = text.replace(anchor, diagnostic, 1)

test.write_text(text)
print('FMR44_QUALIFICATION_DIAGNOSTICS=INSTRUMENTED')
print(f'FMR44_PRODUCTION_ADMISSION_PATCH_COUNT={changed}')
