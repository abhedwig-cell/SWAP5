"""Native-registry C2E Dummy-SWAP / MODFLOW6 research strip."""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import sys

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "src/adapter"))
from fmr_groundwater_application_runtime import FmrGroundwaterApplicationRuntime  # noqa: E402
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher  # noqa: E402
from modflow6_groundwater_application_service import (  # noqa: E402
    GroundwaterApplicationServiceConfig,
    run_groundwater_application_window,
)
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession  # noqa: E402

N = 50
DAY_S = 86400.0
S_DUMMY = 0.05
S_AQUIFER = 0.2
KX = 0.5
DRAIN_C = 100.0
H0 = -1.0
FLUX_TOL = 1.0e-10


class CountingKernel:
    def __init__(self, kernel):
        self.kernel = kernel
        self.calls = dict(prepare_solve=0, solve=0, finalize_solve=0, finalize_time_step=0)

    def __getattr__(self, name):
        return getattr(self.kernel, name)

    def prepare_solve(self, solution_id):
        self.calls["prepare_solve"] += 1
        return self.kernel.prepare_solve(solution_id)

    def solve(self, solution_id):
        self.calls["solve"] += 1
        return self.kernel.solve(solution_id)

    def finalize_solve(self, solution_id):
        self.calls["finalize_solve"] += 1
        return self.kernel.finalize_solve(solution_id)

    def finalize_time_step(self):
        self.calls["finalize_time_step"] += 1
        return self.kernel.finalize_time_step()


class TrackingNativeRuntime(FmrGroundwaterApplicationRuntime):
    def trial_cell_heads(self, heads):
        response = super().trial_cell_heads(heads)
        if response.valid:
            self.last_trial_heads = tuple(float(v) for v in heads)
            self.last_q = response.cell_q_swap_m_per_s
            self.last_tangent = response.cell_dq_swap_dh_per_s
        return response


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def configure_fixture(lib, initial_heads):
    begin = lib.fgc49d_c2e_begin_c
    begin.restype = ctypes.c_int
    begin.argtypes = [ctypes.c_int, ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double,
                      ctypes.POINTER(ctypes.c_double), ctypes.c_int, ctypes.POINTER(ctypes.c_int64)]
    state = lib.fgc49d_c2e_state_c
    state.restype = ctypes.c_int
    state.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_int),
                      ctypes.POINTER(ctypes.c_int)]

    def create(index, t0, t1, recharge, conductance, reject_slot=0):
        mf = (ctypes.c_double * N)(*map(float, initial_heads))
        handle = ctypes.c_int64()
        status = int(begin(index, t0, t1, recharge, conductance, mf, reject_slot, ctypes.byref(handle)))
        if status != 0:
            raise RuntimeError(f"native C2E context construction failed: status={status}, index={index}")
        return int(handle.value)

    def export(index):
        heads = (ctypes.c_double * N)()
        revisions = (ctypes.c_int * N)()
        ledgers = (ctypes.c_int * N)()
        status = int(state(index, heads, revisions, ledgers))
        if status != 0:
            raise RuntimeError(f"native C2E state export failed: status={status}, index={index}")
        return list(heads), list(revisions), list(ledgers)

    return create, export


def run(lib_path: Path, mf6_path: Path, out: Path, mode: str, conductance: float,
        flux_tolerance: float, rejection_control: bool) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    if mode == "zero":
        dts, rain = [0.25] * 4, [0.0] * 4
    elif mode == "c2b-match":
        # Mirror C2B's native 2-period hydrostatic-then-rain window exactly:
        # 0.001-day equilibrium, then 0.1 cm/day (=0.001 m/day) infiltration.
        dts, rain = [0.001, 0.001], [0.0, 0.001]
    else:
        dts, rain = [0.25] * 80 + [0.25] * 40, [0.001] * 80 + [0.0] * 40

    bridge = ctypes.CDLL(str(lib_path))
    accepted_head = np.full(N, H0, dtype=float)
    dummy_head = [H0] * N
    revisions, ledger_counts = [0] * N, [0] * N
    create, export = configure_fixture(bridge, accepted_head)
    rows = []
    c2e_index = 0

    # Fault the native registry before any MODFLOW state is initialized. The
    # rejected participant and all preceding candidates must remain uncommitted.
    rejection_record = None
    if rejection_control:
        c2e_index += 1
        rejected_handle = create(c2e_index, 0.0, dts[0], rain[0], conductance, reject_slot=25)
        rejected = TrackingNativeRuntime(lib_path, rejected_handle)
        assert rejected.capture_origins()
        trial = rejected.trial_cell_heads(accepted_head.tolist())
        if trial.valid:
            raise AssertionError("injected participant rejection unexpectedly produced a valid trial")
        if not rejected.abort_prepublication():
            raise AssertionError("native registry did not discard/abandon all rejected candidates")
        rejected.release()
        check_heads, check_revisions, check_ledgers = export(c2e_index)
        if check_heads != dummy_head or check_revisions != revisions or check_ledgers != ledger_counts:
            raise AssertionError("rejected C2E trial changed committed dummy state, revision or ledger")
        rejection_record = dict(
            rejected_participant=25,
            trial_valid=False,
            dummy_state_unchanged=True,
            revisions_unchanged=True,
            ledgers_unchanged=True,
            modflow_initialized=False,
            modflow_finalize_calls=0,
            retry_origin_time_day=0.0,
        )

    sim = flopy.mf6.MFSimulation(sim_name="strip01c2enative", sim_ws=str(out), exe_name=str(mf6_path))
    flopy.mf6.ModflowTdis(sim, time_units="DAYS", nper=len(dts),
                          perioddata=[(dt, 1, 1) for dt in dts])
    flopy.mf6.ModflowIms(sim, outer_dvclose=1e-10, inner_dvclose=1e-11,
                         outer_maximum=200, inner_maximum=300,
                         rcloserecord=1e-11, linear_acceleration="BICGSTAB")
    gwf = flopy.mf6.ModflowGwf(sim, modelname="STRIP", save_flows=True)
    flopy.mf6.ModflowGwfdis(gwf, nlay=1, nrow=1, ncol=N, delr=1.0, delc=1.0,
                           top=-2.0, botm=-10.0, idomain=1)
    flopy.mf6.ModflowGwfic(gwf, strt=H0)
    flopy.mf6.ModflowGwfnpf(gwf, icelltype=0, k=KX, save_flows=True)
    flopy.mf6.ModflowGwfsto(gwf, iconvert=0, ss=S_AQUIFER / 8.0, sy=0.0,
                            transient={k: True for k in range(len(dts))})
    flopy.mf6.ModflowGwfdrn(gwf, stress_period_data={0: [((0, 0, 0), H0, DRAIN_C)]}, pname="DRN_LEFT")
    flopy.mf6.ModflowGwfapi(gwf, maxbound=N, pname="API_SWAP")
    flopy.mf6.ModflowGwfoc(gwf, head_filerecord="strip.hds", budget_filerecord="strip.cbc",
                          saverecord=[("HEAD", "ALL"), ("BUDGET", "ALL")])
    sim.write_simulation(silent=True)

    raw = XmiWrapper(lib_path=mf6_path.resolve(), working_directory=out.resolve())
    kernel = CountingKernel(raw)
    rows = []
    cumulative_input = cumulative_dummy = cumulative_mf = cumulative_drain = 0.0
    current_time = 0.0
    initialized = False
    try:
        raw.initialize()
        initialized = True
        version = raw.get_version()
        if "6.8.0" not in version:
            raise RuntimeError(f"expected MODFLOW6 6.8.0, got {version}")
        raw.prepare_time_step(current_time)

        for j, (dt, recharge) in enumerate(zip(dts, rain, strict=True)):
            c2e_index += 1
            handle = create(c2e_index, current_time, current_time + dt, recharge, conductance)
            runtime = TrackingNativeRuntime(lib_path, handle)
            session = Modflow6PreparedSolveSession(kernel, "STRIP", "API_SWAP",
                Fgc34CtypesPublisher(lib_path), solution_id=1)
            acquire = session.acquire_after_prepare_time_step()
            if acquire.name != "OK":
                raise RuntimeError(f"MODFLOW package acquisition failed: {session.last_error}")
            answer = run_groundwater_application_window(runtime, session,
                GroundwaterApplicationServiceConfig(flux_tolerance_m_per_s=flux_tolerance, max_coupling_iterations=80))
            if not answer.published:
                runtime.abort_prepublication()
                runtime.release()
                check_heads, check_revisions, check_ledgers = export(c2e_index)
                rows.append(dict(step=j, published=False, stage=answer.failure_stage,
                    iterations=answer.iterations, heads_m=list(answer.final_heads_m),
                    residuals_m_per_s=list(answer.final_residuals_m_per_s),
                    dummy_heads_after_m=check_heads, revisions_after=check_revisions, ledgers_after=check_ledgers,
                    modflow_calls=dict(kernel.calls)))
                break

            heads = np.asarray(answer.final_heads_m, dtype=float)
            old_dummy = list(dummy_head)
            old_mf = accepted_head.copy()
            dummy_head, revisions, ledger_counts = export(c2e_index)
            runtime.release()
            q = np.asarray(runtime.last_q, dtype=float)
            dummy_storage_change = S_DUMMY * sum(n - o for n, o in zip(dummy_head, old_dummy, strict=True))
            mf_storage_change = S_AQUIFER * float(np.sum(heads - old_mf))
            input_volume = recharge * N * dt
            transfer = float(np.sum(q)) * DAY_S * dt
            lateral = [KX * 8.0 * float(heads[i] - heads[i + 1]) for i in range(N - 1)]
            row = dict(step=j, time_day=current_time + dt, dt_day=dt, recharge_m_per_day=recharge,
                published=True, coupling_iterations=answer.iterations, modflow_converged=True,
                max_abs_coupling_residual_m_per_s=max(map(abs, answer.final_residuals_m_per_s)),
                head_m=heads.tolist(), dummy_internal_head_m=dummy_head,
                interface_flux_m3_per_day=q.tolist(), interface_transfer_m3=transfer,
                dummy_storage_change_m3=dummy_storage_change, modflow_storage_change_m3=mf_storage_change,
                input_m3=input_volume, lateral_face_flow_m3_per_day=lateral,
                revisions_min=min(revisions), revisions_max=max(revisions),
                ledgers_min=min(ledger_counts), ledgers_max=max(ledger_counts),
                modflow_calls=dict(kernel.calls))
            row["resistance_law_max_abs_error_m3_per_day"] = max(
                abs(q[i] * DAY_S - conductance * (dummy_head[i] - heads[i])) for i in range(N))
            row["action_reaction_residual_m3"] = 0.0
            row["dummy_interface_out_m3"] = transfer
            row["modflow_interface_in_m3"] = transfer
            row["dummy_component_residual_m3"] = input_volume - dummy_storage_change - transfer
            row["modflow_component_residual_m3"] = transfer - mf_storage_change
            rows.append(row)
            cumulative_input += input_volume
            cumulative_dummy += dummy_storage_change
            cumulative_mf += mf_storage_change
            cumulative_drain += 0.0
            row["cumulative_pre_native_budget"] = dict(input_m3=cumulative_input,
                dummy_storage_change_m3=cumulative_dummy, modflow_storage_change_m3=cumulative_mf,
                drain_outflow_m3=cumulative_drain,
                residual_m3=cumulative_input-cumulative_dummy-cumulative_mf-cumulative_drain)
            accepted_head = heads.copy()
            current_time += dt
            if j + 1 < len(dts):
                raw.prepare_time_step(current_time)
        raw.finalize()
        initialized = False
    finally:
        if initialized:
            raw.finalize()

    if not rows or not all(r["published"] for r in rows):
        result = dict(schema="swap5.fgc.strip01.c2e.native.result.v1", state="NATIVE_DUMMY_RUN_REJECTED",
            mode=mode, conductance_m2_per_day=conductance, rows=rows, rejection_control=rejection_record,
            modflow_version=version, modflow_binary_sha256=sha(mf6_path),
            registry_fixture_library_sha256=sha(lib_path))
        (out / "result.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
        return result

    cbc = flopy.utils.CellBudgetFile(str(out / "strip.cbc"), precision="double")
    grb = flopy.mf6.utils.MfGrdFile(str(out / "STRIP.dis.grb"))
    native_times = cbc.get_times()
    if len(native_times) != len(rows):
        raise RuntimeError(f"native budget contains {len(native_times)} periods for {len(rows)} results")
    cumulative_input = cumulative_dummy = cumulative_mf = cumulative_drain = 0.0
    for j, (row, totim) in enumerate(zip(rows, native_times, strict=True)):
        api = cbc.get_data(text="API", totim=totim)
        storage = cbc.get_data(text="STO-SS", totim=totim)
        if not api or len(api[0]) != N or not storage:
            raise RuntimeError(f"native API/storage budget unavailable at window {j}")
        api_rates = np.asarray(api[0]["q"], dtype=float)
        api_transfer = float(np.sum(api_rates)) * row["dt_day"]
        native_storage_rate = -float(np.sum(np.asarray(storage[0], dtype=float)))
        row["native_api_source_m3_per_day"] = api_rates.tolist()
        row["native_api_transfer_m3"] = api_transfer
        row["max_abs_action_reaction_rate_error_m3_per_day"] = max(
            abs(api_rates[i] - row["interface_flux_m3_per_day"][i] * DAY_S) for i in range(N))
        row["action_reaction_residual_m3"] = api_transfer - row["dummy_interface_out_m3"]
        row["head_derived_modflow_storage_change_m3"] = row["modflow_storage_change_m3"]
        row["native_modflow_storage_rate_m3_per_day"] = native_storage_rate
        row["native_modflow_storage_change_m3"] = native_storage_rate * row["dt_day"]
        row["modflow_storage_change_m3"] = row["native_modflow_storage_change_m3"]
        row["native_storage_vs_head_change_error_m3"] = row["native_modflow_storage_change_m3"] - \
            row["head_derived_modflow_storage_change_m3"]
        drn = cbc.get_data(text="DRN", totim=totim)
        drain_rate = -float(np.sum(drn[0]["q"])) if drn and len(drn[0]) else 0.0
        fjf = np.asarray(cbc.get_data(text="FLOW-JA-FACE", totim=totim)[0]).reshape(-1)
        lateral = []
        for i in range(N - 1):
            start, end = int(grb.ia[i]), int(grb.ia[i + 1])
            slot = next((k for k in range(start, end) if int(grb.ja[k]) == i + 1), None)
            if slot is None:
                raise RuntimeError(f"MODFLOW cell {i + 1} lacks its right face")
            lateral.append(float(fjf[slot]))
        row["native_modflow_drain_m3_per_day"] = drain_rate
        row["drain_outflow_m3"] = drain_rate * row["dt_day"]
        row["lateral_face_flow_m3_per_day"] = lateral
        row["mass_residual_m3"] = row["input_m3"] - row["dummy_storage_change_m3"] - \
            row["modflow_storage_change_m3"] - row["drain_outflow_m3"]
        scale = max(abs(row["input_m3"]), abs(row["dummy_storage_change_m3"]),
                    abs(row["modflow_storage_change_m3"]), abs(row["drain_outflow_m3"]), 1e-30)
        row["mass_relative_residual"] = abs(row["mass_residual_m3"]) / scale
        row["modflow_interface_in_m3"] = api_transfer
        row["modflow_component_residual_m3"] = row["modflow_interface_in_m3"] - \
            row["modflow_storage_change_m3"] - row["drain_outflow_m3"]
        cumulative_input += row["input_m3"]
        cumulative_dummy += row["dummy_storage_change_m3"]
        cumulative_mf += row["modflow_storage_change_m3"]
        cumulative_drain += row["drain_outflow_m3"]
        cumulative_residual = cumulative_input - cumulative_dummy - cumulative_mf - cumulative_drain
        row["cumulative"] = dict(input_m3=cumulative_input, dummy_storage_change_m3=cumulative_dummy,
            modflow_storage_change_m3=cumulative_mf, drain_outflow_m3=cumulative_drain,
            residual_m3=cumulative_residual,
            relative_residual=abs(cumulative_residual) / max(cumulative_input, 1e-30))

    result = dict(schema="swap5.fgc.strip01.c2e.native.result.v1", state="NATIVE_DUMMY_RUN_COMPLETED",
        mode=mode, source_commit=__import__("subprocess").check_output(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip(),
        modflow_version=version, modflow_binary_sha256=sha(mf6_path),
        registry_fixture_library_sha256=sha(lib_path),
        geometry=dict(ncol=N, dx_m=1.0, nlay=1, top_m=-2.0, bottom_m=-10.0, kx_m_per_day=KX),
        ownership=dict(dummy_storage_m_per_m=S_DUMMY, modflow_storage_m_per_m=S_AQUIFER,
            conductance_m2_per_day=conductance, drain_owner="MODFLOW_DRN_LEFT", interface_internal=True),
        flux_tolerance_m_per_s=flux_tolerance, rejection_control=rejection_record,
        rows=rows, native_modflow_cbc_validated=True, fresh_process_replay=False,
        windows_published=sum(bool(r["published"]) for r in rows),
        maximum_absolute_window_residual_m3=max(abs(r["mass_residual_m3"]) for r in rows),
        cumulative_mass_residual_m3=rows[-1]["cumulative"]["residual_m3"],
        cumulative_relative_mass_residual=rows[-1]["cumulative"]["relative_residual"])
    result["maximum_action_reaction_rate_error_m3_per_day"] = max(
        r["max_abs_action_reaction_rate_error_m3_per_day"] for r in rows)
    result["maximum_absolute_action_reaction_residual_m3"] = max(
        abs(r["action_reaction_residual_m3"]) for r in rows)
    result["maximum_native_storage_vs_head_change_error_m3"] = max(
        abs(r["native_storage_vs_head_change_error_m3"]) for r in rows)
    if result["maximum_action_reaction_rate_error_m3_per_day"] > 1.0e-9:
        raise RuntimeError("native MODFLOW API budget does not match dummy action/reaction flux")
    if result["maximum_absolute_window_residual_m3"] > 1.0e-9 or \
            abs(result["cumulative_mass_residual_m3"]) > 1.0e-9:
        raise RuntimeError("complete-domain native budget mass closure exceeds 1e-9 m3")
    if result["maximum_native_storage_vs_head_change_error_m3"] > 1.0e-9:
        raise RuntimeError("native MODFLOW storage budget disagrees with head-derived storage change")
    (out / "result.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--library", type=Path, required=True)
    parser.add_argument("--libmf6", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=["zero", "pulse", "c2b-match"], default="zero")
    parser.add_argument("--conductance", type=float, default=1.0e6)
    parser.add_argument("--flux-tolerance", type=float, default=FLUX_TOL)
    parser.add_argument("--rejection-control", action="store_true")
    args = parser.parse_args()
    result = run(args.library.resolve(), args.libmf6.resolve(), args.output.resolve(), args.mode,
                 args.conductance, args.flux_tolerance, args.rejection_control)
    print(result["state"])


if __name__ == "__main__":
    main()
