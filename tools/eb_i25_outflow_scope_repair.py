from pathlib import Path
import json


def replace_once(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'{label}: expected 1 match, found {n}')
    return text.replace(old, new, 1)

# Owner test: do not claim an accepted external-full/half outflow case when
# the physical fixture is rejected before transaction acceptance.
p = Path('tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90')
s = p.read_text()
s = replace_once(s,
    '       EB_I25_TOP_DONOR_UNAVAILABLE, EB_I25_TOP_OUTFLOW_UNQUALIFIED, EB_I25_TOP_SINGLE_SUBSTEP_INHERITED\n',
    '       EB_I25_TOP_DONOR_UNAVAILABLE, EB_I25_TOP_SINGLE_SUBSTEP_INHERITED\n',
    'remove unqualified outflow status import')
s = replace_once(s,
    '  call verify_two_half_outflow_does_not_reuse_external_donor()\n',
    '  call verify_two_half_outflow_fixture_rejects_without_publication()\n',
    'outflow test call')
old = '''  subroutine verify_two_half_outflow_does_not_reuse_external_donor()\n    type(fmr_serialized_reference_backend_t) :: backend\n    type(kernel_executor_t) :: tx\n    type(kernel_committed_state_t) :: committed\n    type(fmr_logical_column_t) :: column\n    type(fmr_template_t) :: template\n    type(fmr_b110_physical_parameters_t) :: parameters\n    type(fmr_b110_physical_forcing_t) :: forcing\n    type(canonical_numerical_config_t) :: config\n    type(fmr_serialized_column_result_t) :: output\n    type(fmr_column_diagnostics_t) :: diagnostic\n    type(fmr_serialized_batch_diagnostics_t) :: runtime\n    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters\n    type(external_liquid_water_temperature_t) :: top_temperature\n    type(eb_i25_sensible_boundary_publication_t) :: publication\n    type(whole_column_sensible_boundary_t) :: boundary\n    type(fixed_flux_top_boundary_provider_t), target :: top\n    integer :: active_calls\n    logical :: available\n\n    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &\n         runtime, active_calls, energy_parameters, 1.0e-10_real64, .true.)\n    top_temperature%available = .true.\n    top_temperature%temperature_c = top_donor_temperature_c\n    call reset_provider(column_id)\n    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &\n         config, t0, t1, energy_parameters, eb_i25_bottom_provider, top_temperature, output, diagnostic, runtime, &\n         active_calls, publication)\n\n    call require(output%accepted_substeps == 1 .and. publication%ready(), 'outflow external full-half publication')\n    call require(publication%top_status() == EB_I25_TOP_OUTFLOW_UNQUALIFIED, 'outflow donor direction guarded')\n    call publication%boundary_snapshot(boundary, available)\n    call require(available .and. boundary%top_conductive_available, 'outflow conductive aggregate remains available')\n    call require(.not. boundary%top_advective_available, 'external donor not reused for top outflow')\n    call require(.not. boundary%complete(), 'top outflow remains fail closed')\n    write(*,'(A)') 'EB_I25_TOP_OUTFLOW_FAIL_CLOSED=PASS'\n  end subroutine verify_two_half_outflow_does_not_reuse_external_donor\n'''
new = '''  subroutine verify_two_half_outflow_fixture_rejects_without_publication()\n    type(fmr_serialized_reference_backend_t) :: backend\n    type(kernel_executor_t) :: tx\n    type(kernel_committed_state_t) :: committed\n    type(fmr_logical_column_t) :: column\n    type(fmr_template_t) :: template\n    type(fmr_b110_physical_parameters_t) :: parameters\n    type(fmr_b110_physical_forcing_t) :: forcing\n    type(canonical_numerical_config_t) :: config\n    type(fmr_serialized_column_result_t) :: output\n    type(fmr_column_diagnostics_t) :: diagnostic\n    type(fmr_serialized_batch_diagnostics_t) :: runtime\n    type(liquid_water_sensible_enthalpy_parameters_t) :: energy_parameters\n    type(external_liquid_water_temperature_t) :: top_temperature\n    type(eb_i25_sensible_boundary_publication_t) :: publication\n    type(fixed_flux_top_boundary_provider_t), target :: top\n    integer :: active_calls\n\n    call initialize_case(backend, top, committed, column, template, parameters, forcing, config, output, diagnostic, &\n         runtime, active_calls, energy_parameters, 1.0e-10_real64, .true.)\n    top_temperature%available = .true.\n    top_temperature%temperature_c = top_donor_temperature_c\n    call reset_provider(column_id)\n    call fmr_execute_multisubstep_sensible_boundary(backend, tx, column, template, parameters, forcing, committed, &\n         config, t0, t1, energy_parameters, eb_i25_bottom_provider, top_temperature, output, diagnostic, runtime, &\n         active_calls, publication)\n\n    call require(.not. output%completed .and. .not. output%committed .and. output%accepted_substeps == 0, &\n         'external full-half outflow fixture rejected before commit')\n    call require(committed%current_revision() == 0_int64, 'outflow rejection leaves committed revision unchanged')\n    call require(.not. publication%ready(), 'rejected outflow fixture has no I25 publication')\n    write(*,'(A)') 'EB_I25_OUTFLOW_FIXTURE_REJECTED_NO_PUBLICATION=PASS'\n  end subroutine verify_two_half_outflow_fixture_rejects_without_publication\n'''
s = replace_once(s, old, new, 'replace outflow test')
p.write_text(s)

# Contract: distinguish defensive code from qualified accepted-outflow evidence.
p = Path('tests/eb/EB-I25_CONTRACT.md')
s = p.read_text()
s = replace_once(s,
    '- top outflow cannot reuse external donor temperature;\n',
    '- the available positive-flux external-full/half outflow fixture is rejected before commit and produces no I25 publication;\n',
    'contract owner evidence')
s = replace_once(s,
    'EB-I25 does not aggregate multiple outer committed runtime substeps. It does not add or alter Richards, soil-temperature, sensible-enthalpy, donor-temperature, timestep or transaction physics. It does not qualify top liquid outflow sensible transport, mixed inflow/outflow top transport, or snow/melt thermal provenance.',
    'EB-I25 does not aggregate multiple outer committed runtime substeps. It does not add or alter Richards, soil-temperature, sensible-enthalpy, donor-temperature, timestep or transaction physics. It does not qualify accepted external-full/half top liquid outflow sensible transport, mixed inflow/outflow top transport, or snow/melt thermal provenance. The defensive outflow branch remains fail-closed code, not owner evidence that an accepted two-half outflow trajectory exists.',
    'contract hard nonclaim')
p.write_text(s)

# Gate marker follows the actual owner evidence; retain structural outflow guard check.
p = Path('tests/eb/run_eb_i25_multisubstep_sensible_boundary_gate.sh')
s = p.read_text()
s = replace_once(s,
    "  grep -Fx 'EB_I25_TOP_OUTFLOW_FAIL_CLOSED=PASS' \"$OUT/output.txt\"\n",
    "  grep -Fx 'EB_I25_OUTFLOW_FIXTURE_REJECTED_NO_PUBLICATION=PASS' \"$OUT/output.txt\"\n",
    'gate outflow marker')
p.write_text(s)

# Checkpoint records the diagnostic rather than disguising it as accepted evidence.
p = Path('tests/eb/EB-I25_CHECKPOINT.json')
data = json.loads(p.read_text())
data['title'] = 'Accepted external full/half two-half sensible-boundary runtime materialization'
data['new_evidence'].append(
    'Diagnostic run 34986149921/job 104438632067 showed the positive-flux external-full/half outflow fixture is rejected before commit (completed=false, committed=false, accepted_substeps=0, no publication). It cannot qualify accepted two-half outflow semantics.'
)
data['tests'].append({
    'run': 34986149921,
    'job': 104438632067,
    'result': 'EXPECTED_SCOPE_DIAGNOSTIC',
    'finding': 'inflow and missing-donor cases passed; outflow fixture rejected before transaction acceptance, so accepted two-half outflow remains a hard nonclaim'
})
data['verdict'] = 'OWNER_GATE_READY_WITH_OUTFLOW_SCOPE_NARROWED'
data['mutations'].append('narrowed owner outflow evidence to rejected-fixture/no-publication; retained defensive production direction guard without claiming accepted two-half outflow qualification')
data['next_permitted_action'] = 'Run clean EB-I25 owner gate at O0/O2. If green, persist exact owner head/blobs and start independent qualification under an unused F-VQ identifier; independent qualification must preserve the accepted-outflow nonclaim.'
p.write_text(json.dumps(data, indent=2) + '\n')
