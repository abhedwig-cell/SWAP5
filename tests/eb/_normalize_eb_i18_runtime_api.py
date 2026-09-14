from pathlib import Path

OLD = 'fmr_execute_serialized_resolved_physical_column_with_bottom_energy'
NEW = 'fmr_execute_serialized_column_with_bottom_energy'

runtime = Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
text = runtime.read_text()
count = text.count(OLD)
if count <= 0:
    raise SystemExit(f'EB-I18 API normalization: {OLD!r} not found in {runtime}')
text = text.replace(OLD, NEW)
private_constructor = '    thermal_candidate = fmr_bottom_thermal_candidate_t()\n'
if text.count(private_constructor) != 1:
    raise SystemExit('EB-I18 runtime private thermal constructor anchor mismatch')
text = text.replace(private_constructor, '    call thermal_candidate%clear()\n', 1)
if OLD in text:
    raise SystemExit(f'EB-I18 API normalization incomplete in {runtime}')
runtime.write_text(text)
print(f'EB_I18_API_NORMALIZED file={runtime} replacements={count} name={NEW}')
print('EB_I18_PRIVATE_THERMAL_CONSTRUCTOR_REMOVED=PASS')

test = Path('tests/eb/test_eb_i18_transaction_publication.f90')
text = test.read_text()
count = text.count(OLD)
if count <= 0:
    raise SystemExit(f'EB-I18 API normalization: {OLD!r} not found in {test}')
text = text.replace(OLD, NEW)
invalid_constructor = '      response = fmr_external_bottom_thermal_response_t()\n'
invalid_replacement = (
    '      call response%set_complete(request, donor_temperature_c, -1_int64, ok)\n'
    "      if (ok) error stop 'EB-I18 invalid response unexpectedly ready'\n"
)
if text.count(invalid_constructor) != 1:
    raise SystemExit('EB-I18 test private response constructor anchor mismatch')
text = text.replace(invalid_constructor, invalid_replacement, 1)
if OLD in text:
    raise SystemExit(f'EB-I18 API normalization incomplete in {test}')
test.write_text(text)
print(f'EB_I18_API_NORMALIZED file={test} replacements={count} name={NEW}')
print('EB_I18_PRIVATE_RESPONSE_CONSTRUCTOR_REMOVED=PASS')
