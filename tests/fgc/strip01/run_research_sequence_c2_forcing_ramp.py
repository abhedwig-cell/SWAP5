"""C2a-to-C2b continuous two-window SWAP-MODFLOW experiment."""
import argparse
import ctypes
import hashlib
import json
import struct
import traceback
from pathlib import Path
import sys

import flopy
import numpy as np
from xmipy import XmiWrapper

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--library', type=Path, required=True)
parser.add_argument('--libmf6', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--max-committed-substeps', type=int, default=32)
parser.add_argument('--window-duration-day', type=float, default=0.001)
parser.add_argument('--window-count', type=int, default=1)
parser.add_argument('--seed-mode', choices=['tangent', 'zero'], default='zero')
parser.add_argument('--ramp-start-cm-per-day', type=float, default=1e-6)
parser.add_argument('--ramp-factor', type=float, default=1.1)
parser.add_argument('--ramp-cap-cm-per-day', type=float, default=0.1)
parser.add_argument('--diagnostic-rates-cm-per-day', default='', help='Comma-separated research-only forcing rates to probe from the failed transaction origin.')
parser.add_argument('--diagnostic-columns', default='1',
                    help='Comma-separated SWAP column indices, or "all", for discarded failure-origin probes.')
parser.add_argument('--flux-tolerance-m-per-s', type=float, default=1e-15,
                    help='Research coupling residual tolerance; does not change SWAP temporal or mass gates.')
args = parser.parse_args()
sys.path.insert(0, str(args.root.resolve() / 'src/adapter'))
from fmr_groundwater_application_runtime import FmrGroundwaterApplicationRuntime
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_groundwater_application_service import (
    GroundwaterApplicationCorrectorBatch,
    GroundwaterApplicationServiceConfig,
    run_groundwater_application_window,
)
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession


class CountingKernel:
    def __init__(self, kernel):
        self.kernel = kernel
        self.calls = dict(prepare_solve=0, solve=0, finalize_solve=0, finalize_time_step=0)

    def __getattr__(self, name):
        return getattr(self.kernel, name)

    def prepare_solve(self, solution_id):
        self.calls['prepare_solve'] += 1
        return self.kernel.prepare_solve(solution_id)

    def solve(self, solution_id):
        self.calls['solve'] += 1
        return self.kernel.solve(solution_id)

    def finalize_solve(self, solution_id):
        self.calls['finalize_solve'] += 1
        return self.kernel.finalize_solve(solution_id)

    def finalize_time_step(self):
        self.calls['finalize_time_step'] += 1
        return self.kernel.finalize_time_step()


class DomainRuntime(FmrGroundwaterApplicationRuntime):
    def __init__(self, library_path, context_handle, failure_diagnostic):
        super().__init__(library_path, context_handle)
        self.failure_diagnostic = failure_diagnostic
        self.participant_failure_diagnostics = []

    def trial_cell_heads(self, heads):
        self.last_trial_heads = list(heads)
        if any(not (-1.999 < h < 0.0) for h in heads):
            return GroundwaterApplicationCorrectorBatch(False, ())
        answer = super().trial_cell_heads(heads)
        if self.failure_diagnostic is not None:
            cell, tile, participant_status, local_status = (ctypes.c_int() for _ in range(4))
            status = self.failure_diagnostic(
                ctypes.c_int64(self.context_handle), ctypes.byref(cell), ctypes.byref(tile),
                ctypes.byref(participant_status), ctypes.byref(local_status),
            )
            if status == 0 and (cell.value != 0 or tile.value != 0):
                self.participant_failure_diagnostics.append(dict(
                    cell_index=cell.value, tile_index=tile.value,
                    participant_status=participant_status.value, registry_local_status=local_status.value,
                ))
        return answer


def main():
    lib = args.library.resolve()
    mf = args.libmf6.resolve()
    work = args.output.resolve()
    work.mkdir(parents=True, exist_ok=True)
    result = dict(
        state='RUNNING',
        experiment='F-GC-STRIP01-C2B-SEEDED-ONSET-DISCRIMINATOR',
        real_swap=True,
        native_modflow=True,
        experimental=True,
        canonical_admission=False,
        columns=50,
        profile='C2',
        windows=[],
    )
    bridge = ctypes.CDLL(str(lib))
    failure_diagnostic = getattr(bridge, 'fgc49d_last_trial_failure_c', None)
    result['participant_failure_instrumentation_available'] = failure_diagnostic is not None
    if failure_diagnostic is not None:
        failure_diagnostic.restype = ctypes.c_int
        failure_diagnostic.argtypes = [ctypes.c_int64] + [ctypes.POINTER(ctypes.c_int)] * 4
    init = bridge.fgc49d_fixture_initialize_c
    init.restype = ctypes.c_int
    init.argtypes = [
        ctypes.POINTER(ctypes.c_int64),
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),
    ]
    set_top_flux = bridge.fgc49d_fixture_set_top_flux_c
    set_top_flux.restype = ctypes.c_int
    set_top_flux.argtypes = [ctypes.c_double]
    advance = bridge.fgc49d_fixture_advance_c
    advance.restype = ctypes.c_int
    advance.argtypes = [
        ctypes.POINTER(ctypes.c_int64),
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),
    ]
    observe = bridge.strip01_observe_c
    observe.restype = ctypes.c_int
    observe.argtypes = [
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_int),
    ]
    ledger_counts = bridge.strip01_ledger_counts_c
    ledger_counts.restype = ctypes.c_int
    ledger_counts.argtypes = [ctypes.POINTER(ctypes.c_int)]
    diagnose = bridge.strip01_diagnose_detail_c
    diagnose.restype = ctypes.c_int
    diagnose.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double,
                         ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double)]
    diagnose_flux = bridge.strip01_diagnose_detail_flux_c
    diagnose_flux.restype = ctypes.c_int
    diagnose_flux.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_double,
                              ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double)]
    fields_fn = bridge.strip01_fields_c
    fields_fn.restype = ctypes.c_int
    fields_fn.argtypes = [ctypes.POINTER(ctypes.c_double)]

    seed_values = [7.713099137163226] + [0.0] * 19 if args.seed_mode == 'tangent' else [0.0] * 20
    seed = (ctypes.c_double * 20)(*seed_values)
    set_seed = bridge.strip01_seed_derivative_c
    set_seed.argtypes = [ctypes.POINTER(ctypes.c_double)]
    set_seed.restype = ctypes.c_int
    result['seed_binding_status'] = int(set_seed(seed))
    result['seed_mode'] = args.seed_mode
    result['forcing_ramp'] = dict(start_cm_per_day=args.ramp_start_cm_per_day, factor=args.ramp_factor, cap_cm_per_day=args.ramp_cap_cm_per_day)
    assert result['seed_binding_status'] == 0
    set_substeps = bridge.strip01_seed_max_substeps_c
    set_substeps.argtypes = [ctypes.c_int]
    set_substeps.restype = ctypes.c_int
    result['max_committed_substeps'] = int(args.max_committed_substeps)
    result['substep_cap_binding_status'] = int(set_substeps(args.max_committed_substeps))
    assert result['substep_cap_binding_status'] == 0
    set_duration = bridge.strip01_seed_window_duration_c
    set_duration.argtypes = [ctypes.c_double]
    set_duration.restype = ctypes.c_int
    result['window_duration_day'] = float(args.window_duration_day)
    result['window_count'] = int(args.window_count)
    result['window_duration_binding_status'] = int(set_duration(args.window_duration_day))
    assert result['window_duration_binding_status'] == 0
    handle1, h1, h2 = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
    status = init(ctypes.byref(handle1), ctypes.byref(h1), ctypes.byref(h2))
    result['initialization_status'] = int(status)
    if status != 0:
        result['state'] = 'INITIALIZATION_FAIL'
        (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        return

    def state():
        storage, revisions = (ctypes.c_double * 50)(), (ctypes.c_int * 50)()
        assert observe(storage, revisions) == 0
        return list(storage), list(revisions)

    def counts():
        values = (ctypes.c_int * 50)()
        assert ledger_counts(values) == 0
        return list(values)

    nfloat = 3 * 20 + 3
    def state_hash():
        values = (ctypes.c_double * (nfloat * 50))()
        assert fields_fn(values) == 0
        return hashlib.sha256(struct.pack('<' + 'd' * len(values), *values)).hexdigest()

    result['initial_head_m'] = float(h1.value)
    initial_rain_rate = min(args.ramp_cap_cm_per_day, args.ramp_start_cm_per_day)
    rain_rate = initial_rain_rate
    result['infiltration_top_flux_cm_per_day'] = -initial_rain_rate
    result['rain_surface_forcing_status'] = int(set_top_flux(-initial_rain_rate))
    assert result['rain_surface_forcing_status'] == 0
    result['initial_profile_state_sha256'] = state_hash()
    result['initial_storage_m3'], result['initial_revisions'] = state()
    result['initial_ledger_counts'] = counts()

    sim = flopy.mf6.MFSimulation(sim_name='realstrip01sequence', sim_ws=str(work))
    flopy.mf6.ModflowTdis(
        sim,
        time_units='DAYS',
        perioddata=[(args.window_duration_day * args.window_count, args.window_count, 1)],
    )
    flopy.mf6.ModflowIms(
        sim,
        outer_dvclose=1e-10,
        inner_dvclose=1e-11,
        outer_maximum=200,
        inner_maximum=300,
        rcloserecord=1e-11,
    )
    gwf = flopy.mf6.ModflowGwf(sim, modelname='STRIP', save_flows=True)
    flopy.mf6.ModflowGwfdis(
        gwf, nlay=1, nrow=1, ncol=50, delr=1, delc=1, top=-2, botm=-10
    )
    flopy.mf6.ModflowGwfic(gwf, strt=np.full((1, 1, 50), -1.0))
    flopy.mf6.ModflowGwfnpf(gwf, icelltype=0, k=0.5, save_flows=True)
    flopy.mf6.ModflowGwfdrn(
        gwf, stress_period_data=[((0, 0, 0), -1, 100)], pname='DRN_LEFT'
    )
    flopy.mf6.ModflowGwfapi(gwf, maxbound=50, pname='API_SWAP')
    flopy.mf6.ModflowGwfoc(
        gwf,
        head_filerecord='strip.hds',
        budget_filerecord='strip.cbc',
        saverecord=[('HEAD', 'ALL'), ('BUDGET', 'ALL')],
    )
    sim.write_simulation(silent=True)

    raw = XmiWrapper(lib_path=mf, working_directory=work)
    kernel = CountingKernel(raw)
    initialized = False
    try:
        raw.initialize()
        initialized = True
        handles = [int(handle1.value)]
        for window_index in range(args.window_count):
            time_start = window_index * args.window_duration_day
            if window_index > 0:
                rain_rate = min(args.ramp_cap_cm_per_day, args.ramp_start_cm_per_day * args.ramp_factor ** window_index)
                rain_status = int(set_top_flux(ctypes.c_double(-rain_rate)))
                result['rain_surface_forcing_status'] = rain_status
                if rain_status != 0:
                    result['state'] = 'C2B_FORCING_BINDING_FAILED'
                    break
                handle2, next_h1, next_h2 = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
                advance_status = int(
                    advance(
                        ctypes.byref(handle2),
                        ctypes.byref(next_h1),
                        ctypes.byref(next_h2),
                    )
                )
                result['advance_context_status'] = advance_status
                if advance_status != 0:
                    result['state'] = 'C2B_CONTEXT_BINDING_FAILED'
                    break
                handles.append(int(handle2.value))
            raw.prepare_time_step(time_start)
            runtime = DomainRuntime(lib, handles[window_index], failure_diagnostic)
            session = Modflow6PreparedSolveSession(
                kernel,
                'STRIP',
                'API_SWAP',
                Fgc34CtypesPublisher(lib),
                solution_id=1,
            )
            before_hash = state_hash()
            storage_before, revisions_before = state()
            ledgers_before = counts()
            calls_before = dict(kernel.calls)
            answer = run_groundwater_application_window(
                runtime,
                session,
                GroundwaterApplicationServiceConfig(
                    flux_tolerance_m_per_s=args.flux_tolerance_m_per_s,
                    max_coupling_iterations=40,
                ),
            )
            diagnostic = []
            if not answer.published and args.diagnostic_rates_cm_per_day:
                diagnostic_rates = [float(x) for x in args.diagnostic_rates_cm_per_day.split(',') if x.strip()]
                diagnostic_columns = (range(1, 51) if args.diagnostic_columns.lower() == 'all'
                                      else [int(x) for x in args.diagnostic_columns.split(',') if x.strip()])
                for column_index in diagnostic_columns:
                    for rate in diagnostic_rates:
                        for dt in (0.00001, 0.000005, 0.0000025, 0.00000125, 0.000001):
                            codes, values = (ctypes.c_int * 12)(), (ctypes.c_double * 6)()
                            assert diagnose_flux(column_index, -1.0, dt, -rate, codes, values) == 0
                            diagnostic.append(dict(column_index=column_index, head_m=-1.0,
                                                   diagnostic_rain_rate_cm_per_day=rate,
                                                   dt_day=dt, codes=list(codes), observations=list(values)))
            elif window_index == 1 or not answer.published:
                probe_heads = sorted(set([-1.0] + getattr(runtime, 'last_trial_heads', [])[:3]))
                for probe_head in probe_heads:
                    for dt in (0.001, 0.0001, 0.00001, 0.000001):
                        codes, values = (ctypes.c_int * 12)(), (ctypes.c_double * 6)()
                        assert diagnose(1, probe_head, dt, codes, values) == 0
                        diagnostic.append(dict(head_m=probe_head, dt_day=dt, codes=list(codes),
                                               observations=list(values)))
            storage_after, revisions_after = state()
            ledgers_after = counts()
            record = dict(
                corrector_trial_heads_m=list(getattr(runtime, 'last_trial_heads', [])),
                participant_failure_diagnostics=list(runtime.participant_failure_diagnostics),
                post_c2b_one_column_probes=diagnostic,
                label='C2b-forcing-ramp-zero-seed',
                t0_day=time_start,
                duration_day=args.window_duration_day,
                precipitation_m_per_day=rain_rate * 0.01,
                infiltration_top_flux_cm_per_day=-rain_rate,
                precipitation_input_m3=rain_rate * 0.01 * 50.0 * args.window_duration_day,
                service_status=int(answer.status),
                published=bool(answer.published),
                failure_stage=answer.failure_stage,
                iterations=int(answer.iterations),
                heads_m=list(answer.final_heads_m),
                residuals_m_per_s=list(answer.final_residuals_m_per_s),
                state_hash_before=before_hash,
                state_hash_after=state_hash(),
                storage_before_m3=storage_before,
                storage_after_m3=storage_after,
                revisions_before=revisions_before,
                revisions_after=revisions_after,
                ledger_counts_before=ledgers_before,
                ledger_counts_after=ledgers_after,
                modflow_call_delta={
                    key: kernel.calls[key] - calls_before[key] for key in kernel.calls
                },
                accepted_xold_m=session.accepted_xold.tolist()
                if session.accepted_xold is not None
                else [],
                final_xold_m=session.xold.tolist()
                if session.xold is not None
                else [],
            )
            if answer.published:
                assert revisions_after == [revisions_before[0] + 1] * 50
                assert ledgers_after == [ledgers_before[0] + 1] * 50
                if window_index > 0:
                    promote = bridge.fgc49d_fixture_promote_context_c
                    promote.restype = ctypes.c_int
                    promote.argtypes = []
                    result['context_promote_status'] = int(promote())
                    assert result['context_promote_status'] == 0
            else:
                assert before_hash == state_hash()
                assert storage_before == storage_after
                assert revisions_before == revisions_after
                assert ledgers_before == ledgers_after
                assert session.accepted_xold is not None
                assert np.array_equal(session.accepted_xold, session.xold)
                assert kernel.calls['finalize_time_step'] == calls_before['finalize_time_step']
            result['windows'].append(record)
            if not answer.published:
                result['state'] = 'C2B_RAIN_MICRO_WINDOW_REJECTED'
                break
            if window_index == 0:
                result['first_committed_state_sha256'] = state_hash()
                result['first_committed_storage_m3'] = storage_after
                result['first_committed_revisions'] = revisions_after
                result['first_committed_ledger_counts'] = ledgers_after
                result['state'] = 'C2B_SEEDED_WINDOW_PUBLISHED'
            else:
                result['state'] = 'C2B_RAIN_MICRO_WINDOWS_IN_PROGRESS'

        raw.finalize()
        initialized = False
        if result['windows'] and (work / 'strip.cbc').exists() and (work / 'strip.cbc').stat().st_size > 0:
            budget = flopy.utils.CellBudgetFile(work / 'strip.cbc', precision='double')
            for index, window in enumerate(result['windows']):
                drn_records = budget.get_data(text='DRN', kstpkper=(index, 0))
                signed_drn_rate = (
                    float(sum(np.sum(values['q']) for values in drn_records))
                    if drn_records
                    else 0.0
                )
                drain_out_rate = -signed_drn_rate
                window['drain_out_m3_per_day'] = drain_out_rate
                window['drain_out_volume_m3'] = drain_out_rate * window['duration_day']
                delta_storage = sum(window['storage_after_m3']) - sum(window['storage_before_m3'])
                window['delta_swap_storage_m3'] = delta_storage
                window['mass_residual_m3'] = (
                    window['precipitation_input_m3']
                    - window['drain_out_volume_m3']
                    - delta_storage
                )
                if window['published']:
                    assert abs(window['mass_residual_m3']) <= 1e-8
        if len(result['windows']) == args.window_count and all(w['published'] for w in result['windows']):
            result['state'] = 'C2B_RAIN_MICRO_WINDOWS_ALL_PUBLISHED'
        result['final_profile_state_sha256'] = state_hash()
        result['final_storage_m3'], result['final_revisions'] = state()
        result['final_ledger_counts'] = counts()
        result['modflow_calls_total'] = kernel.calls
    except Exception:
        result['state'] = 'SEQUENCE_EXCEPTION'
        result['exception'] = traceback.format_exc()
    finally:
        if initialized:
            raw.finalize()
        (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(result['state'])


if __name__ == '__main__':
    main()
