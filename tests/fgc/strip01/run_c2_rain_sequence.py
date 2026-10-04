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
parser.add_argument('--profile', choices=['C0','C1'], default='C0')
parser.add_argument('--real-context', choices=['c2-rain','c2a'], default='c2-rain',
                    help='select Black-evaporation rain fixture or temporal-history C2A fixture with fixed-flux setter')
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[3])
parser.add_argument('--library', type=Path, required=True)
parser.add_argument('--libmf6', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--flux-tolerance', type=float, default=1e-15,
                    help='research-only groundwater/SWAP coupling residual tolerance (m/s)')
parser.add_argument('--max-coupling-iterations', type=int, default=40)
parser.add_argument('--probe-c2b-columns', action='store_true',
                    help='run exact-window discarded backend probes for all 50 C2B participants after C2a publication')
parser.add_argument('--probe-durations-day', nargs='+', type=float, default=[0.001],
                    help='durations for the discarded participant probe; requires --probe-c2b-columns')
parser.add_argument('--probe-rates-cm-per-day', nargs='+', type=float, default=[0.1],
                    help='fixed inward infiltration rates for discarded participant probes; requires --probe-c2b-columns')
parser.add_argument('--history-ramp-rates', nargs='+', type=float, default=None,
                    help='publish a multi-window history-aware real-SWAP ramp at these rates (cm/day) after C2a')
args = parser.parse_args()
if args.probe_c2b_columns and args.real_context != 'c2a':
    parser.error('--probe-c2b-columns requires --real-context c2a')
if not args.probe_c2b_columns and (args.probe_durations_day != [0.001] or args.probe_rates_cm_per_day != [0.1]):
    parser.error('probe sweep options require --probe-c2b-columns')
if any(not np.isfinite(dt) or dt <= 0 for dt in args.probe_durations_day):
    parser.error('--probe-durations-day values must be finite and positive')
if any(not np.isfinite(rate) or rate < 0 for rate in args.probe_rates_cm_per_day):
    parser.error('--probe-rates-cm-per-day values must be finite and nonnegative')
if args.history_ramp_rates is not None:
    if args.probe_c2b_columns:
        parser.error('--history-ramp-rates cannot be combined with discarded participant probes')
    if not args.history_ramp_rates or any(not np.isfinite(rate) or rate < 0 for rate in args.history_ramp_rates):
        parser.error('--history-ramp-rates must contain finite nonnegative rates')
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
                  experimental=True, canonical_admission=False, columns=50,
                  flux_tolerance_m_per_s=args.flux_tolerance,
                  max_coupling_iterations=args.max_coupling_iterations,
                  real_context=args.real_context,
                  column_probe=args.probe_c2b_columns,
                  experiment='F-GC-STRIP01-C2-RAIN01',
                  preregistration='integration/f-gc/strip01/F-GC-STRIP01_C2_RAIN01_PREREGISTRATION.json')
    bridge = ctypes.CDLL(str(lib.resolve()))
    init = bridge.fgc49d_fixture_initialize_c
    init.restype = ctypes.c_int
    init.argtypes = [ctypes.POINTER(ctypes.c_int64), ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double)]
    handle, h1, h2 = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
    status = init(ctypes.byref(handle), ctypes.byref(h1), ctypes.byref(h2))
    result['initialization_status'] = int(status)
    if status != 0:
        result['state'] = 'INITIALIZATION_FAIL'
        (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
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
    field_count = ((3 * 20 + 3) if args.real_context == 'c2a' else (2 * 20 + 4)) * 50
    def state_hash():
        values = (ctypes.c_double * field_count)()
        assert fields_fn(values) == 0
        return hashlib.sha256(struct.pack('<' + 'd' * field_count, *values)).hexdigest()

    set_rain = bridge.strip01_set_precipitation_c
    set_rain.restype = ctypes.c_int
    set_rain.argtypes = [ctypes.c_double]
    advance = bridge.fgc49d_fixture_advance_c
    advance.restype = ctypes.c_int
    advance.argtypes = init.argtypes
    result['profile'] = 'C1'
    result['windows'] = ['C2a-dynamic-equilibrium'] + (['C2-ramp'] * len(args.history_ramp_rates)
                           if args.history_ramp_rates is not None else ['C2b-rain'])
    result['profile_state_schema'] = 'per column: pressure heads, theta, pond, GWL, Black LDWET, committed time; little-endian float64'
    result['profile_state_float_count'] = field_count
    result['origin_profile_state_sha256'] = state_hash()
    result['origin_ledger_counts'] = counts()
    result['origin_storage_m3'], result['origin_revisions'] = state()

    runtime = DomainRuntime(lib, handle.value)
    sim = flopy.mf6.MFSimulation(sim_name='realstrip01c2rain', sim_ws=str(work))
    nper = 1 + len(args.history_ramp_rates) if args.history_ramp_rates is not None else 2
    flopy.mf6.ModflowTdis(sim, time_units='DAYS', nper=nper,
                          perioddata=[(0.001, 1, 1)] * nper)
    flopy.mf6.ModflowIms(sim, outer_dvclose=1e-10, inner_dvclose=1e-11,
                       outer_maximum=200, inner_maximum=300, rcloserecord=1e-11)
    gwf = flopy.mf6.ModflowGwf(sim, modelname='STRIP', save_flows=True)
    plane, stage = -2, -1
    flopy.mf6.ModflowGwfdis(gwf, nlay=1, nrow=1, ncol=50, delr=1, delc=1, top=plane, botm=-10)
    initial_heads = np.full((1, 1, 50), float(stage))
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
        session_a = Modflow6PreparedSolveSession(kernel, 'STRIP', 'API_SWAP', Fgc34CtypesPublisher(lib), solution_id=1)
        a = run_groundwater_application_window(runtime, session_a,
            GroundwaterApplicationServiceConfig(flux_tolerance_m_per_s=args.flux_tolerance,
                                                max_coupling_iterations=args.max_coupling_iterations))
        result['C2a'] = dict(status=int(a.status), published=a.published, failure_stage=a.failure_stage,
            iterations=a.iterations, request_smaller_window=a.request_smaller_window,
            heads_m=a.final_heads_m, residuals_m_per_s=a.final_residuals_m_per_s,
            profile_state_sha256=state_hash(), storage_m3=None, revisions=None, ledger_counts=counts(),
            modflow_calls=dict(kernel.calls))
        result['C2a']['storage_m3'], result['C2a']['revisions'] = state()
        print(f"C2A published={a.published} failure={a.failure_stage} revisions={result['C2a']['revisions'][0]}", flush=True)

        if a.published and args.history_ramp_rates is not None:
            result['history_ramp'] = []
            cumulative_input = cumulative_swap_storage = cumulative_drain = 0.0
            for index, rate in enumerate(args.history_ramp_rates):
                before_hash = state_hash()
                before_storage, before_revisions = state()
                before_ledgers = counts()
                if set_rain(rate) != 0:
                    raise RuntimeError(f'fixture rejected history-ramp rate {rate} cm/day')
                next_handle, next_h1, next_h2 = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
                advance_status = int(advance(ctypes.byref(next_handle), ctypes.byref(next_h1), ctypes.byref(next_h2)))
                entry = dict(index=index, rate_cm_per_day=rate, t0_day=(index + 1) * 0.001,
                             duration_day=0.001, advance_context_status=advance_status,
                             before_profile_state_sha256=before_hash, before_revisions=before_revisions,
                             before_ledger_counts=before_ledgers)
                if advance_status != 0:
                    entry.update(published=False, failure_stage='context-advance')
                    result['history_ramp'].append(entry)
                    break
                runtime = DomainRuntime(lib, next_handle.value)
                raw.prepare_time_step((index + 1) * 0.001)
                session = Modflow6PreparedSolveSession(kernel, 'STRIP', 'API_SWAP',
                    Fgc34CtypesPublisher(lib), solution_id=1)
                window = run_groundwater_application_window(runtime, session,
                    GroundwaterApplicationServiceConfig(flux_tolerance_m_per_s=args.flux_tolerance,
                                                        max_coupling_iterations=args.max_coupling_iterations))
                after_storage, after_revisions = state()
                entry.update(status=int(window.status), published=window.published,
                    failure_stage=window.failure_stage, iterations=window.iterations,
                    heads_m=window.final_heads_m, residuals_m_per_s=window.final_residuals_m_per_s,
                    after_profile_state_sha256=state_hash(), after_storage_m3=after_storage,
                    after_revisions=after_revisions, after_ledger_counts=counts(),
                    modflow_calls=dict(kernel.calls))
                if not window.published:
                    entry['rollback_verified'] = (entry['after_profile_state_sha256'] == before_hash and
                        after_storage == before_storage and after_revisions == before_revisions and
                        entry['after_ledger_counts'] == before_ledgers)
                    result['history_ramp'].append(entry)
                    break
                rain_input = rate * 0.01 * 50.0 * 0.001
                delta_swap = sum(after_storage) - sum(before_storage)
                cbc = flopy.utils.CellBudgetFile(work / 'strip.cbc', precision='double')
                drain_rate = -float(sum(np.sum(v['q']) for v in cbc.get_data(text='DRN', kstpkper=(0, index + 1))))
                drain_volume = drain_rate * 0.001
                residual = rain_input - delta_swap - drain_volume
                cumulative_input += rain_input
                cumulative_swap_storage += delta_swap
                cumulative_drain += drain_volume
                entry.update(rain_input_m3=rain_input, delta_swap_storage_m3=delta_swap,
                    drain_outflow_m3=drain_volume, modflow_storage_change_m3=0.0,
                    other_external_boundary_m3=0.0, mass_residual_m3=residual,
                    mass_absolute_residual_m3=abs(residual),
                    mass_relative_residual=(residual / rain_input if rain_input else 0.0),
                    cumulative_input_m3=cumulative_input,
                    cumulative_swap_storage_change_m3=cumulative_swap_storage,
                    cumulative_drain_outflow_m3=cumulative_drain,
                    cumulative_mass_residual_m3=cumulative_input-cumulative_swap_storage-cumulative_drain,
                    cumulative_mass_absolute_residual_m3=abs(cumulative_input-cumulative_swap_storage-cumulative_drain),
                    cumulative_mass_relative_residual=((cumulative_input-cumulative_swap_storage-cumulative_drain) /
                                                       cumulative_input if cumulative_input else 0.0))
                result['history_ramp'].append(entry)
            result['state'] = ('C2A_AND_HISTORY_RAMP_PUBLISHED' if len(result['history_ramp']) == len(args.history_ramp_rates)
                               and all(x.get('published') for x in result['history_ramp'])
                               else 'C2A_PUBLISHED_HISTORY_RAMP_REJECTED')
        elif a.published:
            if set_rain(0.1) != 0:
                raise RuntimeError('fixture rejected preregistered 0.1 cm/day precipitation update')
            print('C2A forcing update accepted', flush=True)
            if args.probe_c2b_columns:
                probe = bridge.strip01_diagnose_window_c
                probe.restype = ctypes.c_int
                probe.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_int,
                                  ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_double),
                                  ctypes.POINTER(ctypes.c_double)]
                before = dict(profile_state_sha256=state_hash(), storage_m3=state()[0], revisions=state()[1],
                              ledger_counts=counts())
                rows = []
                for rate in args.probe_rates_cm_per_day:
                    if set_rain(rate) != 0:
                        raise RuntimeError(f'fixture rejected diagnostic infiltration rate {rate} cm/day')
                    for duration in args.probe_durations_day:
                        for slot in range(1, 51):
                            codes, values, completed = (ctypes.c_int * 12)(), (ctypes.c_double * 6)(), ctypes.c_double()
                            probe_status = int(probe(slot, -1.0, 0.001, duration, 0,
                                                     codes, values, ctypes.byref(completed)))
                            rows.append(dict(rate_cm_per_day=rate, duration_day=duration, slot=slot,
                                             call_status=probe_status, codes=list(codes),
                                             observations=list(values), completed_t_day=completed.value))
                if set_rain(0.1) != 0:
                    raise RuntimeError('fixture rejected restoration of C2b 0.1 cm/day forcing')
                after = dict(profile_state_sha256=state_hash(), storage_m3=state()[0], revisions=state()[1],
                             ledger_counts=counts())
                result['C2b_column_probes'] = dict(
                    state_origin='after C2a commit; before C2b native application window',
                    head_m=-1.0, t0_day=0.001, durations_day=args.probe_durations_day,
                    top_infiltration_rates_cm_per_day=args.probe_rates_cm_per_day,
                    tangent_requested=False,
                    code_columns=['result_status', 'accepted_substeps', 'solver_rejections',
                                  'temporal_rejections', 'mass_rejections', 'admission_rejections',
                                  'attempts', 'retries', 'solver_status', 'temporal_status',
                                  'temporal_available', 'head_budget_valid'],
                    observation_columns=['temporal_head_inf_bound_cm', 'temporal_head_budget_cm',
                                         'normalized_temporal_indicator', 'top_flux_cm_per_day',
                                         'bottom_flux_cm_per_day', 'solver_equation_residual'],
                    rows=rows, immutable_origin_before=before,
                    immutable_origin_after=after, committed_origin_unchanged=before == after)
                assert len(rows) == (50 * len(args.probe_durations_day) * len(args.probe_rates_cm_per_day))
                assert all(row['call_status'] == 0 for row in rows)
                assert result['C2b_column_probes']['committed_origin_unchanged']
                print('C2b discarded participant probes completed for 50 columns', flush=True)
            next_handle, next_h1, next_h2 = ctypes.c_int64(), ctypes.c_double(), ctypes.c_double()
            result['advance_context_status'] = int(advance(ctypes.byref(next_handle), ctypes.byref(next_h1), ctypes.byref(next_h2)))
            print(f"C2A next-context status={result['advance_context_status']}", flush=True)
            assert result['advance_context_status'] == 0
            runtime = DomainRuntime(lib, next_handle.value)
            raw.prepare_time_step(0.001)
            session_b = Modflow6PreparedSolveSession(kernel, 'STRIP', 'API_SWAP', Fgc34CtypesPublisher(lib), solution_id=1)
            b = run_groundwater_application_window(runtime, session_b,
                GroundwaterApplicationServiceConfig(flux_tolerance_m_per_s=args.flux_tolerance,
                                                    max_coupling_iterations=args.max_coupling_iterations))
            result['C2b'] = dict(status=int(b.status), published=b.published, failure_stage=b.failure_stage,
                iterations=b.iterations, request_smaller_window=b.request_smaller_window,
                heads_m=b.final_heads_m, residuals_m_per_s=b.final_residuals_m_per_s,
                trial_heads_m=getattr(runtime, 'last_trial_heads', []),
                profile_state_sha256=state_hash(), storage_m3=None, revisions=None, ledger_counts=counts(),
                accepted_xold_heads_m=session_b.accepted_xold.tolist(),
                final_xold_heads_m=session_b.xold.tolist(), modflow_calls=dict(kernel.calls))
            result['C2b']['storage_m3'], result['C2b']['revisions'] = state()
            result['state'] = 'C2A_AND_C2B_PUBLISHED' if b.published else 'C2A_PUBLISHED_C2B_REJECTED'
            if b.published:
                cbc = flopy.utils.CellBudgetFile(work / 'strip.cbc', precision='double')
                drain = float(sum(np.sum(v['q']) for v in cbc.get_data(text='DRN', kstpkper=(0, 1))))
                delta_storage = sum(result['C2b']['storage_m3']) - sum(result['C2a']['storage_m3'])
                drain_out = -drain
                result['C2b']['drain_out_m3_per_day'] = drain_out
                result['C2b']['delta_swap_storage_m3'] = delta_storage
                result['C2b']['rain_input_m3'] = 0.001 * 50.0 * 0.001
                result['C2b']['whole_domain_mass_tolerance_m3'] = 1e-8
                result['C2b']['mass_residual_m3'] = delta_storage - (
                    result['C2b']['rain_input_m3'] - drain_out * 0.001)
                assert abs(result['C2b']['mass_residual_m3']) <= result['C2b']['whole_domain_mass_tolerance_m3']
                assert result['C2b']['revisions'] == [2] * 50
            else:
                assert result['C2a']['profile_state_sha256'] == result['C2b']['profile_state_sha256']
                assert result['C2a']['revisions'] == result['C2b']['revisions'] == [1] * 50
                assert result['C2a']['ledger_counts'] == result['C2b']['ledger_counts'] == [1] * 50
                assert result['C2b']['accepted_xold_heads_m'] == result['C2b']['final_xold_heads_m']
        else:
            result['state'] = 'C2A_REJECTED'
            result['C2a']['profile_state_sha256'] = state_hash()
            result['C2a']['storage_m3'], result['C2a']['revisions'] = state()
            assert result['origin_profile_state_sha256'] == result['C2a']['profile_state_sha256']
            assert result['origin_revisions'] == result['C2a']['revisions']
            assert result['origin_ledger_counts'] == result['C2a']['ledger_counts'] == [0] * 50
            assert np.array_equal(session_a.accepted_xold, session_a.xold)

        result['final_profile_state_sha256'] = state_hash()
        result['final_ledger_counts'] = counts()
        result['final_storage_m3'], result['final_revisions'] = state()
        result['modflow_calls'] = dict(kernel.calls)
        raw.finalize()
        initialized = False
    except Exception:
        result['state'] = 'EXCEPTION'
        result['exception'] = traceback.format_exc()
        result['final_profile_state_sha256'] = state_hash()
        result['final_ledger_counts'] = counts()
        result['final_storage_m3'], result['final_revisions'] = state()
    finally:
        if initialized:
            raw.finalize()
        (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(result['state'])


if __name__ == '__main__':
    main()
