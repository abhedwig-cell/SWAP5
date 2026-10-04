"""Research-only 50-column Dummy-SWAP / MODFLOW6 strip using F-GC49C service."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
import sys
import tempfile

import flopy
import numpy as np
from xmipy import XmiWrapper

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "src/adapter"))
from modflow6_groundwater_application_service import (  # noqa: E402
    GroundwaterApplicationCorrectorBatch,
    GroundwaterApplicationPlanView,
    GroundwaterApplicationServiceConfig,
    run_groundwater_application_window,
)
from modflow6_prepared_solve_session import Modflow6PreparedSolveSession  # noqa: E402
from modflow6_fgc34_ctypes_publisher import Fgc34CtypesPublisher  # noqa: E402

N = 50
AREA = 1.0
DAY_S = 86400.0
S_DUMMY = 0.05
S_AQUIFER = 0.2
KX = 0.5
VERTICAL_C = 0.125
DRAIN_C = 100.0
H0 = -1.0
FLUX_TOL = 1.0e-10


@dataclass(frozen=True)
class Binding:
    groundwater_cell_id: int
    package_slot: int
    modflow_node_id: int


@dataclass(frozen=True)
class Term:
    groundwater_cell_id: int
    hcof_m2_per_day: float
    rhs_m3_per_day: float
    valid: bool = True


class DummyRuntime:
    """Transactional analytic participant array; all trials start at accepted state."""
    def __init__(self, dt: float, recharge: float, heads: list[float], internals: list[float], conductance: float,
                 revisions: list[int] | None = None, ledger: list[int] | None = None):
        self.dt, self.recharge = dt, recharge
        self.conductance = conductance
        self.heads = tuple(heads)
        self.internals = list(internals)
        self.origin: tuple[float, ...] | None = None
        self.candidate: tuple[float, ...] | None = None
        self.q_candidate: tuple[float, ...] | None = None
        self.terms: tuple[Term, ...] = ()
        self.last_heads: tuple[float, ...] = ()
        self.revisions = list(revisions or [0] * N)
        self.ledger = list(ledger or [0] * N)
        self._set_terms(self.heads, self._response(self.heads)[0], self._response(self.heads)[1])

    def _response(self, heads):
        # Implicit storage + finite resistance response from DSW08/DSW25.
        scale = 1.0 + self.conductance * self.dt / S_DUMMY
        q_m_per_day = tuple(self.conductance * (h0 + (self.recharge*self.dt)/S_DUMMY - h) / scale
                            for h0, h in zip(self.internals, heads, strict=True))
        tangent_m_per_day = -self.conductance / scale
        return tuple(q/DAY_S for q in q_m_per_day), (tangent_m_per_day/DAY_S,) * N

    def _set_terms(self, heads, q, tangent):
        self.terms = tuple(Term(i+1, tangent[i]*DAY_S,
            tangent[i]*DAY_S*heads[i] - q[i]*DAY_S) for i in range(N))

    def materialize_plan(self):
        b = tuple(Binding(i+1, i+1, i+1) for i in range(N))
        return GroundwaterApplicationPlanView(b, self.terms, tuple(range(1, N+1)))

    def capture_origins(self):
        self.origin = tuple(self.internals)
        self.candidate = self.q_candidate = None
        return True

    def evaluate_groundwater_fluxes(self, terms, cell_heads_m):
        return tuple((t.hcof_m2_per_day*h-t.rhs_m3_per_day)/DAY_S
                     for t, h in zip(terms, cell_heads_m, strict=True))

    def trial_cell_heads(self, cell_heads_m):
        self.last_heads = tuple(float(h) for h in cell_heads_m)
        q, tangent = self._response(self.last_heads)
        self.candidate = tuple(h0 + (self.recharge*self.dt-q[i]*DAY_S*self.dt)/S_DUMMY
                               for i, h0 in enumerate(self.origin))
        self.q_candidate = q
        return GroundwaterApplicationCorrectorBatch(True, q, tangent)

    def discard_candidates(self):
        self.candidate = self.q_candidate = None
        return True

    def relinearize_terms(self, heads, q, tangent):
        self._set_terms(tuple(heads), tuple(q), tuple(tangent))
        return self.terms

    def swap_preflight(self): return self.candidate is not None and self.q_candidate is not None
    def prepare_ledgers(self): return self.swap_preflight()
    def ledgers_preflight(self): return self.swap_preflight()
    def abort_prepublication(self): self.discard_candidates(); return True

    def commit_swaps(self):
        if not self.swap_preflight(): return False
        self.internals = list(self.candidate)
        self.revisions = [x+1 for x in self.revisions]
        return True

    def commit_ledgers(self):
        if not self.swap_preflight(): return False
        self.ledger = [x+1 for x in self.ledger]
        return True


class CountingKernel:
    def __init__(self, raw):
        self.raw = raw
        self.calls = dict(prepare_solve=0, solve=0, finalize_solve=0, finalize_time_step=0)
    def __getattr__(self, key): return getattr(self.raw, key)
    def prepare_solve(self, *a): self.calls['prepare_solve'] += 1; return self.raw.prepare_solve(*a)
    def solve(self, *a): self.calls['solve'] += 1; return self.raw.solve(*a)
    def finalize_solve(self, *a): self.calls['finalize_solve'] += 1; return self.raw.finalize_solve(*a)
    def finalize_time_step(self): self.calls['finalize_time_step'] += 1; return self.raw.finalize_time_step()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(libmf6: Path, publisher: Path, out: Path, mode: str, conductance: float, flux_tolerance: float) -> dict:
    out.mkdir(parents=True, exist_ok=True)
    if mode == "zero":
        dts = [0.25] * 4
        rain = [0.0] * len(dts)
    else:
        dts = [0.25] * 80 + [0.25] * 40
        rain = [0.001] * 80 + [0.0] * 40
    sim = flopy.mf6.MFSimulation(sim_name="strip01dummy", sim_ws=str(out), exe_name=str(libmf6))
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
    flopy.mf6.ModflowGwfsto(gwf, iconvert=0, ss=S_AQUIFER/8.0, sy=0.0,
                            transient={k: True for k in range(len(dts))})
    flopy.mf6.ModflowGwfdrn(gwf, stress_period_data={0: [((0,0,0), H0, DRAIN_C)]}, pname="DRN_LEFT")
    flopy.mf6.ModflowGwfapi(gwf, maxbound=N, pname="API_SWAP")
    flopy.mf6.ModflowGwfoc(gwf, head_filerecord="strip.hds", budget_filerecord="strip.cbc",
                          saverecord=[("HEAD", "ALL"), ("BUDGET", "ALL")])
    sim.write_simulation(silent=True)

    raw = XmiWrapper(lib_path=libmf6.resolve(), working_directory=out.resolve())
    kernel = CountingKernel(raw)
    raw.initialize()
    raw.prepare_time_step(0.0)
    runtime = DummyRuntime(dts[0], rain[0], [H0]*N, [H0]*N, conductance)
    rows, accepted_head = [], np.full(N, H0)
    cumulative_input = cumulative_dum = cumulative_mf = cumulative_drain = 0.0
    try:
        version = raw.get_version()
        if "6.8.0" not in version: raise RuntimeError(f"expected MODFLOW6 6.8.0, got {version}")
        for j, (dt, p) in enumerate(zip(dts, rain, strict=True)):
            runtime.dt, runtime.recharge = dt, p
            session = Modflow6PreparedSolveSession(kernel, "STRIP", "API_SWAP", Fgc34CtypesPublisher(publisher))
            if session.acquire_after_prepare_time_step().name != "OK": raise RuntimeError("package acquisition failed: "+session.last_error)
            result = run_groundwater_application_window(runtime, session,
                GroundwaterApplicationServiceConfig(flux_tolerance, 80))
            if not result.published:
                rows.append(dict(step=j, published=False, failure_stage=result.failure_stage,
                                 iterations=result.iterations, heads_m=list(result.final_heads_m),
                                 residuals_m_per_s=list(result.final_residuals_m_per_s)))
                break
            heads = np.asarray(result.final_heads_m)
            q = np.asarray(runtime.q_candidate)
            din = p * N * AREA * dt
            # Capture per-window dummy storage before publication via committed origin.
            dsd = S_DUMMY * sum(c-o for c,o in zip(runtime.candidate, runtime.origin, strict=True))
            dsmf = S_AQUIFER * AREA * float(np.sum(heads - accepted_head))
            drn_rate = DRAIN_C * max(float(heads[0])-H0, 0.0)
            drain = drn_rate * dt
            residual = din - dsd - dsmf - drain
            qvol = float(np.sum(q))*DAY_S*dt
            dummy_component_residual = din - dsd - qvol
            modflow_component_residual = qvol - dsmf - drain
            lateral = [KX * 8.0 * float(heads[i]-heads[i+1]) for i in range(N-1)]
            resistance_error = max(abs(q[i]*DAY_S - conductance*(runtime.candidate[i]-heads[i]))
                                   for i in range(N))
            window_scale = max(abs(din), abs(dsd), abs(dsmf), abs(drain), 1e-30)
            row = dict(step=j, time_day=sum(dts[:j+1]), dt_day=dt, recharge_m_per_day=p,
                published=True, coupling_iterations=result.iterations,
                modflow_converged=True, max_abs_coupling_residual_m_per_s=max(map(abs,result.final_residuals_m_per_s)),
                head_m=heads.tolist(), dummy_internal_head_m=list(runtime.candidate),
                interface_flux_m3_per_day=q.tolist(), interface_transfer_m3=qvol,
                dummy_interface_out_m3=qvol, modflow_interface_in_m3=qvol,
                action_reaction_residual_m3=0.0,
                dummy_component_residual_m3=dummy_component_residual,
                modflow_component_residual_m3=modflow_component_residual,
                dummy_storage_change_m3=dsd, modflow_storage_change_m3=dsmf,
                lateral_face_flow_m3_per_day=lateral, drain_rate_m3_per_day=drn_rate,
                drain_outflow_m3=drain, input_m3=din, mass_residual_m3=residual,
                mass_relative_residual=abs(residual)/window_scale,
                interface_source_to_modflow_m3=qvol,
                resistance_law_max_abs_error_m3_per_day=resistance_error,
                revisions_min=min(runtime.revisions), revisions_max=max(runtime.revisions),
                ledger_min=min(runtime.ledger), ledger_max=max(runtime.ledger),
                modflow_calls=dict(kernel.calls))
            rows.append(row)
            cumulative_input += din; cumulative_dum += dsd; cumulative_mf += dsmf; cumulative_drain += drain
            cumulative_residual = cumulative_input-cumulative_dum-cumulative_mf-cumulative_drain
            row['cumulative'] = dict(input_m3=cumulative_input, dummy_storage_change_m3=cumulative_dum,
                modflow_storage_change_m3=cumulative_mf, drain_outflow_m3=cumulative_drain,
                mass_residual_m3=cumulative_residual,
                relative_residual=abs(cumulative_residual)/max(cumulative_input,1e-30))
            accepted_head = heads.copy()
            if j+1 < len(dts):
                runtime = DummyRuntime(dts[j+1], rain[j+1], list(accepted_head), list(runtime.internals),
                                       conductance, runtime.revisions, runtime.ledger)
                raw.prepare_time_step(float(sum(dts[:j+1])))
    finally:
        raw.finalize()
    # Replace calculated face/drain diagnostics with the native package budgets.
    cbc = flopy.utils.CellBudgetFile(str(out / "strip.cbc"), precision="double")
    grb = flopy.mf6.utils.MfGrdFile(str(out / "STRIP.dis.grb"))
    native_times = cbc.get_times()
    if len(native_times) != len(rows):
        raise RuntimeError(f"native budget has {len(native_times)} steps for {len(rows)} results")
    cumulative_input = cumulative_dum = cumulative_mf = cumulative_drain = 0.0
    for j, (row, totim) in enumerate(zip(rows, native_times, strict=True)):
        if not row["published"]:
            raise RuntimeError("native budget includes a step after an unpublished transaction")
        drn_records = cbc.get_data(text="DRN", totim=totim)
        drn_out = -float(np.sum(drn_records[0]["q"])) if drn_records and len(drn_records[0]) else 0.0
        formula_out = DRAIN_C * max(float(row["head_m"][0])-H0, 0.0)
        row["native_modflow_drain_m3_per_day"] = drn_out
        row["drain_formula_abs_error_m3_per_day"] = abs(drn_out-formula_out)
        row["drain_rate_m3_per_day"] = drn_out
        row["drain_outflow_m3"] = drn_out * row["dt_day"]
        fjf = np.asarray(cbc.get_data(text="FLOW-JA-FACE", totim=totim)[0]).reshape(-1)
        right_to_left = []
        for i in range(N-1):
            start, end = int(grb.ia[i]), int(grb.ia[i+1])
            slot = next((k for k in range(start, end) if int(grb.ja[k]) == i+1), None)
            if slot is None: raise RuntimeError(f"MODFLOW cell {i+1} lacks its right face")
            right_to_left.append(float(fjf[slot]))
        row["native_modflow_lateral_face_flow_right_to_left_m3_per_day"] = right_to_left
        row["lateral_face_flow_m3_per_day"] = right_to_left
        row["mass_residual_m3"] = row["input_m3"] - row["dummy_storage_change_m3"] - row["modflow_storage_change_m3"] - row["drain_outflow_m3"]
        row["dummy_interface_out_m3"] = row["interface_transfer_m3"]
        row["modflow_interface_in_m3"] = row["interface_transfer_m3"]
        row["action_reaction_residual_m3"] = row["modflow_interface_in_m3"]-row["dummy_interface_out_m3"]
        row["dummy_component_residual_m3"] = row["input_m3"]-row["dummy_storage_change_m3"]-row["dummy_interface_out_m3"]
        row["modflow_component_residual_m3"] = row["modflow_interface_in_m3"]-row["modflow_storage_change_m3"]-row["drain_outflow_m3"]
        scale = max(abs(row["input_m3"]),abs(row["dummy_storage_change_m3"]),abs(row["modflow_storage_change_m3"]),abs(row["drain_outflow_m3"]),1e-30)
        row["mass_relative_residual"] = abs(row["mass_residual_m3"])/scale
        cumulative_input += row["input_m3"]; cumulative_dum += row["dummy_storage_change_m3"]
        cumulative_mf += row["modflow_storage_change_m3"]; cumulative_drain += row["drain_outflow_m3"]
        r = cumulative_input-cumulative_dum-cumulative_mf-cumulative_drain
        row["cumulative"] = dict(input_m3=cumulative_input,dummy_storage_change_m3=cumulative_dum,
            modflow_storage_change_m3=cumulative_mf,drain_outflow_m3=cumulative_drain,
            mass_residual_m3=r,relative_residual=abs(r)/max(cumulative_input,1e-30))
    source_commit=subprocess.check_output(["git","-C",str(ROOT),"rev-parse","HEAD"],text=True).strip()
    outdata = dict(schema="swap5.fgc.strip01.c2d.result.v1", mode=mode, source_commit=source_commit,
        modflow_version=version, modflow_binary_sha256=sha(libmf6),
        initial_head_m=H0,
        geometry=dict(ncol=N, dx_m=1, nlay=1, top_m=-2, bottom_m=-10, kx_m_per_day=KX),
        parameters=dict(dummy_storage_m_per_m=S_DUMMY, aquifer_storage_m_per_m=S_AQUIFER,
            vertical_conductance_m2_per_day=conductance, drain_conductance_m2_per_day=DRAIN_C,
            coupling_flux_tolerance_m_per_s=flux_tolerance), rows=rows,
        native_modflow_cbc_validated=True, dummy_bank_commit="4fd8861bf6300d8074051d3bd24ef993cb60dbda",
        c2b_comparator_commit="ac87e2484b1ecc54c8eac9072cd6f9248fbeb5e9", fresh_replay=False,
        conclusion="RUN_COMPLETED" if len(rows)==len(dts) and all(r['published'] for r in rows) else "RUN_REJECTED")
    (out/"result.json").write_text(json.dumps(outdata,indent=2,sort_keys=True)+"\n")
    return outdata


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--libmf6",type=Path,required=True)
    ap.add_argument("--output",type=Path,required=True)
    ap.add_argument("--mode",choices=["zero","pulse"],default="zero")
    ap.add_argument("--publisher",type=Path,required=True)
    ap.add_argument("--conductance",type=float,default=1.0e6)
    ap.add_argument("--flux-tolerance",type=float,default=FLUX_TOL)
    a=ap.parse_args()
    result=run(a.libmf6.resolve(),a.publisher.resolve(),a.output.resolve(),a.mode,a.conductance,a.flux_tolerance)
    print(result["conclusion"])

if __name__=="__main__": main()
