#!/usr/bin/env python3
from pathlib import Path
import subprocess

TEST = Path('tests/fmr/test_fmr20_authoritative_one_worker_identity.f90')
EXPECTED = 'd21c727427dc42c84cd4fcd90c4399001fcc5b5a'

def blob(path):
    return subprocess.check_output(['git','hash-object',str(path)], text=True).strip()

def once(text, old, new, label):
    n=text.count(old)
    if n != 1:
        raise SystemExit(f'FMR20_POISON_MATERIALIZE_FAIL {label}: expected 1 occurrence, found {n}')
    return text.replace(old,new,1)

actual=blob(TEST)
if actual != EXPECTED:
    raise SystemExit(f'FMR20_POISON_MATERIALIZE_FAIL preimage {actual} != {EXPECTED}')
print('FMR20_POISON_G01_PREIMAGE_LOCK=PASS')

s=TEST.read_text(encoding='utf-8')
s=once(s,
"  use variables, only: legacy_qrot => qrot\n",
"  use variables, only: legacy_qrot => qrot, legacy_dt => dt, legacy_swbotb => swbotb, &\n"
"       legacy_swkimpl => swkimpl, legacy_swkmean => swkmean, legacy_dtmin => dtmin, &\n"
"       legacy_maxit => maxit, legacy_maxbacktr => maxbacktr, legacy_CritDevBalCp => CritDevBalCp, &\n"
"       legacy_CritDevBalTot => CritDevBalTot, legacy_critdevh2cp => critdevh2cp, &\n"
"       legacy_critdevh1cp => critdevh1cp, legacy_critdevponddt => critdevponddt, &\n"
"       legacy_fldtmin => fldtmin, legacy_qtop => qtop, legacy_qbot => qbot, legacy_hbot => hbot\n",
'import mirror globals')
s=once(s,
"  type(kernel_committed_state_t) :: direct_states(ncol), pool_states(ncol), rejected_states(ncol)\n",
"  type(kernel_committed_state_t) :: direct_states(ncol), pool_states(ncol), poison_states(ncol), rejected_states(ncol)\n",
'poison state registry')
s=once(s,
"  type(fmr_serialized_column_result_t), allocatable :: direct_results(:), pool_results(:), rejected_results(:)\n",
"  type(fmr_serialized_column_result_t), allocatable :: direct_results(:), pool_results(:), poison_results(:), rejected_results(:)\n",
'poison results')
s=once(s,
"  type(fmr_column_diagnostics_t), allocatable :: direct_diag(:), pool_diag(:), rejected_diag(:)\n",
"  type(fmr_column_diagnostics_t), allocatable :: direct_diag(:), pool_diag(:), poison_diag(:), rejected_diag(:)\n",
'poison diagnostics')
s=once(s,
"  type(fmr_aggregate_diagnostics_t) :: direct_aggregate, pool_aggregate, rejected_aggregate\n",
"  type(fmr_aggregate_diagnostics_t) :: direct_aggregate, pool_aggregate, poison_aggregate, rejected_aggregate\n",
'poison aggregate')
s=once(s,
"  type(fmr_serialized_batch_diagnostics_t) :: direct_runtime, pool_runtime, rejected_runtime\n",
"  type(fmr_serialized_batch_diagnostics_t) :: direct_runtime, pool_runtime, poison_runtime, rejected_runtime\n",
'poison runtime diagnostics')
s=once(s,
"    call fmr_new_b110_committed_state(pool_states(i), columns(i)%column_id, column_state, t0, ok)\n    call require(ok, 'pool state initialization')\n",
"    call fmr_new_b110_committed_state(pool_states(i), columns(i)%column_id, column_state, t0, ok)\n    call require(ok, 'pool state initialization')\n    call fmr_new_b110_committed_state(poison_states(i), columns(i)%column_id, column_state, t0, ok)\n    call require(ok, 'poison state initialization')\n",
'poison state initialization')

anchor="""  call require(direct_status == FMR_SERIAL_DISPATCH_OK, 'direct serialized dispatch')
  call require(all_committed(direct_results), 'direct committed')

  call reset_legacy_globals()
"""
insert="""  call require(direct_status == FMR_SERIAL_DISPATCH_OK, 'direct serialized dispatch')
  call require(all_committed(direct_results), 'direct committed')

  call poison_legacy_mirror_globals()
  call fmr_run_serialized_physical_multiswap(columns, templates, parameters, forcings, poison_states, config, &
       top_provider, t0, t1, batch_size, poison_results, poison_diag, poison_aggregate, serialized_status, poison_runtime)
  call require(serialized_status == direct_status, 'poison dispatch identity')
  call require(all_committed(poison_results), 'poison committed')
  call require(result_sets_identical(direct_results, poison_results), 'mirror poison result identity')
  call require(diagnostic_sets_identical(direct_diag, poison_diag), 'mirror poison diagnostics identity')
  call require(aggregates_identical(direct_aggregate, poison_aggregate), 'mirror poison aggregate identity')
  call require(runtime_diagnostics_identical(direct_runtime, poison_runtime), 'mirror poison runtime identity')
  call require(state_sets_identical(direct_states, poison_states), 'mirror poison committed-state identity')
  call require(max_abs_residual(poison_results) <= hard_mass_gate, 'mirror poison hard mass gate')
  write(*,'(A)') 'FMR20_AUTH_CANONICAL_MIRROR_POISON_RESULT_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_AUTH_CANONICAL_MIRROR_POISON_DIAGNOSTIC_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_AUTH_CANONICAL_MIRROR_POISON_STATE_TIME_IDENTITY=PASS'
  write(*,'(A)') 'FMR20_AUTH_CANONICAL_MIRROR_POISON_HARD_MASS_GATE=PASS'

  call reset_legacy_globals()
"""
s=once(s,anchor,insert,'insert poison execution')

anchor2="""  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine reset_legacy_globals
"""
insert2=anchor2+"""

  subroutine poison_legacy_mirror_globals()
    legacy_qdra = 9.87654321e4_real64
    legacy_qssdi = -8.7654321e4_real64
    legacy_qrot = 7.654321e4_real64
    legacy_dt = 91.25_real64
    legacy_swbotb = 3
    legacy_swkimpl = 1
    legacy_swkmean = 9
    legacy_dtmin = 83.5_real64
    legacy_maxit = 37
    legacy_maxbacktr = 29
    legacy_CritDevBalCp = 1.2345e3_real64
    legacy_CritDevBalTot = 2.3456e3_real64
    legacy_critdevh2cp = 3.4567e3_real64
    legacy_critdevh1cp = 4.5678e3_real64
    legacy_critdevponddt = 5.6789e3_real64
    legacy_fldtmin = .true.
    legacy_qtop = 6.7891e3_real64
    legacy_qbot = -7.8912e3_real64
    legacy_hbot = 8.9123e3_real64
    swmacro = 1
    melt = 9.1234e3_real64
  end subroutine poison_legacy_mirror_globals
"""
s=once(s,anchor2,insert2,'poison helper')

for marker in (
    'FMR20_AUTH_CANONICAL_MIRROR_POISON_RESULT_IDENTITY=PASS',
    'FMR20_AUTH_CANONICAL_MIRROR_POISON_DIAGNOSTIC_IDENTITY=PASS',
    'FMR20_AUTH_CANONICAL_MIRROR_POISON_STATE_TIME_IDENTITY=PASS',
    'FMR20_AUTH_CANONICAL_MIRROR_POISON_HARD_MASS_GATE=PASS'):
    if marker not in s:
        raise SystemExit(f'FMR20_POISON_MATERIALIZE_FAIL missing marker {marker}')

TEST.write_text(s,encoding='utf-8')
print('FMR20_POISON_G02_TEST_MATERIALIZED=PASS')
print(f'FMR20_POISON_POSTIMAGE {blob(TEST)}')
