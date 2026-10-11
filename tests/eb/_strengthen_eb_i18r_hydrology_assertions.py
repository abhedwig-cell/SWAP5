from pathlib import Path

path = Path('tests/eb/test_eb_i18_transaction_publication.f90')
text = path.read_text()
anchor = """    call require(output%completed .and. output%committed, 'complete provider hydrology committed')
    call require(committed%current_revision() == 1_int64, 'complete provider single commit')
"""
replacement = """    call require(output%completed .and. output%committed, 'complete provider hydrology committed')
    call require(output%mass%complete, 'complete provider water mass accounting complete')
    call require(abs(output%mass%residual) <= 1.0e-12_real64, 'complete provider hard water mass gate')
    call require(output%accepted_substeps == 1, 'complete provider exactly one accepted substep')
    call require(output%solver_headcalc_calls == 1, 'complete provider bounded one-trajectory HeadCalc cost')
    call require(committed%current_revision() == 1_int64, 'complete provider single commit')
"""
count = text.count(anchor)
if count != 1:
    raise SystemExit(f'EB-I18R hydrology assertion anchor matched {count} times')
text = text.replace(anchor, replacement, 1)
path.write_text(text)
print('EB_I18R_PUBLICATION_HARD_MASS_BINDING=PASS')
print('EB_I18R_PUBLICATION_SINGLE_ACCEPTED_SUBSTEP=PASS')
print('EB_I18R_PUBLICATION_BOUNDED_HEADCALC_COST=PASS')
