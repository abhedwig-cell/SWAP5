"""Experimental real 50-column first-window test, separate from bootstrap."""
import argparse
import ctypes
import json
import hashlib
import struct
from pathlib import Path
import sys
import traceback
import flopy
import numpy as np
from xmipy import XmiWrapper

parser = argparse.ArgumentParser()
parser.add_argument('--profile', choices=['C0','C1','C2'], default='C0')
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[3])
parser.add_argument('--library', type=Path, required=True)
parser.add_argument('--libmf6', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
sys.path.insert(0, str(args.root.resolve() / 'src/adapter'))
from fmr_groundwater_application_runtime import FmrGroundwaterApplicationRuntime
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher
from modflow6_groundwater_application_service import (
    GroundwaterApplicationServiceConfig, run_groundwater_application_window,
    GroundwaterApplicationCorrectorBatch,
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
        if any(not ((-5.999 if args.profile == 'C0' else -1.999) < h < 0) for h in heads):
            return GroundwaterApplicationCorrectorBatch(False, ())
        return super().trial_cell_heads(heads)


def main():
    lib = args.library.resolve()
    mf = args.libmf6.resolve()
    work = args.output.resolve()
    work.mkdir(parents=True, exist_ok=True)
    result = dict(state='RUNNING', real_swap=True, native_modflow=True,
                  experimental=True, canonical_admission=False, columns=50)
    bridge = ctypes.CDLL(str(lib.resolve()))
    init = bridge.fgc49d_fixture_initialize_c
    init.restype = ctypes.c_int
    init.argtypes = [ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double)]
    handle, h1, h2 = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
    status = init(ctypes.byref(handle), ctypes.byref(h1), ctypes.byref(h2))
    result['initialization_status'] = int(status)
    if status != 0:
        result['state'] = 'INITIALIZATION_FAIL'
        (work / 'result.json').write_text(json.dumps(result, indent=2))
        return
    observe = bridge.strip01_observe_c
    observe.restype = ctypes.c_int
    observe.argtypes = [ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int)]

    def state():
        s, r = (ctypes.c_double * 50)(), (ctypes.c_int * 50)()
        assert observe(s, r) == 0
        return list(s), list(r)

    ledger_counts = bridge.strip01_ledger_counts_c
    ledger_counts.argtypes = [ctypes.POINTER(ctypes.c_int)]
    def counts():
        c = (ctypes.c_int * 50)()
        assert ledger_counts(c) == 0
        return list(c)
    fields_fn = bridge.strip01_fields_c
    fields_fn.argtypes = [ctypes.POINTER(ctypes.c_double)]
    field_count = (3 * (60 if args.profile == 'C0' else 20) + 3) * 50
    def state_hash():
        values = (ctypes.c_double * field_count)()
        assert fields_fn(values) == 0
        return hashlib.sha256(struct.pack('<' + 'd' * field_count, *values)).hexdigest()
    result['profile'] = args.profile
    result['origin_profile_state_sha256'] = state_hash()
    result['profile_state_schema'] = 'per column: pressure heads, theta, temporal predecessor derivative, pond, GWL, committed time; little-endian float64'
    result['profile_state_float_count'] = field_count
    result['origin_ledger_counts'] = counts()
    runtime = DomainRuntime(lib, handle.value)
    result['origin_storage_m3'], result['origin_revisions'] = state()
    sim = flopy.mf6.MFSimulation(sim_name='realstrip01', sim_ws=str(work))
    flopy.mf6.ModflowTdis(sim, time_units='DAYS', perioddata=[(0.001, 1, 1)])
    flopy.mf6.ModflowIms(sim, outer_dvclose=1e-10, inner_dvclose=1e-11,
                       outer_maximum=200, inner_maximum=300, rcloserecord=1e-11)
    gwf = flopy.mf6.ModflowGwf(sim, modelname='STRIP', save_flows=True)
    plane, stage = (-6, -5) if args.profile == 'C0' else (-2, -1)
    flopy.mf6.ModflowGwfdis(gwf, nlay=1, nrow=1, ncol=50, delr=1, delc=1, top=plane, botm=-10)
    initial_heads = np.full((1, 1, 50), float(stage))
    if args.profile in ('C0', 'C1'):
        initial_heads[0, 0, -1] = stage + 0.5
    flopy.mf6.ModflowGwfic(gwf, strt=initial_heads)
    flopy.mf6.ModflowGwfnpf(gwf, icelltype=0, k=0.5, save_flows=True)
    flopy.mf6.ModflowGwfdrn(gwf, stress_period_data=[((0, 0, 0), stage, 100)], pname='DRN_LEFT')
    flopy.mf6.ModflowGwfapi(gwf, maxbound=50, pname='API_SWAP')
    flopy.mf6.ModflowGwfoc(gwf, head_filerecord='strip.hds', budget_filerecord='strip.cbc',
                         saverecord=[('HEAD', 'ALL'), ('BUDGET', 'ALL')])
    sim.write_simulation(silent=True)
    raw = XmiWrapper(lib_path=mf.resolve(), working_directory=work.resolve())
    kernel = CountingKernel(raw)
    initialized = False
    try:
        raw.initialize()
        initialized = True
        raw.prepare_time_step(0.0)
        session = Modflow6PreparedSolveSession(kernel, 'STRIP', 'API_SWAP', Fgc34CtypesPublisher(lib), solution_id=1)
        answer = run_groundwater_application_window(runtime, session,
            GroundwaterApplicationServiceConfig(flux_tolerance_m_per_s=1e-15, max_coupling_iterations=40))
        result['service'] = dict(status=int(answer.status), published=answer.published,
            failure_stage=answer.failure_stage, iterations=answer.iterations,
            request_smaller_window=answer.request_smaller_window,
            heads_m=answer.final_heads_m, residuals_m_per_s=answer.final_residuals_m_per_s)
        result['final_profile_state_sha256'] = state_hash()
        result['accepted_xold_heads_m'] = session.accepted_xold.tolist()
        result['final_xold_heads_m'] = session.xold.tolist()
        result['final_ledger_counts'] = counts()
        result['modflow_calls'] = kernel.calls
        result['trial_heads_m'] = getattr(runtime, 'last_trial_heads', [])
        result['final_storage_m3'], result['final_revisions'] = state()
        result['state'] = 'FIRST_WINDOW_PUBLISHED' if answer.published else 'FIRST_WINDOW_REJECTED'
        raw.finalize()
        initialized = False
        if answer.published:
            cbc = flopy.utils.CellBudgetFile(work / 'strip.cbc', precision='double')
            drain = float(sum(np.sum(v['q']) for v in cbc.get_data(text='DRN')))
            ds = sum(result['final_storage_m3']) - sum(result['origin_storage_m3'])
            result['drain_out_m3_per_day'] = -drain
            result['delta_swap_storage_m3'] = ds
            result['mass_residual_m3'] = ds - drain * 0.001
            assert abs(result['mass_residual_m3']) <= 1e-8
            assert result['final_revisions'] == [1] * 50
        else:
            assert result['origin_ledger_counts'] == result['final_ledger_counts'] == [0] * 50
            assert result['origin_profile_state_sha256'] == result['final_profile_state_sha256']
            assert np.array_equal(session.accepted_xold, session.xold)
            assert kernel.calls['finalize_time_step'] == 0
            assert result['origin_revisions'] == result['final_revisions']
            assert result['origin_storage_m3'] == result['final_storage_m3']
    except Exception:
        result['state'] = 'FIRST_WINDOW_EXCEPTION'
        result['exception'] = traceback.format_exc()
        result['final_storage_m3'], result['final_revisions'] = state()
    finally:
        if initialized:
            raw.finalize()
        (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(result['state'])


if __name__ == '__main__':
    main()
