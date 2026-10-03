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
    def trial_cell_heads(self, heads):
        self.last_trial_heads = list(heads)
        if any(not (-1.999 < h < 0.0) for h in heads):
            return GroundwaterApplicationCorrectorBatch(False, ())
        return super().trial_cell_heads(heads)


def main():
    lib = args.library.resolve()
    mf = args.libmf6.resolve()
    work = args.output.resolve()
    work.mkdir(parents=True, exist_ok=True)
    result = dict(
        state='RUNNING',
        experiment='F-GC-STRIP01-C2A-C2B-CONTINUOUS',
        real_swap=True,
        native_modflow=True,
        experimental=True,
        canonical_admission=False,
        columns=50,
        profile='C2',
        windows=[],
    )
    bridge = ctypes.CDLL(str(lib))
    init = bridge.fgc49d_fixture_initialize_c
    init.restype = ctypes.c_int
    init.argtypes = [
        ctypes.POINTER(ctypes.c_int64),
        ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),
    ]
    set_rain = bridge.fgc49d_fixture_set_rain_c
    set_rain.restype = ctypes.c_int
    set_rain.argtypes = [ctypes.c_double]
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
    fields_fn = bridge.strip01_fields_c
    fields_fn.restype = ctypes.c_int
    fields_fn.argtypes = [ctypes.POINTER(ctypes.c_double)]

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
    result['initial_profile_state_sha256'] = state_hash()
    result['initial_storage_m3'], result['initial_revisions'] = state()
    result['initial_ledger_counts'] = counts()

    sim = flopy.mf6.MFSimulation(sim_name='realstrip01sequence', sim_ws=str(work))
    flopy.mf6.ModflowTdis(
        sim,
        time_units='DAYS',
        perioddata=[(0.002, 2, 1)],
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
        for window_index, time_start in enumerate((0.0, 0.001)):
            if window_index == 1:
                rain_status = int(set_rain(ctypes.c_double(0.1)))
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
            runtime = DomainRuntime(lib, handles[window_index])
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
                    flux_tolerance_m_per_s=1e-15,
                    max_coupling_iterations=40,
                ),
            )
            storage_after, revisions_after = state()
            ledgers_after = counts()
            record = dict(
                label='C2a' if window_index == 0 else 'C2b',
                t0_day=time_start,
                duration_day=0.001,
                precipitation_m_per_day=0.0 if window_index == 0 else 0.001,
                precipitation_input_m3=0.0 if window_index == 0 else 0.00005,
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
                result['state'] = 'C2A_REJECTED' if window_index == 0 else 'C2A_ACCEPTED_C2B_REJECTED'
                break
            if window_index == 0:
                result['c2a_committed_state_sha256'] = state_hash()
                result['c2a_committed_storage_m3'] = storage_after
                result['c2a_committed_revisions'] = revisions_after
                result['c2a_committed_ledger_counts'] = ledgers_after
            else:
                result['state'] = 'C2A_C2B_BOTH_PUBLISHED'

        raw.finalize()
        initialized = False
        if result['windows']:
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

