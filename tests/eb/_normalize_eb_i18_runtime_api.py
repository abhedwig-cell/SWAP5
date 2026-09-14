from pathlib import Path

OLD = 'fmr_execute_serialized_resolved_physical_column_with_bottom_energy'
NEW = 'fmr_execute_serialized_column_with_bottom_energy'

for filename in (
    'src/runtime/mod_fmr_serialized_multiswap_runtime.f90',
    'tests/eb/test_eb_i18_transaction_publication.f90',
):
    path = Path(filename)
    text = path.read_text()
    count = text.count(OLD)
    if count <= 0:
        raise SystemExit(f'EB-I18 API normalization: {OLD!r} not found in {filename}')
    text = text.replace(OLD, NEW)
    if OLD in text:
        raise SystemExit(f'EB-I18 API normalization incomplete in {filename}')
    path.write_text(text)
    print(f'EB_I18_API_NORMALIZED file={filename} replacements={count} name={NEW}')
